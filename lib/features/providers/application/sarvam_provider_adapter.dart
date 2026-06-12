import '../../chat/application/sarvam_api_client.dart';
import '../../chat/application/sarvam_stream_client.dart';
import '../../chat/domain/chat_message.dart';
import '../domain/provider_models.dart';
import 'provider_client.dart';

class SarvamProviderAdapter
    implements ProviderCompletionClient, ProviderStreamingClient {
  SarvamProviderAdapter({
    SarvamApiClient? completionClient,
    SarvamStreamClient? streamingClient,
  }) : _completionClient = completionClient ?? SarvamApiClient(),
       _streamingClient = streamingClient ?? SarvamStreamClient();

  final SarvamApiClient _completionClient;
  final SarvamStreamClient _streamingClient;

  static const ProviderDescriptor sarvamDescriptor = ProviderDescriptor(
    providerId: 'sarvam',
    displayName: 'Sarvam',
    supportsStreaming: true,
    supportsToolCalling: true,
  );

  @override
  ProviderDescriptor get descriptor => sarvamDescriptor;

  @override
  Future<ProviderCompletionResult> completeChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<ProviderToolDefinition> tools = const <ProviderToolDefinition>[],
  }) async {
    final result = await _completionClient.completeChat(
      apiKey: apiKey,
      modelId: modelId,
      messages: messages,
      tools: tools.map(_toSarvamToolDefinition).toList(growable: false),
    );
    return _fromSarvamChatResult(result);
  }

  @override
  Stream<AgentStreamEvent> streamChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<ProviderToolDefinition> tools = const <ProviderToolDefinition>[],
  }) {
    return _streamingClient.streamChat(
      apiKey: apiKey,
      modelId: modelId,
      messages: messages,
      tools: tools.map(_toSarvamToolDefinition).toList(growable: false),
    );
  }

  @override
  void cancel() {
    _completionClient.cancel();
    _streamingClient.cancel();
  }

  ProviderCompletionResult _fromSarvamChatResult(SarvamChatResult result) {
    return ProviderCompletionResult(
      content: result.content,
      model: result.model,
      reasoningContent: result.reasoningContent,
      toolCalls: result.toolCalls
          .map(
            (call) => ProviderToolCall(
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

  SarvamToolDefinition _toSarvamToolDefinition(ProviderToolDefinition tool) {
    return SarvamToolDefinition(
      name: tool.name,
      description: tool.description,
      parameters: tool.parameters,
    );
  }
}
