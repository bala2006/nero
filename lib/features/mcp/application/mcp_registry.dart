import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../audit/application/audit_log_store.dart';
import '../../audit/domain/app_capability.dart';
import '../../audit/domain/audit_log_entry.dart';
import '../../capabilities/application/capability_catalog.dart';
import '../domain/mcp_connection_state.dart';
import '../domain/mcp_server_config.dart';
import '../domain/mcp_tool_descriptor.dart';
import 'mcp_capability_provider.dart';
import 'mcp_client.dart';
import 'mcp_server_store.dart';
import 'mcp_transport.dart';

/// Owns every MCP server, its discovered tools and its live connection.
///
/// The registry is the single write path for MCP state: it persists to
/// [McpServerStore], keeps the [CapabilityCatalog] in sync so newly enabled
/// tools are immediately selectable, and records audit entries for
/// connect/discover actions.
class McpRegistry extends ChangeNotifier {
  McpRegistry({
    McpServerStore? store,
    AuditLogStore? auditLogStore,
    CapabilityCatalog? catalog,
    McpTransportFactory? transportFactory,
  }) : _store = store ?? McpServerStore(),
       _auditLogStore = auditLogStore ?? AuditLogStore(),
       _catalog = catalog ?? CapabilityCatalog.instance,
       _transportFactory = transportFactory {
    _provider = McpCapabilityProvider(
      serverSource: () => _servers,
      toolSource: () => _tools,
    );
    _catalog.register(_provider);
  }

  final McpServerStore _store;
  final AuditLogStore _auditLogStore;
  final CapabilityCatalog _catalog;
  final McpTransportFactory? _transportFactory;

  late final McpCapabilityProvider _provider;
  final List<McpServerConfig> _servers = <McpServerConfig>[];
  final List<McpToolDescriptor> _tools = <McpToolDescriptor>[];
  final Map<String, McpConnectionState> _connections =
      <String, McpConnectionState>{};
  final Map<String, McpClient> _clients = <String, McpClient>{};

  bool _loaded = false;

  bool get isLoaded => _loaded;

  List<McpServerConfig> get servers =>
      List<McpServerConfig>.unmodifiable(_servers);

  /// Every discovered tool across every server, including disabled ones.
  List<McpToolDescriptor> get tools => List<McpToolDescriptor>.unmodifiable(_tools);

  /// Tools currently exposed to the model.
  List<McpToolDescriptor> get enabledTools => List<McpToolDescriptor>.unmodifiable(
    _tools.where((tool) {
      if (!tool.enabled) {
        return false;
      }
      final server = serverById(tool.serverId);
      return server != null && server.enabled;
    }),
  );

  McpServerConfig? serverById(String serverId) {
    for (final server in _servers) {
      if (server.id == serverId) {
        return server;
      }
    }
    return null;
  }

  McpConnectionState connectionFor(String serverId) =>
      _connections[serverId] ?? McpConnectionState.idle;

  /// Resolves a `mcp__…__…` tool name back to its descriptor.
  ///
  /// Needed because the qualified name is slugified (so `get-issue` and
  /// `get_issue` collide by design) and therefore not reversible.
  McpToolDescriptor? toolByQualifiedName(String qualifiedName) {
    for (final tool in _tools) {
      if (tool.qualifiedName == qualifiedName) {
        return tool;
      }
    }
    return null;
  }

  List<McpToolDescriptor> toolsForServer(String serverId) =>
      List<McpToolDescriptor>.unmodifiable(
        _tools.where((tool) => tool.serverId == serverId),
      );

