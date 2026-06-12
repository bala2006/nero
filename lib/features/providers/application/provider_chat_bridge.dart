import '../../chat/application/sarvam_api_client.dart';
import '../../chat/application/sarvam_stream_client.dart';
import '../../chat/domain/chat_message.dart';
import '../domain/provider_models.dart';
import 'provider_client.dart';

class ProviderBackedChatCompletionClient implements ChatCompletionClient {
  ProviderBackedChatCompletionClient({
    required ProviderCompletionClient provider,
  }) : _provider = provider;

  final ProviderCompletionClient _provider;

  @override
  Future<SarvamChatResult> completeChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  }) async {
    final result = await _provider.completeChat(
      apiKey: apiKey,
      modelId: modelId,
      messages: messages,
      tools: tools
          .map(
            (tool) => ProviderToolDefinition(
              name: tool.name,
              description: tool.description,
              parameters: tool.parameters,
            ),
          )
          .toList(growable: false),
    );
    return SarvamChatResult(
      content: result.content,
      model: result.model,
      reasoningContent: result.reasoningContent,
      toolCalls: result.toolCalls
          .map(
            (call) => SarvamToolCall(
              id: call.id,
              name: call.name,
              arguments: call.arguments,
            ),
          )
          .toList(growable: false),
      finishReason: result.finishReason,
      promptTokens: result.promptTokens,
      completionTokens: result.completionTokens,
      totalTokens: result.totalTokens,
    );
  }

  @override
  void cancel() {
    _provider.cancel();
  }
}

class ProviderBackedStreamingClient implements ChatStreamingClient {
  ProviderBackedStreamingClient({required ProviderStreamingClient provider})
    : _provider = provider;

  final ProviderStreamingClient _provider;

  @override
  Stream<AgentStreamEvent> streamChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  }) {
    return _provider.streamChat(
      apiKey: apiKey,
      modelId: modelId,
      messages: messages,
      tools: tools
          .map(
            (tool) => ProviderToolDefinition(
              name: tool.name,
              description: tool.description,
              parameters: tool.parameters,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  void cancel() {
    _provider.cancel();
  }
}
