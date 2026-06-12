import '../../docs/application/artifact_request_policy.dart';

class ArtifactStrictFailureHandler {
  const ArtifactStrictFailureHandler();

  String? apply({
    required ArtifactStrictFailureResolution? resolution,
    required bool hasDocumentStep,
    required void Function(String error) onDocumentStepFailed,
    required void Function(String errorMessage) onError,
  }) {
    if (resolution == null) {
      return null;
    }
    if (hasDocumentStep) {
      onDocumentStepFailed(resolution.stepError);
    }
    onError(resolution.errorMessage);
    return resolution.userResponse;
  }
}