  int enabledToolCountForServer(String serverId) => _tools
      .where((tool) => tool.serverId == serverId && tool.enabled)
      .length;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    _servers
      ..clear()
      ..addAll(await _store.loadServers());
    _tools
      ..clear()
      ..addAll(await _store.loadTools());
    _loaded = true;
    _provider.bumpRevision();
    _catalog.notifyProviderChanged(_provider.providerId);
    notifyListeners();
  }

  Future<McpServerConfig> addServer(McpServerConfig config) async {
    final normalized = config.id.trim().isEmpty
        ? config.copyWith(id: _generateServerId(config.displayName))
        : config;
    _servers.add(normalized);
    await _persist();
    notifyListeners();
    return normalized;
  }

  Future<void> updateServer(McpServerConfig config) async {
    final index = _servers.indexWhere((server) => server.id == config.id);
    if (index == -1) {
      return;
    }
    _servers[index] = config;
    if (!config.enabled) {
      await _disconnect(config.id);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> removeServer(String serverId) async {
    await _disconnect(serverId);
    _servers.removeWhere((server) => server.id == serverId);
    _tools.removeWhere((tool) => tool.serverId == serverId);
    _connections.remove(serverId);
    await _persist();
    notifyListeners();
  }

  Future<void> setServerEnabled(String serverId, bool enabled) async {
    final server = serverById(serverId);
    if (server == null) {
      return;
    }
    await updateServer(server.copyWith(enabled: enabled));
  }

  Future<void> setToolEnabled(
    String serverId,
    String toolName,
    bool enabled,
  ) async {
    final index = _tools.indexWhere(
      (tool) => tool.serverId == serverId && tool.name == toolName,
    );
    if (index == -1) {
      return;
    }
    _tools[index] = _tools[index].copyWith(enabled: enabled);
    await _persist();
    notifyListeners();
  }

  Future<void> setToolApprovalMode(
    String serverId,
    String toolName,
    McpToolApprovalMode mode,
  ) async {
    final index = _tools.indexWhere(
      (tool) => tool.serverId == serverId && tool.name == toolName,
    );
    if (index == -1) {
      return;
    }
    _tools[index] = _tools[index].copyWith(approvalMode: mode);
    await _persist();
    notifyListeners();
  }

  /// Effective approval mode for the tool behind [qualifiedName].
  McpToolApprovalMode approvalModeForQualifiedName(String qualifiedName) {
    return toolByQualifiedName(qualifiedName)?.approvalMode ??
        McpToolApprovalMode.inherit;
  }

  /// Connects to [config] (or the stored server with the same id) and
  /// rediscovers its tools. Returns the connection state.
  Future<McpConnectionState> refresh(String serverId) async {
    final server = serverById(serverId);
    if (server == null) {
      return McpConnectionState.idle;
    }
    return _refreshWithConfig(server);
  }

  /// Connects using an unsaved config. Used by the editor's "Test connection".
  Future<McpConnectionState> testConnection(McpServerConfig config) async {
    final client = McpClient(
      config: config,
      transportFactory: _transportFactory,
    );
    try {
      final initialize = await client.initialize();
      final tools = await client.listTools();
      return McpConnectionState(
        status: McpConnectionStatus.connected,
        serverName: initialize.serverName,
        protocolVersion: initialize.protocolVersion,
        toolCount: tools.length,
        updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (error) {
      return McpConnectionState(
        status: _statusForError(error),
        error: describeMcpFailure(error),
        updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      );
    } finally {
      await client.close();
    }
  }

  Future<void> refreshAll() async {
    for (final server in List<McpServerConfig>.from(_servers)) {
      if (!server.enabled) {
        continue;
      }
      await _refreshWithConfig(server);
    }
  }

  Future<McpConnectionState> _refreshWithConfig(McpServerConfig server) async {
    _setConnection(
      server.id,
      McpConnectionState(
        status: McpConnectionStatus.connecting,
        updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _auditLogStore.record(
      capabilityKey: AppCapabilities.mcpServerConnect.key,
      title: AppCapabilities.mcpServerConnect.label,
      detail: 'Connecting to ${server.displayName} (${server.url}).',
      status: AuditLogStatus.started,
    );

    await _disconnect(server.id);
    final client = McpClient(
      config: server,
      transportFactory: _transportFactory,
    );
    _clients[server.id] = client;

    try {
      final initialize = await client.initialize();
      final discovered = await client.listTools();
      _mergeTools(server.id, discovered);
      final state = McpConnectionState(
        status: McpConnectionStatus.connected,
        serverName: initialize.serverName,
        protocolVersion: initialize.protocolVersion,
        toolCount: discovered.length,
        updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      );
      _setConnection(server.id, state);
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.mcpServerConnect.key,
        title: AppCapabilities.mcpServerConnect.label,
        detail:
            'Connected to ${server.displayName}: ${discovered.length} tool(s) discovered.',
        status: AuditLogStatus.success,
      );
      await _persist();
      return state;
    } catch (error) {
      await _disconnect(server.id);
      final state = McpConnectionState(
        status: _statusForError(error),
        error: describeMcpFailure(error),
        toolCount: toolsForServer(server.id).length,
        updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      );
      _setConnection(server.id, state);
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.mcpServerConnect.key,
        title: AppCapabilities.mcpServerConnect.label,
        detail: 'Failed to connect to ${server.displayName}: '
            '${describeMcpFailure(error)}',
        status: AuditLogStatus.failed,
      );
      return state;
    }
  }

  /// The live client for [serverId], connecting first when necessary. Used by
  /// the tool executor so a tool call does not need a prior manual refresh.
  Future<McpClient> clientFor(String serverId) async {
    final existing = _clients[serverId];
    if (existing != null && existing.isInitialized) {
      return existing;
    }
    final server = serverById(serverId);
    if (server == null) {
      throw StateError('Unknown MCP server: $serverId');
    }
    final state = await _refreshWithConfig(server);
    if (!state.isConnected) {
      throw StateError(
        state.error ?? 'Could not connect to ${server.displayName}.',
      );
    }
    final client = _clients[serverId];
    if (client == null) {
      throw StateError('Could not connect to ${server.displayName}.');
    }
    return client;
  }

  Future<void> disconnect(String serverId) async {
    await _disconnect(serverId);
    _setConnection(serverId, McpConnectionState.idle);
  }

  @override
  void dispose() {
    _catalog.unregister(_provider.providerId);
    for (final client in _clients.values) {
      unawaited(client.close());
    }
    _clients.clear();
    super.dispose();
  }

  Future<void> _disconnect(String serverId) async {
    final client = _clients.remove(serverId);
    if (client != null) {
      try {
        await client.close();
      } catch (_) {}
    }
  }

  void _mergeTools(String serverId, List<McpToolDescriptor> discovered) {
    final previous = <String, McpToolDescriptor>{
      for (final tool in _tools)
        if (tool.serverId == serverId) tool.name: tool,
    };
    _tools.removeWhere((tool) => tool.serverId == serverId);
    for (final tool in discovered) {
      final existing = previous[tool.name];
      // Preserve the user's per-tool choices across a refresh.
      _tools.add(
        existing == null
            ? tool
            : tool.copyWith(
                enabled: existing.enabled,
                approvalMode: existing.approvalMode,
              ),
      );
    }
  }

  void _setConnection(String serverId, McpConnectionState state) {
    _connections[serverId] = state;
    _provider.bumpRevision();
    _catalog.notifyProviderChanged(_provider.providerId);
    notifyListeners();
  }

  Future<void> _persist() async {
    await _store.saveServers(_servers);
    await _store.saveTools(_tools);
    _provider.bumpRevision();
    _catalog.notifyProviderChanged(_provider.providerId);
  }

  McpConnectionStatus _statusForError(Object error) {
    if (error is McpTransportException && error.isUnauthorized) {
      return McpConnectionStatus.needsAuth;
    }
    final text = error.toString();
    if (text.contains('401') ||
        text.contains('403') ||
        text.contains('credential')) {
      return McpConnectionStatus.needsAuth;
    }
    return McpConnectionStatus.error;
  }

  String _generateServerId(String displayName) {
    final slug = displayName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final base = slug.isEmpty ? 'server' : slug;
    var candidate = base;
    var counter = 1;
    while (_servers.any((server) => server.id == candidate)) {
      counter += 1;
      candidate = '$base-$counter';
    }
    return candidate;
  }
}
