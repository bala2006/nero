sealed class DocBlock {
  const DocBlock();
}

class HeadingBlock extends DocBlock {
  const HeadingBlock({
    required this.level,
    required this.text,
  });

  final int level;
  final String text;
}

class ParagraphBlock extends DocBlock {
  const ParagraphBlock({required this.text});

  final String text;
}

class BulletListBlock extends DocBlock {
  const BulletListBlock({required this.items});

  final List<String> items;
}

class NumberedListBlock extends DocBlock {
  const NumberedListBlock({required this.items});

  final List<String> items;
}

class TableBlock extends DocBlock {
  const TableBlock({
    required this.columnCount,
    required this.rows,
  });

  final int columnCount;
  final List<List<String>> rows;
}

class PageSettings {
  const PageSettings({
    this.marginTop = 72.0,
    this.marginBottom = 72.0,
    this.marginLeft = 72.0,
    this.marginRight = 72.0,
    this.orientation = 'portrait',
    this.paperSize = 'a4',
  });

  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;
  final String orientation;
  final String paperSize;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'marginTop': marginTop,
        'marginBottom': marginBottom,
        'marginLeft': marginLeft,
        'marginRight': marginRight,
        'orientation': orientation,
        'paperSize': paperSize,
      };
}

class DocRequest {
  const DocRequest({
    required this.title,
    required this.blocks,
    this.pageSettings,
    this.headerText,
    this.footerText,
  });

  final String title;
  final List<DocBlock> blocks;
  final PageSettings? pageSettings;
  final String? headerText;
  final String? footerText;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'blocks': blocks.map((b) => _blockToJson(b)).toList(growable: false),
        'pageSettings': pageSettings?.toJson(),
        'headerText': headerText,
        'footerText': footerText,
      };

  Map<String, dynamic> _blockToJson(DocBlock block) {
    return switch (block) {
      HeadingBlock() => <String, dynamic>{
          'type': 'heading',
          'level': block.level,
          'text': block.text,
        },
      ParagraphBlock() => <String, dynamic>{
          'type': 'paragraph',
          'text': block.text,
        },
      BulletListBlock() => <String, dynamic>{
          'type': 'bulletList',
          'items': block.items,
        },
      NumberedListBlock() => <String, dynamic>{
          'type': 'numberedList',
          'items': block.items,
        },
      TableBlock() => <String, dynamic>{
          'type': 'table',
          'columnCount': block.columnCount,
          'rows': block.rows,
        },
    };
  }
}
