import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import 'composer_action_button.dart';
import 'composer_attachment_entry.dart';
import 'pending_attachment_chip.dart';

/// The chat input surface.
///
/// Extracted from the private `_Composer` in `nero_chat_screen.dart`. The
/// optional [leadingSlots] / [trailingSlots] rows let later phases attach the
/// live thinking strip, the agent-mode selector and the approval indicator
/// without editing the composer again.
class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isGenerating,
    required this.isInputEnabled,
    required this.canSubmit,
    required this.isImportingFiles,
    required this.pendingAttachments,
    required this.footerLabel,
    required this.hintText,
    required this.onImportFiles,
    required this.onRemoveAttachment,
    required this.onSend,
    required this.onStop,
    this.attachedPlanVisible = false,
    this.statusStrip,
    this.modeSelector,
    this.afterInputSlots = const <Widget>[],
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isGenerating;
  final bool isInputEnabled;
  final bool canSubmit;
  final bool isImportingFiles;
  final List<ComposerAttachmentEntry> pendingAttachments;
  final String footerLabel;
  final String hintText;
  final VoidCallback onImportFiles;
  final void Function(String itemId) onRemoveAttachment;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final bool attachedPlanVisible;

  /// Rendered just above the input row (live thinking indicator, banners…).
  final Widget? statusStrip;

  /// Rendered in the footer row, before the send/stop action.
  final Widget? modeSelector;

  /// Extra widgets rendered directly under the text field.
  final List<Widget> afterInputSlots;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        final hasLoadingAttachments = pendingAttachments.any(
          (entry) => entry.isLoading,
        );
        final canSend =
            canSubmit && hasText && !isGenerating && !hasLoadingAttachments;

        return Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceComposer,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(attachedPlanVisible ? 0 : 20),
              topRight: Radius.circular(attachedPlanVisible ? 0 : 20),
              bottomLeft: const Radius.circular(20),
              bottomRight: const Radius.circular(20),
            ),
            border: Border.all(color: AppColors.borderComposer),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (statusStrip != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  child: statusStrip,
                ),
              if (pendingAttachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      height: 58,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (
                              var index = 0;
                              index < pendingAttachments.length;
                              index++
                            ) ...[
                              SizedBox(
                                width: 236,
                                child: PendingAttachmentChip(
                                  item: pendingAttachments[index].item,
                                  isLoading:
                                      pendingAttachments[index].isLoading,
                                  onRemove: () => onRemoveAttachment(
                                    pendingAttachments[index].item.id,
                                  ),
                                ),
                              ),
                              if (index != pendingAttachments.length - 1)
                                const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: isInputEnabled,
                    minLines: 1,
                    maxLines: 5,
                    onSubmitted: (_) => canSend ? onSend() : null,
                    cursorColor: AppColors.textOnDarkStrong,
                    decoration: InputDecoration(
                      hintText: hintText,
                      filled: false,
                      fillColor: Colors.transparent,
                      hintStyle: AppTextStyles.hint.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      height: 1.25,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              for (final slot in afterInputSlots)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                  child: slot,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: isImportingFiles ? null : onImportFiles,
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: Center(
                          child: isImportingFiles
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    color: AppColors.textComposerIcon,
                                  ),
                                )
                              : const Icon(
                                  Icons.attach_file_rounded,
                                  size: 18,
                                  color: AppColors.textComposerIcon,
                                ),
                        ),
                      ),
                    ),
                    if (modeSelector != null) ...[
                      const SizedBox(width: 10),
                      modeSelector!,
                    ],
                    const Spacer(),
                    Text(
                      footerLabel,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11.25,
                        color: AppColors.textComposerFooter,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 14),
                    if (isGenerating)
                      ComposerActionButton(
                        icon: Icons.stop_rounded,
                        semanticLabel: 'Stop generating',
                        background: AppColors.red,
                        foreground: AppColors.textPrimary,
                        onTap: onStop,
                      )
                    else if (hasText)
                      ComposerActionButton(
                        icon: Icons.arrow_upward_rounded,
                        semanticLabel: 'Send',
                        background: canSend
                            ? AppColors.orange
                            : AppColors.surfaceOverlayStrong,
                        foreground: canSend
                            ? AppColors.textOnDarkStrong
                            : AppColors.textMuted,
                        onTap: canSend ? onSend : null,
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          size: 17,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
