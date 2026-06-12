enum ResponseBlockType {
  markdown,
  activity,
  artifact,
  raw,
}

String _responseBlockTypeToJson(ResponseBlockType type) {
  return switch (type) {
    ResponseBlockType.markdown => 'markdown',
    ResponseBlockType.activity => 'activity',
    ResponseBlockType.artifact => 'artifact',
    ResponseBlockType.raw => 'raw',
  };
}

ResponseBlockType _responseBlockTypeFromJson(String? value) {
  return switch (value) {
    'markdown' => ResponseBlockType.markdown,
    'activity' => ResponseBlockType.activity,
    'artifact' => ResponseBlockType.artifact,
    'raw' => ResponseBlockType.raw,
    _ => ResponseBlockType.raw,
  };
}

enum ActivityTraceType {
  planning,
  research,
  build,
  tool,
  verification,
  finalization,
  note,
}

String _activityTraceTypeToJson(ActivityTraceType type) {
  return switch (type) {
    ActivityTraceType.planning => 'planning',
    ActivityTraceType.research => 'research',
    ActivityTraceType.build => 'build',
    ActivityTraceType.tool => 'tool',
    ActivityTraceType.verification => 'verification',
    ActivityTraceType.finalization => 'finalization',
    ActivityTraceType.note => 'note',
  };
}

ActivityTraceType _activityTraceTypeFromJson(String? value) {
  return switch (value) {
    'planning' => ActivityTraceType.planning,
    'research' => ActivityTraceType.research,
    'build' => ActivityTraceType.build,
    'tool' => ActivityTraceType.tool,
    'verification' => ActivityTraceType.verification,
    'finalization' => ActivityTraceType.finalization,
    'note' => ActivityTraceType.note,
    _ => ActivityTraceType.note,
  };
}

enum ActivityTraceStatus {
  pending,
  running,
  completed,
  blocked,
  failed,
  cancelled,
}

String _activityTraceStatusToJson(ActivityTraceStatus status) {
  return switch (status) {
    ActivityTraceStatus.pending => 'pending',
    ActivityTraceStatus.running => 'running',
    ActivityTraceStatus.completed => 'completed',
    ActivityTraceStatus.blocked => 'blocked',
    ActivityTraceStatus.failed => 'failed',
    ActivityTraceStatus.cancelled => 'cancelled',
  };
}

ActivityTraceStatus _activityTraceStatusFromJson(String? value) {
  return switch (value) {
    'pending' => ActivityTraceStatus.pending,
    'running' => ActivityTraceStatus.running,
    'completed' => ActivityTraceStatus.completed,
    'blocked' => ActivityTraceStatus.blocked,
    'failed' => ActivityTraceStatus.failed,
    'cancelled' => ActivityTraceStatus.cancelled,
    _ => ActivityTraceStatus.completed,
  };
}

class ResponseQuality {
  const ResponseQuality({
    this.verified = false,
    this.reviewedByVerifier = false,
    this.score,
    this.notes = const <String>[],
    this.metadata = const <String, Object?>{},
  });

  final bool verified;
  final bool reviewedByVerifier;
  final double? score;
  final List<String> notes;
  final Map<String, Object?> metadata;

  ResponseQuality copyWith({
    bool? verified,
    bool? reviewedByVerifier,
    double? score,
    List<String>? notes,
    Map<String, Object?>? metadata,
  }) {
    return ResponseQuality(
      verified: verified ?? this.verified,
      reviewedByVerifier: reviewedByVerifier ?? this.reviewedByVerifier,
      score: score ?? this.score,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'verified': verified,
        'reviewedByVerifier': reviewedByVerifier,
        'score': score,
        'notes': notes,
        'metadata': metadata,
      };

  factory ResponseQuality.fromJson(Map<String, dynamic> json) {
    final rawNotes = json['notes'];
    return ResponseQuality(
      verified: json['verified'] == true,
      reviewedByVerifier: json['reviewedByVerifier'] == true,
      score: (json['score'] as num?)?.toDouble(),
      notes: rawNotes is List
          ? rawNotes.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      metadata: _readObjectMap(json['metadata']),
    );
  }
}

class ResponseArtifactReference {
  const ResponseArtifactReference({
    required this.artifactId,
    required this.title,
    required this.kindLabel,
    this.extension,
    this.mimeType,
    this.localPath,
    this.sourceUri,
    this.sizeBytes,
    this.metadata = const <String, Object?>{},
  });

