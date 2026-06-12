import 'dart:convert';
import 'dart:io';

import '../domain/chat_message.dart';

class _SarvamRequestProfile {
  const _SarvamRequestProfile({
    required this.temperature,
    required this.maxTokens,
    this.reasoningEffort,
    this.frequencyPenalty,
    this.presencePenalty,
  });

  final double temperature;
  final int maxTokens;
  final String? reasoningEffort;
  final double? frequencyPenalty;
  final double? presencePenalty;
}

class SarvamChatResult {
  const SarvamChatResult({
    required this.content,
    required this.model,
    this.reasoningContent,
    this.toolCalls = const <SarvamToolCall>[],
    this.finishReason,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
  });

  final String content;
  final String model;
  final String? reasoningContent;
  final List<SarvamToolCall> toolCalls;
  final String? finishReason;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;

  SarvamChatResult copyWith({
    String? content,
    String? model,
    String? reasoningContent,
    bool clearReasoningContent = false,
    List<SarvamToolCall>? toolCalls,
    String? finishReason,
    bool clearFinishReason = false,
    int? promptTokens,
    int? completionTokens,
    int? totalTokens,
  }) {
    return SarvamChatResult(
      content: content ?? this.content,
      model: model ?? this.model,
      reasoningContent: clearReasoningContent
          ? null
          : (reasoningContent ?? this.reasoningContent),
      toolCalls: toolCalls ?? this.toolCalls,
      finishReason: clearFinishReason
          ? null
          : (finishReason ?? this.finishReason),
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      totalTokens: totalTokens ?? this.totalTokens,
    );
  }
}

class SarvamToolDefinition {
  const SarvamToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;
}

class SarvamToolCall {
  const SarvamToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final Map<String, dynamic> arguments;
}

class InlineToolExtractionResult {
  const InlineToolExtractionResult({
    required this.content,
    required this.toolCalls,
  });

  final String content;
  final List<SarvamToolCall> toolCalls;
}

abstract class ChatCompletionClient {
  Future<SarvamChatResult> completeChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  });

  void cancel();
}

class SarvamApiClient implements ChatCompletionClient {
  SarvamApiClient({HttpClient? httpClient}) : _httpClient = httpClient;

  HttpClient? _httpClient;
  bool _cancelled = false;

