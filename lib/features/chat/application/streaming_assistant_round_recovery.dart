import 'dart:io';

import '../../settings/app_settings.dart';
import '../domain/chat_message.dart';
import 'legacy_tool_call_recovery_adapter.dart';
import 'sarvam_api_client.dart';

class StreamingAssistantRoundRecovery {
  const StreamingAssistantRoundRecovery({
    required ChatCompletionClient client,
    LegacyToolCallRecoveryAdapter legacyToolCallRecoveryAdapter =
        const LegacyToolCallRecoveryAdapter(),
    this.onCompatibilityRecovery,
  }) : _client = client,
       _legacyToolCallRecoveryAdapter = legacyToolCallRecoveryAdapter;

  final ChatCompletionClient _client;
  final LegacyToolCallRecoveryAdapter _legacyToolCallRecoveryAdapter;
  final void Function(LegacyToolCallRecoveryStats stats)? onCompatibilityRecovery;

  bool shouldFallbackFromBootstrapError(
    Object error, {
    required SarvamChatResult result,
  }) {
    if (result.finishReason != 'retryable_stream_bootstrap_error') {
      return false;
    }
    if (error is SocketException) {
      return true;
    }
    final message = error.toString().toLowerCase();
    return message.contains('connection reset by peer') ||
        message.contains('software caused connection abort') ||
        message.contains('broken pipe') ||
        message.contains('connection closed');
  }

  Future<SarvamChatResult> recoverBootstrapFallback({
    required String apiKey,
    required NeroSettings settings,
    required List<ChatMessage> requestMessages,
    required List<SarvamToolDefinition> tools,
    required Set<String> allowedToolNames,
    required Map<String, Set<String>> requiredToolArguments,
  }) async {
    final fallbackResult = await _client.completeChat(
      apiKey: apiKey,
      modelId: settings.selectedModelId,
      messages: requestMessages,
      tools: tools,
    );
    final recovered = _legacyToolCallRecoveryAdapter.recoverWithStats(
      result: fallbackResult,
      content: fallbackResult.content,
      allowedToolNames: allowedToolNames,
      requiredToolArguments: requiredToolArguments,
    );
    _emitCompatibilityRecovery(recovered.stats);
    return recovered.result;
  }

  SarvamChatResult normalizeRecoveredResult({
    required SarvamChatResult result,
    required String streamedContent,
    required String stagedContent,
    required Set<String> allowedToolNames,
    required Map<String, Set<String>> requiredToolArguments,
  }) {
    final recoveredResult = _legacyToolCallRecoveryAdapter.recoverWithStats(
      result: result,
      content: streamedContent,
      allowedToolNames: allowedToolNames,
      requiredToolArguments: requiredToolArguments,
    );
    _emitCompatibilityRecovery(recoveredResult.stats);
    if (recoveredResult.result.toolCalls.isEmpty && stagedContent.isNotEmpty) {
      final stagedRecovery = _legacyToolCallRecoveryAdapter.recoverWithStats(
        result: recoveredResult.result,
        content: stagedContent,
        allowedToolNames: allowedToolNames,
        requiredToolArguments: requiredToolArguments,
      );
      _emitCompatibilityRecovery(stagedRecovery.stats);
      return stagedRecovery.result;
    }
    return recoveredResult.result;
  }

  void _emitCompatibilityRecovery(LegacyToolCallRecoveryStats stats) {
    if (stats.usedCompatibilityRecovery) {
      onCompatibilityRecovery?.call(stats);
    }
  }
}
