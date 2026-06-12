enum AgentTaskStatus {
  queued,
  running,
  waitingUser,
  completed,
  failed,
  cancelled,
}

AgentTaskStatus agentTaskStatusFromJson(String? value) {
  return switch (value) {
    'queued' => AgentTaskStatus.queued,
    'running' => AgentTaskStatus.running,
    'waitingUser' => AgentTaskStatus.waitingUser,
    'completed' => AgentTaskStatus.completed,
    'failed' => AgentTaskStatus.failed,
    'cancelled' => AgentTaskStatus.cancelled,
    _ => AgentTaskStatus.queued,
  };
}

String agentTaskStatusToJson(AgentTaskStatus status) {
  return switch (status) {
    AgentTaskStatus.queued => 'queued',
    AgentTaskStatus.running => 'running',
    AgentTaskStatus.waitingUser => 'waitingUser',
    AgentTaskStatus.completed => 'completed',
    AgentTaskStatus.failed => 'failed',
    AgentTaskStatus.cancelled => 'cancelled',
  };
}

enum AgentStepStatus {
  pending,
  running,
  completed,
  failed,
  blocked,
  cancelled,
}

AgentStepStatus agentStepStatusFromJson(String? value) {
  return switch (value) {
    'pending' => AgentStepStatus.pending,
    'running' => AgentStepStatus.running,
    'completed' => AgentStepStatus.completed,
    'failed' => AgentStepStatus.failed,
    'blocked' => AgentStepStatus.blocked,
    'cancelled' => AgentStepStatus.cancelled,
    _ => AgentStepStatus.pending,
  };
}

String agentStepStatusToJson(AgentStepStatus status) {
  return switch (status) {
    AgentStepStatus.pending => 'pending',
    AgentStepStatus.running => 'running',
    AgentStepStatus.completed => 'completed',
    AgentStepStatus.failed => 'failed',
    AgentStepStatus.blocked => 'blocked',
    AgentStepStatus.cancelled => 'cancelled',
  };
}

abstract final class AgentStepKinds {
  static const String interpretPrompt = 'interpretPrompt';
  static const String planTask = 'planTask';
  static const String toolResearch = 'toolResearch';
  static const String synthesizeResponse = 'synthesizeResponse';
  static const String generateDocument = 'generateDocument';
  static const String prepareResponse = 'prepareResponse';
  static const String streamResponse = 'streamResponse';
  static const String renderDiagram = 'renderDiagram';
  static const String createFiles = 'createFiles';
  static const String packageProject = 'packageProject';
}

class AgentStep {
  const AgentStep({
    required this.id,
    required this.kind,
    required this.title,
    required this.status,
    this.detail,
    this.startedAtEpochMs,
    this.completedAtEpochMs,
    this.error,
  });

  final String id;
  final String kind;
  final String title;
  final AgentStepStatus status;
  final String? detail;
  final int? startedAtEpochMs;
  final int? completedAtEpochMs;
  final String? error;

  AgentStep copyWith({
    String? id,
    String? kind,
    String? title,
    AgentStepStatus? status,
    String? detail,
    bool clearDetail = false,
    int? startedAtEpochMs,
    bool clearStartedAtEpochMs = false,
    int? completedAtEpochMs,
    bool clearCompletedAtEpochMs = false,
    String? error,
    bool clearError = false,
  }) {
    return AgentStep(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      status: status ?? this.status,
      detail: clearDetail ? null : detail ?? this.detail,
      startedAtEpochMs: clearStartedAtEpochMs
          ? null
          : startedAtEpochMs ?? this.startedAtEpochMs,
      completedAtEpochMs: clearCompletedAtEpochMs
          ? null
          : completedAtEpochMs ?? this.completedAtEpochMs,
      error: clearError ? null : error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind,
        'title': title,
        'status': agentStepStatusToJson(status),
        'detail': detail,
        'startedAtEpochMs': startedAtEpochMs,
        'completedAtEpochMs': completedAtEpochMs,
        'error': error,
      };

  factory AgentStep.fromJson(Map<String, dynamic> json) {
    return AgentStep(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? AgentStepKinds.interpretPrompt,
      title: json['title']?.toString() ?? '',
      status: agentStepStatusFromJson(json['status']?.toString()),
      detail: json['detail']?.toString(),
      startedAtEpochMs: (json['startedAtEpochMs'] as num?)?.toInt(),
      completedAtEpochMs: (json['completedAtEpochMs'] as num?)?.toInt(),
      error: json['error']?.toString(),
    );
  }
}

class AgentTaskProgressSnapshot {
  const AgentTaskProgressSnapshot({
    required this.completedCount,
    required this.totalCount,
    required this.completionRatio,
    required this.currentStep,
    required this.nextStep,
    required this.primaryStep,
    required this.hasFailures,
    required this.hasBlockedSteps,
    required this.isTerminal,
  });

