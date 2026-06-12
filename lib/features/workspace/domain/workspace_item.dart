enum WorkspaceItemType {
  importedFile,
  generatedArtifact,
  packagedArtifact,
}

WorkspaceItemType workspaceItemTypeFromJson(String? value) {
  return switch (value) {
    'generatedArtifact' => WorkspaceItemType.generatedArtifact,
    'importedFile' => WorkspaceItemType.importedFile,
    'packagedArtifact' => WorkspaceItemType.packagedArtifact,
    _ => WorkspaceItemType.importedFile,
  };
}

String workspaceItemTypeToJson(WorkspaceItemType type) {
  return switch (type) {
    WorkspaceItemType.importedFile => 'importedFile',
    WorkspaceItemType.generatedArtifact => 'generatedArtifact',
    WorkspaceItemType.packagedArtifact => 'packagedArtifact',
  };
}

class WorkspaceItem {
  const WorkspaceItem({
    required this.id,
    required this.conversationId,
    required this.type,
    required this.title,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.sourceUri,
    this.localPath,
    this.mimeType,
    this.extension,
    this.sizeBytes,
    this.metadataJson,
  });

  final String id;
  final String conversationId;
  final WorkspaceItemType type;
  final String title;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  final String? sourceUri;
  final String? localPath;
  final String? mimeType;
  final String? extension;
  final int? sizeBytes;
  final String? metadataJson;

  WorkspaceItem copyWith({
    String? id,
    String? conversationId,
    WorkspaceItemType? type,
    String? title,
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
    String? sourceUri,
    bool clearSourceUri = false,
    String? localPath,
    bool clearLocalPath = false,
    String? mimeType,
    bool clearMimeType = false,
    String? extension,
    bool clearExtension = false,
    int? sizeBytes,
    bool clearSizeBytes = false,
    String? metadataJson,
    bool clearMetadataJson = false,
  }) {
    return WorkspaceItem(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      type: type ?? this.type,
      title: title ?? this.title,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      sourceUri: clearSourceUri ? null : sourceUri ?? this.sourceUri,
      localPath: clearLocalPath ? null : localPath ?? this.localPath,
      mimeType: clearMimeType ? null : mimeType ?? this.mimeType,
      extension: clearExtension ? null : extension ?? this.extension,
      sizeBytes: clearSizeBytes ? null : sizeBytes ?? this.sizeBytes,
      metadataJson: clearMetadataJson ? null : metadataJson ?? this.metadataJson,
    );
  }
}
