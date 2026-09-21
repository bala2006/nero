import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/chat_message.dart';
import 'sarvam_api_client.dart';
import 'sarvam_stream_client.dart';

/// Azure AI (Microsoft Foundry Models) provider backed by the Responses API.
///
/// gpt-5.6 models can't combine `reasoning_effort` with function tools on the
/// Chat Completions API — a request that carries `tools` fails unless effort is
/// `none`, and these models default to `medium`. Azure therefore recommends the
/// Responses API for reasoning + tools, which is what this client uses:
/// `POST {baseUrl}/responses` with the `api-key` header.
///
/// The request shape is OpenAI-compatible but not identical to Chat Completions:
/// tools are flat (`{type, name, description, parameters}`), reasoning is
/// `{"reasoning": {"effort": "high"}}`, and the output-limit field is
/// `max_output_tokens`.
class AzureResponsesClient
    implements ChatCompletionClient, ChatStreamingClient {
  AzureResponsesClient({
    required String Function() baseUrlProvider,
    HttpClient? httpClient,
    this.reasoningEffort = defaultReasoningEffort,
    this.reasoningSummary = defaultReasoningSummary,
    this.maxOutputTokens = defaultMaxOutputTokens,
    this.store = true,
  }) : _baseUrlProvider = baseUrlProvider,
       _httpClient = httpClient;

  /// High effort is the configured default: gpt-5.6-luna "performance improves
  /// with increased reasoning effort on complex tasks".
  static const String defaultReasoningEffort = 'high';

  /// The Responses API only emits `response.reasoning_summary_text.delta`
  /// events when a summary level is requested. Without this the app never
  /// receives any reasoning, which is why the transcript used to sit on the
  /// `Planning response` placeholder forever.
  static const String defaultReasoningSummary = 'auto';

  /// Reserve headroom for reasoning tokens; the docs suggest keeping at least
  /// ~25k available for reasoning plus visible output.
  static const int defaultMaxOutputTokens = 25000;

  final String Function() _baseUrlProvider;

  /// Mutable so a settings change applies to the next request without
  /// rebuilding the chat session.
  String reasoningEffort;

  /// `auto`, `concise` or `detailed`; empty or `none` disables summaries.
  String reasoningSummary;

  final int? maxOutputTokens;

  /// When false the response is not retained server-side, which requires
  /// opting into `reasoning.encrypted_content` to keep multi-turn reasoning
  /// continuity. Defaults to true (Azure retains the response).
  final bool store;

  HttpClient? _httpClient;
  bool _cancelled = false;

  @override
  Future<SarvamChatResult> completeChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  }) async {
    _cancelled = false;
    final client = _httpClient ?? HttpClient();
    _httpClient = client;
    try {
      final request = await client.postUrl(_endpoint());
      _applyHeaders(request, apiKey);
      request.add(
        utf8.encode(
          jsonEncode(
            buildAzureResponsesPayload(
              modelId: modelId,
              messages: messages,
              tools: tools,
              reasoningEffort: reasoningEffort,
              reasoningSummary: reasoningSummary,
              maxOutputTokens: maxOutputTokens,
              store: store,
            ),
          ),
        ),
      );

      final response = await request.close();
      if (_cancelled) {
        throw const HttpException('request_cancelled');
      }
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Azure AI request failed (${response.statusCode}): $body',
        );
      }
      return parseAzureResponsesBody(body, modelId: modelId);
    } finally {
      _release(client);
    }
  }

  @override
  Stream<AgentStreamEvent> streamChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  }) async* {
    _cancelled = false;
    final client = _httpClient ?? HttpClient();
    _httpClient = client;
    try {
      final request = await client.postUrl(_endpoint());
      _applyHeaders(request, apiKey);
      request.add(
        utf8.encode(
          jsonEncode(
            buildAzureResponsesPayload(
              modelId: modelId,
              messages: messages,
              tools: tools,
              reasoningEffort: reasoningEffort,
              reasoningSummary: reasoningSummary,
              maxOutputTokens: maxOutputTokens,
              store: store,
              stream: true,
            ),
          ),
        ),
      );

      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.transform(utf8.decoder).join();
        throw HttpException(
          'Azure AI request failed (${response.statusCode}): $body',
        );
      }

      await for (final line
          in response.transform(utf8.decoder).transform(const LineSplitter())) {
        if (_cancelled) {
          break;
        }
        if (!line.startsWith('data:')) {
          continue;
        }
        final payload = line.substring(5).trim();
        if (payload.isEmpty || payload == '[DONE]') {
          continue;
        }
        final decoded = jsonDecode(payload);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }

        switch (decoded['type']?.toString()) {
          case 'response.output_text.delta':
            final delta = decoded['delta']?.toString();
            if (delta != null && delta.isNotEmpty) {
              yield ContentDeltaEvent(delta);
            }
          case 'response.reasoning_summary_part.added':
            yield const ReasoningPartBoundaryEvent();
          case 'response.reasoning_summary_text.delta':
          case 'response.reasoning_text.delta':
            final delta = decoded['delta']?.toString();
            if (delta != null && delta.isNotEmpty) {
              yield ThinkingDeltaEvent(delta);
            }
          case 'response.output_item.done':
            final call = _functionCallFromItem(decoded['item']);
            if (call != null) {
              yield ToolCallFinalEvent(call);
            }
          case 'response.completed':
            final completed = decoded['response'];
            for (final event in _completionEvents(completed, modelId: modelId)) {
              yield event;
            }
          case 'response.failed':
          case 'response.incomplete':
          case 'error':
            yield StreamErrorEvent(
              HttpException(
                _errorMessage(decoded) ?? 'Azure AI response failed.',
              ),
              isRetryable: true,
            );
        }
      }
    } catch (error) {
      if (_cancelled) {
        return;
      }
      yield StreamErrorEvent(error, isRetryable: true);
    } finally {
      _release(client);
    }
  }

  @override
  void cancel() {
    _cancelled = true;
    _httpClient?.close(force: true);
    _httpClient = null;
  }

  Uri _endpoint() {
    final raw = _baseUrlProvider().trim();
    if (raw.isEmpty) {
      throw const HttpException(
        'Azure AI base URL is not configured. Add it in Settings.',
      );
    }
    var normalized = raw;
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (normalized.endsWith('/responses')) {
      return Uri.parse(normalized);
    }
    return Uri.parse('$normalized/responses');
  }

  void _applyHeaders(HttpClientRequest request, String apiKey) {
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set('api-key', apiKey);
  }

  void _release(HttpClient client) {
    if (identical(_httpClient, client)) {
      _httpClient = null;
    } else {
      client.close(force: true);
    }
  }

  Iterable<AgentStreamEvent> _completionEvents(
    Object? completed, {
    required String modelId,
  }) sync* {
    if (completed is! Map) {
      yield const StreamFinishedEvent();
      return;
    }
    final usage = completed['usage'];
    if (usage is Map) {
      yield UsageReportEvent(
        promptTokens: (usage['input_tokens'] as num?)?.toInt(),
        completionTokens: (usage['output_tokens'] as num?)?.toInt(),
        totalTokens: (usage['total_tokens'] as num?)?.toInt(),
      );
      final outputDetails = usage['output_tokens_details'];
      if (outputDetails is Map) {
        final reasoningTokens = (outputDetails['reasoning_tokens'] as num?)
            ?.toInt();
        if (reasoningTokens != null && reasoningTokens > 0) {
          yield ReasoningTokensEvent(reasoningTokens);
        }
      }
    }
    yield StreamFinishedEvent(
      finishReason: completed['status']?.toString(),
      model: completed['model']?.toString() ?? modelId,
    );
  }
}

