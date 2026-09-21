import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/docs/application/doc_block_parser.dart';
import 'package:nero/features/docs/domain/doc_models.dart';

void main() {
  const parser = DocBlockParser();

  test('parses headings and folds adjacent paragraph lines', () {
    final blocks = parser.parseMarkdown('''
# Title
This is line one
and this is line two.

#### Deep Heading
Final paragraph.
''');

    expect(blocks, hasLength(4));
    expectHeading(blocks[0], level: 1, text: 'Title');
    expectParagraph(blocks[1], 'This is line one and this is line two.');
    expectHeading(blocks[2], level: 3, text: 'Deep Heading');
    expectParagraph(blocks[3], 'Final paragraph.');
  });

  test('groups bullet and numbered lists independently', () {
    final blocks = parser.parseMarkdown('''
- Alpha
* Beta

1. First
2) Second
''');

    expect(blocks, hasLength(2));
    expectBulletList(blocks[0], ['Alpha', 'Beta']);
    expectNumberedList(blocks[1], ['First', 'Second']);
  });

  test('parses markdown tables and removes divider rows', () {
    final blocks = parser.parseMarkdown('''
| Name | Capability |
| --- | :---: |
| Nero | DOCX |
| Sarvam | Chat |
''');

    expect(blocks, hasLength(1));
    expectTable(
      blocks.single,
      columnCount: 2,
      rows: [
        ['Name', 'Capability'],
        ['Nero', 'DOCX'],
        ['Sarvam', 'Chat'],
      ],
    );
  });

  test('flushes active structures when block types change', () {
    final blocks = parser.parseMarkdown('''
Intro
- Bullet
| Key | Value |
| --- | --- |
| A | B |
1. Number
Outro
''');

    expect(blocks, hasLength(5));
    expectParagraph(blocks[0], 'Intro');
    expectBulletList(blocks[1], ['Bullet']);
    expectTable(
      blocks[2],
      columnCount: 2,
      rows: [
        ['Key', 'Value'],
        ['A', 'B'],
      ],
    );
    expectNumberedList(blocks[3], ['Number']);
    expectParagraph(blocks[4], 'Outro');
  });

  test('returns blank paragraph for empty markdown', () {
    final blocks = parser.parseMarkdown('  \r\n  ');

    expect(blocks, hasLength(1));
    expectParagraph(blocks.single, '');
  });
}

void expectHeading(DocBlock block, {required int level, required String text}) {
  expect(block, isA<HeadingBlock>());
  final heading = block as HeadingBlock;
  expect(heading.level, level);
  expect(heading.text, text);
}

void expectParagraph(DocBlock block, String text) {
  expect(block, isA<ParagraphBlock>());
  expect((block as ParagraphBlock).text, text);
}

void expectBulletList(DocBlock block, List<String> items) {
  expect(block, isA<BulletListBlock>());
  expect((block as BulletListBlock).items, items);
}

void expectNumberedList(DocBlock block, List<String> items) {
  expect(block, isA<NumberedListBlock>());
  expect((block as NumberedListBlock).items, items);
}

void expectTable(
  DocBlock block, {
  required int columnCount,
  required List<List<String>> rows,
}) {
  expect(block, isA<TableBlock>());
  final table = block as TableBlock;
  expect(table.columnCount, columnCount);
  expect(table.rows, rows);
}
