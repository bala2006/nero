import 'package:flutter/material.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/widgets.dart';
import '../application/sandbox_controller.dart';
import '../application/webview_sandbox_runner.dart';
import '../domain/sandbox_models.dart';

/// On-device sandbox: write a snippet, run it locally, read the output.
///
/// The WebView that executes snippets is mounted by this screen (off-screen, at
/// 1×1), because a WebView only executes while it is in the render tree.
class SandboxHomeScreen extends StatefulWidget {
  const SandboxHomeScreen({super.key, this.controller});

  /// Shared app-lifetime controller. The shell always passes it; when null the
  /// screen builds and owns one, which keeps the screen usable standalone.
  final SandboxController? controller;

  @override
  State<SandboxHomeScreen> createState() => _SandboxHomeScreenState();
}

class _SandboxHomeScreenState extends State<SandboxHomeScreen> {
  late final SandboxController _controller;
  late final bool _ownsController;
  final TextEditingController _sourceController = TextEditingController();

  String? _loadedSessionId;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? SandboxController(
      runner: WebViewSandboxRunner(),
    );
    _controller.addListener(_handleControllerChanged);
    if (_controller.isLoading) {
      _controller.load();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    _sourceController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }
    final session = _controller.activeSession;
    // Only overwrite the editor when the *session* changed; otherwise typing
    // would fight the controller on every rebuild.
    if (session != null && session.id != _loadedSessionId) {
      _loadedSessionId = session.id;
      _sourceController.text = session.source;
    } else if (session == null && _loadedSessionId != null) {
      _loadedSessionId = null;
      _sourceController.text = '';
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          const NeroBackdrop(),
          SafeArea(child: _buildContent()),
          // When the shell owns the controller its WebView host is already
          // mounted app-wide, so only a standalone screen needs its own host.
          if (_ownsController)
            if (_controller.runner is WebViewSandboxRunner)
              (_controller.runner as WebViewSandboxRunner).buildHost(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final session = _controller.activeSession;
    return Column(
      children: <Widget>[
        NeroTopBar(
          title: 'Sandbox',
          subtitle: _controller.isLoading
              ? 'Loading sessions…'
              : '${_controller.sessions.length} session(s) · '
                    'runs on this device',
          onBackTap: () => Navigator.of(context).maybePop(),
          actions: <Widget>[
            HeaderIconButton(
              icon: Icons.add_rounded,
              semanticLabel: 'New sandbox session',
              onTap: _createSession,
            ),
            HeaderIconButton(
              icon: Icons.tune_rounded,
              semanticLabel: 'Sandbox permissions',
              onTap: _openPolicySheet,
            ),
          ],
        ),
        if (_controller.isLoading)
          const Expanded(
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (session == null)
          Expanded(
            child: EmptyState(
              icon: Icons.terminal_rounded,
              title: 'No sandbox session',
              message:
                  'Create a session to write and run code without leaving the '
                  'device.',
              action: FilledButton.icon(
                onPressed: _createSession,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('New session'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.black,
                ),
              ),
            ),
          )
        else
          Expanded(child: _buildSessionBody(session)),
      ],
    );
  }

  Widget _buildSessionBody(SandboxSession session) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      children: <Widget>[
        _buildSessionStrip(session),
        const SizedBox(height: 10),
        _buildToolbar(session),
        const SizedBox(height: 10),
        _buildSourceEditor(session),
        const SizedBox(height: 10),
        _buildRunRow(),
        const SizedBox(height: 10),
        _buildOutputPanel(),
      ],
    );
  }

