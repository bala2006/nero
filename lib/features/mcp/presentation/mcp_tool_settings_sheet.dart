import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/widgets.dart';
import '../../runtime/domain/agent_policy.dart';
import '../application/mcp_registry.dart';
import '../domain/mcp_tool_descriptor.dart';

/// Per-tool customisation: expose it, and decide when it must ask first.
class McpToolSettingsSheet extends StatelessWidget {
  const McpToolSettingsSheet({
    super.key,
    required this.registry,
    required this.serverId,
    required this.toolName,
  });

  final McpRegistry registry;
  final String serverId;
  final String toolName;

  static Future<void> show({
    required BuildContext context,
    required McpRegistry registry,
    required String serverId,
    required String toolName,
  }) {
    return NeroBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      child: McpToolSettingsSheet(
        registry: registry,
        serverId: serverId,
        toolName: toolName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: registry,
      builder: (context, _) {
        final tool = registry
            .toolsForServer(serverId)
            .where((candidate) => candidate.name == toolName)
            .firstOrNull;
        if (tool == null) {
          return const NeroBottomSheet(
            title: 'Tool no longer available',
            children: <Widget>[
              EmptyState(
                icon: Icons.help_outline_rounded,
                title: 'This tool is gone',
                message:
                    'The server no longer publishes it. Refresh the server to '
                    'rediscover its tools.',
                compact: true,
              ),
            ],
          );
        }
        final server = registry.serverById(serverId);
        final risk = tool.annotations.riskLevel;

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: NeroBottomSheet(
              title: tool.displayTitle,
              subtitle: '${server?.displayName ?? serverId} · ${tool.name}',
              children: <Widget>[
                SectionCard(
                  title: 'Exposure',
                  subtitle: tool.enabled
                      ? 'The model can call this tool.'
                      : 'Hidden from the model.',
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: tool.enabled,
                    onChanged: (value) => registry.setToolEnabled(
                      serverId,
                      tool.name,
                      value,
                    ),
                    title: Text(
                      'Offer to the model',
                      style: AppTextStyles.body.copyWith(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SectionCard(
                  title: 'Approval',
                  subtitle: _approvalCaption(tool),
                  child: RadioGroup<McpToolApprovalMode>(
                    groupValue: tool.approvalMode,
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      registry.setToolApprovalMode(
                        serverId,
                        tool.name,
                        value,
                      );
                    },
                    child: Column(
                      children: <Widget>[
                        for (final mode in McpToolApprovalMode.values)
                          RadioListTile<McpToolApprovalMode>(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: mode,
                            title: Text(
                              mode.label,
                              style: AppTextStyles.body.copyWith(fontSize: 13),
                            ),
                            subtitle: Text(
                              _modeCaption(mode),
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SectionCard(
                  title: 'Risk and hints',
                  subtitle:
                      'Hints are published by the server and treated as extra '
                      'caution, never as permission.',
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      StatusPill(
                        label: risk.label,
                        color: switch (risk.name) {
                          'readOnly' => AppColors.tealBright,
                          'destructive' => AppColors.error,
                          _ => AppColors.amber,
                        },
                        icon: Icons.shield_outlined,
                        dense: true,
                      ),
                      if (tool.annotations.idempotentHint)
                        const StatusPill(
                          label: 'Idempotent',
                          color: AppColors.amber,
                          dense: true,
                        ),
                      if (tool.annotations.openWorldHint)
                        const StatusPill(
                          label: 'Open world',
                          color: AppColors.orange,
                          dense: true,
                        ),
                      if (!tool.annotations.hasAnyHint)
                        const StatusPill(
                          label: 'No hints published',
                          color: AppColors.textMuted,
                          dense: true,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SectionCard(
                  title: 'Tool description',
                  subtitle: 'Sanitised before it reaches the model.',
                  child: Text(
                    tool.description.isEmpty
                        ? 'This server did not publish a description.'
                        : tool.description,
                    style: AppTextStyles.bodySecondary.copyWith(
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SectionCard(
                  title: 'Input schema',
                  subtitle: 'Sanitised and depth-limited projection.',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      const JsonEncoder.withIndent('  ').convert(
                        tool.inputSchema.isEmpty
                            ? const <String, Object?>{}
                            : tool.inputSchema,
                      ),
                      style: AppTextStyles.codeMono(
                        color: AppColors.textSecondary,
                        fontSize: 10.6,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _approvalCaption(McpToolDescriptor tool) {
    return switch (tool.approvalMode) {
      McpToolApprovalMode.inherit =>
        'Falls back to the server setting and the global approval policy.',
      McpToolApprovalMode.alwaysAsk =>
        'This tool always pauses for your approval.',
      McpToolApprovalMode.never =>
        'This tool runs without asking. Only use for tools you trust.',
    };
  }

  String _modeCaption(McpToolApprovalMode mode) {
    return switch (mode) {
      McpToolApprovalMode.inherit => 'Use the server and global policy',
      McpToolApprovalMode.alwaysAsk => 'Pause every time this tool is called',
      McpToolApprovalMode.never => 'Do not pause for this tool',
    };
  }
}
