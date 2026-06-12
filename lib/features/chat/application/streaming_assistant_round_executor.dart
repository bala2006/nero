import 'dart:async';

import '../../settings/app_settings.dart';
import '../domain/chat_message.dart';
import 'sarvam_api_client.dart';
import 'sarvam_stream_client.dart';
import 'streaming_assistant_round_recovery.dart';

/// Callback types used by [StreamingAssistantRoundExecutor].
typedef ReasoningDeltaHandler = void Function(String delta);
typedef ContentRevealedHandler = void Function(String content);

/// Encapsulates the streaming or non-streaming execution of one assistant
/// "round" (a single model call that may produce content, tool-calls, or
/// both).
///
/// Extracted from [ChatSessionController] to remove the largest single block
/// of controller-local async logic.  The executor owns:
///
///  - streaming subscription lifecycle
///  - tool-call deduplication keying
///  - content-staging logic (hide content before the first `<tool_call>`)
///  - bootstrap-error fallback (via [StreamingAssistantRoundRecovery])
///  - result normalisation after the stream completes
///
/// All UI callbacks are injected so the executor itself is testable without
/// Flutter or a real streaming client.
class StreamingAssistantRoundExecutor {
  const StreamingAssistantRoundExecutor({
    required ChatCompletionClient client,
    ChatStreamingClient? streamingClient,
    required StreamingAssistantRoundRecovery roundRecovery,
  }) : _client = client,
       _streamingClient = streamingClient,
       _roundRecovery = roundRecovery;

  final ChatCompletionClient _client;
  final ChatStreamingClient? _streamingClient;
  final StreamingAssistantRoundRecovery _roundRecovery;

  /// Executes one assistant round, returning the completed [SarvamChatResult].
  ///
  /// [responseBuffer] is appended with non-tool content so that callers can
  /// accumulate a growing response across multiple rounds.
  ///
  /// [onContentRevealed] fires whenever the visible UI content should be
  /// updated (i.e. staging is resolved or a new chunk arrives).
  ///
  /// [onReasoningDelta] fires for each incremental thinking / reasoning token
  /// so the caller can merge and display reasoning content.
  ///
  /// [onSubscriptionCreated] is called synchronously after the streaming
  /// subscription is opened so the caller can cancel it on demand.
  Future<SarvamChatResult> execute({
    required String apiKey,
    required NeroSettings settings,
    required List<ChatMessage> requestMessages,
    required List<SarvamToolDefinition> tools,
    required StringBuffer responseBuffer,
    required ContentRevealedHandler onContentRevealed,
    required ReasoningDeltaHandler onReasoningDelta,
    required void Function(StreamSubscription<AgentStreamEvent>) onSubscriptionCreated,
  }) async {
    final streamingClient = _streamingClient;
    if (streamingClient == null) {
      return _executeNonStreaming(
        apiKey: apiKey,
        settings: settings,
        requestMessages: requestMessages,
        tools: tools,
        responseBuffer: responseBuffer,
        onContentRevealed: onContentRevealed,
        onReasoningDelta: onReasoningDelta,
      );
    }

    return _executeStreaming(
      apiKey: apiKey,
      settings: settings,
      requestMessages: requestMessages,
      tools: tools,
      responseBuffer: responseBuffer,
      streamingClient: streamingClient,
      onContentRevealed: onContentRevealed,
      onReasoningDelta: onReasoningDelta,
      onSubscriptionCreated: onSubscriptionCreated,
    );
  }

  // ---------------------------------------------------------------------------
  // Non-streaming path
  // ---------------------------------------------------------------------------

