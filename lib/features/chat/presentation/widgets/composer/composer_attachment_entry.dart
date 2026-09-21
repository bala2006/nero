import '../../../../workspace/domain/workspace_item.dart';

/// A workspace item staged in the composer, with a loading flag while its text
/// context is being extracted.
class ComposerAttachmentEntry {
  const ComposerAttachmentEntry({
    required this.item,
    required this.isLoading,
  });

  final WorkspaceItem item;
  final bool isLoading;

  ComposerAttachmentEntry copyWith({WorkspaceItem? item, bool? isLoading}) {
    return ComposerAttachmentEntry(
      item: item ?? this.item,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
