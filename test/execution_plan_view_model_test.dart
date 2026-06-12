import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/agent/domain/agent_task.dart';
import 'package:nero/features/chat/presentation/execution_plan_view_model.dart';
import 'package:nero/features/runtime/domain/runtime_progress_snapshot.dart';
import 'package:nero/features/runtime/domain/runtime_run.dart';
import 'package:nero/features/runtime/domain/runtime_run_node.dart';

void main() {
  test('uses runtime phases when runtime progress is available', () {
    const task = AgentTask(
      id: 'task_1',
      conversationId: 'conversation_1',
      prompt: 'Deliver answer',
      status: AgentTaskStatus.running,
      steps: <AgentStep>[
        AgentStep(
          id: 'step_1',
          kind: AgentStepKinds.interpretPrompt,
          title: 'Interpret request',
          status: AgentStepStatus.completed,
        ),
        AgentStep(
          id: 'step_2',
          kind: AgentStepKinds.prepareResponse,
          title: 'Prepare response',
          status: AgentStepStatus.running,
        ),
      ],
      createdAtEpochMs: 1,
      updatedAtEpochMs: 1,
    );
    const snapshot = RuntimeProgressSnapshot(
      runId: 'run_1',
      runStatus: RuntimeRunStatus.runningTools,
      phases: <RuntimePhaseSnapshot>[
        RuntimePhaseSnapshot(
          phaseKey: 'classify_request',
          title: 'Classify request',
          status: RuntimeRunNodeStatus.completed,
        ),
        RuntimePhaseSnapshot(
          phaseKey: 'execute_tools',
          title: 'Execute tools',
          status: RuntimeRunNodeStatus.running,
        ),
        RuntimePhaseSnapshot(
          phaseKey: 'compose_answer',
          title: 'Compose answer',
          status: RuntimeRunNodeStatus.queued,
        ),
      ],
      currentPhase: RuntimePhaseSnapshot(
        phaseKey: 'execute_tools',
        title: 'Execute tools',
        status: RuntimeRunNodeStatus.running,
      ),
      nextPhase: RuntimePhaseSnapshot(
        phaseKey: 'compose_answer',
        title: 'Compose answer',
        status: RuntimeRunNodeStatus.queued,
      ),
    );

    final model = ExecutionPlanViewModel.fromTask(
      task: task,
      runtimeProgressSnapshot: snapshot,
    );

    expect(model.usesRuntimePhases, isTrue);
    expect(model.title, 'Execute tools');
    expect(model.completedCount, 1);
    expect(model.totalCount, 3);
    expect(model.summaryText, 'Next: Compose answer');
    expect(model.statusLabel, 'Running');
    expect(model.entries, hasLength(3));
  });

  test('synthesizes runtime-style phases from task progress when runtime progress is absent', () {
    const task = AgentTask(
      id: 'task_1',
      conversationId: 'conversation_1',
      prompt: 'Deliver answer',
      status: AgentTaskStatus.running,
      steps: <AgentStep>[
        AgentStep(
          id: 'step_1',
          kind: AgentStepKinds.interpretPrompt,
          title: 'Interpret request',
          status: AgentStepStatus.completed,
        ),
        AgentStep(
          id: 'step_2',
          kind: AgentStepKinds.prepareResponse,
          title: 'Prepare response',
          status: AgentStepStatus.running,
          detail: 'Drafting response.',
        ),
      ],
      createdAtEpochMs: 1,
      updatedAtEpochMs: 1,
    );

    final model = ExecutionPlanViewModel.fromTask(task: task);

    expect(model.usesRuntimePhases, isTrue);
    expect(model.title, 'Prepare response');
    expect(model.completedCount, 1);
    expect(model.totalCount, 2);
    expect(model.summaryText, 'Prepare response');
    expect(model.statusColor, isA<Color>());
    expect(model.entries, hasLength(2));
  });

  test('blocking runtime phase controls title and summary', () {
    const task = AgentTask(
      id: 'task_1',
      conversationId: 'conversation_1',
      prompt: 'Deliver answer',
      status: AgentTaskStatus.running,
      steps: <AgentStep>[
        AgentStep(
          id: 'step_1',
          kind: AgentStepKinds.prepareResponse,
          title: 'Prepare response',
          status: AgentStepStatus.running,
        ),
      ],
      createdAtEpochMs: 1,
      updatedAtEpochMs: 1,
    );
    const snapshot = RuntimeProgressSnapshot(
      runId: 'run_1',
      runStatus: RuntimeRunStatus.failed,
      phases: <RuntimePhaseSnapshot>[
        RuntimePhaseSnapshot(
          phaseKey: 'assistant_round',
          title: 'Assistant round',
          status: RuntimeRunNodeStatus.running,
        ),
        RuntimePhaseSnapshot(
          phaseKey: 'response_verification',
          title: 'Verify response',
          status: RuntimeRunNodeStatus.failed,
          error: 'The response is empty.',
        ),
      ],
      currentPhase: RuntimePhaseSnapshot(
        phaseKey: 'assistant_round',
        title: 'Assistant round',
        status: RuntimeRunNodeStatus.running,
      ),
      blockingPhase: RuntimePhaseSnapshot(
        phaseKey: 'response_verification',
        title: 'Verify response',
        status: RuntimeRunNodeStatus.failed,
        error: 'The response is empty.',
      ),
    );

    final model = ExecutionPlanViewModel.fromTask(
      task: task,
      runtimeProgressSnapshot: snapshot,
    );

    expect(model.title, 'Verify response');
    expect(model.statusLabel, 'Failed');
    expect(model.summaryText, 'The response is empty.');
    expect(model.hasFailures, isTrue);
  });

  test('runtime-only progress still renders when no task is available', () {
    const snapshot = RuntimeProgressSnapshot(
      runId: 'run_1',
      runStatus: RuntimeRunStatus.runningModel,
      phases: <RuntimePhaseSnapshot>[
        RuntimePhaseSnapshot(
          phaseKey: 'prepare_context',
          title: 'Prepare context',
          status: RuntimeRunNodeStatus.completed,
        ),
        RuntimePhaseSnapshot(
          phaseKey: 'assistant_round',
          title: 'Assistant round',
          status: RuntimeRunNodeStatus.running,
          activeDetail: 'Drafting the answer.',
        ),
      ],
      currentPhase: RuntimePhaseSnapshot(
        phaseKey: 'assistant_round',
        title: 'Assistant round',
        status: RuntimeRunNodeStatus.running,
        activeDetail: 'Drafting the answer.',
      ),
    );

    final model = ExecutionPlanViewModel.fromTask(
      runtimeProgressSnapshot: snapshot,
    );

    expect(model.usesRuntimePhases, isTrue);
    expect(model.title, 'Assistant round');
    expect(model.completedCount, 1);
    expect(model.totalCount, 2);
    expect(model.summaryText, 'Assistant round');
    expect(model.entries, hasLength(2));
  });
}
