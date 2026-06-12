import 'runtime_run.dart';
import 'runtime_run_node.dart';

class RuntimePhaseSnapshot {
  const RuntimePhaseSnapshot({
    required this.phaseKey,
    required this.title,
    required this.status,
    this.error,
    this.nodeCount = 1,
    this.completedCount = 0,
    this.totalCount = 1,
    this.activeDetail,
  });

  final String phaseKey;
  final String title;
  final RuntimeRunNodeStatus status;
  final String? error;
  final int nodeCount;
  final int completedCount;
  final int totalCount;
  final String? activeDetail;

  factory RuntimePhaseSnapshot.fromJson(Map<Object?, Object?> json) {
    return RuntimePhaseSnapshot(
      phaseKey: json['phaseKey']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      status: runtimeRunNodeStatusFromJson(json['status']?.toString()),
      error: json['error']?.toString(),
      nodeCount: _readInt(json['nodeCount'], fallback: 1),
      completedCount: _readInt(json['completedCount']),
      totalCount: _readInt(json['totalCount'], fallback: 1),
      activeDetail: json['activeDetail']?.toString(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'phaseKey': phaseKey,
    'title': title,
    'status': runtimeRunNodeStatusToJson(status),
    'error': error,
    'nodeCount': nodeCount,
    'completedCount': completedCount,
    'totalCount': totalCount,
    'activeDetail': activeDetail,
  };

  static int _readInt(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class RuntimeProgressSnapshot {
  const RuntimeProgressSnapshot({
    required this.runId,
    required this.runStatus,
    required this.phases,
    this.currentPhase,
    this.nextPhase,
    this.blockingPhase,
  });

  final String runId;
  final RuntimeRunStatus runStatus;
  final List<RuntimePhaseSnapshot> phases;
  final RuntimePhaseSnapshot? currentPhase;
  final RuntimePhaseSnapshot? nextPhase;
  final RuntimePhaseSnapshot? blockingPhase;

  factory RuntimeProgressSnapshot.fromJson(Map<Object?, Object?> json) {
    RuntimePhaseSnapshot? phaseFromValue(Object? value) {
      if (value is! Map) {
        return null;
      }
      return RuntimePhaseSnapshot.fromJson(Map<Object?, Object?>.from(value));
    }

    return RuntimeProgressSnapshot(
      runId: json['runId']?.toString() ?? '',
      runStatus: runtimeRunStatusFromJson(json['runStatus']?.toString()),
      phases: ((json['phases'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map(
            (item) => RuntimePhaseSnapshot.fromJson(
              Map<Object?, Object?>.from(item),
            ),
          )
          .toList(growable: false),
      currentPhase: phaseFromValue(json['currentPhase']),
      nextPhase: phaseFromValue(json['nextPhase']),
      blockingPhase: phaseFromValue(json['blockingPhase']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'runId': runId,
    'runStatus': runtimeRunStatusToJson(runStatus),
    'phases': phases.map((phase) => phase.toJson()).toList(growable: false),
    'currentPhase': currentPhase?.toJson(),
    'nextPhase': nextPhase?.toJson(),
    'blockingPhase': blockingPhase?.toJson(),
  };
}
