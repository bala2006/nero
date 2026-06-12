import 'dart:convert';

enum RuntimeRunNodeStatus {
  queued,
  running,
  waiting,
  completed,
  failed,
  cancelled,
  blocked,
  skipped,
}

RuntimeRunNodeStatus runtimeRunNodeStatusFromJson(String? value) {
  return switch (value) {
    'queued' => RuntimeRunNodeStatus.queued,
    'running' => RuntimeRunNodeStatus.running,
    'waiting' => RuntimeRunNodeStatus.waiting,
    'completed' => RuntimeRunNodeStatus.completed,
    'failed' => RuntimeRunNodeStatus.failed,
    'cancelled' => RuntimeRunNodeStatus.cancelled,
    'blocked' => RuntimeRunNodeStatus.blocked,
    'skipped' => RuntimeRunNodeStatus.skipped,
    _ => RuntimeRunNodeStatus.queued,
  };
}

String runtimeRunNodeStatusToJson(RuntimeRunNodeStatus status) {
  return switch (status) {
    RuntimeRunNodeStatus.queued => 'queued',
    RuntimeRunNodeStatus.running => 'running',
    RuntimeRunNodeStatus.waiting => 'waiting',
    RuntimeRunNodeStatus.completed => 'completed',
    RuntimeRunNodeStatus.failed => 'failed',
    RuntimeRunNodeStatus.cancelled => 'cancelled',
    RuntimeRunNodeStatus.blocked => 'blocked',
    RuntimeRunNodeStatus.skipped => 'skipped',
  };
}

class RuntimeRunNode {
  const RuntimeRunNode({
    required this.id,
    required this.runId,
    required this.phaseKey,
    required this.title,
    required this.status,
    required this.ordinal,
    required this.attempt,
    required this.startedAtEpochMs,
    required this.updatedAtEpochMs,
    this.parentNodeId,
    this.capabilityKey,
    this.toolName,
    this.toolCallId,
    this.operationKey,
    this.request = const <String, Object?>{},
    this.result,
    this.metadata = const <String, Object?>{},
    this.error,
    this.completedAtEpochMs,
  });

  final String id;
  final String runId;
  final String? parentNodeId;
  final String phaseKey;
  final String title;
  final RuntimeRunNodeStatus status;
  final int ordinal;
  final int attempt;
  final String? capabilityKey;
  final String? toolName;
  final String? toolCallId;
  final String? operationKey;
  final Map<String, Object?> request;
  final Map<String, Object?>? result;
  final Map<String, Object?> metadata;
  final String? error;
  final int startedAtEpochMs;
  final int updatedAtEpochMs;
  final int? completedAtEpochMs;

  RuntimeRunNode copyWith({
    String? id,
    String? runId,
    String? parentNodeId,
    bool clearParentNodeId = false,
    String? phaseKey,
    String? title,
    RuntimeRunNodeStatus? status,
    int? ordinal,
    int? attempt,
    String? capabilityKey,
    bool clearCapabilityKey = false,
    String? toolName,
    bool clearToolName = false,
    String? toolCallId,
    bool clearToolCallId = false,
    String? operationKey,
    bool clearOperationKey = false,
    Map<String, Object?>? request,
    Map<String, Object?>? result,
    bool clearResult = false,
    Map<String, Object?>? metadata,
    String? error,
    bool clearError = false,
    int? startedAtEpochMs,
    int? updatedAtEpochMs,
    int? completedAtEpochMs,
    bool clearCompletedAtEpochMs = false,
  }) {
    return RuntimeRunNode(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      parentNodeId: clearParentNodeId
          ? null
          : parentNodeId ?? this.parentNodeId,
      phaseKey: phaseKey ?? this.phaseKey,
      title: title ?? this.title,
      status: status ?? this.status,
      ordinal: ordinal ?? this.ordinal,
      attempt: attempt ?? this.attempt,
      capabilityKey: clearCapabilityKey
          ? null
          : capabilityKey ?? this.capabilityKey,
      toolName: clearToolName ? null : toolName ?? this.toolName,
      toolCallId: clearToolCallId ? null : toolCallId ?? this.toolCallId,
      operationKey: clearOperationKey
          ? null
          : operationKey ?? this.operationKey,
      request: request ?? this.request,
      result: clearResult ? null : result ?? this.result,
      metadata: metadata ?? this.metadata,
      error: clearError ? null : error ?? this.error,
      startedAtEpochMs: startedAtEpochMs ?? this.startedAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      completedAtEpochMs: clearCompletedAtEpochMs
          ? null
          : completedAtEpochMs ?? this.completedAtEpochMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'runId': runId,
    'parentNodeId': parentNodeId,
    'phaseKey': phaseKey,
    'title': title,
    'status': runtimeRunNodeStatusToJson(status),
    'ordinal': ordinal,
    'attempt': attempt,
    'capabilityKey': capabilityKey,
    'toolName': toolName,
    'toolCallId': toolCallId,
    'operationKey': operationKey,
    'request': request,
    'result': result,
    'metadata': metadata,
    'error': error,
    'startedAtEpochMs': startedAtEpochMs,
    'updatedAtEpochMs': updatedAtEpochMs,
    'completedAtEpochMs': completedAtEpochMs,
  };

  factory RuntimeRunNode.fromJson(Map<String, dynamic> json) {
    return RuntimeRunNode(
      id: json['id']?.toString() ?? '',
      runId: json['runId']?.toString() ?? '',
      parentNodeId: json['parentNodeId']?.toString(),
      phaseKey: json['phaseKey']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      status: runtimeRunNodeStatusFromJson(json['status']?.toString()),
      ordinal: (json['ordinal'] as num?)?.toInt() ?? 0,
      attempt: (json['attempt'] as num?)?.toInt() ?? 1,
      capabilityKey: json['capabilityKey']?.toString(),
      toolName: json['toolName']?.toString(),
      toolCallId: json['toolCallId']?.toString(),
      operationKey: json['operationKey']?.toString(),
      request: _readObjectMap(json['request']),
      result: _readNullableObjectMap(json['result']),
      metadata: _readObjectMap(json['metadata']),
      error: json['error']?.toString(),
      startedAtEpochMs: (json['startedAtEpochMs'] as num?)?.toInt() ?? 0,
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
