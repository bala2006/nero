import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/agent/application/agent_task_runtime_adapter.dart';
import 'package:nero/features/agent/domain/agent_task.dart';

void main() {
  const adapter = AgentTaskRuntimeAdapter();

  test('startTask creates a running task with planned steps', () {
    final task = adapter.startTask(
      conversationId: 'conv',
      prompt: 'Find the latest Flutter CI guidance',
    );

    expect(task.status, AgentTaskStatus.running);
    expect(task.steps, isNotEmpty);
    expect(task.steps.first.kind, AgentStepKinds.interpretPrompt);
  });

  test('markStepRunning and markStepCompleted update the intended step only', () {
    const task = AgentTask(
      id: 'task_1',
      conversationId: 'conv',
      prompt: 'Prompt',
      status: AgentTaskStatus.running,
      createdAtEpochMs: 1,
      updatedAtEpochMs: 1,
      steps: <AgentStep>[
        AgentStep(
          id: 's1',
          kind: AgentStepKinds.interpretPrompt,
          title: 'Interpret prompt',
          status: AgentStepStatus.pending,
        ),
        AgentStep(
          id: 's2',
          kind: AgentStepKinds.prepareResponse,
          title: 'Prepare response',
          status: AgentStepStatus.pending,
        ),
      ],
    );

    final running = adapter.markStepRunning(
      task,
      AgentStepKinds.interpretPrompt,
      detail: 'Working',
    );
    final completed = adapter.markStepCompleted(
      running,
      AgentStepKinds.interpretPrompt,
      detail: 'Done',
    );

    expect(completed.steps.first.status, AgentStepStatus.completed);
    expect(completed.steps.first.detail, 'Done');
    expect(completed.steps.last.status, AgentStepStatus.pending);
  });

  test('failTask blocks pending downstream steps', () {
    const task = AgentTask(
      id: 'task_2',
      conversationId: 'conv',
      prompt: 'Prompt',
      status: AgentTaskStatus.running,
      createdAtEpochMs: 1,
      updatedAtEpochMs: 1,
      steps: <AgentStep>[
        AgentStep(
          id: 's1',
          kind: AgentStepKinds.planTask,
          title: 'Plan task',
          status: AgentStepStatus.running,
        ),
        AgentStep(
          id: 's2',
          kind: AgentStepKinds.toolResearch,
          title: 'Collect context',
          status: AgentStepStatus.pending,
        ),
      ],
    );

    final failed = adapter.failTask(task, 'The response is empty.');

    expect(failed.status, AgentTaskStatus.failed);
    expect(failed.steps.first.status, AgentStepStatus.failed);
    expect(failed.steps.last.status, AgentStepStatus.blocked);
  });

  test('refreshTaskStatus marks render-only pending work as waitingUser', () {
    const task = AgentTask(
      id: 'task_3',
      conversationId: 'conv',
      prompt: 'Prompt',
      status: AgentTaskStatus.running,
      createdAtEpochMs: 1,
      updatedAtEpochMs: 1,
      steps: <AgentStep>[
        AgentStep(
          id: 's1',
          kind: AgentStepKinds.prepareResponse,
          title: 'Prepare response',
          status: AgentStepStatus.completed,
        ),
        AgentStep(
          id: 's2',
          kind: AgentStepKinds.renderDiagram,
          title: 'Render diagram',
          status: AgentStepStatus.pending,
        ),
      ],
    );

    final refreshed = adapter.refreshTaskStatus(task);

    expect(refreshed.status, AgentTaskStatus.waitingUser);
  });
}
