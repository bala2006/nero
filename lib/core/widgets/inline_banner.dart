import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum InlineBannerTone { info, warning, error, success }

/// Inline status strip with an optional action, used above the composer and in
/// detail screens.
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.message,
    this.tone = InlineBannerTone.info,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  final String message;
  final InlineBannerTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  Color get _accent => switch (tone) {
    InlineBannerTone.info => AppColors.amber,
    InlineBannerTone.warning => AppColors.amber,
    InlineBannerTone.error => AppColors.error,
    InlineBannerTone.success => AppColors.tealBright,
  };

  IconData get _icon => switch (tone) {
    InlineBannerTone.info => Icons.info_outline_rounded,
    InlineBannerTone.warning => Icons.warning_amber_rounded,
    InlineBannerTone.error => Icons.error_outline_rounded,
    InlineBannerTone.success => Icons.check_circle_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    final handler = onAction;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon ?? _icon, size: 18, color: _accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12.8,
                height: 1.35,
              ),
            ),
          ),
          if (handler != null && label != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: handler,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.orange,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                label,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.orange,
                  fontSize: 12.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
