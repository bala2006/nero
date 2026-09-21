import 'package:flutter/material.dart';
import 'dart:async';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/widgets.dart';
import '../../audit/application/audit_log_store.dart';
import '../../audit/domain/app_capability.dart';
import '../../audit/domain/audit_log_entry.dart';
import '../../runtime/domain/agent_policy.dart';
import '../reasoning_settings.dart';
import '../nero_model_catalog.dart';
import '../settings_controller.dart';

class NeroSettingsScreen extends StatefulWidget {
  const NeroSettingsScreen({
    super.key,
    this.controller,
  });

  final SettingsController? controller;

  @override
  State<NeroSettingsScreen> createState() => _NeroSettingsScreenState();
}

class _NeroSettingsScreenState extends State<NeroSettingsScreen> {
  late final SettingsController _controller;
  late final AuditLogStore _auditLogStore;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _baseUrlController;
  late final bool _ownsController;
  Timer? _auditRefreshDebounceTimer;
  String? _lastRenderedModelId;
  String? _lastRenderedError;
  final NeroModelCatalog _catalog = const NeroModelCatalog();
  List<AuditLogEntry> _auditLogs = const <AuditLogEntry>[];

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? SettingsController();
    _controller.addListener(_onChanged);
    _auditLogStore = AuditLogStore();
    _apiKeyController = TextEditingController();
    _baseUrlController = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    if (!_controller.isLoaded) {
      await _controller.load();
    }
    _apiKeyController.text = _controller.state.azureApiKey;
    _baseUrlController.text = _controller.state.azureBaseUrl;
    _lastRenderedModelId = _controller.state.selectedModelId;
    _lastRenderedError = _controller.error;
    await _refreshAuditLogs();
  }

  @override
  void dispose() {
    _auditRefreshDebounceTimer?.cancel();
    _controller.removeListener(_onChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) {
      return;
    }
    if (_apiKeyController.text != _controller.state.azureApiKey) {
      _apiKeyController.text = _controller.state.azureApiKey;
      _apiKeyController.selection = TextSelection.fromPosition(
        TextPosition(offset: _apiKeyController.text.length),
      );
    }
    if (_baseUrlController.text != _controller.state.azureBaseUrl) {
      _baseUrlController.text = _controller.state.azureBaseUrl;
    }
    _scheduleAuditLogRefresh();
    final modelIdChanged =
        _lastRenderedModelId != _controller.state.selectedModelId;
    final errorChanged = _lastRenderedError != _controller.error;
    if (modelIdChanged || errorChanged) {
      _lastRenderedModelId = _controller.state.selectedModelId;
      _lastRenderedError = _controller.error;
      setState(() {});
    } else {
      // Reasoning/agent sections read straight from `advanced`, so a rebuild is
      // needed for their selected values to move.
      setState(() {});
    }
  }

  void _scheduleAuditLogRefresh() {
    _auditRefreshDebounceTimer?.cancel();
    _auditRefreshDebounceTimer = Timer(
      const Duration(milliseconds: 250),
      () {
        if (!mounted) {
          return;
        }
        unawaited(_refreshAuditLogs());
      },
    );
  }

  Future<void> _refreshAuditLogs() async {
    _auditLogs = await _auditLogStore.listRecent(limit: 8);
    if (mounted) {
      setState(() {});
    }
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.surfaceGlass,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borderSoft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borderSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.tealBright),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borderSoft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _controller.state;
    final advanced = _controller.advanced;
    final reasoning = advanced.reasoning;
    final currentModel = _catalog.byId(settings.selectedModelId);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: NeroBackdrop()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                NeroTopBar(
                  title: 'Settings',
                  subtitle:
                      'Nero runs on Azure AI with local reasoning, sandbox and MCP control.',
                  onBackTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 8),
                _SectionCard(
                  title: 'Azure AI Endpoint',
                  subtitle:
                      'Fixed in lib/features/providers/azure_ai_config.dart.',
                  child: TextField(
                    controller: _baseUrlController,
                    readOnly: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: _fieldDecoration(
                      'https://<resource>.services.ai.azure.com/openai/v1/responses',
                    ),
                    style: AppTextStyles.body.copyWith(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),
                _SectionCard(
                  title: 'Azure AI API Key',
                  subtitle:
                      'Stored on-device and sent to the Responses API as the api-key header.',
                  child: TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: _fieldDecoration('Azure AI key'),
                    style: AppTextStyles.body.copyWith(fontSize: 13),
                    onChanged: (value) => _controller.setAzureApiKey(value),
                  ),
                ),
                const SizedBox(height: 10),
                _SectionCard(
                  title: 'Model',
                  subtitle: 'The Azure AI deployment Nero uses for chat.',
                  child: DropdownButtonFormField<String>(
                    initialValue: currentModel.id,
                    items: [
                      for (final model in _catalog.list())
                        DropdownMenuItem<String>(
                          value: model.id,
                          child: Text(model.name),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _controller.setSelectedModelId(value);
                      }
                    },
                    dropdownColor: AppColors.surface,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceGlass,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.borderSoft),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.borderSoft),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _SectionCard(
                  title: currentModel.name,
                  subtitle: currentModel.subtitle,
                  child: Text(
                    'Reasoning, tools, MCP servers and the on-device sandbox all run '
                    'from this single Azure deployment.',
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 10),
                _SectionCard(
                  title: 'Reasoning',
                  subtitle:
                      'How Nero asks the model to think, and how much of it chat shows.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _OptionRow<ReasoningDisplayMode>(
                        label: 'Display',
                        value: reasoning.displayMode,
                        values: ReasoningDisplayMode.values,
                        labelFor: (value) => value.label,
                        onSelected: (value) => _controller
                            .setReasoningPreferences(
                              reasoning.copyWith(displayMode: value),
                            ),
                      ),
                      const SizedBox(height: 12),
                      _OptionRow<ReasoningSummaryVerbosity>(
                        label: 'Summary detail',
                        value: reasoning.verbosity,
                        values: ReasoningSummaryVerbosity.values,
                        labelFor: (value) => value.label,
                        onSelected: (value) => _controller
                            .setReasoningPreferences(
                              reasoning.copyWith(verbosity: value),
                            ),
                      ),
                      const SizedBox(height: 12),
                      _OptionRow<ReasoningEffort>(
                        label: 'Effort',
                        value: reasoning.effort,
                        values: ReasoningEffort.values,
                        labelFor: (value) => value.label,
                        onSelected: (value) => _controller
                            .setReasoningPreferences(
                              reasoning.copyWith(effort: value),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reasoning.effort.description,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: reasoning.keepExpandedOnComplete,
                        title: Text(
                          'Keep reasoning expanded',
                          style: AppTextStyles.body.copyWith(fontSize: 12.6),
                        ),
                        subtitle: Text(
                          'Do not auto-collapse a block once thinking finishes.',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 10.8,
                          ),
                        ),
                        onChanged: (value) => _controller
                            .setReasoningPreferences(
                              reasoning.copyWith(
                                keepExpandedOnComplete: value,
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _SectionCard(
                  title: 'Agent',
                  subtitle:
                      'How autonomous the agent is and when it must ask you first.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _OptionRow<AgentMode>(
                        label: 'Default mode',
                        value: advanced.agentMode,
                        values: AgentMode.values,
                        labelFor: (value) => value.label,
                        onSelected: (value) =>
                            _controller.setAgentMode(value),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        advanced.agentMode.description,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _OptionRow<ApprovalPolicy>(
                        label: 'Approval',
                        value: advanced.approvalPolicy,
                        values: ApprovalPolicy.values,
                        labelFor: (value) => value.label,
                        onSelected: (value) =>
                            _controller.setApprovalPolicy(value),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        advanced.approvalPolicy.description,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _BudgetStepper(
                        label: 'Max iterations',
                        value: advanced.budget.maxIterations,
                        min: 1,
                        max: 60,
                        onChanged: (value) => _controller.setRunBudget(
                          advanced.budget.copyWith(maxIterations: value),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _BudgetStepper(
                        label: 'Max tool calls',
                        value: advanced.budget.maxToolCalls,
                        min: 1,
                        max: 120,
                        onChanged: (value) => _controller.setRunBudget(
                          advanced.budget.copyWith(maxToolCalls: value),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _BudgetStepper(
                        label: 'Max minutes',
                        value: advanced.budget.maxWallClockMs ~/ 60000,
                        min: 1,
                        max: 60,
                        onChanged: (value) => _controller.setRunBudget(
                          advanced.budget.copyWith(
                            maxWallClockMs: value * 60000,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _SectionCard(
                  title: 'Audit Log',
                  subtitle:
                      'Recent sensitive and external actions performed by Nero in this app.',
                  child: _auditLogs.isEmpty
                      ? Text(
                          'No audit entries recorded yet.',
                          style: AppTextStyles.bodySecondary.copyWith(
                            fontSize: 11.8,
                          ),
                        )
                      : ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: Scrollbar(
                            thumbVisibility: _auditLogs.length > 4,
                            thickness: 2,
                            radius: const Radius.circular(999),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.only(right: 6),
                              itemCount: _auditLogs.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final entry = _auditLogs[index];
                                final capability = AppCapabilities.byKey(
                                  entry.capabilityKey,
                                );
                                final color = switch (entry.status) {
                                  AuditLogStatus.started => AppColors.orange,
                                  AuditLogStatus.success => AppColors.tealBright,
                                  AuditLogStatus.failed => AppColors.amber,
                                };
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Icon(
                                        switch (entry.status) {
                                          AuditLogStatus.started =>
                                            Icons.play_circle_outline_rounded,
                                          AuditLogStatus.success =>
                                            Icons.check_circle_outline_rounded,
                                          AuditLogStatus.failed =>
                                            Icons.error_outline_rounded,
                                        },
                                        size: 14,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            capability?.label ?? entry.title,
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                  color:
                                                      AppColors.textPrimary,
                                                  fontSize: 11.2,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          if (entry.detail?.isNotEmpty ??
                                              false)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 2,
                                              ),
                                              child: Text(
                                                entry.detail!,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                      color:
                                                          AppColors.textMuted,
                                                      fontSize: 10.1,
                                                      height: 1.2,
                                                    ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _controller.reset,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.borderSoft),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Reset settings'),
                ),
                if (_controller.error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _controller.error!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact label + segmented choice row.
class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onSelected,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textMuted,
            fontSize: 11.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final option in values)
              NeroActionChip(
                label: labelFor(option),
                selected: option == value,
                accentColor: AppColors.tealBright,
                onTap: () => onSelected(option),
              ),
          ],
        ),
      ],
    );
  }
}

/// Small +/- numeric stepper used for run budgets.
class _BudgetStepper extends StatelessWidget {
  const _BudgetStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(fontSize: 12.6),
          ),
        ),
        HeaderIconButton(
          icon: Icons.remove_rounded,
          semanticLabel: 'Decrease $label',
          size: 30,
          iconSize: 16,
          onTap: value <= min ? () {} : () => onChanged(value - 1),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              fontSize: 12.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        HeaderIconButton(
          icon: Icons.add_rounded,
          semanticLabel: 'Increase $label',
          size: 30,
          iconSize: 16,
          onTap: value >= max ? () {} : () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SectionCard(title: title, subtitle: subtitle, child: child);
  }
}
