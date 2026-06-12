import 'dart:convert';

enum RuntimeRunKind {
  conversation,
  tool,
  workflow,
  skill,
  export,
  system,
}

RuntimeRunKind runtimeRunKindFromJson(String? value) {
  return switch (value) {
    'conversation' => RuntimeRunKind.conversation,
    'tool' => RuntimeRunKind.tool,
    'workflow' => RuntimeRunKind.workflow,
    'skill' => RuntimeRunKind.skill,
    'export' => RuntimeRunKind.export,
    'system' => RuntimeRunKind.system,
    _ => RuntimeRunKind.conversation,
  };
}

String runtimeRunKindToJson(RuntimeRunKind kind) {
  return switch (kind) {
    RuntimeRunKind.conversation => 'conversation',
    RuntimeRunKind.tool => 'tool',
    RuntimeRunKind.workflow => 'workflow',
    RuntimeRunKind.skill => 'skill',
    RuntimeRunKind.export => 'export',
    RuntimeRunKind.system => 'system',
  };
}

enum RuntimeRunStatus {
  queued,
  preparing,
  runningModel,
  runningTools,
  finalizing,
  waitingUser,
  blocked,
  completed,
  failed,
  cancelled,
}

RuntimeRunStatus runtimeRunStatusFromJson(String? value) {
  return switch (value) {
    'queued' => RuntimeRunStatus.queued,
    'preparing' => RuntimeRunStatus.preparing,
    'runningModel' => RuntimeRunStatus.runningModel,
    'runningTools' => RuntimeRunStatus.runningTools,
    'finalizing' => RuntimeRunStatus.finalizing,
    'waitingUser' => RuntimeRunStatus.waitingUser,
    'blocked' => RuntimeRunStatus.blocked,
    'completed' => RuntimeRunStatus.completed,
    'failed' => RuntimeRunStatus.failed,
    'cancelled' => RuntimeRunStatus.cancelled,
    _ => RuntimeRunStatus.queued,
  };
}

String runtimeRunStatusToJson(RuntimeRunStatus status) {
  return switch (status) {
    RuntimeRunStatus.queued => 'queued',
    RuntimeRunStatus.preparing => 'preparing',
    RuntimeRunStatus.runningModel => 'runningModel',
    RuntimeRunStatus.runningTools => 'runningTools',
    RuntimeRunStatus.finalizing => 'finalizing',
    RuntimeRunStatus.waitingUser => 'waitingUser',
    RuntimeRunStatus.blocked => 'blocked',
    RuntimeRunStatus.completed => 'completed',
    RuntimeRunStatus.failed => 'failed',
    RuntimeRunStatus.cancelled => 'cancelled',
  };
}

class RuntimeRun {
  const RuntimeRun({
    required this.id,
    required this.kind,
    required this.title,
    required this.status,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.conversationId,
    this.taskId,
    this.parentRunId,
    this.capabilityKey,
    this.request = const <String, Object?>{},
    this.result,
    this.error,
    this.metadata = const <String, Object?>{},
    this.completedAtEpochMs,
  });

  final String id;
  final RuntimeRunKind kind;
  final String title;
  final RuntimeRunStatus status;
  final String? conversationId;
  final String? taskId;
  final String? parentRunId;
  final String? capabilityKey;
  final Map<String, Object?> request;
  final Map<String, Object?>? result;
  final String? error;
  final Map<String, Object?> metadata;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  final int? completedAtEpochMs;

  RuntimeRun copyWith({
    String? id,
    RuntimeRunKind? kind,
    String? title,
    RuntimeRunStatus? status,
    String? conversationId,
    bool clearConversationId = false,
    String? taskId,
    bool clearTaskId = false,
    String? parentRunId,
    bool clearParentRunId = false,
    String? capabilityKey,
    bool clearCapabilityKey = false,
    Map<String, Object?>? request,
    Map<String, Object?>? result,
    bool clearResult = false,
    String? error,
    bool clearError = false,
    Map<String, Object?>? metadata,
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
    int? completedAtEpochMs,
    bool clearCompletedAtEpochMs = false,
  }) {
    return RuntimeRun(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      status: status ?? this.status,
      conversationId: clearConversationId
          ? null
          : conversationId ?? this.conversationId,
      taskId: clearTaskId ? null : taskId ?? this.taskId,
      parentRunId: clearParentRunId
          ? null
          : parentRunId ?? this.parentRunId,
      capabilityKey: clearCapabilityKey
          ? null
          : capabilityKey ?? this.capabilityKey,
      request: request ?? this.request,
      result: clearResult ? null : result ?? this.result,
      error: clearError ? null : error ?? this.error,
      metadata: metadata ?? this.metadata,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      completedAtEpochMs: clearCompletedAtEpochMs
          ? null
          : completedAtEpochMs ?? this.completedAtEpochMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': runtimeRunKindToJson(kind),
        'title': title,
        'status': runtimeRunStatusToJson(status),
        'conversationId': conversationId,
        'taskId': taskId,
        'parentRunId': parentRunId,
        'capabilityKey': capabilityKey,
        'request': request,
        'result': result,
        'error': error,
        'metadata': metadata,
        'createdAtEpochMs': createdAtEpochMs,
        'updatedAtEpochMs': updatedAtEpochMs,
        'completedAtEpochMs': completedAtEpochMs,
      };

  factory RuntimeRun.fromJson(Map<String, dynamic> json) {
    return RuntimeRun(
      id: json['id']?.toString() ?? '',
      kind: runtimeRunKindFromJson(json['kind']?.toString()),
      title: json['title']?.toString() ?? '',
      status: runtimeRunStatusFromJson(json['status']?.toString()),
      conversationId: json['conversationId']?.toString(),
      taskId: json['taskId']?.toString(),
      parentRunId: json['parentRunId']?.toString(),
      capabilityKey: json['capabilityKey']?.toString(),
      request: _readObjectMap(json['request']),
      result: _readNullableObjectMap(json['result']),
      error: json['error']?.toString(),
      metadata: _readObjectMap(json['metadata']),
      createdAtEpochMs: (json['createdAtEpochMs'] as num?)?.toInt() ?? 0,
      updatedAtEpochMs: (json['updatedAtEpochMs'] as num?)?.toInt() ?? 0,
      completedAtEpochMs: (json['completedAtEpochMs'] as num?)?.toInt(),
    );
  }

  String get requestJson => jsonEncode(request);
  String? get resultJson => result == null ? null : jsonEncode(result);
  String get metadataJson => jsonEncode(metadata);

  static Map<String, Object?> _readObjectMap(Object? value) {
    if (value is Map) {
      return Map<String, Object?>.from(value);
    }
    return const <String, Object?>{};
  }

  static Map<String, Object?>? _readNullableObjectMap(Object? value) {
    if (value is Map) {
      return Map<String, Object?>.from(value);
    }
    return null;
  }
}
