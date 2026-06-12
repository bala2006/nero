import '../../runtime/domain/request_classification.dart';
import '../domain/skill_models.dart';
import '../domain/skill_registry.dart';

class SelectedSkillPlan {
  const SelectedSkillPlan({
    required this.skill,
    required this.context,
    required this.input,
    required this.instruction,
  });

  final SkillDescriptor skill;
  final SkillContext context;
  final Map<String, Object?> input;
  final String instruction;
}

class SkillSelector {
  const SkillSelector();

  SelectedSkillPlan? select({
    required String prompt,
    required String conversationId,
    required String? taskId,
    bool allowSideEffects = true,
    RequestClassification? classification,
  }) {
    if (classification?.isArtifactCapabilityQuestion == true) {
      return null;
    }
    final effectiveAllowSideEffects =
        allowSideEffects && (classification?.requiresSideEffect ?? true);
    final requestKind =
        _requestKindFromClassification(classification) ??
        _inferRequestKind(prompt);
    if (requestKind == SkillRequestKind.general) {
      return null;
    }
    final context = SkillContext(
      conversationId: conversationId,
      taskId: taskId,
      requestKind: requestKind,
      allowSideEffects: effectiveAllowSideEffects,
    );
    final candidates = SkillRegistry.availableSkills(context);
    if (candidates.isEmpty) {
      return null;
    }

    final preferred = candidates.firstWhere(
      (skill) => skill.visibility == SkillVisibility.preferred,
      orElse: () => candidates.first,
    );
    return SelectedSkillPlan(
      skill: preferred,
      context: context,
      input: _buildInput(preferred, prompt),
      instruction: _buildInstruction(preferred),
    );
  }

  SkillRequestKind? _requestKindFromClassification(
    RequestClassification? classification,
  ) {
    if (classification == null) {
      return null;
    }
    if (classification.artifactKind != ArtifactKind.none) {
      return SkillRequestKind.document;
    }
    return switch (classification.requestKind) {
      RequestKind.researchAnswer => SkillRequestKind.research,
      RequestKind.hybrid => SkillRequestKind.research,
      RequestKind.artifactGeneration => SkillRequestKind.document,
      RequestKind.workspaceEdit => SkillRequestKind.document,
      RequestKind.directAnswer => SkillRequestKind.general,
    };
  }

  SkillRequestKind _inferRequestKind(String prompt) {
    final lowered = prompt.toLowerCase();
    if (_comparisonPattern.hasMatch(lowered)) {
      return SkillRequestKind.comparison;
    }
    if (_researchPattern.hasMatch(lowered)) {
      return SkillRequestKind.research;
    }
    if (_documentPattern.hasMatch(lowered)) {
      return SkillRequestKind.document;
    }
    return SkillRequestKind.general;
  }

  Map<String, Object?> _buildInput(SkillDescriptor skill, String prompt) {
    switch (skill.skillId) {
      case 'document_generation_skill':
        return <String, Object?>{
          'title': _deriveTitle(prompt),
          'format': _deriveDocumentFormat(prompt),
          'markdown_content': 'Content will be generated during orchestration.',
          'audience': 'general',
        };
      case 'model_comparison_skill':
        return <String, Object?>{
          'models': _extractModelCandidates(prompt),
          'criteria': const <String>['quality', 'reliability', 'fit'],
          'use_case': prompt.trim(),
        };
      case 'research_report_skill':
        return <String, Object?>{
          'topic': prompt.trim(),
          'depth': 'standard',
          'audience': 'general',
        };
      default:
        return <String, Object?>{'prompt': prompt.trim()};
    }
  }

  String _buildInstruction(SkillDescriptor skill) {
    final steps = skill.subgraph.steps
        .map((step) => '${step.title}: ${step.description}')
        .join('\n- ');
    return 'Active skill: ${skill.displayName}\n'
        'Purpose: ${skill.purpose}\n'
        'Follow this skill workflow:\n- $steps\n'
        'Keep the final answer aligned with the skill output contract.';
  }

  String _deriveTitle(String prompt) {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return 'Generated Document';
    }
    final withoutPunctuation = trimmed.replaceAll(RegExp(r'[^\w\s-]'), ' ');
    final collapsed = withoutPunctuation
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(8)
        .join(' ');
    return collapsed.isEmpty ? 'Generated Document' : collapsed;
  }

  String _deriveDocumentFormat(String prompt) {
    final lowered = prompt.toLowerCase();
    if (lowered.contains('pdf')) {
      return 'pdf';
    }
    if (lowered.contains('xlsx') || lowered.contains('excel')) {
      return 'xlsx';
    }
    return 'docx';
  }

  List<String> _extractModelCandidates(String prompt) {
    final normalized = prompt
        .replaceAll(RegExp(r'\b(vs|versus|compare|comparison)\b', caseSensitive: false), ',')
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (normalized.length >= 2) {
      return normalized.take(4).toList(growable: false);
    }
    return <String>[prompt.trim()];
  }

  static final RegExp _researchPattern = RegExp(
    r'\b(research|find out|latest|best|which model|news|compare)\b',
    caseSensitive: false,
  );

  static final RegExp _comparisonPattern = RegExp(
    r'\b(vs|versus|compare|comparison|which model)\b',
    caseSensitive: false,
  );

  static final RegExp _documentPattern = RegExp(
    r'\b(docx?|pdf|xlsx|excel|spreadsheet|workbook|document|downloadable|export|attachment)\b',
    caseSensitive: false,
  );
}
