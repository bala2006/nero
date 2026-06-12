import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/legacy_tool_call_recovery_adapter.dart';
import 'package:nero/features/chat/application/sarvam_api_client.dart';
import 'package:nero/features/chat/application/streaming_assistant_round_recovery.dart';
import 'package:nero/features/chat/domain/chat_message.dart';
import 'package:nero/features/settings/app_settings.dart';

void main() {
  test('shouldFallbackFromBootstrapError accepts retryable bootstrap socket failures', () {
    final recovery = StreamingAssistantRoundRecovery(
      client: _FakeChatCompletionClient(
        const SarvamChatResult(content: '', model: 'sarvam-105b'),
      ),
    );

    final shouldFallback = recovery.shouldFallbackFromBootstrapError(
      const SocketException('Connection reset by peer'),
      result: const SarvamChatResult(
        content: '',
        model: 'sarvam-105b',
        finishReason: 'retryable_stream_bootstrap_error',
      ),
    );

    expect(shouldFallback, isTrue);
  });

  test('recoverBootstrapFallback replays request and normalizes inline tool calls', () async {
    final recovery = StreamingAssistantRoundRecovery(
      client: _FakeChatCompletionClient(
        const SarvamChatResult(
          content:
              'I will create it.\n'
              '<tool_call>generate_docx\n'
              '<arg_key>title</arg_key>\n'
              '<arg_value>Capabilities</arg_value>\n'
              '<arg_key>markdown_content</arg_key>\n'
              '<arg_value># Capabilities</arg_value>\n',
          model: 'sarvam-105b',
        ),
      ),
    );

    final result = await recovery.recoverBootstrapFallback(
      apiKey: 'sk_test',
      settings: const NeroSettings(
        sarvamApiKey: 'sk_test',
        selectedModelId: 'sarvam-105b',
      ),
      requestMessages: const <ChatMessage>[
        ChatMessage(id: 'u1', role: ChatRole.user, content: 'create a docx'),
      ],
      tools: const <SarvamToolDefinition>[
        SarvamToolDefinition(
          name: 'generate_docx',
          description: 'Create docx',
          parameters: <String, dynamic>{},
        ),
      ],
      allowedToolNames: const <String>{'generate_docx'},
      requiredToolArguments: const <String, Set<String>>{
        'generate_docx': <String>{'title', 'markdown_content'},
      },
    );

    expect(result.toolCalls, hasLength(1));
    expect(result.toolCalls.single.name, 'generate_docx');
    expect(result.content, 'I will create it.');
  });

  test('normalizeRecoveredResult prefers staged content when stream content lacks tool call', () {
    LegacyToolCallRecoveryStats? capturedStats;
    final recovery = StreamingAssistantRoundRecovery(
      client: _FakeChatCompletionClient(
        const SarvamChatResult(content: '', model: 'sarvam-105b'),
      ),
      onCompatibilityRecovery: (stats) => capturedStats = stats,
    );

    final result = recovery.normalizeRecoveredResult(
      result: const SarvamChatResult(content: '', model: 'sarvam-105b'),
      streamedContent: '',
      stagedContent:
          'I will create it.\n'
          '<tool_call>generate_docx\n'
          '<arg_key>title</arg_key>\n'
          '<arg_value>Capabilities</arg_value>\n'
          '<arg_key>markdown_content</arg_key>\n'
          '<arg_value># Capabilities</arg_value>\n',
      allowedToolNames: const <String>{'generate_docx'},
      requiredToolArguments: const <String, Set<String>>{
        'generate_docx': <String>{'title', 'markdown_content'},
      },
    );

    expect(result.toolCalls, hasLength(1));
    expect(result.content, 'I will create it.');
    expect(capturedStats, isNotNull);
    expect(capturedStats!.recoveredToolCallCount, 1);
  });
}

class _FakeChatCompletionClient implements ChatCompletionClient {
  _FakeChatCompletionClient(this.result);

  final SarvamChatResult result;

  @override
  Future<SarvamChatResult> completeChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  }) async {
    return result;
  }

  @override
  void cancel() {}
}
