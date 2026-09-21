import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Compact screen header used by every pushed screen.
class NeroTopBar extends StatelessWidget {
  const NeroTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBackTap,
    this.onMenuTap,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? subtitle;

  /// Shown as a back arrow when provided.
  final VoidCallback? onBackTap;

  /// Shown as a hamburger when provided (and [onBackTap] is null).
  final VoidCallback? onMenuTap;

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final leading = onBackTap != null
        ? HeaderIconButton(
            icon: Icons.arrow_back_rounded,
            semanticLabel: 'Back',
            onTap: onBackTap!,
          )
        : (onMenuTap != null
              ? HeaderIconButton(
                  icon: Icons.menu_rounded,
                  semanticLabel: 'Open navigation',
                  onTap: onMenuTap!,
                )
              : null);
    final subtitleText = subtitle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 10)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title.copyWith(fontSize: 16),
                ),
                if (subtitleText != null && subtitleText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitleText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontSize: 10.4),
                  ),
                ],
              ],
            ),
          ),
          for (final action in actions) ...[
            const SizedBox(width: 8),
            action,
          ],
        ],
      ),
    );
  }
}

/// Square glass icon button used in headers and toolbars.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
    this.size = 38,
    this.iconSize = 20,
    this.badge,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? semanticLabel;
  final double size;
  final double iconSize;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Icon(icon, size: iconSize, color: AppColors.textPrimary),
              ),
            ),
          ),
          if (badge != null)
            Positioned(top: -3, right: -3, child: badge!),
        ],
      ),
    );
  }
}
