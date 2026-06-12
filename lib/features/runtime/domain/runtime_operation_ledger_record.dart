import 'dart:convert';

enum RuntimeOperationStatus {
  pending,
  running,
  completed,
  failed,
  cancelled,
  skipped,
}

RuntimeOperationStatus runtimeOperationStatusFromJson(String? value) {
  return switch (value) {
    'pending' => RuntimeOperationStatus.pending,
    'running' => RuntimeOperationStatus.running,
    'completed' => RuntimeOperationStatus.completed,
    'failed' => RuntimeOperationStatus.failed,
    'cancelled' => RuntimeOperationStatus.cancelled,
    'skipped' => RuntimeOperationStatus.skipped,
    _ => RuntimeOperationStatus.pending,
  };
}

String runtimeOperationStatusToJson(RuntimeOperationStatus status) {
  return switch (status) {
    RuntimeOperationStatus.pending => 'pending',
    RuntimeOperationStatus.running => 'running',
    RuntimeOperationStatus.completed => 'completed',
    RuntimeOperationStatus.failed => 'failed',
    RuntimeOperationStatus.cancelled => 'cancelled',
    RuntimeOperationStatus.skipped => 'skipped',
  };
}

class RuntimeOperationRecord {
  const RuntimeOperationRecord({
    required this.id,
    required this.runId,
    required this.operationKey,
    required this.kind,
    required this.status,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.request = const <String, Object?>{},
    this.result,
    this.error,
    this.completedAtEpochMs,
  });

  final String id;
  final String runId;
  final String operationKey;
  final String kind;
  final RuntimeOperationStatus status;
  final Map<String, Object?> request;
  final Map<String, Object?>? result;
  final String? error;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  final int? completedAtEpochMs;

  RuntimeOperationRecord copyWith({
    String? id,
    String? runId,
    String? operationKey,
    String? kind,
    RuntimeOperationStatus? status,
    Map<String, Object?>? request,
    Map<String, Object?>? result,
    bool clearResult = false,
    String? error,
    bool clearError = false,
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
    int? completedAtEpochMs,
    bool clearCompletedAtEpochMs = false,
  }) {
    return RuntimeOperationRecord(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      operationKey: operationKey ?? this.operationKey,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      request: request ?? this.request,
      result: clearResult ? null : result ?? this.result,
      error: clearError ? null : error ?? this.error,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      completedAtEpochMs: clearCompletedAtEpochMs
          ? null
          : completedAtEpochMs ?? this.completedAtEpochMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'runId': runId,
        'operationKey': operationKey,
        'kind': kind,
        'status': runtimeOperationStatusToJson(status),
        'request': request,
        'result': result,
        'error': error,
        'createdAtEpochMs': createdAtEpochMs,
        'updatedAtEpochMs': updatedAtEpochMs,
        'completedAtEpochMs': completedAtEpochMs,
      };

  factory RuntimeOperationRecord.fromJson(Map<String, dynamic> json) {
    return RuntimeOperationRecord(
      id: json['id']?.toString() ?? '',
      runId: json['runId']?.toString() ?? '',
      operationKey: json['operationKey']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'tool',
      status: runtimeOperationStatusFromJson(json['status']?.toString()),
      request: _readObjectMap(json['request']),
      result: _readNullableObjectMap(json['result']),
      error: json['error']?.toString(),
      createdAtEpochMs: (json['createdAtEpochMs'] as num?)?.toInt() ?? 0,
      updatedAtEpochMs: (json['updatedAtEpochMs'] as num?)?.toInt() ?? 0,
      completedAtEpochMs: (json['completedAtEpochMs'] as num?)?.toInt(),
    );
  }

  String get requestJson => jsonEncode(request);
  String? get resultJson => result == null ? null : jsonEncode(result);

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
