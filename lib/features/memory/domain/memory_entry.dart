import 'dart:convert';

enum MemoryEntryKind {
  working,
  episodic,
  semantic,
  artifact,
  contextSnapshot,
}

MemoryEntryKind memoryEntryKindFromJson(String? value) {
  return switch (value) {
    'working' => MemoryEntryKind.working,
    'semantic' => MemoryEntryKind.semantic,
    'artifact' => MemoryEntryKind.artifact,
    'contextSnapshot' => MemoryEntryKind.contextSnapshot,
    'episodic' => MemoryEntryKind.episodic,
    _ => MemoryEntryKind.episodic,
  };
}

String memoryEntryKindToJson(MemoryEntryKind kind) {
  return switch (kind) {
    MemoryEntryKind.working => 'working',
    MemoryEntryKind.episodic => 'episodic',
    MemoryEntryKind.semantic => 'semantic',
    MemoryEntryKind.artifact => 'artifact',
    MemoryEntryKind.contextSnapshot => 'contextSnapshot',
  };
}

class MemoryEntry {
  const MemoryEntry({
    required this.id,
    required this.kind,
    required this.scope,
    required this.title,
    required this.content,
    required this.tags,
    required this.importanceScore,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.summary,
    this.conversationId,
    this.taskId,
    this.sourceEntityType,
    this.sourceEntityId,
    this.lastAccessedAtEpochMs,
  });

  final String id;
  final MemoryEntryKind kind;
  final String scope;
  final String title;
  final Map<String, Object?> content;
  final String? summary;
  final List<String> tags;
  final String? conversationId;
  final String? taskId;
  final String? sourceEntityType;
  final String? sourceEntityId;
  final double importanceScore;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  final int? lastAccessedAtEpochMs;

  MemoryEntry copyWith({
    String? id,
    MemoryEntryKind? kind,
    String? scope,
    String? title,
    Map<String, Object?>? content,
    String? summary,
    bool clearSummary = false,
    List<String>? tags,
    String? conversationId,
    bool clearConversationId = false,
    String? taskId,
    bool clearTaskId = false,
    String? sourceEntityType,
    bool clearSourceEntityType = false,
    String? sourceEntityId,
    bool clearSourceEntityId = false,
    double? importanceScore,
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
    int? lastAccessedAtEpochMs,
    bool clearLastAccessedAtEpochMs = false,
  }) {
    return MemoryEntry(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      scope: scope ?? this.scope,
      title: title ?? this.title,
      content: content ?? this.content,
      summary: clearSummary ? null : summary ?? this.summary,
      tags: tags ?? this.tags,
      conversationId: clearConversationId
          ? null
          : conversationId ?? this.conversationId,
      taskId: clearTaskId ? null : taskId ?? this.taskId,
      sourceEntityType: clearSourceEntityType
          ? null
          : sourceEntityType ?? this.sourceEntityType,
      sourceEntityId: clearSourceEntityId
          ? null
          : sourceEntityId ?? this.sourceEntityId,
      importanceScore: importanceScore ?? this.importanceScore,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      lastAccessedAtEpochMs: clearLastAccessedAtEpochMs
          ? null
          : lastAccessedAtEpochMs ?? this.lastAccessedAtEpochMs,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'kind': memoryEntryKindToJson(kind),
        'scope': scope,
        'title': title,
        'content': content,
        'summary': summary,
        'tags': tags,
        'conversationId': conversationId,
        'taskId': taskId,
        'sourceEntityType': sourceEntityType,
        'sourceEntityId': sourceEntityId,
        'importanceScore': importanceScore,
        'createdAtEpochMs': createdAtEpochMs,
        'updatedAtEpochMs': updatedAtEpochMs,
        'lastAccessedAtEpochMs': lastAccessedAtEpochMs,
      };

  factory MemoryEntry.fromJson(Map<String, Object?> json) {
    final rawContent = json['content'];
    final rawTags = json['tags'];
    return MemoryEntry(
      id: json['id']?.toString() ?? '',
      kind: memoryEntryKindFromJson(json['kind']?.toString()),
      scope: json['scope']?.toString() ?? 'global',
      title: json['title']?.toString() ?? '',
      content: rawContent is Map
          ? Map<String, Object?>.from(rawContent)
          : const <String, Object?>{},
      summary: json['summary']?.toString(),
      tags: rawTags is List
          ? rawTags.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      conversationId: json['conversationId']?.toString(),
      taskId: json['taskId']?.toString(),
      sourceEntityType: json['sourceEntityType']?.toString(),
      sourceEntityId: json['sourceEntityId']?.toString(),
      importanceScore: (json['importanceScore'] as num?)?.toDouble() ?? 0,
      createdAtEpochMs: (json['createdAtEpochMs'] as num?)?.toInt() ?? 0,
      updatedAtEpochMs: (json['updatedAtEpochMs'] as num?)?.toInt() ?? 0,
      lastAccessedAtEpochMs: (json['lastAccessedAtEpochMs'] as num?)?.toInt(),
    );
  }

  String get contentJson => jsonEncode(content);
  String get tagsJson => jsonEncode(tags);
}