  final String artifactId;
  final String title;
  final String kindLabel;
  final String? extension;
  final String? mimeType;
  final String? localPath;
  final String? sourceUri;
  final int? sizeBytes;
  final Map<String, Object?> metadata;

  String get id => artifactId;

  ResponseArtifactReference copyWith({
    String? artifactId,
    String? title,
    String? kindLabel,
    String? extension,
    bool clearExtension = false,
    String? mimeType,
    bool clearMimeType = false,
    String? localPath,
    bool clearLocalPath = false,
    String? sourceUri,
    bool clearSourceUri = false,
    int? sizeBytes,
    bool clearSizeBytes = false,
    Map<String, Object?>? metadata,
  }) {
    return ResponseArtifactReference(
      artifactId: artifactId ?? this.artifactId,
      title: title ?? this.title,
      kindLabel: kindLabel ?? this.kindLabel,
      extension: clearExtension ? null : extension ?? this.extension,
      mimeType: clearMimeType ? null : mimeType ?? this.mimeType,
      localPath: clearLocalPath ? null : localPath ?? this.localPath,
      sourceUri: clearSourceUri ? null : sourceUri ?? this.sourceUri,
      sizeBytes: clearSizeBytes ? null : sizeBytes ?? this.sizeBytes,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'artifactId': artifactId,
        'id': artifactId,
        'title': title,
        'kindLabel': kindLabel,
        'extension': extension,
        'mimeType': mimeType,
        'localPath': localPath,
        'sourceUri': sourceUri,
        'sizeBytes': sizeBytes,
        'metadata': metadata,
      };

  factory ResponseArtifactReference.fromJson(Map<String, dynamic> json) {
    return ResponseArtifactReference(
      artifactId: json['artifactId']?.toString() ??
          json['id']?.toString() ??
          '',
      title: json['title']?.toString() ?? '',
      kindLabel: json['kindLabel']?.toString() ?? 'Artifact',
      extension: json['extension']?.toString(),
      mimeType: json['mimeType']?.toString(),
      localPath: json['localPath']?.toString(),
      sourceUri: json['sourceUri']?.toString(),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      metadata: _readObjectMap(json['metadata']),
    );
  }
}

class ActivityTrace {
  const ActivityTrace({
    required this.id,
    required this.type,
    required this.title,
    this.detail,
    this.status = ActivityTraceStatus.completed,
    this.isComplete = true,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final ActivityTraceType type;
  final String title;
  final String? detail;
  final ActivityTraceStatus status;
  final bool isComplete;
  final Map<String, Object?> metadata;

  ActivityTrace copyWith({
    String? id,
    ActivityTraceType? type,
    String? title,
    String? detail,
    bool clearDetail = false,
    ActivityTraceStatus? status,
    bool? isComplete,
    Map<String, Object?>? metadata,
  }) {
    return ActivityTrace(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      detail: clearDetail ? null : detail ?? this.detail,
      status: status ?? this.status,
      isComplete: isComplete ?? this.isComplete,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': _activityTraceTypeToJson(type),
        'title': title,
        'detail': detail,
        'status': _activityTraceStatusToJson(status),
        'isComplete': isComplete,
        'metadata': metadata,
      };

  factory ActivityTrace.fromJson(Map<String, dynamic> json) {
    return ActivityTrace(
      id: json['id']?.toString() ?? '',
      type: _activityTraceTypeFromJson(json['type']?.toString()),
      title: json['title']?.toString() ?? '',
      detail: json['detail']?.toString(),
      status: _activityTraceStatusFromJson(json['status']?.toString()),
      isComplete: json['isComplete'] == true,
      metadata: _readObjectMap(json['metadata']),
    );
  }
}

abstract class ResponseBlock {
  const ResponseBlock(this.type);

  final ResponseBlockType type;

  Map<String, dynamic> toJson();

  static ResponseBlock fromJson(Map<String, dynamic> json) {
    return switch (_responseBlockTypeFromJson(json['type']?.toString())) {
      ResponseBlockType.markdown => ResponseMarkdownBlock.fromJson(json),
      ResponseBlockType.activity => ResponseActivityBlock.fromJson(json),
      ResponseBlockType.artifact => ResponseArtifactBlock.fromJson(json),
      ResponseBlockType.raw => ResponseRawBlock.fromJson(json),
    };
  }
}

class ResponseMarkdownBlock extends ResponseBlock {
  const ResponseMarkdownBlock({
    required this.content,
    this.title,
    this.metadata = const <String, Object?>{},
  }) : super(ResponseBlockType.markdown);

  final String content;
  final String? title;
  final Map<String, Object?> metadata;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': _responseBlockTypeToJson(type),
        'content': content,
        'title': title,
        'metadata': metadata,
      };

  factory ResponseMarkdownBlock.fromJson(Map<String, dynamic> json) {
    return ResponseMarkdownBlock(
      content: json['content']?.toString() ?? '',
      title: json['title']?.toString(),
      metadata: _readObjectMap(json['metadata']),
    );
  }
}

class ResponseActivityBlock extends ResponseBlock {
  const ResponseActivityBlock({
    required this.trace,
    this.metadata = const <String, Object?>{},
  }) : super(ResponseBlockType.activity);

  final ActivityTrace trace;
  final Map<String, Object?> metadata;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': _responseBlockTypeToJson(type),
        'trace': trace.toJson(),
        'metadata': metadata,
      };

  factory ResponseActivityBlock.fromJson(Map<String, dynamic> json) {
    final rawTrace = json['trace'];
    return ResponseActivityBlock(
      trace: rawTrace is Map
          ? ActivityTrace.fromJson(Map<String, dynamic>.from(rawTrace))
          : ActivityTrace(
              id: json['id']?.toString() ?? 'activity_${DateTime.now().microsecondsSinceEpoch}',
              type: ActivityTraceType.note,
              title: json['title']?.toString() ?? '',
              detail: json['detail']?.toString(),
            ),
      metadata: _readObjectMap(json['metadata']),
    );
  }
}

class ResponseArtifactBlock extends ResponseBlock {
  const ResponseArtifactBlock({
    required this.reference,
    this.note,
    this.metadata = const <String, Object?>{},
  }) : super(ResponseBlockType.artifact);

