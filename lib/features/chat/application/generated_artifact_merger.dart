import '../domain/chat_message.dart';

class GeneratedArtifactMerger {
  const GeneratedArtifactMerger();

  List<GeneratedArtifactReference> merge({
    required List<GeneratedArtifactReference> existing,
    required GeneratedArtifactReference incoming,
  }) {
    return List<GeneratedArtifactReference>.unmodifiable(<GeneratedArtifactReference>[
      for (final artifact in existing)
        if (!_sameArtifactReference(artifact, incoming)) artifact,
      incoming,
    ]);
  }

  bool sameReference(
    GeneratedArtifactReference a,
    GeneratedArtifactReference b,
  ) {
    return _sameArtifactReference(a, b);
  }

  bool _sameArtifactReference(
    GeneratedArtifactReference a,
    GeneratedArtifactReference b,
  ) {
    if (a.id == b.id) {
      return true;
    }
    if (a.localPath != null &&
        b.localPath != null &&
        a.localPath == b.localPath &&
        a.title == b.title) {
      return true;
    }
    if (a.sourceUri != null &&
        b.sourceUri != null &&
        a.sourceUri == b.sourceUri &&
        a.title == b.title) {
      return true;
    }
    return false;
  }
}
