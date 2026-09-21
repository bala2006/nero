import 'dart:convert';

import '../../capabilities/application/capability_catalog.dart';
import '../../capabilities/domain/capability_registry.dart';
import '../domain/agent_policy.dart';

/// Classifies how dangerous a tool call is, for the approval gate.
///
/// Risk comes from the capability's own `sideEffectPolicy` rather than from a
/// hard-coded name list, so a newly registered MCP tool or sandbox tool is
/// classified the moment it appears.
class ToolRiskClassifier {
  ToolRiskClassifier({CapabilityCatalog? catalog})
    : _catalog = catalog ?? CapabilityCatalog.instance;

  final CapabilityCatalog _catalog;

  ToolRiskLevel classify(String toolName) {
    final capability = _catalog.byToolName(toolName);
    if (capability != null) {
      // A remote tool that only read is the one case where a network call is
      // treated as safe; a destructive hint always outranks it.
      if (capability.tags.contains('destructive')) {
        return ToolRiskLevel.destructive;
      }
      if (capability.tags.contains('read') &&
          capability.sideEffectPolicy == CapabilitySideEffectPolicy.readOnly) {
        return ToolRiskLevel.readOnly;
      }
      return switch (capability.sideEffectPolicy) {
        CapabilitySideEffectPolicy.none ||
        CapabilitySideEffectPolicy.readOnly => ToolRiskLevel.readOnly,
        CapabilitySideEffectPolicy.localArtifactWrite ||
        CapabilitySideEffectPolicy.localStateWrite => ToolRiskLevel.write,
        CapabilitySideEffectPolicy.networkWrite => ToolRiskLevel.write,
      };
    }
    if (toolName.startsWith('mcp__')) {
      // Unknown remote tool with no capability entry: assume it can act.
      return ToolRiskLevel.unknown;
    }
    if (toolName.startsWith('sandbox_')) {
      return ToolRiskLevel.write;
    }
    return ToolRiskLevel.unknown;
  }

  /// One-line, truncated rendering of a tool call's arguments for the approval
  /// prompt. Never includes obviously secret-looking values verbatim.
  static String summarizeArguments(Map<String, dynamic> arguments) {
    if (arguments.isEmpty) {
      return 'No arguments';
    }
    final redacted = <String, Object?>{};
    arguments.forEach((key, value) {
      final lowered = key.toLowerCase();
      final looksSecret =
          lowered.contains('token') ||
          lowered.contains('key') ||
          lowered.contains('secret') ||
          lowered.contains('password') ||
          lowered.contains('authorization');
      redacted[key] = looksSecret ? '••••' : value;
    });
    try {
      final encoded = jsonEncode(redacted);
      return encoded.length <= 400
          ? encoded
          : '${encoded.substring(0, 400)}…';
    } catch (_) {
      return '$redacted';
    }
  }
}

/// Alias kept short for the approval gate's own signature.
typedef ToolRiskResolver = ToolRiskLevel Function(String toolName);
