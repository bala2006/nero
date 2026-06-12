import '../../audit/domain/app_capability.dart';

class DiagramRenderResultAction {
  const DiagramRenderResultAction({
    required this.status,
    required this.detail,
    required this.capabilityKey,
    required this.capabilityTitle,
  });

  final DiagramRenderOutcomeStatus status;
  final String detail;
  final String capabilityKey;
  final String capabilityTitle;
}

enum DiagramRenderOutcomeStatus { completed, failed }

class DiagramRenderResultHandler {
  const DiagramRenderResultHandler();

  DiagramRenderResultAction? buildAction({
    required bool hasTask,
    required bool hasRenderStep,
    required bool matchesActiveAssistant,
    required bool success,
    String? error,
  }) {
    if (!hasTask || !hasRenderStep || !matchesActiveAssistant) {
      return null;
    }
    return DiagramRenderResultAction(
      status: success
          ? DiagramRenderOutcomeStatus.completed
          : DiagramRenderOutcomeStatus.failed,
      detail: success ? 'Diagram rendered successfully.' : (error ?? 'Diagram render failed.'),
      capabilityKey: AppCapabilities.diagramRender.key,
      capabilityTitle: AppCapabilities.diagramRender.label,
    );
  }
}
