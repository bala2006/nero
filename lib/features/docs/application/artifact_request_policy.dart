import '../../agent/domain/agent_task.dart';
import '../../runtime/domain/request_classification.dart';

class ArtifactStrictFailureResolution {
  const ArtifactStrictFailureResolution({
    required this.errorMessage,
    required this.userResponse,
    required this.stepError,
  });

  final String errorMessage;
  final String userResponse;
  final String stepError;
}

class ArtifactRequestPolicy {
  const ArtifactRequestPolicy();

  String? preferredOutputToolForPrompt(
    String prompt,
    List<String> selectedTools,
  ) {
    final selected = selectedTools.toSet();
    final lowered = prompt.toLowerCase();
    final allowPromptInference = selected.isEmpty;
    if ((selected.contains('generate_xlsx') || allowPromptInference) &&
        looksLikeSpreadsheetRequest(lowered)) {
      return 'generate_xlsx';
    }
    if ((selected.contains('generate_report_pdf') || allowPromptInference) &&
        looksLikePdfRequest(lowered)) {
      return 'generate_report_pdf';
    }
    if ((selected.contains('generate_docx') || allowPromptInference) &&
        looksLikeDocxRequest(lowered)) {
      return 'generate_docx';
    }
    return null;
  }

  String? toolNameForArtifactKind(ArtifactKind kind) {
    return switch (kind) {
      ArtifactKind.docx => 'generate_docx',
      ArtifactKind.xlsx => 'generate_xlsx',
      ArtifactKind.pdf => 'generate_report_pdf',
      ArtifactKind.textFile => 'create_text_file',
      _ => null,
    };
  }

  String forcedOutputToolInstruction(String toolName) {
    const commonInstruction =
        'You MUST call the tool now. Do NOT respond with intent, promises, "Sure," or any summary text. '
        'Output only the <tool_call> and nothing else. If you repeat conversational filler, the request will fail.';

    return switch (toolName) {
      'generate_xlsx' =>
        'The user requested a downloadable Excel/XLSX spreadsheet, and you have not created it yet. '
            'Call generate_xlsx NOW with a clear title and a sheets array. '
            '$commonInstruction',
      'generate_report_pdf' =>
        'The user requested a downloadable PDF file, and you have not created it yet. '
            'Call generate_report_pdf NOW with a clear title and complete markdown_content for the full PDF body. '
            '$commonInstruction',
      _ =>
        'The user requested a downloadable DOCX file, and you have not created it yet. '
            'Call generate_docx NOW with a clear title and complete markdown_content for the full document. '
            '$commonInstruction',
    };
  }

  bool shouldSkipArtifactCompletion(String prompt) {
    return looksLikeArtifactCapabilityQuestion(prompt.toLowerCase());
  }

  ArtifactStrictFailureResolution? strictFailureIfNeeded({
    required String prompt,
    required List<String> selectedTools,
    required bool hasGeneratedArtifacts,
  }) {
    if (hasGeneratedArtifacts) {
      return null;
    }
    final outputTool = preferredOutputToolForPrompt(prompt, selectedTools);
    if (outputTool == null) {
      return null;
    }
    return const ArtifactStrictFailureResolution(
      errorMessage:
          'The requested file could not be created because no valid artifact was produced.',
      userResponse:
          'I could not complete the requested file artifact because no valid file was produced.',
      stepError: 'Artifact generation ended without a valid file.',
    );
  }

  bool documentGenerationAlreadyAttempted(AgentTask? task) {
    if (task == null) {
      return false;
    }
    return task.steps.any(
      (step) =>
          step.kind == AgentStepKinds.generateDocument &&
          step.status != AgentStepStatus.pending &&
          step.status != AgentStepStatus.running,
    );
  }