  final ResponseArtifactReference reference;
  final String? note;
  final Map<String, Object?> metadata;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': _responseBlockTypeToJson(type),
        'reference': reference.toJson(),
        'note': note,
        'metadata': metadata,
      };

  factory ResponseArtifactBlock.fromJson(Map<String, dynamic> json) {
    final rawReference = json['reference'];
    return ResponseArtifactBlock(
      reference: rawReference is Map
          ? ResponseArtifactReference.fromJson(
              Map<String, dynamic>.from(rawReference),
            )
          : ResponseArtifactReference(
              artifactId: json['artifactId']?.toString() ??
                  json['id']?.toString() ??
                  '',
              title: json['title']?.toString() ?? '',
              kindLabel: json['kindLabel']?.toString() ?? 'Artifact',
              extension: json['extension']?.toString(),
              mimeType: json['mimeType']?.toString(),
              localPath: json['localPath']?.toString(),
              sourceUri: json['sourceUri']?.toString(),
              sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
              metadata: _readObjectMap(json['metadata']),
            ),
      note: json['note']?.toString(),
      metadata: _readObjectMap(json['metadata']),
    );
  }
}

class ResponseRawBlock extends ResponseBlock {
  const ResponseRawBlock({
    required this.content,
    this.label,
    this.metadata = const <String, Object?>{},
  }) : super(ResponseBlockType.raw);

