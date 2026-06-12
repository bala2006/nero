import 'verification_models.dart';

class ResponseVerificationRequest {
  const ResponseVerificationRequest({
    required this.response,
    this.userPrompt,
    this.expectsArtifact = false,
    this.expectedArtifactToolNames = const <String>[],
    this.activeToolNames = const <String>[],
  });

  final String response;
  final String? userPrompt;
  final bool expectsArtifact;
  final List<String> expectedArtifactToolNames;
  final List<String> activeToolNames;
}

class ResponseVerifier {
  const ResponseVerifier();

  VerificationReport verify(ResponseVerificationRequest request) {
    final issues = <VerificationIssue>[];
    final response = request.response.trim();
    final userPrompt = request.userPrompt?.trim();

    if (response.isEmpty) {
      issues.add(
        const VerificationIssue(
          code: 'response.empty',
          message: 'The response is empty.',
          severity: VerificationSeverity.blocking,
          fieldPath: 'response',
        ),
      );
    }

    if (_looksLikeInternalFailure(response, userPrompt)) {
      issues.add(
        const VerificationIssue(
          code: 'response.internal_error_leak',
          message: 'The final response contains an internal error message.',
          severity: VerificationSeverity.blocking,
          fieldPath: 'response',
        ),
      );
    }

    if (_containsToolMarkers(response)) {
      issues.add(
        const VerificationIssue(
          code: 'response.tool_marker_leak',
          message: 'The final response leaks raw tool markers.',
          severity: VerificationSeverity.blocking,
          fieldPath: 'response',
        ),
      );
    }

    final expectsArtifact =
        request.expectsArtifact || _looksLikeArtifactPrompt(request.userPrompt);
    if (expectsArtifact && _looksLikePromiseOnlyArtifactReply(response)) {
      issues.add(
        VerificationIssue(
          code: 'response.promise_only_artifact_reply',
          message:
              'The response promises an artifact instead of delivering a final artifact-backed answer.',
          severity: VerificationSeverity.blocking,
          fieldPath: 'response',
          details: <String, Object?>{
            'expectedArtifactToolNames': request.expectedArtifactToolNames,
            'activeToolNames': request.activeToolNames,
          },
        ),
      );
    }

    return VerificationReport(
      target: VerificationTarget.response,
      subject: request.userPrompt,
      issues: List<VerificationIssue>.unmodifiable(issues),
    );
  }

  bool _containsToolMarkers(String response) {
    return _toolMarkerPattern.hasMatch(response);
  }

  bool _looksLikePromiseOnlyArtifactReply(String response) {
    if (!_promisePattern.hasMatch(response)) {
      return false;
    }

    return !_completionPattern.hasMatch(response);
  }

  bool _looksLikeArtifactPrompt(String? prompt) {
    final value = prompt?.trim();
    if (value == null || value.isEmpty) {
      return false;
    }

    return _artifactPromptPattern.hasMatch(value);
  }

  bool _looksLikeInternalFailure(String response, String? userPrompt) {
    final lowered = response.toLowerCase();
    if (!_internalFailurePattern.hasMatch(lowered)) {
      return false;
    }

    // Allow error-shaped text when the user is explicitly debugging or asking
    // for the literal error content.
    final prompt = userPrompt?.toLowerCase() ?? '';
    if (prompt.contains('error') ||
        prompt.contains('exception') ||
        prompt.contains('stacktrace') ||
        prompt.contains('stack trace') ||
        prompt.contains('log') ||
        prompt.contains('debug')) {
      return false;
    }

    return true;
  }

  static final RegExp _toolMarkerPattern = RegExp(
    r'<\s*(?:/?tool_call|/?arg_key|/?arg_value)\b',
    caseSensitive: false,
  );

  static final RegExp _promisePattern = RegExp(
    r"\b(?:i(?:'ll| will| can| am going to)|let me|i'm going to|i’m going to|i can create|i will create|i'll create|i can generate|i will generate|let me create|let me generate)\b",
    caseSensitive: false,
  );

  static final RegExp _completionPattern = RegExp(
    r'\b(?:created|generated|attached|saved|delivered|ready|included|completed|provided|persisted)\b',
    caseSensitive: false,
  );

  static final RegExp _artifactPromptPattern = RegExp(
    r'\b(?:docx?|pdf|xlsx|spreadsheet|workbook|downloadable|artifact|file|report)\b',
    caseSensitive: false,
  );

  static final RegExp _internalFailurePattern = RegExp(
    r'\b(?:no response emitted|cloud request failed|bad state:|socketexception|clientexception|connection reset by peer|did not emit a valid|something went wrong)\b',
    caseSensitive: false,
  );
}
