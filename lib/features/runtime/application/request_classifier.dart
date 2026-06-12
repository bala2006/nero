import '../domain/request_classification.dart';

class RequestClassifier {
  const RequestClassifier();

  RequestClassification classify(String prompt) {
    final lowered = prompt.trim().toLowerCase();
    if (lowered.isEmpty) {
      return const RequestClassification(
        requestKind: RequestKind.directAnswer,
        artifactKind: ArtifactKind.none,
        requiresExternalContext: false,
        requiresSideEffect: false,
        isArtifactCapabilityQuestion: false,
        isHybrid: false,
        confidence: 0.5,
        reason: 'Empty prompt defaults to direct answer mode.',
        finalAnswerMode: FinalAnswerMode.modelSynthesis,
        fallbackPolicy: FallbackPolicy.repairDirectAnswer,
      );
    }

    final artifactCapabilityQuestion = _looksLikeArtifactCapabilityQuestion(
      lowered,
    );
    if (artifactCapabilityQuestion) {
      return const RequestClassification(
        requestKind: RequestKind.directAnswer,
        artifactKind: ArtifactKind.none,
        requiresExternalContext: false,
        requiresSideEffect: false,
        isArtifactCapabilityQuestion: true,
        isHybrid: false,
        confidence: 0.92,
        reason: 'Prompt asks about artifact capability, not execution.',
        finalAnswerMode: FinalAnswerMode.modelSynthesis,
        fallbackPolicy: FallbackPolicy.repairDirectAnswer,
      );
    }

    final artifactKind = _artifactKindFor(lowered);
    final needsResearch = _needsResearch(lowered);
    final needsWorkspaceEdit =
        _looksLikeProjectCreationRequest(lowered) ||
        _looksLikeFileCreationRequest(lowered) ||
        _looksLikeZipRequest(lowered);
    final requiresSideEffect =
        artifactKind != ArtifactKind.none || needsWorkspaceEdit;
    final isHybrid = needsResearch && requiresSideEffect;

    if (isHybrid) {
      return RequestClassification(
        requestKind: RequestKind.hybrid,
        artifactKind: artifactKind,
        requiresExternalContext: true,
        requiresSideEffect: true,
        isArtifactCapabilityQuestion: false,
        isHybrid: true,
        confidence: 0.88,
        reason: 'Prompt requires external context and output generation.',
        finalAnswerMode: FinalAnswerMode.hybrid,
        fallbackPolicy: FallbackPolicy.artifactStrictError,
      );
    }
    if (artifactKind != ArtifactKind.none) {
      return RequestClassification(
        requestKind: RequestKind.artifactGeneration,
        artifactKind: artifactKind,
        requiresExternalContext: needsResearch,
        requiresSideEffect: true,
        isArtifactCapabilityQuestion: false,
        isHybrid: false,
        confidence: needsResearch ? 0.82 : 0.9,
        reason: 'Prompt requests a generated artifact.',
        finalAnswerMode: FinalAnswerMode.runtimeAssembled,
        fallbackPolicy: FallbackPolicy.artifactStrictError,
      );
    }
    if (needsWorkspaceEdit) {
      return RequestClassification(
        requestKind: RequestKind.workspaceEdit,
        artifactKind: _workspaceArtifactKind(lowered),
        requiresExternalContext: false,
        requiresSideEffect: true,
        isArtifactCapabilityQuestion: false,
        isHybrid: false,
        confidence: 0.86,
        reason: 'Prompt requests file or project creation in workspace.',
        finalAnswerMode: FinalAnswerMode.runtimeAssembled,
        fallbackPolicy: FallbackPolicy.artifactStrictError,
      );
    }
    if (needsResearch) {
      return const RequestClassification(
        requestKind: RequestKind.researchAnswer,
        artifactKind: ArtifactKind.none,
        requiresExternalContext: true,
        requiresSideEffect: false,
        isArtifactCapabilityQuestion: false,
        isHybrid: false,
        confidence: 0.9,
        reason: 'Prompt benefits from evidence-first execution.',
        finalAnswerMode: FinalAnswerMode.modelSynthesis,
        fallbackPolicy: FallbackPolicy.repairToolPlan,
      );
    }
    return const RequestClassification(
      requestKind: RequestKind.directAnswer,
      artifactKind: ArtifactKind.none,
      requiresExternalContext: false,
      requiresSideEffect: false,
      isArtifactCapabilityQuestion: false,
      isHybrid: false,
      confidence: 0.8,
      reason: 'Prompt can be handled as a direct answer.',
      finalAnswerMode: FinalAnswerMode.modelSynthesis,
      fallbackPolicy: FallbackPolicy.repairDirectAnswer,
    );
  }

