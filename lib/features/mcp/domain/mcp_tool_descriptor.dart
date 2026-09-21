import '../../runtime/domain/agent_policy.dart';

/// How approval is decided for a single discovered MCP tool.
enum McpToolApprovalMode {
  /// Use the server's `autoApprove` flag and the global approval policy.
  inherit,

  /// Always ask before calling this tool.
  alwaysAsk,

  /// Never ask for this tool (user opted in explicitly).
  never,
}

extension McpToolApprovalModeX on McpToolApprovalMode {
  String get name => switch (this) {
    McpToolApprovalMode.inherit => 'inherit',
    McpToolApprovalMode.alwaysAsk => 'alwaysAsk',
    McpToolApprovalMode.never => 'never',
  };

  String get label => switch (this) {
    McpToolApprovalMode.inherit => 'Use default',
    McpToolApprovalMode.alwaysAsk => 'Always ask',
    McpToolApprovalMode.never => 'Never ask',
  };

  static McpToolApprovalMode fromName(String? value) {
    return switch (value) {
      'alwaysAsk' => McpToolApprovalMode.alwaysAsk,
      'never' => McpToolApprovalMode.never,
      _ => McpToolApprovalMode.inherit,
    };
  }
}

/// Safety hints a server may publish in `annotations`.
///
/// These are attacker-controlled: they are treated as *additional* caution,
/// never as permission. A tool claiming `readOnlyHint` still has to satisfy the
/// user's approval policy.
class McpToolAnnotations {
  const McpToolAnnotations({
    this.readOnlyHint = false,
    this.destructiveHint = false,
    this.idempotentHint = false,
    this.openWorldHint = false,
  });

  final bool readOnlyHint;
  final bool destructiveHint;
  final bool idempotentHint;
  final bool openWorldHint;

  factory McpToolAnnotations.fromJson(Map<String, dynamic> json) {
    return McpToolAnnotations(
      readOnlyHint: json['readOnlyHint'] == true,
      destructiveHint: json['destructiveHint'] == true,
      idempotentHint: json['idempotentHint'] == true,
      openWorldHint: json['openWorldHint'] == true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'readOnlyHint': readOnlyHint,
    'destructiveHint': destructiveHint,
    'idempotentHint': idempotentHint,
    'openWorldHint': openWorldHint,
  };

  /// Conservative risk classification.
  ///
  /// Absent annotations are treated as the *highest* risk, not the lowest: a
  /// server that says nothing has not promised anything.
  ToolRiskLevel get riskLevel {
    if (destructiveHint) {
      return ToolRiskLevel.destructive;
    }
    if (readOnlyHint) {
      return ToolRiskLevel.readOnly;
    }
    return ToolRiskLevel.unknown;
  }

  bool get hasAnyHint =>
      readOnlyHint || destructiveHint || idempotentHint || openWorldHint;
}

class McpToolDescriptor {
  const McpToolDescriptor({
    required this.serverId,
    required this.name,
    required this.description,
    this.title,
    this.inputSchema = const <String, Object?>{},
    this.annotations = const McpToolAnnotations(),
    this.enabled = true,
    this.approvalMode = McpToolApprovalMode.inherit,
  });

  final String serverId;

  /// Tool name as published by the server (un-namespaced).
  final String name;

  final String? title;
  final String description;
  final Map<String, Object?> inputSchema;
  final McpToolAnnotations annotations;

  /// Whether the user has exposed this tool to the model.
  final bool enabled;

  final McpToolApprovalMode approvalMode;

  String get displayTitle =>
      (title != null && title!.trim().isNotEmpty) ? title! : name;

  /// Fully qualified tool name handed to the model, so tools from different
  /// servers can never collide.
  String get qualifiedName => qualifiedToolName(serverId, name);

  McpToolDescriptor copyWith({
    String? serverId,
    String? name,
    String? title,
    String? description,
    Map<String, Object?>? inputSchema,
    McpToolAnnotations? annotations,
    bool? enabled,
    McpToolApprovalMode? approvalMode,
  }) {
    return McpToolDescriptor(
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      title: title ?? this.title,
      description: description ?? this.description,
      inputSchema: inputSchema ?? this.inputSchema,
      annotations: annotations ?? this.annotations,
      enabled: enabled ?? this.enabled,
      approvalMode: approvalMode ?? this.approvalMode,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'serverId': serverId,
    'name': name,
    'title': title,
    'description': description,
    'inputSchema': inputSchema,
    'annotations': annotations.toJson(),
    'enabled': enabled,
    'approvalMode': approvalMode.name,
  };

  factory McpToolDescriptor.fromJson(Map<String, dynamic> json) {
    final rawSchema = json['inputSchema'];
    final rawAnnotations = json['annotations'];
    return McpToolDescriptor(
      serverId: json['serverId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      title: json['title']?.toString(),
      description: json['description']?.toString() ?? '',
      inputSchema: rawSchema is Map
          ? Map<String, Object?>.from(rawSchema)
          : const <String, Object?>{},
      annotations: rawAnnotations is Map
          ? McpToolAnnotations.fromJson(
              Map<String, dynamic>.from(rawAnnotations),
            )
          : const McpToolAnnotations(),
      enabled: json['enabled'] != false,
      approvalMode: McpToolApprovalModeX.fromName(
        json['approvalMode']?.toString(),
      ),
    );
  }
}

/// `mcp__<serverSlug>__<toolName>`.
///
/// The double-underscore separator keeps the name inside the model's
/// `^[a-zA-Z0-9_-]{1,64}$` tool-name allowance for realistic server and tool
/// names, and makes the owner recoverable without a lookup table.
String qualifiedToolName(String serverId, String toolName) {
  return 'mcp__${slugifyForToolName(serverId)}__${slugifyForToolName(toolName)}';
}

/// Lowercases and replaces anything outside `[a-z0-9_]` with `_`, then caps the
/// length so the qualified name stays within the model's limit.
String slugifyForToolName(String value) {
  final slug = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  if (slug.isEmpty) {
    return 'unnamed';
  }
  return slug.length <= 24 ? slug : slug.substring(0, 24);
}

/// Extracts `<serverSlug>` and `<toolName>` from a qualified name.
({String serverSlug, String toolSlug})? splitQualifiedToolName(
  String qualifiedName,
) {
  if (!qualifiedName.startsWith('mcp__')) {
    return null;
  }
  final remainder = qualifiedName.substring('mcp__'.length);
  final separator = remainder.indexOf('__');
  if (separator <= 0) {
    return null;
  }
  return (
    serverSlug: remainder.substring(0, separator),
    toolSlug: remainder.substring(separator + 2),
  );
}
