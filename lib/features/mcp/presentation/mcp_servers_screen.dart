import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/widgets.dart';
import '../../audit/domain/app_capability.dart';
import '../../runtime/domain/agent_policy.dart';
import '../../../app/app_services.dart';
import '../application/mcp_registry.dart';
import '../domain/mcp_connection_state.dart';
import '../domain/mcp_server_config.dart';
import '../domain/mcp_tool_descriptor.dart';
import 'mcp_server_editor_screen.dart';
import 'mcp_tool_settings_sheet.dart';

/// Lists every configured MCP server, its connection state and its tools.
class McpServersScreen extends StatefulWidget {
  const McpServersScreen({super.key});

  @override
  State<McpServersScreen> createState() => _McpServersScreenState();
}

class _McpServersScreenState extends State<McpServersScreen> {
  McpRegistry? _registry;
  bool _refreshingAll = false;
  final Set<String> _expandedServers = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registry ??= AppServices.maybeOf(context)?.mcpRegistry;
  }

  @override
  Widget build(BuildContext context) {
    final registry = _registry;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          const NeroBackdrop(),
          SafeArea(
            child: Column(
              children: <Widget>[
                NeroTopBar(
                  title: 'MCP servers',
                  subtitle: registry == null
                      ? 'Unavailable'
                      : '${registry.servers.length} configured · '
                            '${registry.enabledTools.length} tools exposed',
                  onBackTap: () => Navigator.of(context).maybePop(),
                  actions: <Widget>[
                    HeaderIconButton(
                      icon: Icons.refresh_rounded,
                      semanticLabel: 'Refresh every server',
                      onTap: registry == null || _refreshingAll
                          ? () {}
                          : _refreshAll,
                    ),
                    HeaderIconButton(
                      icon: Icons.add_rounded,
                      semanticLabel: 'Add MCP server',
                      onTap: registry == null ? () {} : _addServer,
                    ),
                  ],
                ),
                Expanded(child: _buildBody(registry)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(McpRegistry? registry) {
    if (registry == null) {
      return const EmptyState(
        icon: Icons.hub_outlined,
        title: 'MCP is unavailable',
        message:
            'This screen needs the app service container. Open it from inside '
            'Nero rather than in isolation.',
      );
    }
    return AnimatedBuilder(
      animation: registry,
      builder: (context, _) {
        final servers = registry.servers;
        if (servers.isEmpty) {
          return EmptyState(
            icon: Icons.hub_outlined,
            title: 'No MCP servers yet',
            message:
                'Connect a remote Model Context Protocol server to give Nero '
                'its tools. Every tool is discovered automatically and stays '
                'under your control.',
            action: FilledButton.icon(
              onPressed: _addServer,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add a server'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.black,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          itemCount: servers.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == servers.length) {
              return _buildCapabilityNotice(registry);
            }
            return _buildServerCard(registry, servers[index]);
          },
        );
      },
    );
  }

  Widget _buildCapabilityNotice(McpRegistry registry) {
    final enabled = registry.enabledTools.length;
    if (enabled == 0) {
      return InlineBanner(
        message:
            'No MCP tools are exposed to the model yet. Connect a server and '
            'switch on the individual tools you want Nero to be able to call.',
        tone: InlineBannerTone.info,
        icon: Icons.info_outline_rounded,
      );
    }
    return InlineBanner(
      message:
          '$enabled tool${enabled == 1 ? '' : 's'} from MCP servers are now '
          'selectable in chat. Calls to them are recorded in the audit log.',
      tone: InlineBannerTone.success,
      icon: Icons.verified_rounded,
    );
  }

  Widget _buildServerCard(McpRegistry registry, McpServerConfig server) {
    final state = registry.connectionFor(server.id);
    final tools = registry.toolsForServer(server.id);
    final expanded = _expandedServers.contains(server.id);
    final accent = _statusColor(state.status);

    return SectionCard(
      title: server.displayName,
      subtitle: server.url,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      trailing: StatusPill(
        label: state.status.label,
        color: accent,
        icon: switch (state.status) {
          McpConnectionStatus.connected => Icons.check_circle_rounded,
          McpConnectionStatus.connecting => Icons.sync_rounded,
          McpConnectionStatus.needsAuth => Icons.lock_outline_rounded,
          McpConnectionStatus.error => Icons.error_outline_rounded,
          McpConnectionStatus.disconnected => Icons.circle_outlined,
        },
        dense: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              StatusPill(
                label: server.transport.label,
                color: AppColors.amber,
                dense: true,
              ),
              StatusPill(
                label: '${registry.enabledToolCountForServer(server.id)}/'
                    '${tools.length} tools on',
                color: AppColors.tealBright,
                dense: true,
              ),
              if (state.protocolVersion != null)
                StatusPill(
                  label: 'v${state.protocolVersion}',
                  color: AppColors.textMuted,
                  dense: true,
                ),
              if (server.autoApprove)
                const StatusPill(
                  label: 'Auto-approve',
                  color: AppColors.orange,
                  dense: true,
                  icon: Icons.bolt_rounded,
                ),
            ],
          ),
          if (state.error != null) ...<Widget>[
            const SizedBox(height: 10),
            InlineBanner(
              message: state.error!,
              tone: InlineBannerTone.error,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  tools.isEmpty
                      ? 'No tools discovered yet.'
                      : '${tools.length} tool${tools.length == 1 ? '' : 's'} '
                            'discovered',
                  style: AppTextStyles.bodySecondary.copyWith(fontSize: 12.2),
                ),
              ),
              _MiniAction(
                label: expanded ? 'Hide' : 'Tools',
                icon: expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                onTap: () {
                  setState(() {
                    if (expanded) {
                      _expandedServers.remove(server.id);
                    } else {
                      _expandedServers.add(server.id);
                    }
                  });
                },
              ),
              const SizedBox(width: 6),
              _MiniAction(
                label: 'Refresh',
                icon: Icons.sync_rounded,
                onTap: state.status.isBusy || !server.enabled
                    ? null
                    : () => registry.refresh(server.id),
              ),
              const SizedBox(width: 6),
              _MiniAction(
                label: 'Edit',
                icon: Icons.tune_rounded,
                onTap: () => _editServer(server),
              ),
            ],
          ),
          if (expanded) ...<Widget>[
            const SizedBox(height: 10),
            for (final tool in tools)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildToolRow(registry, server, tool),
              ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: () => registry.setServerEnabled(
                    server.id,
                    !server.enabled,
                  ),
                  icon: Icon(
                    server.enabled
                        ? Icons.toggle_on_rounded
                        : Icons.toggle_off_rounded,
                    size: 18,
                  ),
                  label: Text(
                    server.enabled ? 'Disable server' : 'Enable server',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _confirmDelete(server),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text(
                    'Remove',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolRow(
    McpRegistry registry,
    McpServerConfig server,
    McpToolDescriptor tool,
  ) {
    final risk = tool.annotations.riskLevel;
    return NeroTile(
      title: tool.displayTitle,
      subtitle: tool.annotations.hasAnyHint
          ? '${risk.label} · ${tool.name}'
          : '${tool.name} · no hints published',
      icon: tool.enabled
          ? Icons.extension_rounded
          : Icons.extension_off_rounded,
      accentColor: tool.enabled ? AppColors.tealBright : AppColors.textMuted,
      dense: true,
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      borderRadius: 12,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Switch.adaptive(
            value: tool.enabled,
            onChanged: (value) =>
                registry.setToolEnabled(server.id, tool.name, value),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, size: 18),
            color: AppColors.textMuted,
            tooltip: 'Tool settings',
            onPressed: () => McpToolSettingsSheet.show(
              context: context,
              registry: registry,
              serverId: server.id,
              toolName: tool.name,
            ),
          ),
        ],
      ),
      onTap: () => McpToolSettingsSheet.show(
        context: context,
        registry: registry,
        serverId: server.id,
        toolName: tool.name,
      ),
    );
  }

  // ---- actions ------------------------------------------------------------

  Future<void> _refreshAll() async {
    final registry = _registry;
    if (registry == null) {
      return;
    }
    setState(() => _refreshingAll = true);
    await registry.refreshAll();
    if (!mounted) {
      return;
    }
    setState(() => _refreshingAll = false);
  }

  Future<void> _addServer() async {
    final registry = _registry;
    if (registry == null) {
      return;
    }
    await _openEditor(registry, null);
  }

  Future<void> _editServer(McpServerConfig server) async {
    final registry = _registry;
    if (registry == null) {
      return;
    }
    await _openEditor(registry, server);
  }

  Future<void> _openEditor(
    McpRegistry registry,
    McpServerConfig? server,
  ) async {
    final capability = AppCapabilities.mcpServerConnect;
    if (server == null && capability.requiresApproval) {
      final approved = await _confirm(
        title: 'Connect a server?',
        message:
            'Nero will send requests to the URL you provide and will hand this '
            'server\'s tool descriptions to the model. Only connect servers you '
            'trust.',
        confirmLabel: 'Continue',
      );
      if (!approved || !mounted) {
        return;
      }
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            McpServerEditorScreen(registry: registry, existing: server),
      ),
    );
  }

  Future<void> _confirmDelete(McpServerConfig server) async {
    final registry = _registry;
    if (registry == null) {
      return;
    }
    final confirmed = await _confirm(
      title: 'Remove ${server.displayName}?',
      message:
          'Its tools will be removed from the model and its stored token will '
          'be deleted from this device.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    await registry.removeServer(server.id);
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(title, style: AppTextStyles.titleSmall),
        content: Text(
          message,
          style: AppTextStyles.bodySecondary.copyWith(fontSize: 12.8),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textMuted,
                fontSize: 12.6,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              confirmLabel,
              style: AppTextStyles.body.copyWith(
                color: destructive ? AppColors.error : AppColors.orange,
                fontSize: 12.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Color _statusColor(McpConnectionStatus status) {
    return switch (status) {
      McpConnectionStatus.connected => AppColors.tealBright,
      McpConnectionStatus.connecting => AppColors.amber,
      McpConnectionStatus.needsAuth => AppColors.orange,
      McpConnectionStatus.error => AppColors.error,
      McpConnectionStatus.disconnected => AppColors.textMuted,
    };
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 11.6)),
      style: TextButton.styleFrom(
        foregroundColor: onTap == null
            ? AppColors.textMuted
            : AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
