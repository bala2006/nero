import 'dart:convert';

enum RuntimeRunEventKind {
  created,
  statusChanged,
  stepStarted,
  stepCompleted,
  toolRequested,
  toolCompleted,
  toolFailed,
  note,
  completed,
  failed,
  cancelled,
}

RuntimeRunEventKind runtimeRunEventKindFromJson(String? value) {
  return switch (value) {
    'created' => RuntimeRunEventKind.created,
    'statusChanged' => RuntimeRunEventKind.statusChanged,
    'stepStarted' => RuntimeRunEventKind.stepStarted,
    'stepCompleted' => RuntimeRunEventKind.stepCompleted,
    'toolRequested' => RuntimeRunEventKind.toolRequested,
    'toolCompleted' => RuntimeRunEventKind.toolCompleted,
    'toolFailed' => RuntimeRunEventKind.toolFailed,
    'note' => RuntimeRunEventKind.note,
    'completed' => RuntimeRunEventKind.completed,
    'failed' => RuntimeRunEventKind.failed,
    'cancelled' => RuntimeRunEventKind.cancelled,
    _ => RuntimeRunEventKind.note,
  };
}

String runtimeRunEventKindToJson(RuntimeRunEventKind kind) {
  return switch (kind) {
    RuntimeRunEventKind.created => 'created',
    RuntimeRunEventKind.statusChanged => 'statusChanged',
    RuntimeRunEventKind.stepStarted => 'stepStarted',
    RuntimeRunEventKind.stepCompleted => 'stepCompleted',
    RuntimeRunEventKind.toolRequested => 'toolRequested',
    RuntimeRunEventKind.toolCompleted => 'toolCompleted',
    RuntimeRunEventKind.toolFailed => 'toolFailed',
    RuntimeRunEventKind.note => 'note',
    RuntimeRunEventKind.completed => 'completed',
    RuntimeRunEventKind.failed => 'failed',
    RuntimeRunEventKind.cancelled => 'cancelled',
  };
}

class RuntimeRunEvent {
  const RuntimeRunEvent({
    required this.id,
    required this.runId,
    required this.kind,
    required this.title,
    required this.createdAtEpochMs,
    this.detail,
    this.payload = const <String, Object?>{},
  });

  final String id;
  final String runId;
  final RuntimeRunEventKind kind;
  final String title;
  final String? detail;
  final Map<String, Object?> payload;
  final int createdAtEpochMs;

  RuntimeRunEvent copyWith({
    String? id,
    String? runId,
    RuntimeRunEventKind? kind,
    String? title,
    String? detail,
    bool clearDetail = false,
    Map<String, Object?>? payload,
    int? createdAtEpochMs,
  }) {
    return RuntimeRunEvent(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      detail: clearDetail ? null : detail ?? this.detail,
      payload: payload ?? this.payload,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'runId': runId,
        'kind': runtimeRunEventKindToJson(kind),
        'title': title,
        'detail': detail,
        'payload': payload,
        'createdAtEpochMs': createdAtEpochMs,
      };

  factory RuntimeRunEvent.fromJson(Map<String, dynamic> json) {
    return RuntimeRunEvent(
      id: json['id']?.toString() ?? '',
      runId: json['runId']?.toString() ?? '',
      kind: runtimeRunEventKindFromJson(json['kind']?.toString()),
      title: json['title']?.toString() ?? '',
      detail: json['detail']?.toString(),
      payload: _readObjectMap(json['payload']),
      createdAtEpochMs: (json['createdAtEpochMs'] as num?)?.toInt() ?? 0,
    );
  }

  String get payloadJson => jsonEncode(payload);

  static Map<String, Object?> _readObjectMap(Object? value) {
    if (value is Map) {
      return Map<String, Object?>.from(value);
    }
    return const <String, Object?>{};
  }
}
