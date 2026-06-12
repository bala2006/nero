import '../domain/runtime_progress_snapshot.dart';
import '../domain/runtime_run.dart';
import '../domain/runtime_run_node.dart';

class RuntimeProgressSnapshotBuilder {
  const RuntimeProgressSnapshotBuilder();

  RuntimeProgressSnapshot build({
    required RuntimeRun run,
    required List<RuntimeRunNode> nodes,
  }) {
    final ordered = List<RuntimeRunNode>.from(nodes)
      ..sort((a, b) => a.ordinal.compareTo(b.ordinal));
    final phaseSnapshots = _canonicalPhaseSnapshots(ordered);
    RuntimePhaseSnapshot? currentPhase;
    RuntimePhaseSnapshot? blockingPhase;
    for (final phase in phaseSnapshots) {
      if (phase.status == RuntimeRunNodeStatus.blocked ||
          phase.status == RuntimeRunNodeStatus.failed) {
        blockingPhase ??= phase;
      }
      if (phase.status == RuntimeRunNodeStatus.running ||
          phase.status == RuntimeRunNodeStatus.waiting) {
        currentPhase ??= phase;
      }
    }
    currentPhase ??= blockingPhase;
    RuntimePhaseSnapshot? nextPhase;
    if (currentPhase != null) {
      final currentIndex = phaseSnapshots.indexOf(currentPhase);
      if (currentIndex >= 0 && currentIndex + 1 < phaseSnapshots.length) {
        nextPhase = phaseSnapshots.skip(currentIndex + 1).firstWhere(
          _isPendingPhase,
          orElse: () => phaseSnapshots[currentIndex + 1],
        );
      }
    }
    return RuntimeProgressSnapshot(
      runId: run.id,
      runStatus: run.status,
      phases: phaseSnapshots,
      currentPhase: currentPhase,
      nextPhase: nextPhase,
      blockingPhase: blockingPhase,
    );
  }

  bool _isPendingPhase(RuntimePhaseSnapshot phase) {
    return phase.status == RuntimeRunNodeStatus.queued ||
        phase.status == RuntimeRunNodeStatus.waiting;
  }

  List<RuntimePhaseSnapshot> _canonicalPhaseSnapshots(
    List<RuntimeRunNode> orderedNodes,
  ) {
    final phaseGroups = <String, List<RuntimeRunNode>>{};
    for (final node in orderedNodes) {
      if (node.phaseKey == 'root') {
        continue;
      }
      phaseGroups
          .putIfAbsent(_canonicalPhaseKey(node), () => <RuntimeRunNode>[])
          .add(node);
    }
    return phaseGroups.values
        .map(_snapshotForPhaseGroup)
        .toList(growable: false);
  }

  RuntimePhaseSnapshot _snapshotForPhaseGroup(List<RuntimeRunNode> nodes) {
    final representative = _representativeNode(nodes);
    return RuntimePhaseSnapshot(
      phaseKey: _canonicalPhaseKey(representative),
      title: representative.title,
      status: _aggregateStatus(nodes),
      error: _firstError(nodes),
      nodeCount: nodes.length,
      completedCount: nodes.where(_isTerminalSuccessNode).length,
      totalCount: nodes.length,
      activeDetail: _activeDetail(nodes),
    );
  }

  String _canonicalPhaseKey(RuntimeRunNode node) {
    return switch (node.phaseKey) {
      'skill_step' => 'skill_execution',
      'tool_call' => 'tool_batch',
      _ => node.phaseKey,
    };
  }

  RuntimeRunNode _representativeNode(List<RuntimeRunNode> nodes) {
    for (final status in const <RuntimeRunNodeStatus>[
      RuntimeRunNodeStatus.failed,
      RuntimeRunNodeStatus.blocked,
      RuntimeRunNodeStatus.running,
      RuntimeRunNodeStatus.waiting,
      RuntimeRunNodeStatus.queued,
    ]) {
      final matches = nodes.where((node) => node.status == status);
      if (matches.isNotEmpty) {
        return matches.last;
      }
    }
    return nodes.last;
  }

  RuntimeRunNodeStatus _aggregateStatus(List<RuntimeRunNode> nodes) {
    if (nodes.any((node) => node.status == RuntimeRunNodeStatus.failed)) {
      return RuntimeRunNodeStatus.failed;
    }
    if (nodes.any((node) => node.status == RuntimeRunNodeStatus.blocked)) {
      return RuntimeRunNodeStatus.blocked;
    }
    if (nodes.any((node) => node.status == RuntimeRunNodeStatus.running)) {
      return RuntimeRunNodeStatus.running;
    }
    if (nodes.any((node) => node.status == RuntimeRunNodeStatus.waiting)) {
      return RuntimeRunNodeStatus.waiting;
    }
    if (nodes.any((node) => node.status == RuntimeRunNodeStatus.queued)) {
      return RuntimeRunNodeStatus.queued;
    }
    if (nodes.any((node) => node.status == RuntimeRunNodeStatus.cancelled)) {
      return RuntimeRunNodeStatus.cancelled;
    }
    if (nodes.any((node) => node.status == RuntimeRunNodeStatus.completed)) {
      return RuntimeRunNodeStatus.completed;
    }
    return RuntimeRunNodeStatus.skipped;
  }

  String? _firstError(List<RuntimeRunNode> nodes) {
    for (final node in nodes) {
      final error = node.error?.trim();
      if (error != null && error.isNotEmpty) {
        return error;
      }
    }
    return null;
  }

  bool _isTerminalSuccessNode(RuntimeRunNode node) {
    return node.status == RuntimeRunNodeStatus.completed ||
        node.status == RuntimeRunNodeStatus.skipped;
  }

  String? _activeDetail(List<RuntimeRunNode> nodes) {
    final active = nodes.where(
      (node) =>
          node.status == RuntimeRunNodeStatus.running ||
          node.status == RuntimeRunNodeStatus.waiting ||
          node.status == RuntimeRunNodeStatus.blocked ||
          node.status == RuntimeRunNodeStatus.failed,
    );
    if (active.isNotEmpty) {
      return active.last.title;
    }
    if (nodes.length > 1) {
      return nodes.last.title;
    }
    return null;
  }
}