  final String content;
  final String? label;
  final Map<String, Object?> metadata;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': _responseBlockTypeToJson(type),
        'content': content,
        'label': label,
        'metadata': metadata,
      };

  factory ResponseRawBlock.fromJson(Map<String, dynamic> json) {
    return ResponseRawBlock(
      content: json['content']?.toString() ?? '',
      label: json['label']?.toString(),
      metadata: _readObjectMap(json['metadata']),
    );
  }
}

class RunSummary {
  const RunSummary({
    required this.runId,
    required this.title,
    required this.status,
    required this.summaryText,
    this.conversationId,
    this.modelId,
    this.artifactCount = 0,
    this.activityCount = 0,
    this.verified = false,
    this.reviewedByVerifier = false,
    this.createdAtEpochMs,
    this.completedAtEpochMs,
    this.metadata = const <String, Object?>{},
  });

  final String runId;
  final String title;
  final String status;
  final String summaryText;
  final String? conversationId;
  final String? modelId;
  final int artifactCount;
  final int activityCount;
  final bool verified;
  final bool reviewedByVerifier;
  final int? createdAtEpochMs;
  final int? completedAtEpochMs;
  final Map<String, Object?> metadata;

  bool get isTerminal {
    return switch (status) {
      'completed' || 'failed' || 'cancelled' || 'blocked' => true,
      _ => false,
    };
  }

