import '../../chat/domain/chat_message.dart';
import '../../chat/application/sarvam_stream_client.dart';
import '../domain/provider_models.dart';

abstract class ProviderCompletionClient {
  ProviderDescriptor get descriptor;

  Future<ProviderCompletionResult> completeChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<ProviderToolDefinition> tools = const <ProviderToolDefinition>[],
  });

  void cancel();
}

abstract class ProviderStreamingClient {
  ProviderDescriptor get descriptor;

  Stream<AgentStreamEvent> streamChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<ProviderToolDefinition> tools = const <ProviderToolDefinition>[],
  });

  void cancel();
}
