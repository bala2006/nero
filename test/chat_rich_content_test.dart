import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nero/features/chat/presentation/chat_rich_content.dart';

void main() {
  testWidgets('renders inline DOCX blocks as downloadable artifacts', (
    tester,
  ) async {
    String? tappedTitle;
    String? tappedMarkdown;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatRichContent(
            data:
                '[[NERO_BLOCK:DOCX title="Test Doc" markdown_content="# Hello World"]]',
            onDownloadArtifact: (title, markdownContent) async {
              tappedTitle = title;
              tappedMarkdown = markdownContent;
            },
          ),
        ),
      ),
    );

    expect(find.text('Test Doc'), findsOneWidget);
    expect(find.text('DOCX document'), findsOneWidget);
    expect(find.textContaining('NERO_BLOCK:DOCX'), findsNothing);

    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();

    expect(tappedTitle, 'Test Doc');
    expect(tappedMarkdown, '# Hello World');
  });
}
