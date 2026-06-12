import '../domain/doc_models.dart';

class DocBlockParser {
  const DocBlockParser();

  List<DocBlock> parseMarkdown(String markdown) {
    final lines = markdown
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final blocks = <DocBlock>[];
    final paragraph = <String>[];
    final bullets = <String>[];
    final numbers = <String>[];
    final tableRows = <List<String>>[];

    void flushParagraph() {
      final text = paragraph.join(' ').trim();
      if (text.isNotEmpty) {
        blocks.add(ParagraphBlock(text: text));
      }
      paragraph.clear();
    }

    void flushBullets() {
      if (bullets.isNotEmpty) {
        blocks.add(BulletListBlock(items: List<String>.of(bullets)));
      }
      bullets.clear();
    }

    void flushNumbers() {
      if (numbers.isNotEmpty) {
        blocks.add(NumberedListBlock(items: List<String>.of(numbers)));
      }
      numbers.clear();
    }

    void flushTable() {
      if (tableRows.isNotEmpty) {
        final rows = tableRows
            .where((row) => !_isMarkdownDividerRow(row))
            .toList(growable: false);
        if (rows.isNotEmpty) {
          blocks.add(
            TableBlock(
              columnCount: rows
                  .map((row) => row.length)
                  .reduce((a, b) => a > b ? a : b),
              rows: rows,
            ),
          );
        }
      }
      tableRows.clear();
    }

    void flushListsAndTable() {
      flushBullets();
      flushNumbers();
      flushTable();
    }

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        flushParagraph();
        flushListsAndTable();
        continue;
      }

      final heading = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(trimmed);
      if (heading != null) {
        flushParagraph();
        flushListsAndTable();
        blocks.add(
          HeadingBlock(
            level: heading.group(1)!.length.clamp(1, 3),
            text: heading.group(2)!.trim(),
          ),
        );
        continue;
      }

      if (_looksLikeMarkdownTableRow(trimmed)) {
        flushParagraph();
        flushBullets();
        flushNumbers();
        tableRows.add(_parseMarkdownTableRow(trimmed));
        continue;
      }

      final bullet = RegExp(r'^[-*]\s+(.+)$').firstMatch(trimmed);
      if (bullet != null) {
        flushParagraph();
        flushNumbers();
        flushTable();
        bullets.add(bullet.group(1)!.trim());
        continue;
      }

      final number = RegExp(r'^\d+[.)]\s+(.+)$').firstMatch(trimmed);
      if (number != null) {
        flushParagraph();
        flushBullets();
        flushTable();
        numbers.add(number.group(1)!.trim());
        continue;
      }

      flushListsAndTable();
      paragraph.add(trimmed);
    }

    flushParagraph();
    flushListsAndTable();
    if (blocks.isEmpty) {
      return [ParagraphBlock(text: markdown.trim())];
    }
    return blocks;
  }

  bool _looksLikeMarkdownTableRow(String line) {
    return line.startsWith('|') &&
        line.endsWith('|') &&
        line.indexOf('|', 1) != -1;
  }

  List<String> _parseMarkdownTableRow(String line) {
    final trimmed = line.substring(1, line.length - 1);
    return trimmed
        .split('|')
        .map((cell) => cell.trim())
        .toList(growable: false);
  }

  bool _isMarkdownDividerRow(List<String> row) {
    return row.isNotEmpty &&
        row.every((cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell.trim()));
  }
}
