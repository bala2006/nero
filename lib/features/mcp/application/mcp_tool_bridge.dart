import '../../capabilities/domain/capability_registry.dart';
import '../../runtime/domain/agent_policy.dart';
import '../domain/mcp_tool_descriptor.dart';
import 'mcp_schema_projector.dart';

/// Converts discovered MCP tools into [CapabilityDefinition]s.
///
/// Everything a server publishes is passed through [sanitizeMcpText] and
/// [projectMcpInputSchema] first, because the text and schema land in the
/// model's prompt and are therefore a prompt-injection surface.
class McpToolBridge {
  const McpToolBridge();

  CapabilityDefinition toCapability({
    required McpToolDescriptor tool,
    required String serverId,
    required String serverDisplayName,
  }) {
    final risk = tool.annotations.riskLevel;
    return CapabilityDefinition(
      key: 'mcp.$serverId.${tool.name}',
      version: 1,
      displayName: sanitizeMcpText(tool.displayTitle, maxLength: 90),
      description: sanitizeMcpText(
        tool.description.isEmpty
            ? 'Tool "${tool.name}" from MCP server $serverDisplayName.'
            : tool.description,
      ),
      kind: CapabilityKind.tool,
      category: risk == ToolRiskLevel.readOnly
          ? CapabilityCategory.read
          : CapabilityCategory.effect,
      sideEffectPolicy: risk == ToolRiskLevel.readOnly
          ? CapabilitySideEffectPolicy.readOnly
          : CapabilitySideEffectPolicy.networkWrite,
      singleUse: false,
      reliabilityClass: CapabilityReliabilityClass.medium,
      modelExposure: tool.enabled
          ? CapabilityModelExposure.visible
          : CapabilityModelExposure.hidden,
      toolDescriptor: CapabilityToolDescriptor(
        name: tool.qualifiedName,
        description: _modelDescription(
          tool: tool,
          serverDisplayName: serverDisplayName,
        ),
        parameters: projectMcpInputSchema(tool.inputSchema),
      ),
      tags: <String>[
        'mcp',
        'mcp:$serverId',
        if (risk == ToolRiskLevel.readOnly) 'read',
        if (risk == ToolRiskLevel.destructive) 'destructive',
      ],
    );
  }

  /// The description the model actually sees.
  ///
  /// The server name is prepended so the model can tell similarly named tools
  /// apart, and the surrounding guidance is Nero-authored rather than
  /// server-authored.
  String _modelDescription({
    required McpToolDescriptor tool,
    required String serverDisplayName,
  }) {
    final purpose = sanitizeMcpText(tool.description);
    final buffer = StringBuffer()
      ..write('External tool "')
      ..write(tool.name)
      ..write('" provided by the MCP server "')
      ..write(sanitizeMcpText(serverDisplayName, maxLength: 60))
      ..write('". ');
    if (purpose.isNotEmpty) {
      buffer
        ..write('It reports: ')
        ..write(purpose)
        ..write(' ');
    }
    buffer.write(
      'Call it only when the user\'s request actually needs it, and use the '
      'exact arguments its schema defines.',
    );
    return buffer.toString();
  }
}
