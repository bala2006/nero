import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/sarvam_api_client.dart';
import 'package:nero/features/chat/application/sarvam_stream_client.dart';
import 'package:nero/features/chat/domain/chat_message.dart';
import 'package:nero/features/providers/application/sarvam_provider_adapter.dart';
import 'package:nero/features/providers/domain/provider_models.dart';

void main() {
  test(
    'SarvamProviderAdapter maps completion results into provider models',
    () async {
      final adapter = SarvamProviderAdapter(
        completionClient: _FakeSarvamApiClient(),
        streamingClient: _FakeSarvamStreamClient(),
      );

      final result = await adapter.completeChat(
        apiKey: 'sk_test',
        modelId: 'sarvam-105b',
        messages: const <ChatMessage>[
          ChatMessage(id: 'u1', role: ChatRole.user, content: 'Hello'),
        ],
        tools: const <ProviderToolDefinition>[
          ProviderToolDefinition(
            name: 'generate_docx',
            description: 'Generate docx',
            parameters: <String, dynamic>{},
          ),
        ],
      );

      expect(adapter.descriptor.providerId, 'sarvam');
      expect(result.model, 'sarvam-105b');
      expect(result.content, 'Final answer');
      expect(result.toolCalls.single.name, 'generate_docx');
    },
  );

  test(
    'SarvamProviderAdapter delegates streaming through the Sarvam stream client',
    () async {
      final adapter = SarvamProviderAdapter(
        completionClient: _FakeSarvamApiClient(),
        streamingClient: _FakeSarvamStreamClient(),
      );

      final events = await adapter
          .streamChat(
            apiKey: 'sk_test',
            modelId: 'sarvam-105b',
            messages: const <ChatMessage>[
              ChatMessage(id: 'u1', role: ChatRole.user, content: 'Hello'),
            ],
          )
          .toList();

      expect(events.whereType<ContentDeltaEvent>(), isNotEmpty);
      expect(events.whereType<StreamFinishedEvent>(), isNotEmpty);
    },
  );
}

class _FakeSarvamApiClient extends SarvamApiClient {
  @override
  Future<SarvamChatResult> completeChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  }) async {
    return const SarvamChatResult(
      content: 'Final answer',
      model: 'sarvam-105b',
      toolCalls: <SarvamToolCall>[
        SarvamToolCall(
          id: 'tool_1',
          name: 'generate_docx',
          arguments: <String, dynamic>{'title': 'Doc'},
        ),
      ],
    );
  }
}

class _FakeSarvamStreamClient extends SarvamStreamClient {
  @override
  Stream<AgentStreamEvent> streamChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  }) {
    return Stream<AgentStreamEvent>.fromIterable(const <AgentStreamEvent>[
      ContentDeltaEvent('Hello'),
      StreamFinishedEvent(model: 'sarvam-105b'),
    ]);
  }
}
