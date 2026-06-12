import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/chat_message.dart';
import 'sarvam_api_client.dart';
import '../../../platform/database/app_metadata_store.dart';

sealed class AgentStreamEvent {
  const AgentStreamEvent();
}

class ContentDeltaEvent extends AgentStreamEvent {
  const ContentDeltaEvent(this.delta);

  final String delta;
}

class ThinkingDeltaEvent extends AgentStreamEvent {
  const ThinkingDeltaEvent(this.delta);

  final String delta;
}

class ToolCallFinalEvent extends AgentStreamEvent {
  const ToolCallFinalEvent(this.call);

  final SarvamToolCall call;
}

class UsageReportEvent extends AgentStreamEvent {
  const UsageReportEvent({
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
  });

  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
}

class StreamFinishedEvent extends AgentStreamEvent {
  const StreamFinishedEvent({this.finishReason, this.model});

  final String? finishReason;
  final String? model;
}

class StreamErrorEvent extends AgentStreamEvent {
  const StreamErrorEvent(this.error, {required this.isRetryable});

  final Object error;
  final bool isRetryable;
}

abstract class ChatStreamingClient {
  Stream<AgentStreamEvent> streamChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  });

  void cancel();
}

class SarvamStreamClient implements ChatStreamingClient {
  SarvamStreamClient({
    HttpClient? httpClient,
    AppMetadataStore? appMetadataStore,
  }) : _httpClient = httpClient,
       _appMetadataStore = appMetadataStore ?? AppMetadataStore();

  HttpClient? _httpClient;
  SarvamApiClient? _fallbackClient;
  final AppMetadataStore _appMetadataStore;
  final Map<String, bool> _streamingSupported = <String, bool>{};
  bool _cancelled = false;
  static const String _streamingSupportedKeyPrefix =
      'sarvam_streaming_supported';

  @override
  Stream<AgentStreamEvent> streamChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  }) async* {
    final supportsStreaming = await _resolveStreamingSupport(modelId);
    if (!supportsStreaming) {
      yield* _fallbackBufferedStream(
        apiKey: apiKey,
        modelId: modelId,
        messages: messages,
        tools: tools,
      );
      return;
    }

    _cancelled = false;
    final client = _httpClient ?? HttpClient();
    _httpClient = client;
    var sawPayload = false;

    try {
      final request = await client.postUrl(
        Uri.parse('https://api.sarvam.ai/v1/chat/completions'),
      );
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('api-subscription-key', apiKey);
      request.add(
        utf8.encode(
          jsonEncode(
            buildSarvamChatPayload(
              modelId: modelId,
              messages: messages,
              tools: tools,
              stream: true,
            ),
          ),
        ),
      );

      final response = await request.close();
      if (response.statusCode == 422 || response.statusCode == 400) {
        await _setStreamingSupport(modelId, false);
        yield* _fallbackBufferedStream(
          apiKey: apiKey,
          modelId: modelId,
          messages: messages,
          tools: tools,
        );
        return;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.transform(utf8.decoder).join();
        throw HttpException(
          'Sarvam API request failed (${response.statusCode}): $body',
        );
      }

      await for (final line
          in response.transform(utf8.decoder).transform(const LineSplitter())) {
        if (_cancelled) {
          break;
        }
        if (!line.startsWith('data: ')) {
          continue;
        }
        final payload = line.substring(6).trim();
        if (payload == '[DONE]') {
          yield const StreamFinishedEvent();
          break;
        }
        final decoded = jsonDecode(payload);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        final choices = decoded['choices'];
        if (choices is! List || choices.isEmpty || choices.first is! Map) {
          continue;
        }
        final choice = Map<String, dynamic>.from(choices.first as Map);
        final delta = choice['delta'];
        if (delta is Map) {
          final content = delta['content']?.toString();
          if (content != null && content.isNotEmpty) {
            sawPayload = true;
            yield ContentDeltaEvent(content);
          }
          final reasoning = delta['reasoning_content']?.toString();
          if (reasoning != null && reasoning.isNotEmpty) {
            sawPayload = true;
            yield ThinkingDeltaEvent(reasoning);
          }
          final toolCalls = parseToolCalls(delta['tool_calls']);
          for (final toolCall in toolCalls) {
            sawPayload = true;
            yield ToolCallFinalEvent(toolCall);
          }
        }
        final usage = decoded['usage'];
        if (usage is Map) {
          yield UsageReportEvent(
            promptTokens: (usage['prompt_tokens'] as num?)?.toInt(),
            completionTokens: (usage['completion_tokens'] as num?)?.toInt(),
            totalTokens: (usage['total_tokens'] as num?)?.toInt(),
          );
        }
        final finishReason = choice['finish_reason']?.toString();
        if (finishReason != null && finishReason.isNotEmpty) {
          yield StreamFinishedEvent(
            finishReason: finishReason,
            model: decoded['model']?.toString(),
          );
        }
      }
    } catch (error) {
      if (_cancelled) {
        return;
      }
      if (!sawPayload && error is SocketException) {
        yield* _fallbackBufferedStream(
          apiKey: apiKey,
          modelId: modelId,
          messages: messages,
          tools: tools,
        );
        return;
      }
      yield StreamErrorEvent(error, isRetryable: true);
    } finally {
      if (!identical(_httpClient, client)) {
        client.close(force: true);
      } else {
        _httpClient = null;
      }
    }
  }

  @override
  void cancel() {
    _cancelled = true;
    _httpClient?.close(force: true);
    _httpClient = null;
    _fallbackClient?.cancel();
    _fallbackClient = null;
  }

  Stream<AgentStreamEvent> _fallbackBufferedStream({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    required List<SarvamToolDefinition> tools,
  }) async* {
    final client = SarvamApiClient();
    _fallbackClient = client;
    try {
      final result = await client.completeChat(
        apiKey: apiKey,
        modelId: modelId,
        messages: messages,
        tools: tools,
      );
      if (_cancelled) {
        return;
      }
      if (result.reasoningContent != null &&
          result.reasoningContent!.isNotEmpty) {
        yield ThinkingDeltaEvent(result.reasoningContent!);
      }
      for (final toolCall in result.toolCalls) {
        yield ToolCallFinalEvent(toolCall);
      }
      if (result.content.isNotEmpty) {
        yield ContentDeltaEvent(result.content);
      }
      yield UsageReportEvent(
        promptTokens: result.promptTokens,
        completionTokens: result.completionTokens,
        totalTokens: result.totalTokens,
      );
      yield StreamFinishedEvent(
        finishReason: result.finishReason,
        model: result.model,
      );
    } finally {
      if (identical(_fallbackClient, client)) {
        _fallbackClient = null;
      }
    }
  }

  Future<bool> _resolveStreamingSupport(String modelId) async {
    final cacheKey = _streamingSupportKey(modelId);
    final cached = _streamingSupported[cacheKey];
    if (cached != null) {
      return cached;
    }
    final stored = await _appMetadataStore.read(cacheKey);
    if (stored == 'true') {
      _streamingSupported[cacheKey] = true;
      return true;
    }
    if (stored == 'false') {
      _streamingSupported[cacheKey] = false;
      return false;
    }
    _streamingSupported[cacheKey] = true;
    return true;
  }

  Future<void> _setStreamingSupport(String modelId, bool value) async {
    final cacheKey = _streamingSupportKey(modelId);
    _streamingSupported[cacheKey] = value;
    await _appMetadataStore.write(cacheKey, value ? 'true' : 'false');
  }

  String _streamingSupportKey(String modelId) {
    return '$_streamingSupportedKeyPrefix:${modelId.trim()}';
  }
}
