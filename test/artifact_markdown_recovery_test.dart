import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/docs/application/artifact_markdown_recovery.dart';

void main() {
  const recovery = ArtifactMarkdownRecovery();

  test('sanitizeMarkdown rejects planning prose', () {
    final sanitized = recovery.sanitizeMarkdown(
      'We need to call generate_docx with title and markdown_content.',
    );

    expect(sanitized, isNull);
  });

  test('sanitizeMarkdown strips legacy markers and tool wrappers', () {
    final sanitized = recovery.sanitizeMarkdown(
      '[[NERO_BLOCK:TABLE]]\n| A | B |\n| --- | --- |\n| 1 | 2 |\n[[/NERO_BLOCK]]',
    );

    expect(sanitized, '| A | B |\n| --- | --- |\n| 1 | 2 |');
  });

  test('resolveTitle falls back from prompt-like titles to markdown heading', () {
    final title = recovery.resolveTitle(
      proposedTitle: 'Generate a doc about your capabilities',
      prompt: 'Generate a doc about your capabilities',
      markdownContent: '# Nero Capabilities\n\nOverview',
    );

    expect(title, 'Nero Capabilities');
  });

  test('sanitizeMarkdown rejects raw tool markers', () {
    final sanitized = recovery.sanitizeMarkdown(
      '<tool_call><arg_key>title</arg_key></tool_call>',
    );

    expect(sanitized, isNull);
  });

  test('sanitizeMarkdown extracts embedded markdown_content from code-like output', () {
    final sanitized = recovery.sanitizeMarkdown(
      '''
```python
result = generate_docx(
  title="Capabilities",
  markdown_content="""# My Capabilities

## Core Features
- Answer questions
- Generate files
"""
)
```
''',
    );

    expect(
      sanitized,
      '# My Capabilities\n\n## Core Features\n- Answer questions\n- Generate files',
    );
  });
}