  bool looksLikeDocxRequest(String loweredPrompt) {
    if (looksLikeArtifactCapabilityQuestion(loweredPrompt)) {
      return false;
    }
    if (looksLikeSpreadsheetRequest(loweredPrompt) ||
        looksLikePdfRequest(loweredPrompt)) {
      return false;
    }
    final asksToCreate = _asksForArtifact(loweredPrompt);
    final namesDocument =
        loweredPrompt.contains('docx') ||
        loweredPrompt.contains('word doc') ||
        loweredPrompt.contains('word document') ||
        loweredPrompt.contains('document file') ||
        loweredPrompt.contains('downloadable document') ||
        RegExp(r'\bdoc\b').hasMatch(loweredPrompt) ||
        RegExp(r'\breport\b').hasMatch(loweredPrompt) ||
        RegExp(r'\bmemo\b').hasMatch(loweredPrompt) ||
        RegExp(r'\bletter\b').hasMatch(loweredPrompt);
    return asksToCreate && namesDocument;
  }

  bool looksLikeSpreadsheetRequest(String loweredPrompt) {
    if (looksLikeArtifactCapabilityQuestion(loweredPrompt)) {
      return false;
    }
    final asksToCreate = _asksForArtifact(loweredPrompt);
    final namesSpreadsheet =
        loweredPrompt.contains('xlsx') ||
        loweredPrompt.contains('excel') ||
        loweredPrompt.contains('spreadsheet') ||
        loweredPrompt.contains('sheet') ||
        loweredPrompt.contains('workbook') ||
        loweredPrompt.contains('csv table');
    return asksToCreate && namesSpreadsheet;
  }

  bool looksLikePdfRequest(String loweredPrompt) {
    if (looksLikeArtifactCapabilityQuestion(loweredPrompt)) {
      return false;
    }
    final asksToCreate = _asksForArtifact(loweredPrompt);
    final namesPdf =
        loweredPrompt.contains('pdf') ||
        loweredPrompt.contains('portable document');
    return asksToCreate && namesPdf;
  }

  bool looksLikeArtifactCapabilityQuestion(String loweredPrompt) {
    final trimmed = loweredPrompt.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final asksCapability =
        trimmed.startsWith('can you ') ||
        trimmed.startsWith('could you ') ||
        trimmed.startsWith('are you able to ') ||
        trimmed.startsWith('do you support ') ||
        trimmed.startsWith('do you have ') ||
        trimmed.startsWith('is it possible to ');
    if (!asksCapability) {
      return false;
    }
    final mentionsArtifact =
        trimmed.contains('docx') ||
        RegExp(r'\bdoc\b').hasMatch(trimmed) ||
        trimmed.contains('document') ||
        trimmed.contains('word doc') ||
        trimmed.contains('word document') ||
        trimmed.contains('pdf') ||
        trimmed.contains('spreadsheet') ||
        trimmed.contains('excel') ||
        trimmed.contains('xlsx');
    if (!mentionsArtifact) {
      return false;
    }
    final hasConcreteContent =
        trimmed.contains(' about ') ||
        trimmed.contains(' for ') ||
        trimmed.contains(' from ') ||
        trimmed.contains(' using ') ||
        trimmed.contains(' based on ') ||
        trimmed.contains(' with this ') ||
        trimmed.contains(' from this ') ||
        trimmed.contains(' summar') ||
        trimmed.contains(' report on ') ||
        trimmed.contains(' file for ');
    final shortQuestion = trimmed.split(RegExp(r'\s+')).length <= 8;
    return !hasConcreteContent || shortQuestion;
  }

  bool _asksForArtifact(String loweredPrompt) {
    return loweredPrompt.contains('create') ||
        loweredPrompt.contains('generate') ||
        loweredPrompt.contains('make') ||
        loweredPrompt.contains('prepare') ||
        loweredPrompt.contains('write') ||
        loweredPrompt.contains('build') ||
        loweredPrompt.contains('export') ||
        loweredPrompt.contains('i want') ||
        loweredPrompt.contains('i need') ||
        loweredPrompt.contains('want a') ||
        loweredPrompt.contains('need a') ||
        loweredPrompt.contains('want an') ||
        loweredPrompt.contains('need an') ||
        loweredPrompt.contains('give me') ||
        loweredPrompt.contains('provide a') ||
        loweredPrompt.contains('provide an');
  }
}
