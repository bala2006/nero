import 'dart:async';

import '../domain/skill_models.dart';
import '../domain/skill_registry.dart';

enum SkillStepStatus { pending, running, completed, skipped, blocked, failed }

SkillStepStatus skillStepStatusFromJson(String? value) {
  return switch (value) {
    'pending' => SkillStepStatus.pending,
    'running' => SkillStepStatus.running,
    'completed' => SkillStepStatus.completed,
    'skipped' => SkillStepStatus.skipped,
    'blocked' => SkillStepStatus.blocked,
    'failed' => SkillStepStatus.failed,
    _ => SkillStepStatus.completed,
  };
}

String skillStepStatusToJson(SkillStepStatus status) {
  return switch (status) {
    SkillStepStatus.pending => 'pending',
    SkillStepStatus.running => 'running',
    SkillStepStatus.completed => 'completed',
    SkillStepStatus.skipped => 'skipped',
    SkillStepStatus.blocked => 'blocked',
    SkillStepStatus.failed => 'failed',
  };
}

enum SkillRunStatus { queued, running, blocked, completed, failed }

SkillRunStatus skillRunStatusFromJson(String? value) {
  return switch (value) {
    'queued' => SkillRunStatus.queued,
    'running' => SkillRunStatus.running,
    'blocked' => SkillRunStatus.blocked,
    'completed' => SkillRunStatus.completed,
    'failed' => SkillRunStatus.failed,
    _ => SkillRunStatus.queued,
  };
}

String skillRunStatusToJson(SkillRunStatus status) {
  return switch (status) {
    SkillRunStatus.queued => 'queued',
    SkillRunStatus.running => 'running',
    SkillRunStatus.blocked => 'blocked',
    SkillRunStatus.completed => 'completed',
    SkillRunStatus.failed => 'failed',
  };
}

class SkillStepExecutionContext {
  const SkillStepExecutionContext({
    required this.skill,
    required this.step,
    required this.context,
    required this.input,
    required this.previousSteps,
    required this.stepIndex,
  });

  final SkillDescriptor skill;
  final SkillStepDescriptor step;
  final SkillContext context;
  final Map<String, Object?> input;
  final List<SkillStepResult> previousSteps;
  final int stepIndex;

  bool get isTerminalStep => step.id == skill.subgraph.terminalStepId;
}

typedef SkillStepExecutor = FutureOr<SkillStepResult> Function(
  SkillStepExecutionContext context,
);

class SkillStepResult {
  const SkillStepResult({
    required this.stepId,
    required this.status,
    this.summary,
    this.debugSummary,
    this.output = const <String, Object?>{},
    this.error,
    this.metadata = const <String, Object?>{},
    this.startedAtEpochMs,
    this.finishedAtEpochMs,
  });

  factory SkillStepResult.completed({
    required String stepId,
    String? summary,
    String? debugSummary,
    Map<String, Object?> output = const <String, Object?>{},
    Map<String, Object?> metadata = const <String, Object?>{},
    int? startedAtEpochMs,
    int? finishedAtEpochMs,
  }) {
    return SkillStepResult(
      stepId: stepId,
      status: SkillStepStatus.completed,
      summary: summary,
      debugSummary: debugSummary,
      output: output,
      metadata: metadata,
      startedAtEpochMs: startedAtEpochMs,
      finishedAtEpochMs: finishedAtEpochMs,
    );
  }

  factory SkillStepResult.blocked({
    required String stepId,
    required String error,
    String? summary,
    Map<String, Object?> output = const <String, Object?>{},
    Map<String, Object?> metadata = const <String, Object?>{},
    int? startedAtEpochMs,
    int? finishedAtEpochMs,
  }) {
    return SkillStepResult(
      stepId: stepId,
      status: SkillStepStatus.blocked,
      summary: summary,
      output: output,
      error: error,
      metadata: metadata,
      startedAtEpochMs: startedAtEpochMs,
      finishedAtEpochMs: finishedAtEpochMs,
    );
  }

  factory SkillStepResult.failed({
    required String stepId,
    required String error,
    String? summary,
    Map<String, Object?> output = const <String, Object?>{},
    Map<String, Object?> metadata = const <String, Object?>{},
    int? startedAtEpochMs,
    int? finishedAtEpochMs,
  }) {
    return SkillStepResult(
      stepId: stepId,
      status: SkillStepStatus.failed,
      summary: summary,
      output: output,
      error: error,
      metadata: metadata,
      startedAtEpochMs: startedAtEpochMs,
      finishedAtEpochMs: finishedAtEpochMs,
    );
  }

