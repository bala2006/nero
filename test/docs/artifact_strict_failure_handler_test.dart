import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/artifact_strict_failure_handler.dart';
import 'package:nero/features/docs/application/artifact_request_policy.dart';

void main() {
  const handler = ArtifactStrictFailureHandler();

  test('apply returns null when there is no strict failure resolution', () {
    var failedStep = false;
    var reportedError = false;

    final response = handler.apply(
      resolution: null,
      hasDocumentStep: true,
      onDocumentStepFailed: (_) => failedStep = true,
      onError: (_) => reportedError = true,
    );

    expect(response, isNull);
    expect(failedStep, isFalse);
    expect(reportedError, isFalse);
  });

  test('apply fails document step and reports error when resolution exists', () {
    String? stepError;
    String? reportedError;

    final response = handler.apply(
      resolution: const ArtifactStrictFailureResolution(
        errorMessage: 'No valid artifact was produced.',
        userResponse: 'I could not complete the file request.',
        stepError: 'Artifact generation ended without a valid file.',
      ),
      hasDocumentStep: true,
      onDocumentStepFailed: (error) => stepError = error,
      onError: (errorMessage) => reportedError = errorMessage,
    );

    expect(response, 'I could not complete the file request.');
    expect(stepError, 'Artifact generation ended without a valid file.');
    expect(reportedError, 'No valid artifact was produced.');
  });

  test('apply skips document step mutation when no document step exists', () {
    var failedStep = false;
    String? reportedError;

    final response = handler.apply(
      resolution: const ArtifactStrictFailureResolution(
        errorMessage: 'No valid artifact was produced.',
        userResponse: 'I could not complete the file request.',
        stepError: 'Artifact generation ended without a valid file.',
      ),
      hasDocumentStep: false,
      onDocumentStepFailed: (_) => failedStep = true,
      onError: (errorMessage) => reportedError = errorMessage,
    );

    expect(response, 'I could not complete the file request.');
    expect(failedStep, isFalse);
    expect(reportedError, 'No valid artifact was produced.');
  });
}