/// Builds the `/responses` request body. Exposed for testing.
Map<String, dynamic> buildAzureResponsesPayload({
  required String modelId,
  required List<ChatMessage> messages,
  List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  String reasoningEffort = AzureResponsesClient.defaultReasoningEffort,
  String reasoningSummary = AzureResponsesClient.defaultReasoningSummary,
  int? maxOutputTokens = AzureResponsesClient.defaultMaxOutputTokens,
  bool store = true,
  bool stream = false,
}) {
  final normalizedSummary = reasoningSummary.trim().toLowerCase();
  final requestSummary = normalizedSummary.isNotEmpty &&
      normalizedSummary != 'none' &&
      normalizedSummary != 'off';
  return <String, dynamic>{
    'model': modelId,
    'input': serializeAzureResponsesInput(messages),
    if (reasoningEffort.isNotEmpty)
      'reasoning': <String, dynamic>{
        'effort': reasoningEffort,
        if (requestSummary) 'summary': normalizedSummary,
      },
    if (maxOutputTokens != null) 'max_output_tokens': maxOutputTokens,
    'store': store,
    // Without `store`, reasoning items are not retained server-side, so the
    // encrypted payload must be echoed back to keep reasoning continuity
    // across turns of the same run.
    if (!store && requestSummary)
      'include': <String>['reasoning.encrypted_content'],
    if (stream) 'stream': true,
    if (tools.isNotEmpty)
      'tools': <Map<String, dynamic>>[
        for (final tool in tools)
          <String, dynamic>{
            'type': 'function',
            'name': tool.name,
            'description': tool.description,
            'parameters': tool.parameters,
          },
      ],
  };
}