  final String stepId;
  final SkillStepStatus status;
  final String? summary;
  final String? debugSummary;
  final Map<String, Object?> output;
  final String? error;
  final Map<String, Object?> metadata;
  final int? startedAtEpochMs;
  final int? finishedAtEpochMs;

  Duration? get duration {
    if (startedAtEpochMs == null || finishedAtEpochMs == null) {
      return null;
    }
    return Duration(milliseconds: finishedAtEpochMs! - startedAtEpochMs!);
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'stepId': stepId,
      'status': skillStepStatusToJson(status),
      'summary': summary,
      'debugSummary': debugSummary,
      'output': output,
      'error': error,
      'metadata': metadata,
      'startedAtEpochMs': startedAtEpochMs,
      'finishedAtEpochMs': finishedAtEpochMs,
    };
  }
}

class SkillRunResult {
  const SkillRunResult({
    required this.skill,
    required this.status,
    required this.input,
    required this.steps,
    required this.metadata,
    required this.startedAtEpochMs,
    required this.finishedAtEpochMs,
    this.output = const <String, Object?>{},
    this.blockedReason,
    this.error,
  });

  factory SkillRunResult.completed({
    required SkillDescriptor skill,
    required Map<String, Object?> input,
    required Map<String, Object?> output,
    required List<SkillStepResult> steps,
    required Map<String, Object?> metadata,
    required int startedAtEpochMs,
    required int finishedAtEpochMs,
  }) {
    return SkillRunResult(
      skill: skill,
      status: SkillRunStatus.completed,
      input: input,
      output: output,
      steps: steps,
      metadata: metadata,
      startedAtEpochMs: startedAtEpochMs,
      finishedAtEpochMs: finishedAtEpochMs,
    );
  }

  factory SkillRunResult.blocked({
    required SkillDescriptor? skill,
    required Map<String, Object?> input,
    required List<SkillStepResult> steps,
    required Map<String, Object?> metadata,
    required int startedAtEpochMs,
    required int finishedAtEpochMs,
    required String blockedReason,
    String? error,
  }) {
    return SkillRunResult(
      skill: skill,
      status: SkillRunStatus.blocked,
      input: input,
      steps: steps,
      metadata: metadata,
      startedAtEpochMs: startedAtEpochMs,
      finishedAtEpochMs: finishedAtEpochMs,
      blockedReason: blockedReason,
      error: error,
    );
  }

  factory SkillRunResult.failed({
    required SkillDescriptor skill,
    required Map<String, Object?> input,
    required List<SkillStepResult> steps,
    required Map<String, Object?> metadata,
    required int startedAtEpochMs,
    required int finishedAtEpochMs,
    required String error,
    Map<String, Object?> output = const <String, Object?>{},
  }) {
    return SkillRunResult(
      skill: skill,
      status: SkillRunStatus.failed,
      input: input,
      output: output,
      steps: steps,
      metadata: metadata,
      startedAtEpochMs: startedAtEpochMs,
      finishedAtEpochMs: finishedAtEpochMs,
      error: error,
    );
  }

  final SkillDescriptor? skill;
  final SkillRunStatus status;
  final Map<String, Object?> input;
  final Map<String, Object?> output;
  final List<SkillStepResult> steps;
  final Map<String, Object?> metadata;
  final int startedAtEpochMs;
  final int finishedAtEpochMs;
  final String? blockedReason;
  final String? error;

  Duration get duration =>
      Duration(milliseconds: finishedAtEpochMs - startedAtEpochMs);

  List<String> get completedStepIds =>
      steps.map((step) => step.stepId).toList(growable: false);

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'skillId': skill?.skillId,
      'status': skillRunStatusToJson(status),
      'input': input,
      'output': output,
      'steps': steps.map((step) => step.toMap()).toList(growable: false),
      'metadata': metadata,
      'startedAtEpochMs': startedAtEpochMs,
      'finishedAtEpochMs': finishedAtEpochMs,
      'blockedReason': blockedReason,
      'error': error,
    };
  }
}

class SkillRunner {
  SkillRunner({
    SkillDescriptor? Function(String skillId)? lookup,
    SkillStepExecutor? defaultStepExecutor,
  }) : _lookup = lookup ?? SkillRegistry.byId,
       _defaultStepExecutor = defaultStepExecutor ?? _buildDefaultStepResult;

