import 'package:nero/features/chat/domain/chat_message.dart';

import '../domain/response_envelope.dart';

class ResponseEnvelopeBuilder {
  const ResponseEnvelopeBuilder();

  ResponseEnvelope buildFromFinalContent({
    required String finalContent,
    Iterable<GeneratedArtifactReference> artifacts = const <GeneratedArtifactReference>[],
    Iterable<ActivityTrace> activities = const <ActivityTrace>[],
    RunSummary? runSummary,
    ResponseQuality quality = const ResponseQuality(),
    Map<String, Object?> metadata = const <String, Object?>{},
    String? runId,
    String? conversationId,
    String? modelId,
    String? title,
    String status = 'completed',
    bool? verified,
    bool? reviewedByVerifier,
    int? createdAtEpochMs,
    int? completedAtEpochMs,
  }) {
    final normalizedContent = finalContent.trimRight();
    final artifactReferences = artifacts
        .map((artifact) => artifact.toResponseArtifactReference())
        .toList(growable: false);
    final activityList = activities.toList(growable: false);
    final resolvedQuality = quality.copyWith(
      verified: verified,
      reviewedByVerifier: reviewedByVerifier,
    );
    final resolvedSummaryText = _resolveSummaryText(
      normalizedContent,
      artifactReferences,
      activityList,
    );
    final resolvedTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : _deriveTitle(normalizedContent, artifactReferences, activityList);
    final resolvedRunSummary = (runSummary ??
            RunSummary(
              runId: runId ?? 'run_unassigned',
              title: resolvedTitle,
              status: status,
              summaryText: resolvedSummaryText,
              conversationId: conversationId,
              modelId: modelId,
              artifactCount: artifactReferences.length,
              activityCount: activityList.length,
              verified: resolvedQuality.verified,
              reviewedByVerifier: resolvedQuality.reviewedByVerifier,
              createdAtEpochMs: createdAtEpochMs,
              completedAtEpochMs: completedAtEpochMs,
              metadata: metadata,
            ))
        .copyWith(
          runId: runId,
          title: resolvedTitle,
          status: status,
          summaryText: resolvedSummaryText,
          conversationId: conversationId,
          modelId: modelId,
          artifactCount: artifactReferences.length,
          activityCount: activityList.length,
          verified: resolvedQuality.verified,
          reviewedByVerifier: resolvedQuality.reviewedByVerifier,
          createdAtEpochMs: createdAtEpochMs,
          completedAtEpochMs: completedAtEpochMs,
          metadata: metadata,
        );

    final blocks = <ResponseBlock>[
      if (normalizedContent.isNotEmpty)
        ResponseMarkdownBlock(content: normalizedContent),
      ...activityList.map(
        (activity) => ResponseActivityBlock(trace: activity),
      ),
      ...artifactReferences.map(
        (artifact) => ResponseArtifactBlock(reference: artifact),
      ),
    ];

    return ResponseEnvelope(
      summaryText: resolvedSummaryText,
      blocks: blocks,
      artifacts: artifactReferences,
      activities: activityList,
      runSummary: resolvedRunSummary,
      quality: resolvedQuality,
      metadata: metadata,
    );
  }

  ResponseEnvelope buildFromChatMessage({
    required ChatMessage message,
    Iterable<ActivityTrace> activities = const <ActivityTrace>[],
    RunSummary? runSummary,
    ResponseQuality quality = const ResponseQuality(),
    Map<String, Object?> metadata = const <String, Object?>{},
    String? runId,
    String? conversationId,
    String? modelId,
    String? title,
    String status = 'completed',
    bool? verified,
    bool? reviewedByVerifier,
    int? createdAtEpochMs,
    int? completedAtEpochMs,
  }) {
    return buildFromFinalContent(
      finalContent: message.content,
      artifacts: message.generatedArtifacts,
      activities: activities,
      runSummary: runSummary,
      quality: quality,
      metadata: metadata,
      runId: runId,
      conversationId: conversationId,
      modelId: modelId,
      title: title,
      status: status,
      verified: verified,
      reviewedByVerifier: reviewedByVerifier,
      createdAtEpochMs: createdAtEpochMs,
      completedAtEpochMs: completedAtEpochMs,
    );
  }

  static String _resolveSummaryText(
    String content,
    List<ResponseArtifactReference> artifacts,
    List<ActivityTrace> activities,
  ) {
    if (content.isNotEmpty) {
      return _truncateSummary(_collapseWhitespace(content));
    }
    if (artifacts.isNotEmpty) {
      return 'Created ${artifacts.length} artifact${artifacts.length == 1 ? '' : 's'}.';
    }
    if (activities.isNotEmpty) {
      return 'Completed ${activities.length} activity trace${activities.length == 1 ? '' : 's'}.';
    }
      return '';
    }

    static String _deriveTitle(
      String content,
      List<ResponseArtifactReference> artifacts,
      List<ActivityTrace> activities,
  ) {
    final firstLine = content.split('\n').firstWhere(
          (line) => line.trim().isNotEmpty,
          orElse: () => '',
        );
    if (firstLine.isNotEmpty) {
      return firstLine.trim();
    }
    if (artifacts.isNotEmpty) {
      return artifacts.first.title;
    }
    if (activities.isNotEmpty) {
      return activities.first.title;
    }
    return 'Response';
  }

  static String _collapseWhitespace(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _truncateSummary(String value) {
    const max = 320;
    if (value.length <= max) {
      return value;
    }
    return '${value.substring(0, max - 3)}...';
  }
}

extension GeneratedArtifactReferenceResponseEnvelopeX
    on GeneratedArtifactReference {
  ResponseArtifactReference toResponseArtifactReference() {
    return ResponseArtifactReference(
      artifactId: id,
      title: title,
      kindLabel: kindLabel,
      extension: extension,
      mimeType: mimeType,
      localPath: localPath,
      sourceUri: sourceUri,
      sizeBytes: sizeBytes,
    );
  }
}

extension ResponseArtifactReferenceGeneratedArtifactReferenceX
    on ResponseArtifactReference {
  GeneratedArtifactReference toGeneratedArtifactReference() {
    return GeneratedArtifactReference(
      id: artifactId,
      title: title,
      kindLabel: kindLabel,
      extension: extension,
      mimeType: mimeType,
      localPath: localPath,
      sourceUri: sourceUri,
      sizeBytes: sizeBytes,
    );
  }
}