  ArtifactKind _artifactKindFor(String prompt) {
    if (_looksLikeSpreadsheetRequest(prompt)) {
      return ArtifactKind.xlsx;
    }
    if (_looksLikePdfRequest(prompt)) {
      return ArtifactKind.pdf;
    }
    if (_looksLikeDocumentGenerationRequest(prompt)) {
      return ArtifactKind.docx;
    }
    return ArtifactKind.none;
  }

  ArtifactKind _workspaceArtifactKind(String prompt) {
    if (_looksLikeProjectCreationRequest(prompt) || _looksLikeZipRequest(prompt)) {
      return ArtifactKind.projectBundle;
    }
    if (_looksLikeFileCreationRequest(prompt)) {
      return ArtifactKind.textFile;
    }
    return ArtifactKind.none;
  }

  bool _needsResearch(String prompt) {
    const keywords = <String>[
      'research',
      'find out',
      'latest',
      'today',
      'current',
      'news',
      'recent',
      'search',
      'look up',
      'browse',
      'find online',
      'web',
      'website',
      'url',
      'link',
      'docs',
      'documentation',
      'difference between',
      'compare',
      'comparison',
      'vs',
      'which is better',
      'best model',
    ];
    return keywords.any(prompt.contains);
  }

  bool _looksLikeDocumentGenerationRequest(String prompt) {
    if (_looksLikeArtifactCapabilityQuestion(prompt) ||
        _looksLikeSpreadsheetRequest(prompt) ||
        _looksLikePdfRequest(prompt)) {
      return false;
    }
    final asksToCreate = _asksForArtifact(prompt);
    final namesDocument =
        prompt.contains('docx') ||
        RegExp(r'\bdoc\b').hasMatch(prompt) ||
        prompt.contains('word doc') ||
        prompt.contains('word document') ||
        prompt.contains('document file') ||
        prompt.contains('downloadable document') ||
        prompt.contains('word') ||
        prompt.contains('document') ||
        prompt.contains('report') ||
        prompt.contains('memo') ||
        prompt.contains('letter');
    return asksToCreate && namesDocument;
  }

  bool _looksLikeSpreadsheetRequest(String prompt) {
    final asksToCreate = _asksForArtifact(prompt);
    final namesSpreadsheet =
        prompt.contains('xlsx') ||
        prompt.contains('excel') ||
        prompt.contains('spreadsheet') ||
        prompt.contains('workbook') ||
        prompt.contains('sheet');
    return asksToCreate && namesSpreadsheet;
  }

  bool _looksLikePdfRequest(String prompt) {
    if (_looksLikeArtifactCapabilityQuestion(prompt)) {
      return false;
    }
    final asksToCreate = _asksForArtifact(prompt);
    final namesPdf =
        prompt.contains('pdf') || prompt.contains('portable document');
    return asksToCreate && namesPdf;
  }

  bool _looksLikeFileCreationRequest(String prompt) {
    final asksToCreate = _asksForArtifact(prompt);
    final namesFile =
        prompt.contains('.txt') ||
        prompt.contains('.md') ||
        prompt.contains('.py') ||
        prompt.contains('.js') ||
        prompt.contains('.json') ||
        prompt.contains('.csv') ||
        prompt.contains('.html') ||
        prompt.contains('.yaml') ||
        prompt.contains('text file') ||
        prompt.contains('readme') ||
        prompt.contains('notes file') ||
        prompt.contains('config file');
    return asksToCreate && namesFile;
  }

  bool _looksLikeProjectCreationRequest(String prompt) {
    final asksToCreate = _asksForArtifact(prompt) || prompt.contains('scaffold');
    final namesProject =
        prompt.contains('project') ||
        prompt.contains('boilerplate') ||
        prompt.contains('starter') ||
        prompt.contains('template') ||
        (prompt.contains('multiple') && prompt.contains('file'));
    return asksToCreate && namesProject;
  }

  bool _looksLikeZipRequest(String prompt) {
    return prompt.contains('zip') ||
        prompt.contains('archive') ||
        prompt.contains('bundle') ||
        (prompt.contains('download') && prompt.contains('file'));
  }

  bool _looksLikeArtifactCapabilityQuestion(String prompt) {
    final trimmed = prompt.trim();
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
    return !hasConcreteContent;
  }

  bool _asksForArtifact(String prompt) {
    return prompt.contains('create') ||
        prompt.contains('generate') ||
        prompt.contains('make') ||
        prompt.contains('prepare') ||
        prompt.contains('write') ||
        prompt.contains('build') ||
        prompt.contains('export') ||
        prompt.contains('i want') ||
        prompt.contains('i need') ||
        prompt.contains('want a') ||
        prompt.contains('need a') ||
        prompt.contains('want an') ||
        prompt.contains('need an') ||
        prompt.contains('give me') ||
        prompt.contains('provide a') ||
        prompt.contains('provide an');
  }
}
