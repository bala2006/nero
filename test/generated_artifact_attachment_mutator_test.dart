import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/generated_artifact_attachment_mutator.dart';
import 'package:nero/features/chat/domain/chat_message.dart';

void main() {
  const mutator = GeneratedArtifactAttachmentMutator();

  test('attachArtifact appends a generated artifact to a message', () {
    const message = ChatMessage(
      id: 'assistant_1',
      role: ChatRole.assistant,
      content: 'Done',
    );
    const artifact = GeneratedArtifactReference(
      id: 'artifact_1',
      title: 'Report.docx',
      kindLabel: 'Document',
      extension: 'docx',
    );

    final updated = mutator.attachArtifact(message, artifact);

    expect(updated.generatedArtifacts, hasLength(1));
    expect(updated.generatedArtifacts.single.id, 'artifact_1');
  });

  test('attachArtifact replaces an existing duplicate artifact', () {
    const message = ChatMessage(
      id: 'assistant_1',
      role: ChatRole.assistant,
      content: 'Done',
      generatedArtifacts: <GeneratedArtifactReference>[
        GeneratedArtifactReference(
          id: 'artifact_1',
          title: 'Old.docx',
          kindLabel: 'Document',
          extension: 'docx',
        ),
      ],
    );
    const replacement = GeneratedArtifactReference(
      id: 'artifact_1',
      title: 'Updated.docx',
      kindLabel: 'Document',
      extension: 'docx',
    );

    final updated = mutator.attachArtifact(message, replacement);

    expect(updated.generatedArtifacts, hasLength(1));
    expect(updated.generatedArtifacts.single.title, 'Updated.docx');
  });
}
