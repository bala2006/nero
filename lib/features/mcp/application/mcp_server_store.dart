import 'dart:convert';

import '../../../platform/database/app_metadata_store.dart';
import '../domain/mcp_server_config.dart';
import '../domain/mcp_tool_descriptor.dart';

/// Persists MCP configuration in the key/value metadata table.
///
/// Stored as JSON rather than a drift table so adding a config field never
/// requires a schema migration; the payload is small and read once at startup.
class McpServerStore {
  McpServerStore({AppMetadataStore? metadataStore})
    : _metadataStore = metadataStore ?? AppMetadataStore();

  static const String serversKey = 'mcp.servers';
  static const String toolsKey = 'mcp.tools';

  final AppMetadataStore _metadataStore;

  Future<List<McpServerConfig>> loadServers() async {
    final raw = await _metadataStore.read(serversKey);
    final decoded = _decodeList(raw);
    return decoded
        .map(McpServerConfig.fromJson)
        .where((server) => server.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> saveServers(List<McpServerConfig> servers) async {
    await _metadataStore.write(
      serversKey,
      jsonEncode(servers.map((server) => server.toJson()).toList()),
    );
  }

  Future<List<McpToolDescriptor>> loadTools() async {
    final raw = await _metadataStore.read(toolsKey);
    final decoded = _decodeList(raw);
    return decoded
        .map(McpToolDescriptor.fromJson)
        .where((tool) => tool.name.isNotEmpty && tool.serverId.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> saveTools(List<McpToolDescriptor> tools) async {
    await _metadataStore.write(
      toolsKey,
      jsonEncode(tools.map((tool) => tool.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    await _metadataStore.write(serversKey, null);
    await _metadataStore.write(toolsKey, null);
  }

  List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
    } catch (_) {}
    return const <Map<String, dynamic>>[];
  }
}
