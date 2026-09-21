import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/agent/domain/agent_task.dart';
import 'package:nero/features/chat/application/response_repair_coordinator.dart';
import 'package:nero/features/chat/application/sarvam_api_client.dart';
import 'package:nero/features/chat/application/streaming_run_completion_coordinator.dart';
import 'package:nero/features/chat/domain/chat_message.dart';
import 'package:nero/features/runtime/domain/runtime_run.dart';

void main() {
  final coordinator = StreamingRunCompletionCoordinator(
    responseRepairCoordinator: ResponseRepairCoordinator(
      client: _FakeChatCompletionClient(),
    ),
  );

  test('recoverFromRepeatedToolLoop completes task and updates run', () async {
    String? status;
    String? blockingReason;
    String? primaryDraftingDetail;
    String? streamDetail;
    String? replacedContent;
    RuntimeRun? updatedRun;
    var completedTask = false;
    var thinkingCleared = false;
    var requestCleared = false;
    var notified = false;

    final recovered = await coordinator.recoverFromRepeatedToolLoop(
      error: StateError('Model is repeating the same tool calls without making progress.'),
      task: AgentTask(
        id: 'task_1',
        conversationId: 'conversation_1',
        prompt: 'generate doc',
        status: AgentTaskStatus.running,
        createdAtEpochMs: 1,
        updatedAtEpochMs: 1,
        steps: const <AgentStep>[
          AgentStep(
            id: 'step_doc',
            kind: AgentStepKinds.generateDocument,
            title: 'Generate document',
            status: AgentStepStatus.completed,
          ),
        ],
      ),
      hasArtifact: false,
      setStatus: (value) => status = value,
      setBlockingReason: (value) => blockingReason = value,
      markPrimaryDraftingStepCompleted: (detail) => primaryDraftingDetail = detail,
      markStepCompletedIfPresent: (_, {required detail}) => streamDetail = detail,
      completeActiveTask: () => completedTask = true,
      clearThinking: () => thinkingCleared = true,
      replaceActiveAssistantContent: (
        content, {
        required bool isStreaming,
        bool clearAverageTokensPerSecond = false,
      }) {
        replacedContent = content;
      },
      clearRequestStartedAt: () => requestCleared = true,
      run: const RuntimeRun(
        id: 'run_1',
        kind: RuntimeRunKind.conversation,
        title: 'Generate doc',
        status: RuntimeRunStatus.runningModel,
        conversationId: 'conversation_1',
        createdAtEpochMs: 1,
        updatedAtEpochMs: 1,
      ),
      completeRecoveredRun: (run, response) async =>
          run.copyWith(
            status: RuntimeRunStatus.completed,
            result: <String, Object?>{'response': response, 'recovered': true},
          ),
      applyRunUpdate: (run) => updatedRun = run,
      notifyListeners: () => notified = true,
    );

    expect(recovered, isTrue);
    expect(status, 'Done');
    expect(blockingReason, isNull);
    expect(primaryDraftingDetail, isNotEmpty);
    expect(streamDetail, isNotEmpty);
    expect(completedTask, isTrue);
    expect(thinkingCleared, isTrue);
    expect(replacedContent, isNotEmpty);
    expect(requestCleared, isTrue);
    expect(updatedRun?.status, RuntimeRunStatus.completed);
    expect(notified, isTrue);
  });
}

class _FakeChatCompletionClient implements ChatCompletionClient {
  @override
  void cancel() {}

  @override
  Future<SarvamChatResult> completeChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  }) async {
    return const SarvamChatResult(content: '', model: 'sarvam-105b');
  }
}
