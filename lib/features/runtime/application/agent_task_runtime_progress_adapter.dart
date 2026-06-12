import '../../agent/domain/agent_task.dart';
import '../domain/runtime_progress_snapshot.dart';
import '../domain/runtime_run.dart';
import '../domain/runtime_run_node.dart';

class AgentTaskRuntimeProgressAdapter {
  const AgentTaskRuntimeProgressAdapter();

  RuntimeProgressSnapshot? adapt(AgentTask? task) {
    if (task == null || task.steps.isEmpty) {
      return null;
    }

    final phases = task.steps
        .map(
          (step) => RuntimePhaseSnapshot(
            phaseKey: step.kind,
            title: step.title,
            status: _mapStepStatus(step.status),
            error: step.error,
            activeDetail: step.error ?? step.detail,
          ),
        )
        .toList(growable: false);

    RuntimePhaseSnapshot? currentPhase;
    RuntimePhaseSnapshot? blockingPhase;
    RuntimePhaseSnapshot? nextPhase;
    for (final phase in phases) {
      if (blockingPhase == null &&
          (phase.status == RuntimeRunNodeStatus.failed ||
              phase.status == RuntimeRunNodeStatus.blocked)) {
        blockingPhase = phase;
      }
      if (currentPhase == null &&
          (phase.status == RuntimeRunNodeStatus.running ||
              phase.status == RuntimeRunNodeStatus.waiting)) {
        currentPhase = phase;
      }
      if (nextPhase == null && phase.status == RuntimeRunNodeStatus.queued) {
        nextPhase = phase;
      }
    }
    currentPhase ??= blockingPhase;

    return RuntimeProgressSnapshot(
      runId: 'task:${task.id}',
      runStatus: _mapTaskStatus(task.status),
      phases: phases,
      currentPhase: currentPhase,
      nextPhase: nextPhase,
      blockingPhase: blockingPhase,
    );
  }

  RuntimeRunNodeStatus _mapStepStatus(AgentStepStatus status) {
    return switch (status) {
      AgentStepStatus.pending => RuntimeRunNodeStatus.queued,
      AgentStepStatus.running => RuntimeRunNodeStatus.running,
      AgentStepStatus.completed => RuntimeRunNodeStatus.completed,
      AgentStepStatus.failed => RuntimeRunNodeStatus.failed,
      AgentStepStatus.blocked => RuntimeRunNodeStatus.blocked,
      AgentStepStatus.cancelled => RuntimeRunNodeStatus.cancelled,
    };
  }

  RuntimeRunStatus _mapTaskStatus(AgentTaskStatus status) {
    return switch (status) {
      AgentTaskStatus.queued => RuntimeRunStatus.queued,
      AgentTaskStatus.running => RuntimeRunStatus.runningModel,
      AgentTaskStatus.waitingUser => RuntimeRunStatus.waitingUser,
      AgentTaskStatus.completed => RuntimeRunStatus.completed,
      AgentTaskStatus.failed => RuntimeRunStatus.failed,
      AgentTaskStatus.cancelled => RuntimeRunStatus.cancelled,
    };
  }
}
