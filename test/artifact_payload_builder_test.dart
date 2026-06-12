import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/docs/application/artifact_payload_builder.dart';

void main() {
  const builder = ArtifactPayloadBuilder();

  test('prepareMarkdownPayload uses sanitized markdown when available', () async {
    final payload = await builder.prepareMarkdownPayload(
      proposedTitle: 'Generate a doc about your capabilities',
      rawMarkdownContent:
          '[[NERO_BLOCK:TABLE]]\n# Nero Capabilities\n\n- Search\n[[/NERO_BLOCK]]',
      activeRequestPrompt: 'Generate a doc about your capabilities',
      latestUserPrompt: null,
    );

    expect(payload, isNotNull);
    expect(payload!.title, 'Nero Capabilities');
    expect(payload.markdownContent, '# Nero Capabilities\n\n- Search');
  });

  test('prepareMarkdownPayload rejects unusable raw content', () async {
    final payload = await builder.prepareMarkdownPayload(
      proposedTitle: 'Generate a pdf about capabilities',
      rawMarkdownContent:
          'We need to call generate_report_pdf with title and markdown_content.',
      activeRequestPrompt: 'Generate a pdf about capabilities',
      latestUserPrompt: null,
    );

    expect(payload, isNull);
  });

  test('prepareMarkdownPayload returns null when raw content is unusable', () async {
    final payload = await builder.prepareMarkdownPayload(
      proposedTitle: 'Generate a doc about capabilities',
      rawMarkdownContent:
          'We need to call generate_docx with title and markdown_content.',
      activeRequestPrompt: null,
      latestUserPrompt: null,
    );

    expect(payload, isNull);
  });
}