  static const Map<String, _SarvamRequestProfile> _profiles =
      <String, _SarvamRequestProfile>{
    'sarvam-105b': _SarvamRequestProfile(
      temperature: 0.2,
      maxTokens: 2048,
      reasoningEffort: 'high',
      frequencyPenalty: 0.15,
      presencePenalty: 0.0,
    ),
    'sarvam-30b': _SarvamRequestProfile(
      temperature: 0.2,
      maxTokens: 1536,
      reasoningEffort: 'high',
      frequencyPenalty: 0.1,
      presencePenalty: 0.0,
    ),
    'sarvam-m': _SarvamRequestProfile(
      temperature: 0.2,
      maxTokens: 1024,
      reasoningEffort: 'high',
      frequencyPenalty: 0.05,
      presencePenalty: 0.0,
    ),
  };

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
    return completeChatLegacy(
      client: client,
      apiKey: apiKey,
      modelId: modelId,
      messages: messages,
      tools: tools,
    );
  }

  Future<SarvamChatResult> completeChatLegacy({
    required HttpClient client,
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  }) async {
    final profile = _profiles[modelId] ?? _profiles['sarvam-105b']!;

    try {
      final request = await client.postUrl(
        Uri.parse('https://api.sarvam.ai/v1/chat/completions'),
      );
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('api-subscription-key', apiKey);
      request.add(
        utf8.encode(
          jsonEncode(
            <String, dynamic>{
              'model': modelId,
              'messages': serializeMessages(messages),
              'temperature': profile.temperature,
              'max_tokens': profile.maxTokens,
              if (profile.reasoningEffort != null)
                'reasoning_effort': profile.reasoningEffort,
              if (profile.frequencyPenalty != null)
                'frequency_penalty': profile.frequencyPenalty,
              if (profile.presencePenalty != null)
                'presence_penalty': profile.presencePenalty,
              if (tools.isNotEmpty)
                'tools': [
                  for (final tool in tools)
                    <String, dynamic>{
                      'type': 'function',
                      'function': <String, dynamic>{
                        'name': tool.name,
                        'description': tool.description,
                        'parameters': tool.parameters,
                      },
                    },
                ],
            },
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
          'Sarvam API request failed (${response.statusCode}): $body',
        );
      }

      return parseChatResponse(body, modelId: modelId);
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
  }

}

Map<String, dynamic> buildSarvamChatPayload({
  required String modelId,
  required List<ChatMessage> messages,
  List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  bool stream = false,
}) {
  final profile = SarvamApiClient._profiles[modelId] ??
      SarvamApiClient._profiles['sarvam-105b']!;
  return <String, dynamic>{
    'model': modelId,
    'messages': serializeMessages(messages),
    'temperature': profile.temperature,
    'max_tokens': profile.maxTokens,
    if (profile.reasoningEffort != null)
      'reasoning_effort': profile.reasoningEffort,
    if (profile.frequencyPenalty != null)
      'frequency_penalty': profile.frequencyPenalty,
    if (profile.presencePenalty != null)
      'presence_penalty': profile.presencePenalty,
    if (stream) 'stream': true,
    if (tools.isNotEmpty)
      'tools': [
        for (final tool in tools)
          <String, dynamic>{
            'type': 'function',
            'function': <String, dynamic>{
              'name': tool.name,
              'description': tool.description,
              'parameters': tool.parameters,
            },
          },
      ],
  };
}

List<Map<String, String>> serializeMessages(List<ChatMessage> messages) {
  return <Map<String, String>>[
    for (final message in messages)
      <String, String>{
        'role': switch (message.role) {
          ChatRole.user => 'user',
          ChatRole.assistant => 'assistant',
          ChatRole.system => 'system',
        },
        'content': message.content,
      },
  ];
}

SarvamChatResult parseChatResponse(String body, {required String modelId}) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Invalid Sarvam API response.');
  }

  final choices = decoded['choices'];
  if (choices is! List || choices.isEmpty) {
    throw const FormatException('Sarvam API returned no choices.');
  }

  final firstChoice = choices.first;
  if (firstChoice is! Map) {
    throw const FormatException('Sarvam API returned malformed choices.');
  }

  final message = firstChoice['message'];
  if (message is! Map) {
    throw const FormatException('Sarvam API returned no message.');
  }

  final content = message['content']?.toString().trim() ?? '';
  final reasoningContent = message['reasoning_content']?.toString().trim();
  final toolCalls = parseToolCalls(message['tool_calls']);
  if (content.isEmpty && toolCalls.isEmpty) {
    throw const FormatException('Sarvam API returned an empty response.');
  }

  final usage = decoded['usage'];
  return SarvamChatResult(
    content: content,
    model: decoded['model']?.toString() ?? modelId,
    reasoningContent: reasoningContent?.isEmpty ?? true ? null : reasoningContent,
    toolCalls: toolCalls,
    finishReason: firstChoice['finish_reason']?.toString(),
    promptTokens: usage is Map ? (usage['prompt_tokens'] as num?)?.toInt() : null,
    completionTokens: usage is Map
        ? (usage['completion_tokens'] as num?)?.toInt()
        : null,
    totalTokens: usage is Map ? (usage['total_tokens'] as num?)?.toInt() : null,
  );
}

List<SarvamToolCall> parseToolCalls(Object? rawToolCalls) {
  if (rawToolCalls is! List) {
    return const <SarvamToolCall>[];
  }

  final toolCalls = <SarvamToolCall>[];
  for (final item in rawToolCalls) {
    if (item is! Map) {
      continue;
    }
    final function = item['function'];
    if (function is! Map) {
      continue;
    }
    final name = function['name']?.toString().trim();
    if (name == null || name.isEmpty) {
      continue;
    }
    final rawArguments = function['arguments']?.toString().trim() ?? '{}';
    Map<String, dynamic> parsedArguments;
    try {
      final decoded = jsonDecode(rawArguments);
      parsedArguments = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
    } catch (_) {
      parsedArguments = <String, dynamic>{};
    }
    toolCalls.add(
      SarvamToolCall(
        id: item['id']?.toString() ?? name,
        name: name,
        arguments: parsedArguments,
      ),
    );
  }
  return toolCalls;
}
