import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/runtime/application/run_route_selector.dart';
import 'package:nero/features/runtime/domain/run_route.dart';
import 'package:nero/features/skills/skills.dart';

void main() {
  const selector = RunRouteSelector();

  test('artifact prompts route to artifact critical mode', () {
    final selection = selector.select(
      prompt: 'Generate a PDF report about Nero in 2 pages.',
      selectedSkill: null,
    );

    expect(selection.route, RunRoute.artifactFirst);
    expect(selection.qualityMode, RunQualityMode.artifactCritical);
  });

  test('research prompts route to high accuracy mode', () {
    final selection = selector.select(
      prompt: 'Research and compare Claude Code vs Codex.',
      selectedSkill: null,
    );

    expect(selection.route, RunRoute.researchFirst);
    expect(selection.qualityMode, RunQualityMode.highAccuracy);
  });

  test('selected document skill upgrades route to skill-first', () {
    final plan = SelectedSkillPlan(
      skill: SkillRegistry.documentGenerationSkill,
      context: const SkillContext(requestKind: SkillRequestKind.document),
      input: const <String, Object?>{
        'title': 'Doc',
        'format': 'docx',
        'markdown_content': '# Body',
      },
      instruction: 'Use the document skill.',
    );

    final selection = selector.select(
      prompt: 'Generate a docx file.',
      selectedSkill: plan,
    );

    expect(selection.route, RunRoute.skillFirst);
    expect(selection.qualityMode, RunQualityMode.artifactCritical);
  });
}
