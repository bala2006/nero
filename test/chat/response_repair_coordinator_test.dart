import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/agent/domain/agent_task.dart';
import 'package:nero/features/chat/application/response_repair_coordinator.dart';
import 'package:nero/features/chat/application/sarvam_api_client.dart';
import 'package:nero/features/chat/domain/chat_message.dart';
import 'package:nero/features/settings/app_settings.dart';

void main() {
  test('repairEmptyDirectResponseIfNeeded retries direct responses only', () async {
    final client = _FakeChatCompletionClient(
      const SarvamChatResult(
        content: 'Recovered answer',
        model: 'sarvam-105b',
      ),
    );
    final coordinator = ResponseRepairCoordinator(client: client);

    final repaired = await coordinator.repairEmptyDirectResponseIfNeeded(
      apiKey: 'sk_test',
      settings: const NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-105b',
      ),
      prompt: 'research and compare models',
      requestMessages: const <ChatMessage>[
        ChatMessage(id: 'u1', role: ChatRole.user, content: 'research'),
      ],
      currentResponse: '',
      selectedTools: const <String>['search_web'],
    );

    expect(repaired, 'Recovered answer');
    expect(client.lastMessages.last.role, ChatRole.system);
  });

  test('repairEmptyDirectResponseIfNeeded skips artifact requests', () async {
    final client = _FakeChatCompletionClient(
      const SarvamChatResult(
        content: 'unused',
        model: 'sarvam-105b',
      ),
    );
    final coordinator = ResponseRepairCoordinator(client: client);

    final repaired = await coordinator.repairEmptyDirectResponseIfNeeded(
      apiKey: 'sk_test',
      settings: const NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-105b',
      ),
      prompt: 'create a docx about capabilities',
      requestMessages: const <ChatMessage>[],
      currentResponse: '',
      selectedTools: const <String>['generate_docx'],
    );

    expect(repaired, isNull);
    expect(client.callCount, 0);
  });

  test('repeated tool loop recovery policy requires completed document step', () {
    final coordinator = ResponseRepairCoordinator(
      client: _FakeChatCompletionClient(
        const SarvamChatResult(content: 'unused', model: 'sarvam-105b'),
      ),
    );
    final task = AgentTask(
      id: 'task_1',
      conversationId: 'conversation_1',
      prompt: 'create a docx',
      status: AgentTaskStatus.running,
      steps: const <AgentStep>[
        AgentStep(
          id: 'step_generate_document',
          kind: AgentStepKinds.generateDocument,
          title: 'Generate document',
          detail: 'done',
          status: AgentStepStatus.completed,
        ),
      ],
      createdAtEpochMs: 1,
      updatedAtEpochMs: 1,
    );

    expect(
      coordinator.shouldRecoverFromRepeatedToolLoop(
        StateError('Model is repeating the same tool calls without making progress.'),
        task,
      ),
      isTrue,
    );
    expect(
      coordinator.repeatedToolLoopRecoveryMessage(hasArtifact: true),
      'I created the file and attached it above.',
    );
  });
}

class _FakeChatCompletionClient implements ChatCompletionClient {
  _FakeChatCompletionClient(this.result);

  final SarvamChatResult result;
  int callCount = 0;
  List<ChatMessage> lastMessages = const <ChatMessage>[];

  @override
  Future<SarvamChatResult> completeChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  }) async {
    callCount += 1;
    lastMessages = messages;
    return result;
  }

  @override
  void cancel() {}
}