  RunSummary copyWith({
    String? runId,
    String? title,
    String? status,
    String? summaryText,
    String? conversationId,
    bool clearConversationId = false,
    String? modelId,
    bool clearModelId = false,
    int? artifactCount,
    int? activityCount,
    bool? verified,
    bool? reviewedByVerifier,
    int? createdAtEpochMs,
    bool clearCreatedAtEpochMs = false,
    int? completedAtEpochMs,
    bool clearCompletedAtEpochMs = false,
    Map<String, Object?>? metadata,
  }) {
    return RunSummary(
      runId: runId ?? this.runId,
      title: title ?? this.title,
      status: status ?? this.status,
      summaryText: summaryText ?? this.summaryText,
      conversationId: clearConversationId
          ? null
          : conversationId ?? this.conversationId,
      modelId: clearModelId ? null : modelId ?? this.modelId,
      artifactCount: artifactCount ?? this.artifactCount,
      activityCount: activityCount ?? this.activityCount,
      verified: verified ?? this.verified,
      reviewedByVerifier: reviewedByVerifier ?? this.reviewedByVerifier,
      createdAtEpochMs: clearCreatedAtEpochMs
          ? null
          : createdAtEpochMs ?? this.createdAtEpochMs,
      completedAtEpochMs: clearCompletedAtEpochMs
          ? null
          : completedAtEpochMs ?? this.completedAtEpochMs,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'runId': runId,
        'title': title,
        'status': status,
        'summaryText': summaryText,
        'conversationId': conversationId,
        'modelId': modelId,
        'artifactCount': artifactCount,
        'activityCount': activityCount,
        'verified': verified,
        'reviewedByVerifier': reviewedByVerifier,
        'createdAtEpochMs': createdAtEpochMs,
        'completedAtEpochMs': completedAtEpochMs,
        'metadata': metadata,
      };

  factory RunSummary.fromJson(Map<String, dynamic> json) {
    return RunSummary(
      runId: json['runId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      status: json['status']?.toString() ?? 'completed',
      summaryText: json['summaryText']?.toString() ?? '',
      conversationId: json['conversationId']?.toString(),
      modelId: json['modelId']?.toString(),
      artifactCount: (json['artifactCount'] as num?)?.toInt() ?? 0,
      activityCount: (json['activityCount'] as num?)?.toInt() ?? 0,
      verified: json['verified'] == true,
      reviewedByVerifier: json['reviewedByVerifier'] == true,
      createdAtEpochMs: (json['createdAtEpochMs'] as num?)?.toInt(),
      completedAtEpochMs: (json['completedAtEpochMs'] as num?)?.toInt(),
      metadata: _readObjectMap(json['metadata']),
    );
  }
}

class ResponseEnvelope {
  const ResponseEnvelope({
    required this.summaryText,
    this.blocks = const <ResponseBlock>[],
    this.artifacts = const <ResponseArtifactReference>[],
    this.activities = const <ActivityTrace>[],
    this.runSummary,
    this.quality = const ResponseQuality(),
    this.metadata = const <String, Object?>{},
  });

  final String summaryText;
  final List<ResponseBlock> blocks;
  final List<ResponseArtifactReference> artifacts;
  final List<ActivityTrace> activities;
  final RunSummary? runSummary;
  final ResponseQuality quality;
  final Map<String, Object?> metadata;

  List<ResponseArtifactReference> get artifactReferences => artifacts;

  String get displayText {
    if (summaryText.trim().isNotEmpty) {
      return summaryText;
    }
    for (final block in blocks) {
      if (block is ResponseMarkdownBlock && block.content.trim().isNotEmpty) {
        return block.content;
      }
      if (block is ResponseRawBlock && block.content.trim().isNotEmpty) {
        return block.content;
      }
    }
    return '';
  }

  bool get hasArtifacts => artifacts.isNotEmpty;

  ResponseEnvelope copyWith({
    String? summaryText,
    List<ResponseBlock>? blocks,
    List<ResponseArtifactReference>? artifacts,
    List<ActivityTrace>? activities,
    RunSummary? runSummary,
    bool clearRunSummary = false,
    ResponseQuality? quality,
    Map<String, Object?>? metadata,
  }) {
    return ResponseEnvelope(
      summaryText: summaryText ?? this.summaryText,
      blocks: blocks ?? this.blocks,
      artifacts: artifacts ?? this.artifacts,
      activities: activities ?? this.activities,
      runSummary: clearRunSummary ? null : runSummary ?? this.runSummary,
      quality: quality ?? this.quality,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'summaryText': summaryText,
        'blocks': blocks.map((block) => block.toJson()).toList(growable: false),
        'artifacts':
            artifacts.map((artifact) => artifact.toJson()).toList(growable: false),
        'activities':
            activities.map((activity) => activity.toJson()).toList(growable: false),
        'runSummary': runSummary?.toJson(),
        'quality': quality.toJson(),
        'metadata': metadata,
      };

  factory ResponseEnvelope.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['blocks'];
    final rawArtifacts = json['artifacts'];
    final rawActivities = json['activities'];
    final rawSummary = json['runSummary'];
    final rawQuality = json['quality'];
    return ResponseEnvelope(
      summaryText: json['summaryText']?.toString() ?? '',
      blocks: rawBlocks is List
          ? rawBlocks
              .whereType<Map>()
              .map(
                (item) => ResponseBlock.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const <ResponseBlock>[],
      artifacts: rawArtifacts is List
          ? rawArtifacts
              .whereType<Map>()
              .map(
                (item) => ResponseArtifactReference.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const <ResponseArtifactReference>[],
      activities: rawActivities is List
          ? rawActivities
              .whereType<Map>()
              .map(
                (item) => ActivityTrace.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const <ActivityTrace>[],
      runSummary: rawSummary is Map
          ? RunSummary.fromJson(Map<String, dynamic>.from(rawSummary))
          : null,
      quality: rawQuality is Map
          ? ResponseQuality.fromJson(Map<String, dynamic>.from(rawQuality))
          : const ResponseQuality(),
      metadata: _readObjectMap(json['metadata']),
    );
  }
}

Map<String, Object?> _readObjectMap(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  return const <String, Object?>{};
}
