import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/agent/application/agent_task_runtime_adapter.dart';
import 'package:nero/features/agent/application/agent_task_store.dart';
import 'package:nero/features/agent/domain/agent_task.dart';
import 'package:nero/features/chat/application/active_agent_task_session.dart';

void main() {
  test('startTask creates and persists a running task', () async {
    final store = _FakeAgentTaskStore();
    final changed = <AgentTask?>[];
    final session = ActiveAgentTaskSession(
      runtimeAdapter: const AgentTaskRuntimeAdapter(),
      taskStore: store,
      onTaskChanged: changed.add,
    );

    await session.startTask(
      conversationId: 'conversation_1',
      prompt: 'Create a doc',
    );

    expect(session.task, isNotNull);
    expect(session.task!.status, AgentTaskStatus.running);
    expect(store.tasks, hasLength(1));
    expect(changed.last, isNotNull);
  });

  test('markStepCompletedIfPresent updates and persists current task', () async {
    final store = _FakeAgentTaskStore();
    final session = ActiveAgentTaskSession(
      runtimeAdapter: const AgentTaskRuntimeAdapter(),
      taskStore: store,
    );

    await session.startTask(
      conversationId: 'conversation_1',
      prompt: 'Research and answer',
    );
    session.markStepCompletedIfPresent(
      AgentStepKinds.interpretPrompt,
      detail: 'Interpreted.',
    );
    await Future<void>.delayed(Duration.zero);

    final updated = session.task!;
    final step = updated.steps.firstWhere(
      (entry) => entry.kind == AgentStepKinds.interpretPrompt,
    );
    expect(step.status, AgentStepStatus.completed);
    expect(step.detail, 'Interpreted.');
    expect(store.tasks.last.steps.first.status, AgentStepStatus.completed);
  });
}

class _FakeAgentTaskStore extends AgentTaskStore {
  _FakeAgentTaskStore() : super();

  final List<AgentTask> tasks = <AgentTask>[];

  @override
  Future<void> upsertTask(AgentTask task) async {
    tasks.add(task);
  }
}
