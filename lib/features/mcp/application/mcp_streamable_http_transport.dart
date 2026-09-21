import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/mcp_protocol.dart';
import '../domain/mcp_server_config.dart';
import 'mcp_sse_parser.dart';
import 'mcp_transport.dart';

/// MCP "Streamable HTTP" transport.
///
/// One endpoint accepts JSON-RPC requests over POST and answers either with a
/// JSON body or with an SSE stream. The server may hand back an
/// `Mcp-Session-Id` header that must be echoed on subsequent calls.
///
/// Implemented directly on `dart:io`'s `HttpClient` to match how the rest of
/// Nero talks to remote services, and to keep timeouts and cancellation under
/// our control.
class McpStreamableHttpTransport implements McpTransport {
  McpStreamableHttpTransport({
    required this.config,
    HttpClient? httpClient,
    Duration? timeout,
  }) : _httpClient = httpClient,
       _timeout = timeout ?? Duration(milliseconds: config.timeoutMs);

  final McpServerConfig config;
  final Duration _timeout;

  HttpClient? _httpClient;
  String? _sessionId;
  bool _closed = false;

  /// Session id discovered so far, if the server uses sessions.
  String? get sessionId => _sessionId;

  @override
  Future<McpTransportResponse> send(
    McpRequest request, {
    String? sessionId,
  }) async {
    final effectiveSession = sessionId ?? _sessionId;
    final response = await _post(
      request.toJson(),
      effectiveSession: effectiveSession,
    );
    return response;
  }

  @override
  Future<void> notify(
    McpNotification notification, {
    String? sessionId,
  }) async {
    await _post(
      notification.toJson(),
      effectiveSession: sessionId ?? _sessionId,
      expectResponse: false,
    );
  }

  @override
  Future<void> close() async {
    _closed = true;
    _httpClient?.close(force: true);
    _httpClient = null;
  }

  Future<McpTransportResponse> _post(
    Map<String, dynamic> payload, {
    required String? effectiveSession,
    bool expectResponse = true,
  }) async {
    if (_closed) {
      throw const McpTransportException('MCP transport is closed.');
    }
    final endpoint = Uri.tryParse(config.url.trim());
    if (endpoint == null || !endpoint.hasScheme) {
      throw McpTransportException(
        'Invalid MCP server URL: "${config.url}".',
      );
    }

    final client = _httpClient ??= HttpClient();
    client.connectionTimeout = _timeout;

    try {
      final request = await client.postUrl(endpoint).timeout(_timeout);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json, text/event-stream',
      );
      request.headers.set('mcp-protocol-version', mcpProtocolVersion);
      if (effectiveSession != null && effectiveSession.isNotEmpty) {
        request.headers.set('mcp-session-id', effectiveSession);
      }
      _applyAuth(request);
      request.add(utf8.encode(jsonEncode(payload)));

      final response = await request.close().timeout(_timeout);
      final returnedSession =
          response.headers.value('mcp-session-id') ?? effectiveSession;
      if (returnedSession != null && returnedSession.isNotEmpty) {
        _sessionId = returnedSession;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        // Drain so the socket is reusable, then report as auth failure.
        await response.drain<void>().catchError((_) {});
        throw McpTransportException(
          'MCP server rejected the credentials (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode == 202 || response.statusCode == 204) {
        await response.drain<void>().catchError((_) {});
        return McpTransportResponse(sessionId: returnedSession);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response
            .transform(utf8.decoder)
            .join()
            .catchError((_) => '');
        throw McpTransportException(
          'MCP request failed (${response.statusCode}): '
          '${_truncate(body, 300)}',
          statusCode: response.statusCode,
        );
      }

      final contentType =
          response.headers.contentType?.mimeType.toLowerCase() ?? '';
      if (contentType.contains('text/event-stream')) {
        return McpTransportResponse(
          messages: await _readSseStream(response),
          sessionId: returnedSession,
        );
      }

      final body = await response.transform(utf8.decoder).join();
      if (body.trim().isEmpty) {
        return McpTransportResponse(sessionId: returnedSession);
      }
      return McpTransportResponse(
        messages: _decodeJsonBody(body),
        sessionId: returnedSession,
      );
    } on McpTransportException {
      rethrow;
    } on TimeoutException {
      _httpClient?.close(force: true);
      _httpClient = null;
      throw McpTransportException(
        'MCP request timed out after ${_timeout.inSeconds}s.',
      );
    } on SocketException catch (error) {
      throw McpTransportException('MCP connection failed: ${error.message}');
    } catch (error) {
      throw McpTransportException('MCP request failed: $error');
    }
  }

  void _applyAuth(HttpClientRequest request) {
    final token = config.authToken.trim();
    if (token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    config.headers.forEach((name, value) {
      if (name.trim().isEmpty) {
        return;
      }
      try {
        request.headers.set(name, value);
      } catch (_) {
        // Ignore headers the platform refuses; they are user-supplied.
      }
    });
  }

  Future<List<McpMessage>> _readSseStream(HttpClientResponse response) async {
    final parser = SseParser();
    final messages = <McpMessage>[];
    await for (final line
        in response
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      final frame = parser.addLine(line);
      if (frame == null) {
        continue;
      }
      final decoded = _tryDecodeMessage(frame.data);
      if (decoded != null) {
        messages.add(decoded);
      }
    }
    final trailing = parser.flush();
    if (trailing != null) {
      final decoded = _tryDecodeMessage(trailing.data);
      if (decoded != null) {
        messages.add(decoded);
      }
    }
    return messages;
  }

  List<McpMessage> _decodeJsonBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => McpMessage.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false);
      }
      if (decoded is Map) {
        return <McpMessage>[
          McpMessage.fromJson(Map<String, dynamic>.from(decoded)),
        ];
      }
    } catch (_) {
      // Fall through to the exception below.
    }
    throw McpTransportException(
      'MCP server returned an unreadable JSON body: '
      '${_truncate(body, 200)}',
    );
  }

  McpMessage? _tryDecodeMessage(String data) {
    final trimmed = data.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return McpMessage.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return null;
  }

  String _truncate(String value, int max) {
    final collapsed = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.length <= max
        ? collapsed
        : '${collapsed.substring(0, max)}…';
  }
}
