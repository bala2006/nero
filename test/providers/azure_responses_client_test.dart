import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/azure_responses_client.dart';
import 'package:nero/features/chat/application/sarvam_api_client.dart';
import 'package:nero/features/chat/domain/chat_message.dart';
import 'package:nero/features/providers/azure_ai_config.dart';

void main() {
  group('buildAzureResponsesPayload', () {
    test('sends the deployment, high reasoning effort, and flat tools', () {
      final payload = buildAzureResponsesPayload(
        modelId: 'gpt-5.6-luna',
        messages: const <ChatMessage>[
          ChatMessage(
            id: 'm1',
            role: ChatRole.system,
            content: 'You are Nero.',
            sentAtEpochMs: 0,
          ),
          ChatMessage(
            id: 'm2',
            role: ChatRole.user,
            content: 'Hi',
            sentAtEpochMs: 1,
          ),
        ],
        tools: const <SarvamToolDefinition>[
          SarvamToolDefinition(
            name: 'search_web',
            description: 'Search the web',
            parameters: <String, dynamic>{'type': 'object'},
          ),
        ],
        stream: true,
      );

      expect(payload['model'], 'gpt-5.6-luna');
      expect(payload['reasoning'], <String, dynamic>{'effort': 'high'});
      expect(payload['max_output_tokens'], AzureAiConfig.maxOutputTokens);
      expect(payload['stream'], isTrue);

      final input = payload['input']! as List<Map<String, dynamic>>;
      expect(input.first['role'], 'developer');
      expect(input.last['role'], 'user');

      final tools = payload['tools']! as List<Map<String, dynamic>>;
      expect(tools.single, <String, dynamic>{
        'type': 'function',
        'name': 'search_web',
        'description': 'Search the web',
        'parameters': <String, dynamic>{'type': 'object'},
      });
    });

    test('defaults to high reasoning effort and omits tools when none given',
        () {
      final payload = buildAzureResponsesPayload(
        modelId: 'gpt-5.6-luna',
        messages: const <ChatMessage>[],
      );

      expect(payload['reasoning'], <String, dynamic>{'effort': 'high'});
      expect(payload.containsKey('tools'), isFalse);
      expect(payload.containsKey('stream'), isFalse);
    });
  });

  group('parseAzureResponsesBody', () {
    test('extracts content, reasoning summary, tool calls, and usage', () {
      final body = jsonEncode(<String, dynamic>{
        'model': 'gpt-5.6-luna',
        'status': 'completed',
        'output': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'reasoning',
            'summary': <Map<String, dynamic>>[
              <String, dynamic>{'text': 'Let me think. '},
            ],
          },
          <String, dynamic>{
            'type': 'message',
            'content': <Map<String, dynamic>>[
              <String, dynamic>{'type': 'output_text', 'text': 'Hello there.'},
            ],
          },
          <String, dynamic>{
            'type': 'function_call',
            'call_id': 'call_1',
            'name': 'search_web',
            'arguments': '{"query":"nero"}',
          },
        ],
        'usage': <String, dynamic>{
          'input_tokens': 10,
          'output_tokens': 5,
          'total_tokens': 15,
        },
      });

      final result = parseAzureResponsesBody(body, modelId: 'gpt-5.6-luna');

      expect(result.content, 'Hello there.');
      expect(result.reasoningContent, 'Let me think.');
      expect(result.model, 'gpt-5.6-luna');
      expect(result.finishReason, 'completed');
      expect(result.promptTokens, 10);
      expect(result.completionTokens, 5);
      expect(result.totalTokens, 15);

      final call = result.toolCalls.single;
      expect(call.id, 'call_1');
      expect(call.name, 'search_web');
      expect(call.arguments, <String, dynamic>{'query': 'nero'});
    });

    test('throws when the response carries no content and no tool calls', () {
      expect(
        () => parseAzureResponsesBody(
          jsonEncode(<String, dynamic>{'output': <Object>[]}),
          modelId: 'gpt-5.6-luna',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
