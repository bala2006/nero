import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/skills/skills.dart';

void main() {
  test('runner executes a skill subgraph in order and validates output', () async {
    final runner = SkillRunner();
    final result = await runner.run(
      skillId: 'research_report_skill',
      input: const <String, Object?>{
        'topic': 'GATE exam preparation',
        'depth': 'deep',
      },
      context: const SkillContext(
        requestKind: SkillRequestKind.research,
      ),
      stepExecutor: (context) {
        return SkillStepResult.completed(
          stepId: context.step.id,
          output: switch (context.step.id) {
            'research_report_skill.classify_request' => <String, Object?>{
                'classification': 'research',
                'research_scope': 'structured',
              },
            'research_report_skill.gather_evidence' => <String, Object?>{
                'evidence': <Object?>[
                  <String, Object?>{'source': 'web', 'title': 'Result 1'},
                ],
                'source_index': <Object?>['web:1'],
              },
            'research_report_skill.rank_evidence' => <String, Object?>{
                'ranked_evidence': <Object?>[
                  <String, Object?>{'source': 'web', 'score': 0.95},
                ],
              },
            'research_report_skill.synthesize_report' => <String, Object?>{
                'summary': 'A compact research summary.',
                'findings': <Object?>['Finding 1'],
                'recommendation': 'Use the concise approach.',
              },
            'research_report_skill.verify_report' => <String, Object?>{
                'verification_status': 'ok',
              },
            'research_report_skill.emit_response' => <String, Object?>{
                'summary': 'A compact research summary.',
                'evidence': <Object?>[
                  <String, Object?>{'source': 'web', 'title': 'Result 1'},
                ],
                'findings': <Object?>['Finding 1'],
                'recommendation': 'Use the concise approach.',
              },
            _ => <String, Object?>{},
          },
        );
      },
    );

    expect(result.status, SkillRunStatus.completed);
    expect(
      result.completedStepIds,
      equals(SkillRegistry.researchReportSkill.subgraph.stepIds),
    );
    expect(result.output['summary'], 'A compact research summary.');
    expect(result.output['findings'], isA<List>());
    expect(result.output['evidence'], isA<List>());
    expect(result.output['recommendation'], 'Use the concise approach.');
  });

  test('runner fails closed on missing input for a skill', () async {
    final runner = SkillRunner();
    final result = await runner.run(
      skillId: 'document_generation_skill',
      input: const <String, Object?>{
        'format': 'docx',
        'markdown_content': '# Missing title',
      },
      context: const SkillContext(
        requestKind: SkillRequestKind.document,
      ),
    );

    expect(result.status, SkillRunStatus.blocked);
    expect(result.blockedReason, contains('title'));
    expect(result.steps, isEmpty);
  });

  test('runner blocks consumed single-use skills', () async {
    final runner = SkillRunner();
    final result = await runner.run(
      skillId: 'document_generation_skill',
      input: const <String, Object?>{
        'title': 'Generated doc',
        'format': 'docx',
        'markdown_content': '# Body',
      },
      context: const SkillContext(
        requestKind: SkillRequestKind.document,
        consumedSkillIds: <String>{'document_generation_skill'},
      ),
    );

    expect(result.status, SkillRunStatus.blocked);
    expect(result.blockedReason, contains('already consumed'));
    expect(result.skill, isNotNull);
    expect(result.steps, isEmpty);
  });

  test('runner blocks unknown skill ids safely', () async {
    final runner = SkillRunner();
    final result = await runner.run(
      skillId: 'does_not_exist',
      input: const <String, Object?>{},
      context: const SkillContext(),
    );

    expect(result.status, SkillRunStatus.blocked);
    expect(result.skill, isNull);
    expect(result.blockedReason, contains('Unknown skill'));
  });
}
