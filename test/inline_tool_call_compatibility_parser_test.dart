import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/inline_tool_call_compatibility_parser.dart';

void main() {
  test('extracts inline tool calls and strips compatibility markup', () {
    const parser = InlineToolCallCompatibilityParser();

    final result = parser.extract(
      'I will create it.\n'
      '<tool_call>generate_docx\n'
      '<arg_key>title</arg_key>\n'
      '<arg_value>Capabilities</arg_value>\n'
      '<arg_key>markdown_content</arg_key>\n'
      '<arg_value># Capabilities</arg_value>\n',
    );

    expect(result.toolCalls, hasLength(1));
    expect(result.toolCalls.single.name, 'generate_docx');
    expect(result.toolCalls.single.arguments['title'], 'Capabilities');
    expect(result.content, 'I will create it.');
  });

  test('returns original trimmed content when no compatibility markup exists', () {
    const parser = InlineToolCallCompatibilityParser();

    final result = parser.extract(' Hello world. ');

    expect(result.toolCalls, isEmpty);
    expect(result.content, 'Hello world.');
  });
}
