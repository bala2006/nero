import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/agent/domain/agent_task.dart';
import 'package:nero/features/runtime/application/agent_task_runtime_progress_adapter.dart';

void main() {
  const adapter = AgentTaskRuntimeProgressAdapter();

  test('adapt maps task steps into runtime phases', () {
    final snapshot = adapter.adapt(
      const AgentTask(
        id: 'task_1',
        conversationId: 'conversation_1',
        prompt: 'Deliver answer',
        status: AgentTaskStatus.running,
        createdAtEpochMs: 1,
        updatedAtEpochMs: 2,
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
          AgentStep(
            id: 'step_3',
            kind: AgentStepKinds.streamResponse,
            title: 'Stream response',
            status: AgentStepStatus.pending,
          ),
        ],
      ),
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.runId, 'task:task_1');
    expect(snapshot.phases, hasLength(3));
    expect(snapshot.currentPhase?.phaseKey, AgentStepKinds.prepareResponse);
    expect(snapshot.nextPhase?.phaseKey, AgentStepKinds.streamResponse);
    expect(snapshot.currentPhase?.activeDetail, 'Drafting response.');
  });

  test('adapt returns null when no task steps exist', () {
    expect(
      adapter.adapt(
        const AgentTask(
          id: 'task_1',
          conversationId: 'conversation_1',
          prompt: 'Nothing to do',
          status: AgentTaskStatus.completed,
          createdAtEpochMs: 1,
          updatedAtEpochMs: 2,
          steps: <AgentStep>[],
        ),
      ),
      isNull,
    );
  });
}