  final SkillDescriptor? Function(String skillId) _lookup;
  final SkillStepExecutor _defaultStepExecutor;

  Future<SkillRunResult> run({
    required String skillId,
    required Map<String, Object?> input,
    required SkillContext context,
    SkillStepExecutor? stepExecutor,
  }) async {
    final startedAtEpochMs = DateTime.now().millisecondsSinceEpoch;
    final skill = _lookup(skillId);
    if (skill == null) {
      return SkillRunResult.blocked(
        skill: null,
        input: input,
        steps: const <SkillStepResult>[],
        metadata: <String, Object?>{
          'skillId': skillId,
          'reason': 'unknown_skill',
        },
        startedAtEpochMs: startedAtEpochMs,
        finishedAtEpochMs: startedAtEpochMs,
        blockedReason: 'Unknown skill: $skillId',
        error: 'Skill registry lookup failed.',
      );
    }

    final issues = skill.validateStructure();
    if (issues.isNotEmpty) {
      return SkillRunResult.failed(
        skill: skill,
        input: input,
        steps: const <SkillStepResult>[],
        metadata: <String, Object?>{
          'skillId': skill.skillId,
          'structure_issues': issues,
        },
        startedAtEpochMs: startedAtEpochMs,
        finishedAtEpochMs: startedAtEpochMs,
        error: issues.join(' '),
      );
    }

    if (!skill.isAvailableFor(context)) {
      return SkillRunResult.blocked(
        skill: skill,
        input: input,
        steps: const <SkillStepResult>[],
        metadata: <String, Object?>{
          'skillId': skill.skillId,
          'requestKind': skillRequestKindToJson(context.requestKind),
        },
        startedAtEpochMs: startedAtEpochMs,
        finishedAtEpochMs: startedAtEpochMs,
        blockedReason: _blockedReason(skill, context),
      );
    }

    final inputIssues = skill.inputContract.validate(input);
    if (inputIssues.isNotEmpty) {
      return SkillRunResult.blocked(
        skill: skill,
        input: input,
        steps: const <SkillStepResult>[],
        metadata: <String, Object?>{
          'skillId': skill.skillId,
          'input_issues': inputIssues,
        },
        startedAtEpochMs: startedAtEpochMs,
        finishedAtEpochMs: startedAtEpochMs,
        blockedReason: inputIssues.first,
      );
    }

    final executor = stepExecutor ?? _defaultStepExecutor;
    final stepResults = <SkillStepResult>[];
    final mergedOutput = <String, Object?>{};

    for (var index = 0; index < skill.subgraph.steps.length; index++) {
      final step = skill.subgraph.steps[index];
      final stepContext = SkillStepExecutionContext(
        skill: skill,
        step: step,
        context: context,
        input: input,
        previousSteps: List<SkillStepResult>.unmodifiable(stepResults),
        stepIndex: index,
      );

      final stepStartedAt = DateTime.now().millisecondsSinceEpoch;
      SkillStepResult stepResult;
      try {
        stepResult = await Future<SkillStepResult>.value(executor(stepContext));
      } catch (error) {
        final finishedAt = DateTime.now().millisecondsSinceEpoch;
        stepResults.add(
          SkillStepResult.failed(
            stepId: step.id,
            error: error.toString(),
            startedAtEpochMs: stepStartedAt,
            finishedAtEpochMs: finishedAt,
          ),
        );
        return SkillRunResult.failed(
          skill: skill,
          input: input,
          steps: List<SkillStepResult>.unmodifiable(stepResults),
          metadata: <String, Object?>{
            'skillId': skill.skillId,
            'failed_step_id': step.id,
          },
          startedAtEpochMs: startedAtEpochMs,
          finishedAtEpochMs: finishedAt,
          error: error.toString(),
          output: mergedOutput,
        );
      }

      final finishedAt = DateTime.now().millisecondsSinceEpoch;
      if (stepResult.stepId != step.id) {
        final error = 'Step executor returned ${stepResult.stepId} for ${step.id}.';
        stepResults.add(
          SkillStepResult.failed(
            stepId: step.id,
            error: error,
            startedAtEpochMs: stepStartedAt,
            finishedAtEpochMs: finishedAt,
          ),
        );
        return SkillRunResult.failed(
          skill: skill,
          input: input,
          steps: List<SkillStepResult>.unmodifiable(stepResults),
          metadata: <String, Object?>{
            'skillId': skill.skillId,
            'failed_step_id': step.id,
          },
          startedAtEpochMs: startedAtEpochMs,
          finishedAtEpochMs: finishedAt,
          error: error,
          output: mergedOutput,
        );
      }

      final normalizedStepResult = SkillStepResult(
        stepId: stepResult.stepId,
        status: stepResult.status,
        summary: stepResult.summary,
        debugSummary: stepResult.debugSummary,
        output: stepResult.output,
        error: stepResult.error,
        metadata: stepResult.metadata,
        startedAtEpochMs: stepStartedAt,
        finishedAtEpochMs: finishedAt,
      );
      stepResults.add(normalizedStepResult);
      mergedOutput.addAll(normalizedStepResult.output);

      if (normalizedStepResult.status == SkillStepStatus.blocked) {
        return SkillRunResult.blocked(
          skill: skill,
          input: input,
          steps: List<SkillStepResult>.unmodifiable(stepResults),
          metadata: <String, Object?>{
            'skillId': skill.skillId,
            'blocked_step_id': step.id,
          },
          startedAtEpochMs: startedAtEpochMs,
          finishedAtEpochMs: finishedAt,
          blockedReason:
              normalizedStepResult.error ?? 'Step blocked: ${step.id}',
          error: normalizedStepResult.error,
        );
      }
      if (normalizedStepResult.status == SkillStepStatus.failed) {
        return SkillRunResult.failed(
          skill: skill,
          input: input,
          steps: List<SkillStepResult>.unmodifiable(stepResults),
          metadata: <String, Object?>{
            'skillId': skill.skillId,
            'failed_step_id': step.id,
          },
          startedAtEpochMs: startedAtEpochMs,
          finishedAtEpochMs: finishedAt,
          error: normalizedStepResult.error ?? 'Step failed: ${step.id}',
          output: mergedOutput,
        );
      }
    }

    final outputIssues = skill.outputContract.validate(mergedOutput);
    if (outputIssues.isNotEmpty) {
      final finishedAt = DateTime.now().millisecondsSinceEpoch;
      return SkillRunResult.failed(
        skill: skill,
        input: input,
        steps: List<SkillStepResult>.unmodifiable(stepResults),
        metadata: <String, Object?>{
          'skillId': skill.skillId,
          'output_issues': outputIssues,
        },
        startedAtEpochMs: startedAtEpochMs,
        finishedAtEpochMs: finishedAt,
        error: outputIssues.join(' '),
        output: mergedOutput,
      );
    }

    final finishedAt = DateTime.now().millisecondsSinceEpoch;
    return SkillRunResult.completed(
      skill: skill,
      input: input,
      output: Map<String, Object?>.unmodifiable(mergedOutput),
      steps: List<SkillStepResult>.unmodifiable(stepResults),
      metadata: <String, Object?>{
        'skillId': skill.skillId,
        'step_ids': stepResults.map((step) => step.stepId).toList(growable: false),
        'requestKind': skillRequestKindToJson(context.requestKind),
      },
      startedAtEpochMs: startedAtEpochMs,
      finishedAtEpochMs: finishedAt,
    );
  }

