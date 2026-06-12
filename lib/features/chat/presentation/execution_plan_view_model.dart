import 'package:flutter/material.dart';

import '../../agent/domain/agent_task.dart';
import '../../runtime/application/agent_task_runtime_progress_adapter.dart';
import '../../runtime/domain/runtime_progress_snapshot.dart';
import '../../runtime/domain/runtime_run_node.dart';
import '../../../core/theme/app_colors.dart';

class ExecutionPlanViewModel {
  const ExecutionPlanViewModel({
    required this.title,
    required this.statusLabel,
    required this.statusColor,
    required this.completedCount,
    required this.totalCount,
    required this.completionRatio,
    required this.hasFailures,
    required this.summaryText,
    required this.entries,
    required this.usesRuntimePhases,
  });

  factory ExecutionPlanViewModel.fromTask({
    AgentTask? task,
    RuntimeProgressSnapshot? runtimeProgressSnapshot,
  }) {
    final runtimeProgress =
        runtimeProgressSnapshot ??
        const AgentTaskRuntimeProgressAdapter().adapt(task);
    if (runtimeProgress == null || runtimeProgress.phases.isEmpty) {
      return const ExecutionPlanViewModel(
        title: 'No active task',
        statusLabel: 'Done',
        statusColor: AppColors.textMuted,
        completedCount: 0,
        totalCount: 0,
        completionRatio: 0.0,
        hasFailures: false,
        summaryText: 'Task finished.',
        entries: <ExecutionPlanEntry>[],
        usesRuntimePhases: true,
      );
    }

    final phases = runtimeProgress.phases;
    final primaryRuntimePhase =
        runtimeProgress.blockingPhase ?? runtimeProgress.currentPhase;
    final completedCount = phases
        .where(
          (phase) =>
              phase.status == RuntimeRunNodeStatus.completed ||
              phase.status == RuntimeRunNodeStatus.skipped,
        )
        .length;
    final summaryText = runtimeProgress.blockingPhase != null
        ? (runtimeProgress.blockingPhase!.error ??
              runtimeProgress.blockingPhase!.title)
        : runtimeProgress.currentPhase != null &&
              runtimeProgress.nextPhase != null
        ? 'Next: ${runtimeProgress.nextPhase!.title}'
        : (runtimeProgress.currentPhase?.title ?? 'Task finished.');
    return ExecutionPlanViewModel(
      title: primaryRuntimePhase?.title ?? 'No active task',
      statusLabel: primaryRuntimePhase != null
          ? _runtimeStatusLabel(primaryRuntimePhase.status)
          : 'Done',
      statusColor: primaryRuntimePhase != null
          ? _runtimeStatusColor(primaryRuntimePhase.status)
          : AppColors.textMuted,
      completedCount: completedCount,
      totalCount: phases.length,
      completionRatio: phases.isEmpty ? 0.0 : completedCount / phases.length,
      hasFailures:
          runtimeProgress.blockingPhase != null ||
          phases.any(
            (phase) =>
                phase.status == RuntimeRunNodeStatus.failed ||
                phase.status == RuntimeRunNodeStatus.blocked,
          ),
      summaryText: summaryText,
      entries: phases
          .asMap()
          .entries
          .map(
            (entry) => ExecutionPlanEntry(
              id: '${entry.value.phaseKey}:${entry.value.status.name}:${entry.key}',
              title: entry.value.title,
              detail: entry.value.error ?? entry.value.activeDetail,
              status: _runtimeStatusToAgentStepStatus(entry.value.status),
            ),
          )
          .toList(growable: false),
      usesRuntimePhases: true,
    );
  }

  final String title;
  final String statusLabel;
  final Color statusColor;
  final int completedCount;
  final int totalCount;
  final double completionRatio;
  final bool hasFailures;
  final String summaryText;
  final List<ExecutionPlanEntry> entries;
  final bool usesRuntimePhases;

  static IconData stepIcon(AgentStepStatus status) {
    return switch (status) {
      AgentStepStatus.pending => Icons.circle_outlined,
      AgentStepStatus.running => Icons.sync_rounded,
      AgentStepStatus.completed => Icons.check_circle_rounded,
      AgentStepStatus.failed => Icons.error_rounded,
      AgentStepStatus.blocked => Icons.pause_circle_rounded,
      AgentStepStatus.cancelled => Icons.remove_circle_rounded,
    };
  }

  static Color stepColor(AgentStepStatus status) => _stepColor(status);

  static String stepStatusLabel(AgentStepStatus status) =>
      _stepStatusLabel(status);
}

class ExecutionPlanEntry {
  const ExecutionPlanEntry({
    required this.id,
    required this.title,
    required this.detail,
    required this.status,
  });

  final String id;
  final String title;
  final String? detail;
  final AgentStepStatus status;
}

AgentStepStatus _runtimeStatusToAgentStepStatus(RuntimeRunNodeStatus status) {
  return switch (status) {
    RuntimeRunNodeStatus.queued => AgentStepStatus.pending,
    RuntimeRunNodeStatus.running => AgentStepStatus.running,
    RuntimeRunNodeStatus.waiting => AgentStepStatus.running,
    RuntimeRunNodeStatus.completed => AgentStepStatus.completed,
    RuntimeRunNodeStatus.failed => AgentStepStatus.failed,
    RuntimeRunNodeStatus.cancelled => AgentStepStatus.cancelled,
    RuntimeRunNodeStatus.blocked => AgentStepStatus.blocked,
    RuntimeRunNodeStatus.skipped => AgentStepStatus.completed,
  };
}

Color _runtimeStatusColor(RuntimeRunNodeStatus status) {
  return _stepColor(_runtimeStatusToAgentStepStatus(status));
}

String _runtimeStatusLabel(RuntimeRunNodeStatus status) {
  return switch (status) {
    RuntimeRunNodeStatus.queued => 'Pending',
    RuntimeRunNodeStatus.running => 'Running',
    RuntimeRunNodeStatus.waiting => 'Waiting',
    RuntimeRunNodeStatus.completed => 'Done',
    RuntimeRunNodeStatus.failed => 'Failed',
    RuntimeRunNodeStatus.cancelled => 'Cancelled',
    RuntimeRunNodeStatus.blocked => 'Blocked',
    RuntimeRunNodeStatus.skipped => 'Skipped',
  };
}

Color _stepColor(AgentStepStatus status) {
  return switch (status) {
    AgentStepStatus.pending => AppColors.textMuted,
    AgentStepStatus.running => AppColors.orange,
    AgentStepStatus.completed => AppColors.orange,
    AgentStepStatus.failed => AppColors.amber,
    AgentStepStatus.blocked => AppColors.amber,
    AgentStepStatus.cancelled => AppColors.textMuted,
  };
}

String _stepStatusLabel(AgentStepStatus status) {
  return switch (status) {
    AgentStepStatus.pending => 'Pending',
    AgentStepStatus.running => 'Running',
    AgentStepStatus.completed => 'Done',
    AgentStepStatus.failed => 'Failed',
    AgentStepStatus.blocked => 'Blocked',
    AgentStepStatus.cancelled => 'Cancelled',
  };
}
