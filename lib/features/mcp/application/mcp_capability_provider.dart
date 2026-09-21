import '../../capabilities/application/capability_provider.dart';
import '../../capabilities/domain/capability_registry.dart';
import '../domain/mcp_server_config.dart';
import '../domain/mcp_tool_descriptor.dart';
import 'mcp_tool_bridge.dart';

/// Exposes every enabled MCP tool as a model-visible capability.
///
/// Registered once and refreshed by [McpRegistry]; [bumpRevision] must be
/// called after a refresh so the catalog rebuilds and the tool selector drops
/// its decision cache.
class McpCapabilityProvider implements CapabilityProvider {
  McpCapabilityProvider({
    required this.serverSource,
    required this.toolSource,
    this.bridge = const McpToolBridge(),
  });

  final List<McpServerConfig> Function() serverSource;
  final List<McpToolDescriptor> Function() toolSource;
  final McpToolBridge bridge;

  int _revision = 0;

  @override
  String get providerId => 'mcp';

  @override
  int get revision => _revision;

  @override
  String get sourceLabel => 'MCP servers';

  /// Signals that the underlying servers or tool list changed.
  void bumpRevision() {
    _revision += 1;
  }

  @override
  List<CapabilityDefinition> capabilities() {
    final serversById = <String, McpServerConfig>{
      for (final server in serverSource()) server.id: server,
    };
    final capabilities = <CapabilityDefinition>[];
    for (final tool in toolSource()) {
      if (!tool.enabled) {
        continue;
      }
      final server = serversById[tool.serverId];
      if (server == null || !server.enabled) {
        continue;
      }
      capabilities.add(
        bridge.toCapability(
          tool: tool,
          serverId: server.id,
          serverDisplayName: server.displayName,
        ),
      );
    }
    return List<CapabilityDefinition>.unmodifiable(capabilities);
  }
}
