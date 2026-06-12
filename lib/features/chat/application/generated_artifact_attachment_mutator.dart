import '../domain/chat_message.dart';
import 'generated_artifact_merger.dart';

class GeneratedArtifactAttachmentMutator {
  const GeneratedArtifactAttachmentMutator({
    GeneratedArtifactMerger? merger,
  }) : _merger = merger ?? const GeneratedArtifactMerger();

  final GeneratedArtifactMerger _merger;

  ChatMessage attachArtifact(
    ChatMessage message,
    GeneratedArtifactReference artifact,
  ) {
    return message.copyWith(
      generatedArtifacts: _merger.merge(
        existing: message.generatedArtifacts,
        incoming: artifact,
      ),
    );
  }
}
