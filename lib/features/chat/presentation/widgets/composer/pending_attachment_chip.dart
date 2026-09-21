import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../workspace/domain/workspace_item.dart';
import 'attachment_descriptors.dart';

/// Compact chip showing a staged workspace item in the composer.
class PendingAttachmentChip extends StatelessWidget {
  const PendingAttachmentChip({
    super.key,
    required this.item,
    required this.isLoading,
    required this.onRemove,
  });

  final WorkspaceItem item;
  final bool isLoading;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: const Color(0xFF343331),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: attachmentAccentForExtension(
                item.extension,
              ).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              attachmentIconForExtension(item.extension),
              color: AppColors.textOnDarkStrong,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12.7,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  attachmentTypeLabelForExtension(item.extension),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySecondary.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11.4,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: SizedBox(
              width: 12,
              height: 12,
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(1.5),
                      child: CircularProgressIndicator(
                        strokeWidth: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : Material(
                      color: const Color(0xFF9A9A97),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: onRemove,
                        customBorder: const CircleBorder(),
                        child: const SizedBox(
                          width: 12,
                          height: 12,
                          child: Icon(
                            Icons.close_rounded,
                            size: 9,
                            color: Color(0xFF2C2B29),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