  Future<SarvamChatResult> _executeNonStreaming({
    required String apiKey,
    required NeroSettings settings,
    required List<ChatMessage> requestMessages,
    required List<SarvamToolDefinition> tools,
    required StringBuffer responseBuffer,
    required ContentRevealedHandler onContentRevealed,
    required ReasoningDeltaHandler onReasoningDelta,
  }) async {
    final result = await _client.completeChat(
      apiKey: apiKey,
      modelId: settings.selectedModelId,
      messages: requestMessages,
      tools: tools,
    );
    if (result.reasoningContent != null &&
        result.reasoningContent!.isNotEmpty) {
      onReasoningDelta(result.reasoningContent!);
    }
    if (result.content.isNotEmpty && result.toolCalls.isEmpty) {
      responseBuffer.write(result.content);
      onContentRevealed(responseBuffer.toString());
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Streaming path
  // ---------------------------------------------------------------------------

  Future<SarvamChatResult> _executeStreaming({
    required String apiKey,
    required NeroSettings settings,
    required List<ChatMessage> requestMessages,
    required List<SarvamToolDefinition> tools,
    required StringBuffer responseBuffer,
    required ChatStreamingClient streamingClient,
    required ContentRevealedHandler onContentRevealed,
    required ReasoningDeltaHandler onReasoningDelta,
    required void Function(StreamSubscription<AgentStreamEvent>) onSubscriptionCreated,
  }) async {
    final completer = Completer<SarvamChatResult>();
    final contentBuffer = StringBuffer();
    final stagedContentBuffer = StringBuffer();
    final reasoningBuffer = StringBuffer();

    final allowedToolNames = tools.map((t) => t.name).toSet();
    final requiredToolArgs = <String, Set<String>>{
      for (final tool in tools)
        tool.name: ((tool.parameters['required'] as List?) ?? const [])
            .map((item) => item.toString())
            .toSet(),
    };
    final toolCallsByKey = <String, SarvamToolCall>{};

    String? finishReason;
    String model = settings.selectedModelId;
    int? promptTokens;
    int? completionTokens;
    int? totalTokens;
    var sawToolCall = false;
    Object? retryableBootstrapError;

    late final StreamSubscription<AgentStreamEvent> subscription;
    subscription = streamingClient
        .streamChat(
          apiKey: apiKey,
          modelId: settings.selectedModelId,
          messages: requestMessages,
          tools: tools,
        )
        .listen(
          (event) {
            switch (event) {
              case ContentDeltaEvent():
                contentBuffer.write(event.delta);
                if (!sawToolCall) {
                  stagedContentBuffer.write(event.delta);
                  final stagedText = stagedContentBuffer.toString();
                  final visibleContent = stagedText.contains('<tool_call>')
                      ? stagedText.substring(
                          0,
                          stagedText.indexOf('<tool_call>'),
                        )
                      : stagedText;
                  onContentRevealed(
                    '${responseBuffer.toString()}$visibleContent',
                  );
                }
              case ThinkingDeltaEvent():
                // Accumulate locally so the result can expose the full
                // reasoning string, while also notifying the caller
                // incrementally for merging.
                reasoningBuffer.write(event.delta);
                onReasoningDelta(event.delta);
              case ToolCallFinalEvent():
                if (!sawToolCall && stagedContentBuffer.isNotEmpty) {
                  onContentRevealed(responseBuffer.toString());
                }
                sawToolCall = true;
                final call = event.call;
                if (!allowedToolNames.contains(call.name)) { break; }
                if (!_hasRequiredToolArguments(
                  call,
                  requiredToolArgs[call.name],
                )) { break; }
                final key = _stableToolCallKey(call);
                final existing = toolCallsByKey[key];
                if (existing == null ||
                    _toolCallArgumentScore(call) >=
                        _toolCallArgumentScore(existing)) {
                  toolCallsByKey[key] = call;
                }
              case UsageReportEvent():
                promptTokens = event.promptTokens ?? promptTokens;
                completionTokens = event.completionTokens ?? completionTokens;
                totalTokens = event.totalTokens ?? totalTokens;
              case StreamFinishedEvent():
                finishReason = event.finishReason ?? finishReason;
                model = event.model ?? model;
                if (!completer.isCompleted) {
                  completer.complete(
                    SarvamChatResult(
                      content: contentBuffer.toString(),
                      model: model,
                      reasoningContent: reasoningBuffer.isEmpty
                          ? null
                          : reasoningBuffer.toString(),
                      toolCalls: List<SarvamToolCall>.unmodifiable(
                        toolCallsByKey.values,
                      ),
                      finishReason: finishReason,
                      promptTokens: promptTokens,
                      completionTokens: completionTokens,
                      totalTokens: totalTokens,
                    ),
                  );
                }
              case StreamErrorEvent():
                if (!completer.isCompleted) {
                  if (event.isRetryable &&
                      contentBuffer.isEmpty &&
                      toolCallsByKey.isEmpty) {
                    retryableBootstrapError = event.error;
                    completer.complete(
                      SarvamChatResult(
                        content: '',
                        model: model,
                        reasoningContent: null,
                        toolCalls: const <SarvamToolCall>[],
                        finishReason: 'retryable_stream_bootstrap_error',
                        promptTokens: promptTokens,
                        completionTokens: completionTokens,
                        totalTokens: totalTokens,
                      ),
                    );
                  } else {
                    completer.completeError(event.error);
                  }
                }
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);
            }
          },
          onDone: () {
            if (!completer.isCompleted) {
              completer.complete(
                SarvamChatResult(
                  content: contentBuffer.toString(),
                  model: model,
                  reasoningContent: reasoningBuffer.isEmpty
                      ? null
                      : reasoningBuffer.toString(),
                  toolCalls: List<SarvamToolCall>.unmodifiable(
                    toolCallsByKey.values,
                  ),
                  finishReason: finishReason,
                  promptTokens: promptTokens,
                  completionTokens: completionTokens,
                  totalTokens: totalTokens,
                ),
              );
            }
          },
          cancelOnError: false,
        );

    onSubscriptionCreated(subscription);

    try {
      final result = await completer.future;

      // Bootstrap-error fallback path — uses the non-streaming client.
      if (retryableBootstrapError != null &&
          _roundRecovery.shouldFallbackFromBootstrapError(
            retryableBootstrapError!,
            result: result,
          )) {
        final recovered = await _roundRecovery.recoverBootstrapFallback(
          apiKey: apiKey,
          settings: settings,
          requestMessages: requestMessages,
          tools: tools,
          allowedToolNames: allowedToolNames,
          requiredToolArguments: requiredToolArgs,
        );
        if (recovered.reasoningContent != null &&
            recovered.reasoningContent!.isNotEmpty) {
          onReasoningDelta(recovered.reasoningContent!);
        }
        if (recovered.content.isNotEmpty && recovered.toolCalls.isEmpty) {
          responseBuffer.write(recovered.content);
          onContentRevealed(responseBuffer.toString());
        }
        return recovered;
      }

      // Normal result normalisation — legacy compatibility recovery.
      final normalized = _roundRecovery.normalizeRecoveredResult(
        result: result,
        streamedContent: contentBuffer.toString(),
        stagedContent: stagedContentBuffer.toString(),
        allowedToolNames: allowedToolNames,
        requiredToolArguments: requiredToolArgs,
      );
      if (normalized.content.isNotEmpty &&
          normalized.content != result.content &&
          normalized.toolCalls.isEmpty) {
        responseBuffer.write(normalized.content);
      }
      return normalized;
    } finally {
      await subscription.cancel();
    }
  }

  // ---------------------------------------------------------------------------
  // Tool-call helpers (pure functions, no side effects)
  // ---------------------------------------------------------------------------

  static String _stableToolCallKey(SarvamToolCall call) {
    final id = call.id.trim();
    if (id.isNotEmpty) {
      return '${call.name}:$id';
    }
    final keys = call.arguments.keys.toList(growable: false)..sort();
    final normalized =
        keys.map((key) => '$key=${call.arguments[key]}').join(',');
    return '${call.name}:$normalized';
  }

  static bool _hasRequiredToolArguments(
    SarvamToolCall call,
    Set<String>? requiredKeys,
  ) {
    if (requiredKeys == null || requiredKeys.isEmpty) {
      return call.arguments.isNotEmpty;
    }
    for (final key in requiredKeys) {
      final value = call.arguments[key];
      if (value == null) return false;
      if (value is String && value.trim().isEmpty) return false;
    }
    return true;
  }

  static int _toolCallArgumentScore(SarvamToolCall call) {
    var score = 0;
    for (final entry in call.arguments.entries) {
      final value = entry.value;
      if (value == null) continue;
      score += value is String ? value.trim().length : value.toString().length;
    }
    return score;
  }
}
