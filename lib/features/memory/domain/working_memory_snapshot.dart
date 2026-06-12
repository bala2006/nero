class WorkingMemorySnapshot {
  const WorkingMemorySnapshot({
    required this.id,
    required this.taskId,
    required this.summary,
    required this.assumptions,
    required this.focusFilePaths,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.conversationId,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final String? conversationId;
  final String taskId;
  final String summary;
  final List<String> assumptions;
  final List<String> focusFilePaths;
  final Map<String, Object?> metadata;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;

  WorkingMemorySnapshot copyWith({
    String? id,
    String? conversationId,
    bool clearConversationId = false,
    String? taskId,
    String? summary,
    List<String>? assumptions,
    List<String>? focusFilePaths,
    Map<String, Object?>? metadata,
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
  }) {
    return WorkingMemorySnapshot(
      id: id ?? this.id,
      conversationId: clearConversationId
          ? null
          : conversationId ?? this.conversationId,
      taskId: taskId ?? this.taskId,
      summary: summary ?? this.summary,
      assumptions: assumptions ?? this.assumptions,
      focusFilePaths: focusFilePaths ?? this.focusFilePaths,
      metadata: metadata ?? this.metadata,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
    );
  }
}
