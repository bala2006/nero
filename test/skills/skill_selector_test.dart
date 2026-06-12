import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/runtime/application/request_classifier.dart';
import 'package:nero/features/skills/skills.dart';

void main() {
  const selector = SkillSelector();

  test('selects comparison skill for vs prompts', () {
    final plan = selector.select(
      prompt: 'Which model is best: kimi k2.5 vs minimax m2.7?',
      conversationId: 'c1',
      taskId: 't1',
    );

    expect(plan, isNotNull);
    expect(plan!.context.requestKind, SkillRequestKind.comparison);
    expect(plan.skill.skillId, 'model_comparison_skill');
  });

  test('treats research report phrasing as research, not document', () {
    final plan = selector.select(
      prompt: 'Create a research report on GATE exam timelines.',
      conversationId: 'c1',
      taskId: 't1',
    );

    expect(plan, isNotNull);
    expect(plan!.context.requestKind, SkillRequestKind.research);
    expect(plan.skill.skillId, 'research_report_skill');
  });

  test('selects document skill for explicit pdf/doc prompts', () {
    final plan = selector.select(
      prompt: 'Generate a PDF document about my tools in 1 page.',
      conversationId: 'c1',
      taskId: 't1',
    );

    expect(plan, isNotNull);
    expect(plan!.context.requestKind, SkillRequestKind.document);
    expect(plan.skill.skillId, 'document_generation_skill');
    expect(plan.input['format'], 'pdf');
  });

  test('returns null for plain greetings', () {
    final plan = selector.select(
      prompt: 'hi',
      conversationId: 'c1',
      taskId: 't1',
    );

    expect(plan, isNull);
  });

  test('returns null for artifact capability questions when classified', () {
    const classifier = RequestClassifier();
    final classification = classifier.classify('Can you create doc and pdf?');

    final plan = selector.select(
      prompt: 'Can you create doc and pdf?',
      conversationId: 'c1',
      taskId: 't1',
      allowSideEffects: classification.requiresSideEffect,
      classification: classification,
    );

    expect(classification.isArtifactCapabilityQuestion, isTrue);
    expect(plan, isNull);
  });

  test('uses classifier artifact intent over local regex fallback', () {
    const classifier = RequestClassifier();
    final classification = classifier.classify(
      'Research current Flutter testing guidance and create a docx report',
    );

    final plan = selector.select(
      prompt: 'Research current Flutter testing guidance and create a docx report',
      conversationId: 'c1',
      taskId: 't1',
      allowSideEffects: classification.requiresSideEffect,
      classification: classification,
    );

    expect(classification.requestKind.name, 'hybrid');
    expect(plan, isNotNull);
    expect(plan!.context.requestKind, SkillRequestKind.document);
    expect(plan.skill.skillId, 'document_generation_skill');
  });
}
