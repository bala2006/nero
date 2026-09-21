import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/generated_artifact_merger.dart';
import 'package:nero/features/chat/domain/chat_message.dart';

void main() {
  const merger = GeneratedArtifactMerger();

  test('merge appends a new artifact when no duplicate exists', () {
    const existing = <GeneratedArtifactReference>[
      GeneratedArtifactReference(
        id: 'a1',
        title: 'Old.docx',
        kindLabel: 'Document',
        extension: 'docx',
      ),
    ];
    const incoming = GeneratedArtifactReference(
      id: 'a2',
      title: 'New.pdf',
      kindLabel: 'PDF',
      extension: 'pdf',
    );

    final merged = merger.merge(existing: existing, incoming: incoming);

    expect(merged, hasLength(2));
    expect(merged.last.id, 'a2');
  });

  test('merge replaces an artifact with the same id', () {
    const existing = <GeneratedArtifactReference>[
      GeneratedArtifactReference(
        id: 'a1',
        title: 'Old.docx',
        kindLabel: 'Document',
        extension: 'docx',
      ),
    ];
    const incoming = GeneratedArtifactReference(
      id: 'a1',
      title: 'Updated.docx',
      kindLabel: 'Document',
      extension: 'docx',
    );

    final merged = merger.merge(existing: existing, incoming: incoming);

    expect(merged, hasLength(1));
    expect(merged.single.title, 'Updated.docx');
  });

  test('merge replaces an artifact with the same local path and title', () {
    const existing = <GeneratedArtifactReference>[
      GeneratedArtifactReference(
        id: 'a1',
        title: 'Report.pdf',
        kindLabel: 'PDF',
        extension: 'pdf',
        localPath: 'C:\\temp\\report.pdf',
      ),
    ];
    const incoming = GeneratedArtifactReference(
      id: 'a2',
      title: 'Report.pdf',
      kindLabel: 'PDF',
      extension: 'pdf',
      localPath: 'C:\\temp\\report.pdf',
    );

    final merged = merger.merge(existing: existing, incoming: incoming);

    expect(merged, hasLength(1));
    expect(merged.single.id, 'a2');
  });
}
