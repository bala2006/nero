import '../../chat/application/sarvam_api_client.dart';
import '../../chat/domain/chat_message.dart';
import 'artifact_markdown_recovery.dart';

typedef ArtifactAssistantRoundExecutor =
    Future<SarvamChatResult> Function({
      required List<ChatMessage> requestMessages,
      required List<SarvamToolDefinition> tools,
      required StringBuffer responseBuffer,
    });

typedef ArtifactToolCallExecutor =
    Future<SarvamToolCall?> Function(SarvamChatResult result, String outputTool);

typedef ArtifactToolRuntimeExecutor =
    Future<ToolExecutionOutcome> Function(SarvamToolCall toolCall);
typedef ArtifactMarkdownRecoveryExecutor =
    Future<ToolExecutionOutcome?> Function(
      SarvamChatResult result,
      String outputTool,
    );

class ToolExecutionOutcome {
  const ToolExecutionOutcome({
    required this.success,
    required this.formattedOutput,
    required this.generatedArtifactCount,
  });

  final bool success;
  final String formattedOutput;
  final int generatedArtifactCount;
}

class ArtifactFallbackResult {
  const ArtifactFallbackResult({
    required this.finalResponse,
    required this.stepDetail,
    this.errorMessage,
  });

  final String finalResponse;
  final String stepDetail;
  final String? errorMessage;
}

class ArtifactFallbackCoordinator {
  const ArtifactFallbackCoordinator({
    ArtifactMarkdownRecovery markdownRecovery =
        const ArtifactMarkdownRecovery(),
  }) : _markdownRecovery = markdownRecovery;

  final ArtifactMarkdownRecovery _markdownRecovery;

  Future<ArtifactFallbackResult?> completePendingArtifact({
    required String prompt,
    required String outputTool,
    required List<ChatMessage> requestMessages,
    required String currentResponse,
    required List<SarvamToolDefinition> availableTools,
    required bool documentGenerationAlreadyAttempted,
    required bool alreadyHasArtifact,
    required ArtifactAssistantRoundExecutor executeAssistantRound,
    required ArtifactToolCallExecutor findToolCall,
    required ArtifactToolRuntimeExecutor executeToolCall,
    required ArtifactMarkdownRecoveryExecutor recoverArtifactFromMarkdown,
    required String forcedInstruction,
  }) async {
    final currentResponseTrimmed = currentResponse.trim();
    if (alreadyHasArtifact) {
      return currentResponseTrimmed.isNotEmpty
          ? null
          : ArtifactFallbackResult(
              finalResponse: outputTool == 'generate_docx'
                  ? 'I created the document and attached it above.'
                  : 'I created the file and attached it above.',
              stepDetail: 'File artifact already existed for this response.',
            );
    }

    if (_shouldAttemptMarkdownRecovery(currentResponseTrimmed)) {
      final recoveredFromCurrentResponse = await recoverArtifactFromMarkdown(
        SarvamChatResult(
          content: currentResponseTrimmed,
          model: 'artifact_markdown_recovery',
        ),
        outputTool,
      );
      final mappedResult = _mapRecoveryOutcome(
        outputTool: outputTool,
        outcome: recoveredFromCurrentResponse,
        detailOnSuccess: 'File artifact generated successfully from validated markdown.',
        detailOnFailure:
            'Artifact generation failed because validated markdown did not produce a file.',
        errorOnFailure:
            'The requested file could not be created because validated markdown did not produce a file.',
      );
      if (mappedResult != null) {
        return mappedResult;
      }
    }

    final forcedMessages = List<ChatMessage>.of(requestMessages, growable: true);
    if (currentResponseTrimmed.isNotEmpty) {
      forcedMessages.add(
        ChatMessage(
          id: 'assistant_incomplete_doc_${forcedMessages.length}',
          role: ChatRole.assistant,
          content: currentResponseTrimmed,
        ),
      );
    }
    forcedMessages.add(
      ChatMessage(
        id: 'force_${outputTool}_${forcedMessages.length}',
        role: ChatRole.system,
        content: forcedInstruction,
      ),
    );

    final forcedResult = await executeAssistantRound(
      requestMessages: forcedMessages,
      tools: availableTools
          .where((tool) => tool.name == outputTool)
          .toList(growable: false),
      responseBuffer: StringBuffer(),
    );

    final toolCall = await findToolCall(forcedResult, outputTool);
    if (toolCall != null) {
      final toolResult = await executeToolCall(toolCall);
      if (toolResult.success && toolResult.generatedArtifactCount > 0) {
        return ArtifactFallbackResult(
          finalResponse: outputTool == 'generate_docx'
              ? 'I created the document and attached it above.'
              : 'I created the file and attached it above.',
          stepDetail: 'File artifact generated successfully.',
        );
      }
      final detail = toolResult.formattedOutput.trim();
      return ArtifactFallbackResult(
        finalResponse:
            'I could not complete the requested file artifact because native file generation did not produce an artifact.',
        stepDetail: detail.isNotEmpty
            ? detail
            : 'Artifact generation failed because native execution did not produce a file.',
        errorMessage: detail.isNotEmpty
            ? detail
            : 'The requested file could not be created because native execution did not produce a file.',
      );
    }

    if (_shouldAttemptMarkdownRecovery(forcedResult.content)) {
      final recoveredFromMarkdown = await recoverArtifactFromMarkdown(
        forcedResult,
        outputTool,
      );
      final mappedMarkdownRecovery = _mapRecoveryOutcome(
        outputTool: outputTool,
        outcome: recoveredFromMarkdown,
        detailOnSuccess:
            'File artifact generated successfully from validated markdown.',
        detailOnFailure:
            'Artifact generation failed because markdown recovery did not produce a file.',
        errorOnFailure:
            'The requested file could not be created because markdown recovery did not produce a file.',
      );
      if (mappedMarkdownRecovery != null) {
        return mappedMarkdownRecovery;
      }
    }

    return ArtifactFallbackResult(
      finalResponse:
          'I could not complete the requested file artifact because the model did not emit a valid $outputTool tool call.',
      stepDetail: 'Artifact generation stopped because no valid tool call was emitted.',
      errorMessage:
          'The requested file could not be created because the model did not emit a valid $outputTool tool call.',
    );
  }

  bool _shouldAttemptMarkdownRecovery(String content) {
    if (content.trim().isEmpty) {
      return false;
    }
    return _markdownRecovery.sanitizeMarkdown(content) != null;
  }

  ArtifactFallbackResult? _mapRecoveryOutcome({
    required String outputTool,
    required ToolExecutionOutcome? outcome,
    required String detailOnSuccess,
    required String detailOnFailure,
    required String errorOnFailure,
  }) {
    if (outcome == null) {
      return null;
    }
    if (outcome.success && outcome.generatedArtifactCount > 0) {
      return ArtifactFallbackResult(
        finalResponse: outputTool == 'generate_docx'
            ? 'I created the document and attached it above.'
            : 'I created the file and attached it above.',
        stepDetail: detailOnSuccess,
      );
    }
    final detail = outcome.formattedOutput.trim();
    return ArtifactFallbackResult(
      finalResponse:
          'I could not complete the requested file artifact because native file generation did not produce an artifact.',
      stepDetail: detail.isNotEmpty ? detail : detailOnFailure,
      errorMessage: detail.isNotEmpty ? detail : errorOnFailure,
    );
  }
}
