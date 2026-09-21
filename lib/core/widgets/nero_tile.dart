import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Generic actionable row: leading icon, title, optional subtitle and trailing.
///
/// Replaces the near-identical `_SidebarActionTile`, `_ExportFormatTile` and
/// `_AttachmentSourceTile` copies that lived inside private widget files.
class NeroTile extends StatelessWidget {
  const NeroTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.accentColor = AppColors.textPrimary,
    this.iconSize = 18,
    this.padding = const EdgeInsets.fromLTRB(14, 14, 14, 14),
    this.borderRadius = 16,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color accentColor;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle;
    final leadingWidget =
        leading ??
        (icon != null
            ? Icon(icon, size: iconSize, color: accentColor)
            : null);

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          if (leadingWidget != null) ...[
            leadingWidget,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: dense ? 12.6 : 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitleText != null && subtitleText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitleText,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );

    return Material(
      color: AppColors.surfaceGlass,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      ),
    );
  }
}

/// One-line pill used for quick actions inside sheets.
class NeroActionChip extends StatelessWidget {
  const NeroActionChip({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.accentColor = AppColors.textSecondary,
    this.selected = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color accentColor;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final iconData = icon;
    final foreground = selected ? accentColor : AppColors.textSecondary;
    return Material(
      color: selected
          ? accentColor.withValues(alpha: 0.14)
          : AppColors.surfaceOverlay,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? accentColor.withValues(alpha: 0.34)
                  : AppColors.borderSoft,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconData != null) ...[
                Icon(iconData, size: 13, color: foreground),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: foreground,
                  fontSize: 11.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
