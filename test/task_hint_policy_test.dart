import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/task_hint_policy.dart';

void main() {
  const policy = TaskHintPolicy();

  test('buildHint emits code and markdown hints for coding prompts', () {
    final hint = policy.buildHint('write a dart function with markdown summary');

    expect(hint, isNotNull);
    expect(hint, contains('[[NERO_BLOCK:CODE lang=<language>]]'));
    expect(hint, contains('Use concise Markdown formatting'));
  });

  test('buildHint emits artifact tool hint for docx request', () {
    final hint = policy.buildHint('create a docx about capabilities');

    expect(hint, isNotNull);
    expect(hint, contains('Call the generate_docx tool'));
  });

  test('buildHint emits workspace and zip hints for project bundle requests', () {
    final hint = policy.buildHint(
      'build a starter project with multiple files and zip archive',
    );

    expect(hint, isNotNull);
    expect(hint, contains('Call the write_project_files tool'));
    expect(hint, contains('call the package_zip tool'));
  });

  test('buildHint returns null when no structured hint applies', () {
    expect(policy.buildHint('hello there'), isNull);
  });
}
