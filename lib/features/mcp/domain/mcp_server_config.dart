/// Connection settings for one remote Model Context Protocol server.
library;

/// How Nero talks to the server. Android cannot spawn local processes, so only
/// remote transports are supported.
enum McpTransportKind { streamableHttp, sse }

extension McpTransportKindX on McpTransportKind {
  String get name => switch (this) {
    McpTransportKind.streamableHttp => 'streamableHttp',
    McpTransportKind.sse => 'sse',
  };

  String get label => switch (this) {
    McpTransportKind.streamableHttp => 'Streamable HTTP',
    McpTransportKind.sse => 'HTTP + SSE (legacy)',
  };

  String get description => switch (this) {
    McpTransportKind.streamableHttp =>
      'Single endpoint, JSON or SSE responses. Recommended.',
    McpTransportKind.sse =>
      'Separate SSE stream plus a POST endpoint. Older servers.',
  };

  static McpTransportKind fromName(String? value) {
    return switch (value) {
      'sse' => McpTransportKind.sse,
      _ => McpTransportKind.streamableHttp,
    };
  }
}

class McpServerConfig {
  const McpServerConfig({
    required this.id,
    required this.displayName,
    required this.url,
    this.transport = McpTransportKind.streamableHttp,
    this.headers = const <String, String>{},
    this.authToken = '',
    this.enabled = true,
    this.autoApprove = false,
    this.timeoutMs = 20000,
    this.allowedToolNames = const <String>[],
    this.blockedToolNames = const <String>[],
  });

  final String id;
  final String displayName;
  final String url;
  final McpTransportKind transport;

  /// Extra headers sent with every request (excluding auth).
  final Map<String, String> headers;

  /// Bearer token sent as `Authorization: Bearer <token>`. Stored on-device.
  final String authToken;

  final bool enabled;

  /// When true, tools from this server skip the approval gate.
  final bool autoApprove;

  final int timeoutMs;

  /// When non-empty, only these tool names are exposed to the model.
  final List<String> allowedToolNames;

  /// Never exposed to the model, even if allowed.
  final List<String> blockedToolNames;

  /// Whether [toolName] may be exposed, before per-tool enable flags apply.
  bool allowsTool(String toolName) {
    if (blockedToolNames.contains(toolName)) {
      return false;
    }
    if (allowedToolNames.isEmpty) {
      return true;
    }
    return allowedToolNames.contains(toolName);
  }

  String get maskedToken {
    final trimmed = authToken.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.length <= 6) {
      return '••••';
    }
    return '••••${trimmed.substring(trimmed.length - 4)}';
  }

  McpServerConfig copyWith({
    String? id,
    String? displayName,
    String? url,
    McpTransportKind? transport,
    Map<String, String>? headers,
    String? authToken,
    bool? enabled,
    bool? autoApprove,
    int? timeoutMs,
    List<String>? allowedToolNames,
    List<String>? blockedToolNames,
  }) {
    return McpServerConfig(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      url: url ?? this.url,
      transport: transport ?? this.transport,
      headers: headers ?? this.headers,
      authToken: authToken ?? this.authToken,
      enabled: enabled ?? this.enabled,
      autoApprove: autoApprove ?? this.autoApprove,
      timeoutMs: timeoutMs ?? this.timeoutMs,
      allowedToolNames: allowedToolNames ?? this.allowedToolNames,
      blockedToolNames: blockedToolNames ?? this.blockedToolNames,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'displayName': displayName,
    'url': url,
    'transport': transport.name,
    'headers': headers,
    'authToken': authToken,
    'enabled': enabled,
    'autoApprove': autoApprove,
    'timeoutMs': timeoutMs,
    'allowedToolNames': allowedToolNames,
    'blockedToolNames': blockedToolNames,
  };

  factory McpServerConfig.fromJson(Map<String, dynamic> json) {
    final rawHeaders = json['headers'];
    final rawAllowed = json['allowedToolNames'];
    final rawBlocked = json['blockedToolNames'];
    return McpServerConfig(
      id: json['id']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'MCP server',
      url: json['url']?.toString() ?? '',
      transport: McpTransportKindX.fromName(json['transport']?.toString()),
      headers: rawHeaders is Map
          ? <String, String>{
              for (final entry in rawHeaders.entries)
                entry.key.toString(): entry.value?.toString() ?? '',
            }
          : const <String, String>{},
      authToken: json['authToken']?.toString() ?? '',
      enabled: json['enabled'] != false,
      autoApprove: json['autoApprove'] == true,
      timeoutMs: (json['timeoutMs'] as num?)?.toInt() ?? 20000,
      allowedToolNames: rawAllowed is List
          ? rawAllowed.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      blockedToolNames: rawBlocked is List
          ? rawBlocked.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
    );
  }
}
