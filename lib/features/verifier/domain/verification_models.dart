enum VerificationTarget { response, toolIntent }

enum VerificationSeverity { info, warning, blocking }

class VerificationIssue {
  const VerificationIssue({
    required this.code,
    required this.message,
    required this.severity,
    this.fieldPath,
    this.subject,
    this.details = const <String, Object?>{},
  });

  final String code;
  final String message;
  final VerificationSeverity severity;
  final String? fieldPath;
  final String? subject;
  final Map<String, Object?> details;

  bool get isBlocking => severity == VerificationSeverity.blocking;
}

class VerificationReport {
  const VerificationReport({
    required this.target,
    required this.issues,
    this.subject,
  });

  final VerificationTarget target;
  final String? subject;
  final List<VerificationIssue> issues;

  bool get hasIssues => issues.isNotEmpty;

  bool get hasBlockingIssues =>
      issues.any((issue) => issue.severity == VerificationSeverity.blocking);

  bool get isAccepted => !hasBlockingIssues;

  List<VerificationIssue> get blockingIssues =>
      List<VerificationIssue>.unmodifiable(
        issues.where(
          (issue) => issue.severity == VerificationSeverity.blocking,
        ),
      );

  List<VerificationIssue> get warningIssues =>
      List<VerificationIssue>.unmodifiable(
        issues.where((issue) => issue.severity == VerificationSeverity.warning),
      );

  String? get primaryFailureMessage =>
      blockingIssues.isNotEmpty ? blockingIssues.first.message : null;
}

class ToolIntent {
  const ToolIntent({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final Map<String, Object?> arguments;

  ToolIntent copyWith({
    String? id,
    String? name,
    Map<String, Object?>? arguments,
  }) {
    return ToolIntent(
      id: id ?? this.id,
      name: name ?? this.name,
      arguments: arguments ?? this.arguments,
    );
  }
}

class VerifiedToolIntent {
  const VerifiedToolIntent({required this.intent, required this.capabilityKey});

  final ToolIntent intent;
  final String capabilityKey;
}

class RejectedToolIntent {
  const RejectedToolIntent({required this.intent, required this.issues});

  final ToolIntent intent;
  final List<VerificationIssue> issues;

  bool get hasBlockingIssues =>
      issues.any((issue) => issue.severity == VerificationSeverity.blocking);
}

class ToolIntentVerificationResult {
  const ToolIntentVerificationResult({
    required this.report,
    required this.acceptedIntents,
    required this.rejectedIntents,
  });

  final VerificationReport report;
  final List<VerifiedToolIntent> acceptedIntents;
  final List<RejectedToolIntent> rejectedIntents;

  bool get isAccepted => report.isAccepted;

  bool get hasBlockingIssues => report.hasBlockingIssues;

  List<VerificationIssue> get blockingIssues => report.blockingIssues;
}
