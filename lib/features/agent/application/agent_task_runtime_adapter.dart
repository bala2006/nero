import '../domain/agent_task.dart';
import 'agent_task_planner.dart';

class AgentTaskRuntimeAdapter {
  const AgentTaskRuntimeAdapter({
    AgentTaskPlanner planner = const AgentTaskPlanner(),
  }) : _planner = planner;

  final AgentTaskPlanner _planner;

  AgentTask startTask({
    required String conversationId,
    required String prompt,
  }) {
    final task = _planner.createTask(
      conversationId: conversationId,
      prompt: prompt,
    );
    return task.copyWith(status: AgentTaskStatus.running);
  }

  AgentTask replanForSelection({
    required AgentTask task,
    required List<String> selectedTools,
  }) {
    return _planner.replanForSelectedTools(
      task: task,
      selectedTools: selectedTools,
    );
  }

  AgentTask replanForToolOutcomes({
    required AgentTask task,
    required List<String> selectedTools,
    required List<AgentToolOutcome> outcomes,
  }) {
    return _planner.replanForToolOutcomes(
      task: task,
      selectedTools: selectedTools,
      outcomes: outcomes,
    );
  }

  bool hasStep(AgentTask task, String kind) {
    return task.steps.any((step) => step.kind == kind);
  }

  String? primaryDraftingStepKind(AgentTask task) {
    if (hasStep(task, AgentStepKinds.synthesizeResponse)) {
      return AgentStepKinds.synthesizeResponse;
    }
    if (hasStep(task, AgentStepKinds.prepareResponse)) {
      return AgentStepKinds.prepareResponse;
    }
    return null;
  }

  AgentTask markStepRunning(AgentTask task, String kind, {String? detail}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedSteps = task.steps
        .map((step) {
          if (step.kind != kind) {
            return step;
          }
          return step.copyWith(
            status: AgentStepStatus.running,
            startedAtEpochMs: step.startedAtEpochMs ?? now,
            completedAtEpochMs: null,
            clearCompletedAtEpochMs: true,
            detail: detail,
            clearError: true,
          );
        })
        .toList(growable: false);
    return task.copyWith(
      status: AgentTaskStatus.running,
      updatedAtEpochMs: now,
      steps: updatedSteps,
      clearError: true,
    );
  }

  AgentTask markStepCompleted(AgentTask task, String kind, {String? detail}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedSteps = task.steps
        .map((step) {
          if (step.kind != kind) {
            return step;
          }
          return step.copyWith(
            status: AgentStepStatus.completed,
            startedAtEpochMs: step.startedAtEpochMs ?? now,
            completedAtEpochMs: now,
            detail: detail ?? step.detail,
            clearError: true,
          );
        })
        .toList(growable: false);
    return task.copyWith(
      updatedAtEpochMs: now,
      steps: updatedSteps,
      clearError: true,
    );
  }

  AgentTask markStepFailed(AgentTask task, String kind, {required String error}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedSteps = task.steps
        .map((step) {
          if (step.kind != kind) {
            return step;
          }
          return step.copyWith(
            status: AgentStepStatus.failed,
            startedAtEpochMs: step.startedAtEpochMs ?? now,
            completedAtEpochMs: now,
            error: error,
          );
        })
        .toList(growable: false);
    return task.copyWith(
      updatedAtEpochMs: now,
      steps: updatedSteps,
    );
  }

  AgentTask completeTask(AgentTask task) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedSteps = task.steps
        .map((step) {
          if (step.kind == AgentStepKinds.renderDiagram) {
            return step;
          }
          if (step.status == AgentStepStatus.pending ||
              step.status == AgentStepStatus.running) {
            return step.copyWith(
              status: AgentStepStatus.completed,
              startedAtEpochMs: step.startedAtEpochMs ?? now,
              completedAtEpochMs: now,
            );
          }
          return step;
        })
        .toList(growable: false);
    final hasPendingDiagram = updatedSteps.any(
      (step) =>
          step.kind == AgentStepKinds.renderDiagram &&
          (step.status == AgentStepStatus.pending ||
              step.status == AgentStepStatus.running),
    );
    final hasFailedSteps = updatedSteps.any(
      (step) => step.status == AgentStepStatus.failed,
    );
    return task.copyWith(
      status: hasPendingDiagram
          ? AgentTaskStatus.waitingUser
          : hasFailedSteps
          ? AgentTaskStatus.failed
          : AgentTaskStatus.completed,
      updatedAtEpochMs: now,
      steps: updatedSteps,
      error: hasFailedSteps ? (task.error ?? 'One or more steps failed.') : null,
      clearError: !hasFailedSteps,
    );
  }

  AgentTask failTask(AgentTask task, String error) {
    final now = DateTime.now().millisecondsSinceEpoch;
    var markedRunningStep = false;
    final updatedSteps = task.steps
        .map((step) {
          if (step.status == AgentStepStatus.running && !markedRunningStep) {
            markedRunningStep = true;
            return step.copyWith(
              status: AgentStepStatus.failed,
              completedAtEpochMs: now,
              error: error,
            );
          }
          if (step.status == AgentStepStatus.pending) {
            return step.copyWith(
              status: AgentStepStatus.blocked,
              error: 'Stopped because an earlier step failed.',
            );
          }
          return step;
        })
        .toList(growable: false);
    return task.copyWith(
      status: AgentTaskStatus.failed,
      updatedAtEpochMs: now,
      steps: updatedSteps,
      error: error,
    );
  }

  AgentTask cancelTask(AgentTask task) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedSteps = task.steps
        .map((step) {
          if (step.status == AgentStepStatus.pending ||
              step.status == AgentStepStatus.running) {
            return step.copyWith(
              status: AgentStepStatus.cancelled,
              completedAtEpochMs: now,
            );
          }
          return step;
        })
        .toList(growable: false);
    return task.copyWith(
      status: AgentTaskStatus.cancelled,
      updatedAtEpochMs: now,
      steps: updatedSteps,
      error: 'Generation cancelled by the user.',
    );
  }

  AgentTask refreshTaskStatus(AgentTask task) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final hasFailed = task.steps.any(
      (step) => step.status == AgentStepStatus.failed,
    );
    final hasPending = task.steps.any(
      (step) =>
          step.status == AgentStepStatus.pending ||
          step.status == AgentStepStatus.running,
    );
    final pendingSteps = task.steps
        .where(
          (step) =>
              step.status == AgentStepStatus.pending ||
              step.status == AgentStepStatus.running,
        )
        .toList(growable: false);
    final waitingOnUser =
        pendingSteps.isNotEmpty &&
        pendingSteps.every((step) => step.kind == AgentStepKinds.renderDiagram);
    return task.copyWith(
      status: hasPending
          ? (waitingOnUser ? AgentTaskStatus.waitingUser : AgentTaskStatus.running)
          : hasFailed
          ? AgentTaskStatus.failed
          : AgentTaskStatus.completed,
      updatedAtEpochMs: now,
      error: hasFailed ? (task.error ?? 'One or more steps failed.') : null,
      clearError: !hasFailed,
    );
  }
}
