import 'package:flutter/material.dart';
import 'dart:async';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../audit/application/audit_log_store.dart';
import '../../audit/domain/app_capability.dart';
import '../../audit/domain/audit_log_entry.dart';
import '../sarvam_model_catalog.dart';
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
  late final bool _ownsController;
  Timer? _auditRefreshDebounceTimer;
  String? _lastRenderedModelId;
  String? _lastRenderedError;
  final SarvamModelCatalog _catalog = const SarvamModelCatalog();
  List<AuditLogEntry> _auditLogs = const <AuditLogEntry>[];

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? SettingsController();
    _controller.addListener(_onChanged);
    _auditLogStore = AuditLogStore();
    _apiKeyController = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    if (!_controller.isLoaded) {
      await _controller.load();
    }
    _apiKeyController.text = _controller.state.sarvamApiKey;
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
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) {
      return;
    }
    if (_apiKeyController.text != _controller.state.sarvamApiKey) {
      _apiKeyController.text = _controller.state.sarvamApiKey;
      _apiKeyController.selection = TextSelection.fromPosition(
        TextPosition(offset: _apiKeyController.text.length),
      );
    }
    _scheduleAuditLogRefresh();
    final modelIdChanged =
        _lastRenderedModelId != _controller.state.selectedModelId;
    final errorChanged = _lastRenderedError != _controller.error;
    if (modelIdChanged || errorChanged) {
      _lastRenderedModelId = _controller.state.selectedModelId;
      _lastRenderedError = _controller.error;
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

  @override
  Widget build(BuildContext context) {
    final settings = _controller.state;
    final currentModel = _catalog.byId(settings.selectedModelId);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _NeroBackdrop()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              children: [
                _TopBar(
                  title: 'Cloud Settings',
                  subtitle: 'Connect Nero to Sarvam AI and choose the cloud model for chat.',
                  onBackTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 8),
                _SectionCard(
                  title: 'Sarvam API Key',
                  subtitle:
                      'Paste your Sarvam API subscription key. It is stored on-device for this app.',
                  child: TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      hintText: 'sk_...',
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
                    ),
                    style: AppTextStyles.body.copyWith(fontSize: 13),
                    onChanged: (value) => _controller.setSarvamApiKey(value),
                  ),
                ),
                const SizedBox(height: 10),
                _SectionCard(
                  title: 'Model',
                  subtitle: 'Choose which Sarvam AI chat model Nero should use.',
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
                    'Cloud-only mode is active. Local downloads, native inference, and device-memory runtime limits have been removed.',
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
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
                          style: AppTextStyles.bodySecondary.copyWith(fontSize: 11.8),
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
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            capability?.label ?? entry.title,
                                            style: AppTextStyles.caption.copyWith(
                                              color: AppColors.textPrimary,
                                              fontSize: 11.2,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (entry.detail?.isNotEmpty ?? false)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                entry.detail!,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTextStyles.caption.copyWith(
                                                  color: AppColors.textMuted,
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
                const SizedBox(height: 10),
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
                  child: const Text('Reset cloud settings'),
                ),
                if (_controller.error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _controller.error!,
                    style: AppTextStyles.caption.copyWith(color: AppColors.error),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.bodySecondary.copyWith(fontSize: 11.8),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.onBackTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      child: Row(
        children: [
          Material(
            color: AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onBackTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.title.copyWith(fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 10.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NeroBackdrop extends StatelessWidget {
  const _NeroBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: AppColors.backgroundBackdrop),
        Positioned(
          bottom: -120,
          left: -90,
          child: _GlowOrb(color: AppColors.backdropGlowSecondary),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}
