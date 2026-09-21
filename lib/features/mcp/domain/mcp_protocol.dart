import 'mcp_tool_descriptor.dart';

/// JSON-RPC 2.0 envelopes and the subset of the MCP spec Nero speaks.

const String mcpProtocolVersion = '2025-06-18';

/// Versions Nero can negotiate down to when a server reports an older one.
const List<String> mcpSupportedProtocolVersions = <String>[
  '2025-06-18',
  '2025-03-26',
  '2024-11-05',
];

/// Method names used by the client.
abstract final class McpMethods {
  static const String initialize = 'initialize';
  static const String initialized = 'notifications/initialized';
  static const String ping = 'ping';
  static const String toolsList = 'tools/list';
  static const String toolsCall = 'tools/call';
  static const String cancelled = 'notifications/cancelled';
}

class McpRequest {
  const McpRequest({
    required this.id,
    required this.method,
    this.params = const <String, Object?>{},
  });

  final int id;
  final String method;
  final Map<String, Object?> params;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'jsonrpc': '2.0',
    'id': id,
    'method': method,
    if (params.isNotEmpty) 'params': params,
  };
}

class McpNotification {
  const McpNotification({
    required this.method,
    this.params = const <String, Object?>{},
  });

  final String method;
  final Map<String, Object?> params;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'jsonrpc': '2.0',
    'method': method,
    if (params.isNotEmpty) 'params': params,
  };
}

/// A decoded JSON-RPC message: either a response or a server-initiated request.
class McpMessage {
  const McpMessage({
    this.id,
    this.result,
    this.error,
    this.method,
    this.params,
  });

  /// Null for server notifications.
  final int? id;

  final Map<String, Object?>? result;

  /// `{code, message, data}` when the call failed.
  final Map<String, Object?>? error;

  /// Set for server-initiated requests/notifications.
  final String? method;

  final Map<String, Object?>? params;

  bool get isError => error != null;

  bool get isServerInitiated => method != null && id == null;

  String? get errorMessage {
    final message = error?['message']?.toString();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    return error == null ? null : 'MCP request failed.';
  }

  factory McpMessage.fromJson(Map<String, dynamic> json) {
    final rawResult = json['result'];
    final rawError = json['error'];
    final rawParams = json['params'];
    return McpMessage(
      id: (json['id'] as num?)?.toInt(),
      result: rawResult is Map
          ? Map<String, Object?>.from(rawResult)
          : (rawResult == null ? null : <String, Object?>{'value': rawResult}),
      error: rawError is Map
          ? Map<String, Object?>.from(rawError)
          : (rawError == null ? null : <String, Object?>{'message': '$rawError'}),
      method: json['method']?.toString(),
      params: rawParams is Map ? Map<String, Object?>.from(rawParams) : null,
    );
  }
}

/// Decoded `initialize` result.
class McpInitializeResult {
  const McpInitializeResult({
    required this.protocolVersion,
    this.serverName,
    this.serverVersion,
    this.instructions,
    this.capabilities = const <String, Object?>{},
  });

  final String protocolVersion;
  final String? serverName;
  final String? serverVersion;
  final String? instructions;
  final Map<String, Object?> capabilities;

  bool get supportsTools =>
      capabilities.containsKey('tools') ||
      // Older servers omit capabilities entirely but still serve tools.
      capabilities.isEmpty;

  factory McpInitializeResult.fromResult(Map<String, Object?> result) {
    final serverInfo = result['serverInfo'];
    final rawCapabilities = result['capabilities'];
    return McpInitializeResult(
      protocolVersion:
          result['protocolVersion']?.toString() ?? mcpProtocolVersion,
      serverName: serverInfo is Map ? serverInfo['name']?.toString() : null,
      serverVersion:
          serverInfo is Map ? serverInfo['version']?.toString() : null,
      instructions: result['instructions']?.toString(),
      capabilities: rawCapabilities is Map
          ? Map<String, Object?>.from(rawCapabilities)
          : const <String, Object?>{},
    );
  }
}

/// One page of `tools/list`.
class McpToolListPage {
  const McpToolListPage({required this.tools, this.nextCursor});

  final List<McpToolDescriptor> tools;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  factory McpToolListPage.fromResult(
    Map<String, Object?> result, {
    required String serverId,
  }) {
    final rawTools = result['tools'];
    final tools = <McpToolDescriptor>[];
    if (rawTools is List) {
      for (final item in rawTools) {
        if (item is! Map) {
          continue;
        }
        final map = Map<String, dynamic>.from(item);
        final name = map['name']?.toString().trim() ?? '';
        if (name.isEmpty) {
          continue;
        }
        final rawAnnotations = map['annotations'];
        final rawSchema = map['inputSchema'];
        tools.add(
          McpToolDescriptor(
            serverId: serverId,
            name: name,
            title: map['title']?.toString(),
            description: map['description']?.toString() ?? '',
            inputSchema: rawSchema is Map
                ? Map<String, Object?>.from(rawSchema)
                : const <String, Object?>{},
            annotations: rawAnnotations is Map
                ? McpToolAnnotations.fromJson(
                    Map<String, dynamic>.from(rawAnnotations),
                  )
                : const McpToolAnnotations(),
          ),
        );
      }
    }
    return McpToolListPage(
      tools: tools,
      nextCursor: result['nextCursor']?.toString(),
    );
  }
}

/// One item of a `tools/call` result's `content` array.
class McpContentItem {
  const McpContentItem({
    required this.type,
    this.text,
    this.data,
    this.mimeType,
    this.uri,
    this.name,
  });

  final String type;
  final String? text;

  /// Base64 payload for `image` items.
  final String? data;
  final String? mimeType;
  final String? uri;
  final String? name;

  factory McpContentItem.fromJson(Map<String, dynamic> json) {
    final resource = json['resource'];
    return McpContentItem(
      type: json['type']?.toString() ?? 'unknown',
      text: json['text']?.toString() ??
          (resource is Map ? resource['text']?.toString() : null),
      data: json['data']?.toString() ??
          (resource is Map ? resource['blob']?.toString() : null),
      mimeType: json['mimeType']?.toString() ??
          (resource is Map ? resource['mimeType']?.toString() : null),
      uri: json['uri']?.toString() ??
          (resource is Map ? resource['uri']?.toString() : null),
      name: json['name']?.toString(),
    );
  }
}

/// Decoded `tools/call` result.
class McpToolCallResult {
  const McpToolCallResult({
    required this.content,
    this.isError = false,
  });

  final List<McpContentItem> content;
  final bool isError;

  /// Concatenated text of every text item.
  String get text {
    final buffer = StringBuffer();
    for (final item in content) {
      final value = item.text;
      if (value == null || value.trim().isEmpty) {
        continue;
      }
      if (buffer.isNotEmpty) {
        buffer.write('\n');
      }
      buffer.write(value.trim());
    }
    return buffer.toString();
  }

  factory McpToolCallResult.fromResult(Map<String, Object?> result) {
    final rawContent = result['content'];
    return McpToolCallResult(
      content: rawContent is List
          ? rawContent
                .whereType<Map>()
                .map(
                  (item) => McpContentItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const <McpContentItem>[],
      isError: result['isError'] == true,
    );
  }
}
