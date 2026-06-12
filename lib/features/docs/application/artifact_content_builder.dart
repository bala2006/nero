import '../domain/doc_models.dart';
import 'artifact_payload_builder.dart';
import 'doc_block_parser.dart';

class PreparedArtifactContent {
  const PreparedArtifactContent({
    required this.title,
    required this.markdownContent,
    required this.blocks,
  });

  final String title;
  final String markdownContent;
  final List<DocBlock> blocks;

  DocRequest toDocRequest({
    PageSettings? pageSettings,
    String? footerText,
    String? headerText,
  }) {
    return DocRequest(
      title: title,
      blocks: blocks,
      pageSettings: pageSettings,
      headerText: headerText,
      footerText: footerText,
    );
  }
}

class ArtifactContentBuilder {
  const ArtifactContentBuilder({
    ArtifactPayloadBuilder? payloadBuilder,
    DocBlockParser? docBlockParser,
  }) : _payloadBuilder = payloadBuilder ?? const ArtifactPayloadBuilder(),
       _docBlockParser = docBlockParser ?? const DocBlockParser();

  final ArtifactPayloadBuilder _payloadBuilder;
  final DocBlockParser _docBlockParser;

  Future<PreparedArtifactContent?> prepareDocumentContent({
    required String proposedTitle,
    required String rawMarkdownContent,
    required String? activeRequestPrompt,
    required String? latestUserPrompt,
  }) async {
    final payload = await _payloadBuilder.prepareMarkdownPayload(
      proposedTitle: proposedTitle,
      rawMarkdownContent: rawMarkdownContent,
      activeRequestPrompt: activeRequestPrompt,
      latestUserPrompt: latestUserPrompt,
    );
    if (payload == null) {
      return null;
    }
    return PreparedArtifactContent(
      title: payload.title,
      markdownContent: payload.markdownContent,
      blocks: _docBlockParser.parseMarkdown(payload.markdownContent),
    );
  }
}
