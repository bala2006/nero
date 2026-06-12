import 'dart:convert';

import '../../chat/domain/chat_message.dart';
import '../../tools/domain/tool_runtime_models.dart' as runtime;
import '../../workspace/domain/workspace_item.dart';
import '../../chat/application/web_tools.dart';

class ArtifactResultAdapter {
  const ArtifactResultAdapter();

  ArtifactPresentationOutcome outcomeForWorkspaceItem({
    required WorkspaceItem item,
    required String successSummary,
    required String activityTitle,
    required String artifactLabel,
  }) {
    final reference = referenceForWorkspaceItem(item);
    return ArtifactPresentationOutcome(
      artifacts: <GeneratedArtifactReference>[reference],
      activity: activityForWorkspaceItem(
        item: item,
        title: activityTitle,
      ),
      toolResult: ToolExecutionResult(
        success: true,
        summary: '$successSummary "${item.title}".',
        formattedOutput:
            'Created and attached `${item.title}` as a $artifactLabel.',
        items: [
          ToolExecutionItem(
            title: item.title,
            subtitle: _artifactKindLabelForExtension(item.extension),
            trailing: item.sizeBytes == null ? null : '${item.sizeBytes} bytes',
          ),
        ],
      ),
    );
  }

  GeneratedArtifactReference referenceForWorkspaceItem(WorkspaceItem item) {
    final metadata = _decodeArtifactMetadata(item.metadataJson);
    return GeneratedArtifactReference(
      id: item.id,
      title: item.title,
      kindLabel: _artifactKindLabelForExtension(item.extension),
      extension: item.extension,
      mimeType: item.mimeType,
      localPath: item.localPath,
      sourceUri: item.sourceUri,
      sizeBytes: item.sizeBytes,
      previewMarkdown: metadata['previewMarkdown']?.toString(),
    );
  }

  GeneratedArtifactReference referenceForDescriptor(
    runtime.GeneratedArtifactDescriptor descriptor,
  ) {
    return GeneratedArtifactReference(
      id: descriptor.id,
      title: descriptor.title,
      kindLabel: descriptor.kindLabel,
      extension: descriptor.extension,
      mimeType: descriptor.mimeType,
      localPath: descriptor.localPath,
      sourceUri: descriptor.sourceUri,
      sizeBytes: descriptor.sizeBytes,
      previewMarkdown: descriptor.metadata['previewMarkdown']?.toString(),
    );
  }

  ToolExecutionResult toolExecutionResultFromNativeResult({
    required runtime.ToolExecutionResult runtimeResult,
    required String successSummary,
    required String failurePrefix,
  }) {
    if (runtimeResult.status != runtime.RuntimeJobStatus.completed ||
        runtimeResult.artifacts.isEmpty) {
      final message = runtimeResult.errorMessage?.trim();
      return ToolExecutionResult(
        success: false,
        summary: '$failurePrefix.',
        formattedOutput: message == null || message.isEmpty
            ? '$failurePrefix.'
            : '$failurePrefix: $message',
      );
    }

    final descriptors = runtimeResult.artifacts;
    final primary = descriptors.first;
    return ToolExecutionResult(
      success: true,
      summary: '$successSummary "${primary.title}".',
      formattedOutput:
          'Created and attached `${primary.title}` as a generated artifact.',
      items: [
        for (final descriptor in descriptors)
          ToolExecutionItem(
            title: descriptor.title,
            subtitle: descriptor.kindLabel,
            trailing: descriptor.sizeBytes == null
                ? null
                : '${descriptor.sizeBytes} bytes',
          ),
      ],
    );
  }

  ArtifactPresentationOutcome outcomeForNativeRuntimeResult({
    required runtime.ToolExecutionResult runtimeResult,
    required String successSummary,
    required String failurePrefix,
    required String activityTitle,
  }) {
    final artifacts = runtimeResult.artifacts
        .map(referenceForDescriptor)
        .toList(growable: false);
    final activity = runtimeResult.status == runtime.RuntimeJobStatus.completed &&
            runtimeResult.artifacts.isNotEmpty
        ? activityForDescriptors(
            descriptors: runtimeResult.artifacts,
            title: activityTitle,
          )
        : null;
    return ArtifactPresentationOutcome(
      artifacts: artifacts,
      activity: activity,
      toolResult: toolExecutionResultFromNativeResult(
        runtimeResult: runtimeResult,
        successSummary: successSummary,
        failurePrefix: failurePrefix,
      ),
    );
  }

  ChatActivity activityForWorkspaceItem({
    required WorkspaceItem item,
    required String title,
  }) {
    return ChatActivity(
      type: ChatActivityType.agentPlan,
      title: title,
      subtitle: item.title,
      items: [
        ChatActivityItem(
          title: item.title,
          subtitle: _artifactKindLabelForExtension(item.extension),
          trailing: item.sizeBytes == null ? null : '${item.sizeBytes} bytes',
        ),
      ],
      isComplete: true,
    );
  }

  ChatActivity activityForDescriptors({
    required List<runtime.GeneratedArtifactDescriptor> descriptors,
    required String title,
  }) {
    final primary = descriptors.first;
    return ChatActivity(
      type: ChatActivityType.agentPlan,
      title: title,
      subtitle: primary.title,
      items: [
        for (final descriptor in descriptors)
          ChatActivityItem(
            title: descriptor.title,
            subtitle: descriptor.kindLabel,
            trailing: descriptor.sizeBytes == null
                ? null
                : '${descriptor.sizeBytes} bytes',
          ),
      ],
      isComplete: true,
    );
  }

  Map<String, Object?> _decodeArtifactMetadata(String? metadataJson) {
    if (metadataJson == null || metadataJson.trim().isEmpty) {
      return const <String, Object?>{};
    }
    try {
      final decoded = jsonDecode(metadataJson);
      if (decoded is Map) {
        return Map<String, Object?>.from(decoded);
      }
    } catch (_) {}
    return const <String, Object?>{};
  }

  String _artifactKindLabelForExtension(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'xlsx':
        return 'Spreadsheet';
      case 'pdf':
        return 'PDF';
      default:
        return 'Document';
    }
  }
}

class ArtifactPresentationOutcome {
  const ArtifactPresentationOutcome({
    required this.artifacts,
    required this.activity,
    required this.toolResult,
  });

  final List<GeneratedArtifactReference> artifacts;
  final ChatActivity? activity;
  final ToolExecutionResult toolResult;
}