  final int completedCount;
  final int totalCount;
  final double completionRatio;
  final AgentStep? currentStep;
  final AgentStep? nextStep;
  final AgentStep? primaryStep;
  final bool hasFailures;
  final bool hasBlockedSteps;
  final bool isTerminal;
}

class AgentTask {
  const AgentTask({
    required this.id,
    required this.conversationId,
    required this.prompt,
    required this.status,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    required this.steps,
    this.error,
  });

  final String id;
  final String conversationId;
  final String prompt;
  final AgentTaskStatus status;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  final List<AgentStep> steps;
  final String? error;

  AgentTaskProgressSnapshot get progressSnapshot {
    final completedCount = steps
        .where((step) => step.status == AgentStepStatus.completed)
        .length;
    final totalCount = steps.length;
    final completionRatio = totalCount == 0 ? 0.0 : completedCount / totalCount;
    final currentStep = _firstStepWithStatus(AgentStepStatus.running);
    final blockedStep = _firstStepWithStatus(AgentStepStatus.blocked);
    final failedStep = _firstStepWithStatus(AgentStepStatus.failed);
    final nextStep = _firstStepWithStatus(AgentStepStatus.pending);
    final lastCompleted = steps.lastWhere(
      (step) => step.status == AgentStepStatus.completed,
      orElse: () => const AgentStep(
        id: 'none',
        kind: AgentStepKinds.interpretPrompt,
        title: 'No active task',
        status: AgentStepStatus.completed,
      ),
    );
    final primaryStep =
        currentStep ??
        blockedStep ??
        failedStep ??
        nextStep ??
        (steps.isEmpty ? null : lastCompleted);
    return AgentTaskProgressSnapshot(
      completedCount: completedCount,
      totalCount: totalCount,
      completionRatio: completionRatio,
      currentStep: currentStep ?? blockedStep ?? failedStep,
      nextStep: nextStep,
      primaryStep: primaryStep,
      hasFailures: failedStep != null,
      hasBlockedSteps: blockedStep != null,
      isTerminal:
          status == AgentTaskStatus.completed ||
          status == AgentTaskStatus.failed ||
          status == AgentTaskStatus.cancelled,
    );
  }

  AgentStep? _firstStepWithStatus(AgentStepStatus status) {
    for (final step in steps) {
      if (step.status == status) {
        return step;
      }
    }
    return null;
  }

  AgentTask copyWith({
    String? id,
    String? conversationId,
    String? prompt,
    AgentTaskStatus? status,
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
    List<AgentStep>? steps,
    String? error,
    bool clearError = false,
  }) {
    return AgentTask(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      prompt: prompt ?? this.prompt,
      status: status ?? this.status,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      steps: steps ?? this.steps,
      error: clearError ? null : error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'conversationId': conversationId,
        'prompt': prompt,
        'status': agentTaskStatusToJson(status),
        'createdAtEpochMs': createdAtEpochMs,
        'updatedAtEpochMs': updatedAtEpochMs,
        'steps': steps.map((step) => step.toJson()).toList(growable: false),
        'error': error,
      };

  factory AgentTask.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'];
    return AgentTask(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      prompt: json['prompt']?.toString() ?? '',
      status: agentTaskStatusFromJson(json['status']?.toString()),
      createdAtEpochMs: (json['createdAtEpochMs'] as num?)?.toInt() ?? 0,
      updatedAtEpochMs: (json['updatedAtEpochMs'] as num?)?.toInt() ?? 0,
      steps: rawSteps is List
          ? rawSteps
              .whereType<Map>()
              .map(
                (item) => AgentStep.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const <AgentStep>[],
      error: json['error']?.toString(),
    );
  }
}
