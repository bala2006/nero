import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Titled card container used to group settings and detail rows.
///
/// Extracted from the private `_SectionCard` in the settings screen so the new
/// MCP, sandbox, skills and memory screens can share it.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(12),
  });

  final String title;
  final String? subtitle;
  final Widget? child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.2,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitleText != null && subtitleText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitleText,
              style: AppTextStyles.bodySecondary.copyWith(fontSize: 11.8),
            ),
          ],
          if (child != null) ...[
            const SizedBox(height: 10),
            child!,
          ],
        ],
      ),
    );
  }
}
