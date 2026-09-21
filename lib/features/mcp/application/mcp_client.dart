import 'dart:async';
import 'dart:io';

import '../domain/mcp_protocol.dart';
import '../domain/mcp_server_config.dart';
import '../domain/mcp_tool_descriptor.dart';
import 'mcp_sse_transport.dart';
import 'mcp_streamable_http_transport.dart';
import 'mcp_transport.dart';

/// Creates the right transport for a server config. Injectable so tests can
/// drive an in-memory transport.
typedef McpTransportFactory = McpTransport Function(McpServerConfig config);

McpTransport defaultMcpTransportFactory(McpServerConfig config) {
  return switch (config.transport) {
    McpTransportKind.streamableHttp => McpStreamableHttpTransport(
      config: config,
    ),
    McpTransportKind.sse => McpSseTransport(config: config),
  };
}

/// Speaks the MCP client side: handshake, tool discovery and tool calls.
class McpClient {
  McpClient({
    required this.config,
    McpTransport? transport,
    McpTransportFactory? transportFactory,
  }) : _transport =
           transport ??
           (transportFactory ?? defaultMcpTransportFactory)(config);

  final McpServerConfig config;
  final McpTransport _transport;

  int _nextId = 1;
  bool _initialized = false;
  McpInitializeResult? _initializeResult;

  McpInitializeResult? get initializeResult => _initializeResult;

  bool get isInitialized => _initialized;

  /// Performs the MCP handshake. Idempotent: repeated calls reuse the session.
  ///
  /// The negotiated version is downgraded to the newest version this client
  /// supports when the server reports something newer or unknown, per the spec.
  Future<McpInitializeResult> initialize({String? sessionId}) async {
    if (_initialized && _initializeResult != null) {
      return _initializeResult!;
    }

    final request = McpRequest(
      id: _nextId++,
      method: McpMethods.initialize,
      params: <String, Object?>{
        'protocolVersion': mcpProtocolVersion,
        'capabilities': const <String, Object?>{},
        'clientInfo': const <String, Object?>{
          'name': 'nero',
          'version': '1.0.0',
        },
      },
    );

    final response = await _transport.send(request, sessionId: sessionId);
    final message = response.responseFor(request.id);
    if (message == null) {
      throw const McpTransportException(
        'MCP server did not answer the initialize request.',
      );
    }
    if (message.isError) {
      throw McpTransportException(
        'MCP initialize failed: ${message.errorMessage}',
      );
    }

    final result = McpInitializeResult.fromResult(
      message.result ?? const <String, Object?>{},
    );
    final negotiated = mcpSupportedProtocolVersions.contains(
      result.protocolVersion,
    )
        ? result.protocolVersion
        : mcpProtocolVersion;

    _initializeResult = McpInitializeResult(
      protocolVersion: negotiated,
      serverName: result.serverName,
      serverVersion: result.serverVersion,
      instructions: result.instructions,
      capabilities: result.capabilities,
    );
    _initialized = true;

    // Best-effort; a server failing to accept the notification is not fatal.
    try {
      await _transport.notify(
        const McpNotification(method: McpMethods.initialized),
        sessionId: response.sessionId,
      );
    } catch (_) {}

    return _initializeResult!;
  }

  /// Lists every tool, following `nextCursor` pagination.
  Future<List<McpToolDescriptor>> listTools({int maxPages = 10}) async {
    await initialize();
    final tools = <McpToolDescriptor>[];
    String? cursor;
    var page = 0;
    while (page < maxPages) {
      page += 1;
      final request = McpRequest(
        id: _nextId++,
        method: McpMethods.toolsList,
        params: <String, Object?>{
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        },
      );
      final response = await _transport.send(request);
      final message = response.responseFor(request.id);
      if (message == null) {
        throw const McpTransportException(
          'MCP server did not answer tools/list.',
        );
      }
      if (message.isError) {
        throw McpTransportException(
          'MCP tools/list failed: ${message.errorMessage}',
        );
      }
      final toolPage = McpToolListPage.fromResult(
        message.result ?? const <String, Object?>{},
        serverId: config.id,
      );
      tools.addAll(toolPage.tools);
      if (!toolPage.hasMore) {
        break;
      }
      cursor = toolPage.nextCursor;
    }
    return List<McpToolDescriptor>.unmodifiable(tools);
  }

  /// Invokes one tool. Never throws for a tool-level failure — that is
  /// reported as `isError` on the result so the model can react to it.
  Future<McpToolCallResult> callTool({
    required String name,
    required Map<String, dynamic> arguments,
  }) async {
    await initialize();
    final request = McpRequest(
      id: _nextId++,
      method: McpMethods.toolsCall,
      params: <String, Object?>{'name': name, 'arguments': arguments},
    );
    final response = await _transport.send(request);
    final message = response.responseFor(request.id);
    if (message == null) {
      throw const McpTransportException(
        'MCP server did not answer tools/call.',
      );
    }
    if (message.isError) {
      return McpToolCallResult(
        content: <McpContentItem>[
          McpContentItem(type: 'text', text: message.errorMessage),
        ],
        isError: true,
      );
    }
    return McpToolCallResult.fromResult(
      message.result ?? const <String, Object?>{},
    );
  }

  /// Connectivity check used by the server editor's "Test connection" button.
  Future<void> ping() async {
    await initialize();
    final request = McpRequest(id: _nextId++, method: McpMethods.ping);
    try {
      await _transport.send(request);
    } on McpTransportException catch (error) {
      // Servers are allowed to not implement ping; only real connectivity
      // failures should surface.
      if (error.statusCode == 405 || error.statusCode == 404) {
        return;
      }
      rethrow;
    }
  }

  Future<void> close() => _transport.close();
}

/// Maps a low-level failure to a user-facing message.
String describeMcpFailure(Object error) {
  if (error is McpTransportException) {
    if (error.isUnauthorized) {
      return 'Authentication failed. Add or refresh this server\'s token.';
    }
    return error.message;
  }
  if (error is TimeoutException) {
    return 'The server did not respond in time.';
  }
  if (error is SocketException) {
    return 'Could not reach the server: ${error.message}';
  }
  return error.toString();
}
