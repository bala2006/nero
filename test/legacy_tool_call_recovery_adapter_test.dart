import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/legacy_tool_call_recovery_adapter.dart';
import 'package:nero/features/chat/application/sarvam_api_client.dart';

void main() {
  const adapter = LegacyToolCallRecoveryAdapter();

  test('parseChatResponse leaves inline compatibility markup as plain content', () {
    final result = parseChatResponse(
      '''
{
  "model": "sarvam-105b",
  "choices": [
    {
      "message": {
        "content": "I will create it.\\n<tool_call>generate_docx\\n<arg_key>title</arg_key>\\n<arg_value>Capabilities</arg_value>\\n<arg_key>markdown_content</arg_key>\\n<arg_value># Capabilities</arg_value>"
      }
    }
  ]
}
''',
      modelId: 'sarvam-105b',
    );

    expect(result.toolCalls, isEmpty);
    expect(result.content, contains('<tool_call>generate_docx'));
  });

  test('recoverResult promotes allowed inline compatibility tool call', () {
    const result = SarvamChatResult(
      content:
          'I will create it.\n'
          '<tool_call>generate_docx\n'
          '<arg_key>title</arg_key>\n'
          '<arg_value>Capabilities</arg_value>\n'
          '<arg_key>markdown_content</arg_key>\n'
          '<arg_value># Capabilities</arg_value>\n',
      model: 'sarvam-105b',
    );

    final recovered = adapter.recoverResult(
      result: result,
      content: result.content,
      allowedToolNames: const <String>{'generate_docx'},
      requiredToolArguments: const <String, Set<String>>{
        'generate_docx': <String>{'title', 'markdown_content'},
      },
    );

    expect(recovered.toolCalls, hasLength(1));
    expect(recovered.toolCalls.single.name, 'generate_docx');
    expect(recovered.content, 'I will create it.');
    expect(recovered.finishReason, 'tool_calls');
  });

  test('recoverWithStats reports compatibility recovery usage', () {
    const result = SarvamChatResult(
      content:
          'I will create it.\n'
          '<tool_call>generate_docx\n'
          '<arg_key>title</arg_key>\n'
          '<arg_value>Capabilities</arg_value>\n'
          '<arg_key>markdown_content</arg_key>\n'
          '<arg_value># Capabilities</arg_value>\n',
      model: 'sarvam-105b',
    );

    final recovered = adapter.recoverWithStats(
      result: result,
      content: result.content,
      allowedToolNames: const <String>{'generate_docx'},
      requiredToolArguments: const <String, Set<String>>{
        'generate_docx': <String>{'title', 'markdown_content'},
      },
    );

    expect(recovered.stats.usedCompatibilityRecovery, isTrue);
    expect(recovered.stats.recoveredToolCallCount, 1);
    expect(recovered.stats.strippedCompatibilityMarkup, isTrue);
  });

  test('recoverResult strips compatibility markup even when tool is not allowed', () {
    const result = SarvamChatResult(
      content:
          'Before.\n'
          '<tool_call>generate_docx\n'
          '<arg_key>title</arg_key>\n'
          '<arg_value>Capabilities</arg_value>\n',
      model: 'sarvam-105b',
    );

    final recovered = adapter.recoverResult(
      result: result,
      content: result.content,
      allowedToolNames: const <String>{'search_web'},
      requiredToolArguments: const <String, Set<String>>{},
    );

    expect(recovered.toolCalls, isEmpty);
    expect(recovered.content, 'Before.');
  });

  test('recoverResult strips compatibility markup but does not promote long mixed prose', () {
    const result = SarvamChatResult(
      content:
          'I will create the document after explaining the full plan and detailed structure first.\n'
          '<tool_call>generate_docx\n'
          '<arg_key>title</arg_key>\n'
          '<arg_value>Capabilities</arg_value>\n'
          '<arg_key>markdown_content</arg_key>\n'
          '<arg_value># Capabilities</arg_value>\n',
      model: 'sarvam-105b',
    );

    final recovered = adapter.recoverResult(
      result: result,
      content: result.content,
      allowedToolNames: const <String>{'generate_docx'},
      requiredToolArguments: const <String, Set<String>>{
        'generate_docx': <String>{'title', 'markdown_content'},
      },
    );

    expect(recovered.toolCalls, isEmpty);
    expect(recovered.content, contains('I will create the document'));
  });
}
