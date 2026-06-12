import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/agent/domain/agent_task.dart';
import 'package:nero/features/chat/application/conversation_memory_capture_builder.dart';

void main() {
  const builder = ConversationMemoryCaptureBuilder();

  test('build creates snapshot and fact from conversation state', () {
    final capture = builder.build(
      task: const AgentTask(
        id: 'task_1',
        conversationId: 'conversation_1',
        prompt: 'Explain Flutter performance',
        status: AgentTaskStatus.completed,
        createdAtEpochMs: 1,
        updatedAtEpochMs: 2,
        steps: <AgentStep>[],
      ),
      conversationId: 'conversation_1',
      prompt: 'Explain Flutter performance',
      finalResponse:
          'Use profiling, reduce rebuilds, and measure before optimizing.',
      currentThought: 'Summarizing the main recommendations.',
      visibleActivityCount: 2,
      messageCount: 4,
      nowEpochMs: 123,
    );

    expect(capture.snapshot.id, 'working_task_1');
    expect(capture.snapshot.metadata['status'], 'completed');
    expect(capture.snapshot.metadata['messageCount'], 4);
    expect(
      capture.snapshot.assumptions,
      contains('Summarizing the main recommendations.'),
    );
    expect(
      capture.snapshot.assumptions,
      contains('Used 2 visible activity entries.'),
    );
    expect(capture.fact.id, 'fact_latest_response_task_1');
    expect(capture.fact.value['prompt'], 'Explain Flutter performance');
    expect(
      capture.fact.value['summary'],
      contains('Prompt: Explain Flutter performance'),
    );
  });

  test('summarize clips long responses', () {
    final summary = builder.summarize('Prompt', 'a' * 300);

    expect(summary, startsWith('Prompt: Prompt | Response: '));
    expect(summary.endsWith('...'), isTrue);
  });
}
