import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../runtime/domain/agent_policy.dart';

/// Compact composer control for the next turn's autonomy level.
///
/// Lives in the composer footer so switching between answering, planning and
/// running autonomously is one tap away instead of a trip to settings.
class AgentModeSelector extends StatelessWidget {
  const AgentModeSelector({
    super.key,
    required this.mode,
    required this.onChanged,
    this.isOverridden = false,
    this.isEnabled = true,
  });

  final AgentMode mode;
  final ValueChanged<AgentMode> onChanged;

  /// True when the current mode differs from the saved default.
  final bool isOverridden;

  final bool isEnabled;

  Color get _accent => switch (mode) {
    AgentMode.chat => AppColors.textSecondary,
    AgentMode.planFirst => AppColors.amber,
    AgentMode.auto => AppColors.orange,
  };

  IconData get _icon => switch (mode) {
    AgentMode.chat => Icons.chat_bubble_outline_rounded,
    AgentMode.planFirst => Icons.checklist_rounded,
    AgentMode.auto => Icons.bolt_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceOverlay,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: isEnabled ? () => _openPicker(context) : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _accent.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(_icon, size: 13, color: _accent),
              const SizedBox(width: 5),
              Text(
                mode.label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11.4,
                  fontWeight: FontWeight.w700,
                  color: isEnabled ? _accent : AppColors.textMuted,
                ),
              ),
              if (isOverridden) ...[
                const SizedBox(width: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final selected = await NeroBottomSheet.show<AgentMode>(
      context: context,
      child: NeroBottomSheet(
        title: 'How should Nero answer?',
        subtitle: 'Applies to your next message.',
        children: <Widget>[
          for (final option in AgentMode.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NeroTile(
                title: option.label,
                subtitle: option.description,
                icon: switch (option) {
                  AgentMode.chat => Icons.chat_bubble_outline_rounded,
                  AgentMode.planFirst => Icons.checklist_rounded,
                  AgentMode.auto => Icons.bolt_rounded,
                },
                accentColor: option == mode
                    ? AppColors.orange
                    : AppColors.textSecondary,
                trailing: option == mode
                    ? const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: AppColors.orange,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(option),
              ),
            ),
        ],
      ),
    );
    if (selected != null) {
      onChanged(selected);
    }
  }
}
