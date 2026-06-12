import 'artifact_markdown_recovery.dart';

class ArtifactPayload {
  const ArtifactPayload({
    required this.title,
    required this.markdownContent,
  });

  final String title;
  final String markdownContent;
}

class ArtifactPayloadBuilder {
  const ArtifactPayloadBuilder({
    ArtifactMarkdownRecovery? markdownRecovery,
  }) : _markdownRecovery = markdownRecovery ?? const ArtifactMarkdownRecovery();

  final ArtifactMarkdownRecovery _markdownRecovery;

  Future<ArtifactPayload?> prepareMarkdownPayload({
    required String proposedTitle,
    required String rawMarkdownContent,
    required String? activeRequestPrompt,
    required String? latestUserPrompt,
  }) async {
    final sanitized = _markdownRecovery.sanitizeMarkdown(rawMarkdownContent);
    final prompt = activeRequestPrompt ?? latestUserPrompt ?? proposedTitle;
    if (sanitized != null && sanitized.trim().isNotEmpty) {
      final markdown = sanitized.trim();
      return ArtifactPayload(
        title: _markdownRecovery.resolveTitle(
          proposedTitle: proposedTitle,
          prompt: prompt,
          markdownContent: markdown,
        ),
        markdownContent: markdown,
      );
    }
    return null;
  }
}