/// Responses API input items. Reasoning models use `developer` in place of
/// `system`; the two are functionally equivalent.
List<Map<String, dynamic>> serializeAzureResponsesInput(
  List<ChatMessage> messages,
) {
  return <Map<String, dynamic>>[
    for (final message in messages)
      <String, dynamic>{
        'type': 'message',
        'role': switch (message.role) {
          ChatRole.system => 'developer',
          ChatRole.user => 'user',
          ChatRole.assistant => 'assistant',
        },
        'content': message.content,
      },
  ];
}

/// Parses a non-streaming `/responses` body into the app's chat result shape.
SarvamChatResult parseAzureResponsesBody(
  String body, {
  required String modelId,
}) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Invalid Azure AI response.');
  }

  final content = StringBuffer();
  final reasoning = StringBuffer();
  final toolCalls = <SarvamToolCall>[];

  final output = decoded['output'];
  if (output is List) {
    for (final item in output) {
      if (item is! Map) {
        continue;
      }
      switch (item['type']?.toString()) {
        case 'message':
          final parts = item['content'];
          if (parts is List) {
            for (final part in parts) {
              if (part is Map && part['type']?.toString() == 'output_text') {
                content.write(part['text']?.toString() ?? '');
              }
            }
          }
        case 'reasoning':
          final summary = item['summary'];
          if (summary is List) {
            for (final part in summary) {
              if (part is Map) {
                reasoning.write(part['text']?.toString() ?? '');
              }
            }
          }
        case 'function_call':
          final call = _functionCallFromItem(item);
          if (call != null) {
            toolCalls.add(call);
          }
      }
    }
  }

  var resolvedContent = content.toString().trim();
  if (resolvedContent.isEmpty) {
    // Older/compact responses also expose a convenience `output_text` field.
    resolvedContent = decoded['output_text']?.toString().trim() ?? '';
  }
  if (resolvedContent.isEmpty && toolCalls.isEmpty) {
    throw const FormatException('Azure AI returned an empty response.');
  }

  final usage = decoded['usage'];
  final reasoningText = reasoning.toString().trim();
  return SarvamChatResult(
    content: resolvedContent,
    model: decoded['model']?.toString() ?? modelId,
    reasoningContent: reasoningText.isEmpty ? null : reasoningText,
    toolCalls: toolCalls,
    finishReason: decoded['status']?.toString(),
    promptTokens: usage is Map ? (usage['input_tokens'] as num?)?.toInt() : null,
    completionTokens: usage is Map
        ? (usage['output_tokens'] as num?)?.toInt()
        : null,
    totalTokens: usage is Map ? (usage['total_tokens'] as num?)?.toInt() : null,
  );
}

SarvamToolCall? _functionCallFromItem(Object? item) {
  if (item is! Map) {
    return null;
  }
  if (item['type']?.toString() != 'function_call') {
    return null;
  }
  final name = item['name']?.toString().trim();
  if (name == null || name.isEmpty) {
    return null;
  }
  final rawArguments = item['arguments']?.toString().trim() ?? '{}';
  Map<String, dynamic> parsedArguments;
  try {
    final decoded = jsonDecode(rawArguments);
    parsedArguments = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
  } catch (_) {
    parsedArguments = <String, dynamic>{};
  }
  return SarvamToolCall(
    id: item['call_id']?.toString() ?? item['id']?.toString() ?? name,
    name: name,
    arguments: parsedArguments,
  );
}

String? _errorMessage(Map<String, dynamic> event) {
  final direct = event['error'];
  if (direct is Map) {
    return direct['message']?.toString();
  }
  final response = event['response'];
  if (response is Map) {
    final error = response['error'];
    if (error is Map) {
      return error['message']?.toString();
    }
    final details = response['incomplete_details'];
    if (details is Map) {
      return 'Response incomplete: ${details['reason']}';
    }
  }
  return null;
}
