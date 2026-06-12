import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/skills/skills.dart';

void main() {
  test('registry exposes the three initial skill descriptors', () {
    expect(SkillRegistry.all, hasLength(3));
    expect(
      SkillRegistry.skillIds(),
      equals(<String>[
        'research_report_skill',
        'document_generation_skill',
        'model_comparison_skill',
      ]),
    );
  });

  test('initial skill subgraphs use explicit ordered step ids', () {
    expect(
      SkillRegistry.researchReportSkill.subgraph.stepIds,
      equals(<String>[
        'research_report_skill.classify_request',
        'research_report_skill.gather_evidence',
        'research_report_skill.rank_evidence',
        'research_report_skill.synthesize_report',
        'research_report_skill.verify_report',
        'research_report_skill.emit_response',
      ]),
    );
    expect(
      SkillRegistry.documentGenerationSkill.subgraph.stepIds,
      equals(<String>[
        'document_generation_skill.determine_format',
        'document_generation_skill.build_content_model',
        'document_generation_skill.validate_structure',
        'document_generation_skill.render_artifact',
        'document_generation_skill.persist_artifact',
        'document_generation_skill.compose_response',
      ]),
    );
    expect(
      SkillRegistry.modelComparisonSkill.subgraph.stepIds,
      equals(<String>[
        'model_comparison_skill.normalize_models',
        'model_comparison_skill.gather_model_data',
        'model_comparison_skill.compare_dimensions',
        'model_comparison_skill.rank_recommendation',
        'model_comparison_skill.verify_comparison',
        'model_comparison_skill.emit_response',
      ]),
    );
  });

  test('registry filters consumed single-use skills and side-effecting skills', () {
    final documentContext = const SkillContext(
      requestKind: SkillRequestKind.document,
    );
    final availableDocumentSkills = SkillRegistry.availableSkills(
      documentContext,
    );
    expect(availableDocumentSkills, hasLength(1));
    expect(availableDocumentSkills.single.skillId, 'document_generation_skill');

    final consumedDocumentSkills = SkillRegistry.availableSkills(
      const SkillContext(
        requestKind: SkillRequestKind.document,
        consumedSkillIds: <String>{'document_generation_skill'},
      ),
    );
    expect(consumedDocumentSkills, isEmpty);

    final readOnlySkills = SkillRegistry.availableSkills(
      const SkillContext(
        requestKind: SkillRequestKind.general,
        allowSideEffects: false,
      ),
    );
    expect(
      readOnlySkills.map((skill) => skill.skillId),
      containsAll(<String>[
        'research_report_skill',
        'model_comparison_skill',
      ]),
    );
    expect(
      readOnlySkills.any((skill) => skill.skillId == 'document_generation_skill'),
      isFalse,
    );
  });
}