  Widget _buildSessionStrip(SandboxSession active) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          for (final session in _controller.sessions) ...<Widget>[
            NeroActionChip(
              label: session.name,
              icon: session.language == SandboxLanguage.html
                  ? Icons.web_asset_rounded
                  : Icons.code_rounded,
              selected: session.id == active.id,
              accentColor: AppColors.orange,
              onTap: () => _controller.selectSession(session.id),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildToolbar(SandboxSession session) {
    return SectionCard(
      title: session.name,
      subtitle: session.language.description,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          HeaderIconButton(
            icon: Icons.drive_file_rename_outline_rounded,
            semanticLabel: 'Rename session',
            size: 32,
            iconSize: 16,
            onTap: () => _renameSession(session),
          ),
          const SizedBox(width: 6),
          HeaderIconButton(
            icon: Icons.delete_outline_rounded,
            semanticLabel: 'Delete session',
            size: 32,
            iconSize: 16,
            onTap: () => _deleteSession(session),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final language in SandboxLanguage.values)
                NeroActionChip(
                  label: language.label,
                  selected: session.language == language,
                  accentColor: AppColors.orange,
                  onTap: () => _controller.setLanguage(session.id, language),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final permission in SandboxPermission.values)
                StatusPill(
                  label: permission.label,
                  color: _controller.policy.allows(permission)
                      ? AppColors.tealBright
                      : AppColors.textMuted,
                  icon: _controller.policy.allows(permission)
                      ? Icons.check_circle_outline_rounded
                      : Icons.block_rounded,
                  dense: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceEditor(SandboxSession session) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                session.language == SandboxLanguage.html
                    ? 'HTML source'
                    : 'JavaScript source',
                style: AppTextStyles.caption.copyWith(fontSize: 11.2),
              ),
              const Spacer(),
              Text(
                '${_sourceController.text.length} chars',
                style: AppTextStyles.caption.copyWith(fontSize: 10.6),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _sourceController,
            maxLines: null,
            minLines: 12,
            keyboardType: TextInputType.multiline,
            style: AppTextStyles.codeMono(
              color: AppColors.textPrimary,
              fontSize: 12.2,
              height: 1.45,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (value) {
              _controller.updateSource(session.id, value);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRunRow() {
    final running = _controller.isRunning;
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            onPressed: running ? null : _controller.run,
            icon: running
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text(running ? 'Running…' : 'Run on device'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _controller.clearOutcome,
          icon: const Icon(Icons.cleaning_services_outlined, size: 16),
          label: const Text('Clear'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.borderSoft),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOutputPanel() {
    final outcome = _controller.lastOutcome;
    if (outcome == null) {
      return const InlineBanner(
        message:
            'Nothing has run yet. Output, errors and every console call land '
            'here.',
        tone: InlineBannerTone.info,
      );
    }
    final errorText = outcome.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionCard(
          title: outcome.success ? 'Output' : 'The snippet failed',
          subtitle: outcome.durationMs == null
              ? null
              : 'Finished in ${formatDurationMs(outcome.durationMs)}'
                    '${outcome.outputTruncated ? ' · output truncated' : ''}',
          trailing: StatusPill(
            label: outcome.success ? 'ok' : 'error',
            color: outcome.success ? AppColors.tealBright : AppColors.error,
            dense: true,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (errorText != null && errorText.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: SelectableText(
                    errorText,
                    style: AppTextStyles.codeMono(
                      color: AppColors.error,
                      fontSize: 11.4,
                      height: 1.4,
                    ),
                  ),
                ),
              if (outcome.output.isNotEmpty) ...<Widget>[
                if (errorText != null) const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    outcome.output,
                    style: AppTextStyles.codeMono(
                      color: AppColors.textSecondary,
                      fontSize: 11.4,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              if (outcome.logs.isEmpty &&
                  outcome.output.isEmpty &&
                  (errorText == null || errorText.isEmpty))
                Text(
                  'The snippet produced no output.',
                  style: AppTextStyles.bodySecondary.copyWith(fontSize: 12.4),
                ),
            ],
          ),
        ),
        if (outcome.logs.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          SectionCard(
            title: 'Console',
            subtitle: '${outcome.logs.length} call(s)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final entry in outcome.logs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SelectableText(
                      '${entry.level}: ${entry.message}',
                      style: AppTextStyles.codeMono(
                        color: entry.isError
                            ? AppColors.error
                            : entry.level == 'warn'
                            ? AppColors.amber
                            : AppColors.textSecondary,
                        fontSize: 11.2,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ---- actions ------------------------------------------------------------

  Future<void> _createSession() async {
    final language = await NeroBottomSheet.show<SandboxLanguage>(
      context: context,
      child: NeroBottomSheet(
        title: 'New sandbox session',
        subtitle: 'Pick what this session runs.',
        children: <Widget>[
          for (final option in SandboxLanguage.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NeroTile(
                title: option.label,
                subtitle: option.description,
                icon: option == SandboxLanguage.html
                    ? Icons.web_asset_rounded
                    : Icons.code_rounded,
                onTap: () => Navigator.of(context).pop(option),
              ),
            ),
        ],
      ),
    );
    if (language == null) {
      return;
    }
    await _controller.createSession(language);
  }

  Future<void> _renameSession(SandboxSession session) async {
    final controller = TextEditingController(text: session.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text('Rename session', style: AppTextStyles.titleSmall),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTextStyles.body,
          decoration: const InputDecoration(hintText: 'Session name'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) {
      return;
    }
    await _controller.renameSession(session.id, name);
  }

  Future<void> _deleteSession(SandboxSession session) async {
    await _controller.deleteSession(session.id);
  }

  Future<void> _openPolicySheet() async {
    await NeroBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => NeroBottomSheet(
          title: 'Sandbox permissions',
          subtitle:
              'Everything is denied unless you grant it. Grants apply to every '
              'session on this device.',
          children: <Widget>[
            SectionCard(
              title: 'Permissions',
              child: Column(
                children: <Widget>[
                  for (final permission in SandboxPermission.values)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _controller.policy.allows(permission),
                      onChanged: (_) =>
                          _controller.togglePermission(permission),
                      title: Text(
                        permission.label,
                        style: AppTextStyles.body.copyWith(fontSize: 13),
                      ),
                      subtitle: Text(
                        permission.description,
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SectionCard(
              title: 'Time limit',
              subtitle: 'A snippet that overruns is abandoned.',
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final option in const <int>[2000, 5000, 15000, 30000])
                    NeroActionChip(
                      label: '${option ~/ 1000}s',
                      selected: _controller.policy.maxRuntimeMs == option,
                      accentColor: AppColors.orange,
                      onTap: () => _controller.setMaxRuntimeMs(option),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const InlineBanner(
              message:
                  'The sandbox runs inside a WebView, isolated from Dart, your '
                  'files and the native bridge. The permission shims are '
                  'defence in depth, so keep running only snippets you are '
                  'willing to trust.',
              tone: InlineBannerTone.warning,
            ),
          ],
        ),
      ),
    );
  }
}