  static FutureOr<SkillStepResult> _buildDefaultStepResult(
    SkillStepExecutionContext context,
  ) {
    return SkillStepResult.completed(
      stepId: context.step.id,
      summary: context.step.description,
      debugSummary: 'Dry-run step recorded for ${context.step.id}.',
      output: <String, Object?>{
        'step_id': context.step.id,
        'skill_id': context.skill.skillId,
        'step_kind': skillStepKindToJson(context.step.kind),
        'step_title': context.step.title,
        'step_index': context.stepIndex,
        'terminal': context.isTerminalStep,
      },
      metadata: <String, Object?>{
        'input_keys': context.step.inputKeys,
        'output_keys': context.step.outputKeys,
      },
    );
  }

  static String _blockedReason(
    SkillDescriptor skill,
    SkillContext context,
  ) {
    if (skill.policy.singleUse && context.consumedSkillIds.contains(skill.skillId)) {
      return 'Skill already consumed: ${skill.skillId}';
    }
    final isSideEffecting =
        skill.policy.sideEffectPolicy != SkillSideEffectPolicy.none &&
        skill.policy.sideEffectPolicy != SkillSideEffectPolicy.readOnly;
    if (!context.allowSideEffects && isSideEffecting) {
      return 'Skill requires side effects: ${skill.skillId}';
    }
    return 'Skill not available for the current context: ${skill.skillId}';
  }
}
