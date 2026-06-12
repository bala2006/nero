import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/response/response.dart';

void main() {
  test('builder collapses and truncates summary text but preserves full content', () {
    const builder = ResponseEnvelopeBuilder();

    final longContent = List<String>.generate(
      100,
      (index) => 'Line $index: This is a longer sentence to inflate the content.',
    ).join('\n');

    final envelope = builder.buildFromFinalContent(finalContent: longContent);

    expect(envelope.summaryText.length, lessThanOrEqualTo(320));
    expect(envelope.summaryText.contains('\n'), isFalse);
    expect(envelope.blocks.whereType<ResponseMarkdownBlock>().single.content, longContent);
  });
}

