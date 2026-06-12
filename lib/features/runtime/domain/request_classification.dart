enum RequestKind {
  directAnswer,
  researchAnswer,
  artifactGeneration,
  workspaceEdit,
  hybrid,
}

enum ArtifactKind {
  none,
  docx,
  pdf,
  xlsx,
  textFile,
  projectBundle,
}

enum FinalAnswerMode {
  modelSynthesis,
  runtimeAssembled,
  hybrid,
}

enum FallbackPolicy {
  none,
  repairDirectAnswer,
  repairToolPlan,
  artifactStrictError,
}

class RequestClassification {
  const RequestClassification({
    required this.requestKind,
    required this.artifactKind,
    required this.requiresExternalContext,
    required this.requiresSideEffect,
    required this.isArtifactCapabilityQuestion,
    required this.isHybrid,
    required this.confidence,
    required this.reason,
    this.finalAnswerMode = FinalAnswerMode.modelSynthesis,
    this.fallbackPolicy = FallbackPolicy.none,
  });

  final RequestKind requestKind;
  final ArtifactKind artifactKind;
  final bool requiresExternalContext;
  final bool requiresSideEffect;
  final bool isArtifactCapabilityQuestion;
  final bool isHybrid;
  final double confidence;
  final String reason;
  final FinalAnswerMode finalAnswerMode;
  final FallbackPolicy fallbackPolicy;
}
