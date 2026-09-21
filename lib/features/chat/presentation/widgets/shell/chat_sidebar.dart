import 'package:flutter/material.dart';

import '../../../../../app/navigation.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../application/chat_history_controller.dart';
import '../../../domain/chat_conversation.dart';

/// Navigation drawer for the app: app destinations plus recent conversations.
///
/// Extracted from the private `_ChatSidebar` in `nero_chat_screen.dart` so the
/// shell can own it and later phases can add destinations without touching the
/// chat screen again.
class ChatSidebar extends StatefulWidget {
  const ChatSidebar({
    super.key,
    required this.historyController,
    required this.activeConversationId,
    required this.onNewChat,
    required this.onSelectConversation,
    required this.onDeleteConversation,
    required this.destinations,
    required this.onOpenDestination,
    this.footer,
  });

  final ChatHistoryController historyController;
  final String? activeConversationId;
  final Future<void> Function() onNewChat;
  final Future<void> Function(ChatConversation conversation)
  onSelectConversation;

  /// Swipe-to-delete on a conversation row. When null, no dismiss affordance.
  final Future<void> Function(ChatConversation conversation)?
  onDeleteConversation;

  final List<NeroDestination> destinations;
  final Future<void> Function(NeroDestination destination) onOpenDestination;

  /// Bottom strip (settings entry, status lines). Built by the host screen so
  /// it can read services the sidebar does not know about.
  final Widget? footer;

  @override
  State<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends State<ChatSidebar> {
  /// Longest label among the destinations, used to reserve footer space so
  /// adding an entry never causes a layout jump on first build.
  static const double _footerReservedHeight = 34;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.historyController,
      builder: (context, _) {
        final conversations = widget.historyController.conversations;
        return Drawer(
          backgroundColor: AppColors.surfaceSoft,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 12, 10),
                  child: Row(
                    children: [
                      Text(
                        'Nero',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      _SidebarIconButton(
                        icon: Icons.create_rounded,
                        semanticLabel: 'New chat',
                        onTap: widget.onNewChat,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _SidebarActionTile(
                    icon: Icons.add_rounded,
                    label: 'New chat',
                    onTap: widget.onNewChat,
                  ),
                ),
                if (widget.destinations.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 16, 18, 4),
                    child: Text(
                      'Tools',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        for (final destination in widget.destinations)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: _SidebarActionTile(
                              icon: destination.icon,
                              label: destination.label,
                              subtitle: destination.subtitle,
                              onTap: () async {
                                Navigator.of(context).pop();
                                await widget.onOpenDestination(destination);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
                  child: Text(
                    'Recents',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: conversations.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                          child: Text(
                            'Nothing yet. Start a chat and it will show up here.',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11.6,
                              height: 1.4,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                          itemCount: conversations.length,
                          itemBuilder: (context, index) {
                            final conversation = conversations[index];
                            final selected =
                                conversation.id == widget.activeConversationId;
                            final tile = _ConversationListTile(
                              conversation: conversation,
                              isSelected: selected,
                              onTap: () =>
                                  widget.onSelectConversation(conversation),
                            );
                            final onDelete =
                                widget.onDeleteConversation;
                            if (onDelete == null) {
                              return tile;
                            }
                            return Dismissible(
                              key: ValueKey('conversation_${conversation.id}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.only(right: 18),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(
                                    alpha: 0.16,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: AppColors.error,
                                ),
                              ),
                              confirmDismiss: (_) async {
                                return await _confirmDelete(conversation);
                              },
                              onDismissed: (_) =>
                                  onDelete(conversation),
                              child: tile,
                            );
                          },
                        ),
                ),
                // Footer keeps a fixed slot so the list never jumps when the
                // status row appears or disappears.
                SizedBox(
                  height: _footerReservedHeight,
                  child: widget.footer ?? const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDelete(ChatConversation conversation) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this chat?'),
        content: Text(
          '"${conversation.title}" and its messages will be removed from this '
          'device.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _SidebarActionTile extends StatelessWidget {
  const _SidebarActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitleText != null && subtitleText.isNotEmpty)
                    Text(
                      subtitleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 10.6,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationListTile extends StatelessWidget {
  const _ConversationListTile({
    required this.conversation,
    required this.isSelected,
    required this.onTap,
  });

  final ChatConversation conversation;
  final bool isSelected;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected ? AppColors.surfaceOverlayStrong : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.orange.withValues(alpha: 0.32)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  isSelected
                      ? Icons.chat_bubble_rounded
                      : Icons.chat_bubble_outline_rounded,
                  size: 13,
                  color: isSelected
                      ? AppColors.orange
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    conversation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarIconButton extends StatelessWidget {
  const _SidebarIconButton({
    required this.icon,
    required this.onTap,
    this.semanticLabel,
  });

  final IconData icon;
  final Future<void> Function() onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: AppColors.surfaceOverlay,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.textPrimary, size: 18),
          ),
        ),
      ),
    );
  }
}
