import '../domain/request_classification.dart';
import '../../skills/skills.dart';
import '../domain/run_route.dart';

class RunRouteSelector {
  const RunRouteSelector();

  RunRouteSelection select({
    required String prompt,
    required SelectedSkillPlan? selectedSkill,
    RequestClassification? classification,
  }) {
    if (selectedSkill != null) {
      final skillId = selectedSkill.skill.skillId;
      if (skillId == 'document_generation_skill') {
        return RunRouteSelection(
          route: RunRoute.skillFirst,
          qualityMode: RunQualityMode.artifactCritical,
          reason: 'Document skill selected for artifact generation.',
          metadata: <String, Object?>{
            'skillId': skillId,
            'requestKind': skillRequestKindToJson(
              selectedSkill.context.requestKind,
            ),
          },
        );
      }
      if (skillId == 'research_report_skill' ||
          skillId == 'model_comparison_skill') {
        return RunRouteSelection(
          route: RunRoute.skillFirst,
          qualityMode: RunQualityMode.highAccuracy,
          reason:
              'Research-oriented skill selected for evidence-first execution.',
          metadata: <String, Object?>{
            'skillId': skillId,
            'requestKind': skillRequestKindToJson(
              selectedSkill.context.requestKind,
            ),
          },
        );
      }
    }

    final requestClassification = classification;
    if (requestClassification != null) {
      if (requestClassification.isHybrid) {
        return RunRouteSelection(
          route: RunRoute.workflowFirst,
          qualityMode: RunQualityMode.highAccuracy,
          reason: requestClassification.reason,
          metadata: <String, Object?>{
            'requestKind': requestClassification.requestKind.name,
            'artifactKind': requestClassification.artifactKind.name,
            'requiresExternalContext':
                requestClassification.requiresExternalContext,
            'requiresSideEffect': requestClassification.requiresSideEffect,
            'confidence': requestClassification.confidence,
          },
        );
      }
      if (requestClassification.requestKind == RequestKind.artifactGeneration) {
        return RunRouteSelection(
          route: RunRoute.artifactFirst,
          qualityMode: RunQualityMode.artifactCritical,
          reason: requestClassification.reason,
          metadata: <String, Object?>{
            'requestKind': requestClassification.requestKind.name,
            'artifactKind': requestClassification.artifactKind.name,
            'requiresExternalContext':
                requestClassification.requiresExternalContext,
            'confidence': requestClassification.confidence,
          },
        );
      }
      if (requestClassification.requestKind == RequestKind.researchAnswer) {
        return RunRouteSelection(
          route: RunRoute.researchFirst,
          qualityMode: RunQualityMode.highAccuracy,
          reason: requestClassification.reason,
          metadata: <String, Object?>{
            'requestKind': requestClassification.requestKind.name,
            'confidence': requestClassification.confidence,
          },
        );
      }
      if (requestClassification.requestKind == RequestKind.workspaceEdit) {
        return RunRouteSelection(
          route: RunRoute.workflowFirst,
          qualityMode: RunQualityMode.balanced,
          reason: requestClassification.reason,
          metadata: <String, Object?>{
            'requestKind': requestClassification.requestKind.name,
            'artifactKind': requestClassification.artifactKind.name,
            'confidence': requestClassification.confidence,
          },
        );
      }
    }

    final lowered = prompt.toLowerCase();
    final asksForArtifact =
        lowered.contains('doc') ||
        lowered.contains('pdf') ||
        lowered.contains('xlsx') ||
        lowered.contains('excel') ||
        lowered.contains('spreadsheet') ||
        lowered.contains('file') ||
        lowered.contains('report');
    final asksForResearch =
        lowered.contains('research') ||
        lowered.contains('find out') ||
        lowered.contains('latest') ||
        lowered.contains('compare') ||
        lowered.contains('vs') ||
        lowered.contains('which model') ||
        lowered.contains('best');
    final asksForWorkflow =
        lowered.contains('step by step') ||
        lowered.contains('workflow') ||
        lowered.contains('plan and execute') ||
        lowered.contains('build') ||
        lowered.contains('implement');

    if (asksForArtifact) {
      return const RunRouteSelection(
        route: RunRoute.artifactFirst,
        qualityMode: RunQualityMode.artifactCritical,
        reason: 'Prompt requests a generated artifact.',
      );
    }
    if (asksForResearch) {
      return const RunRouteSelection(
        route: RunRoute.researchFirst,
        qualityMode: RunQualityMode.highAccuracy,
        reason: 'Prompt benefits from evidence-first execution.',
      );
    }
    if (asksForWorkflow) {
      return const RunRouteSelection(
        route: RunRoute.workflowFirst,
        qualityMode: RunQualityMode.balanced,
        reason: 'Prompt implies a multi-step workflow.',
      );
    }
    return const RunRouteSelection(
      route: RunRoute.direct,
      qualityMode: RunQualityMode.fast,
      reason: 'Prompt can be handled as a direct response.',
    );
  }
}
