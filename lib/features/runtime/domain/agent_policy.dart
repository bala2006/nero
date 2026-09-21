/// Agent execution policy: how autonomous a run is, how much it may spend, and
/// when it must stop and ask the user.
library;

/// How the agent should behave for a single turn.
enum AgentMode {
  /// Answer directly; no planning pass, tools only when clearly required.
  chat,

  /// Produce a plan, then execute it.
  planFirst,

  /// Plan, execute, verify and self-correct without asking between steps
  /// unless the approval policy requires it.
  auto,
}

extension AgentModeX on AgentMode {
  String get name => switch (this) {
    AgentMode.chat => 'chat',
    AgentMode.planFirst => 'planFirst',
    AgentMode.auto => 'auto',
  };

  String get label => switch (this) {
    AgentMode.chat => 'Chat',
    AgentMode.planFirst => 'Plan',
    AgentMode.auto => 'Agent',
  };

  String get description => switch (this) {
    AgentMode.chat => 'Answer directly. Tools run only when required.',
    AgentMode.planFirst => 'Draft a plan first, then execute it step by step.',
    AgentMode.auto => 'Run autonomously: plan, act, verify, self-correct.',
  };

  /// Whether the plan-first stage should be forced for this mode.
  bool get requiresPlan => this != AgentMode.chat;

  /// Whether verification and self-correction stages should run.
  bool get isAutonomous => this == AgentMode.auto;

  static AgentMode fromName(String? value) {
    return switch (value) {
      'auto' => AgentMode.auto,
      'planFirst' => AgentMode.planFirst,
      _ => AgentMode.chat,
    };
  }
}

/// Hard limits enforced by the orchestration loop so a run cannot spin forever.
class RunBudget {
  const RunBudget({
    this.maxIterations = 12,
    this.maxToolCalls = 24,
    this.maxWallClockMs = 300000,
  });

  final int maxIterations;
  final int maxToolCalls;
  final int maxWallClockMs;

  static const RunBudget unlimited = RunBudget(
    maxIterations: 1 << 20,
    maxToolCalls: 1 << 20,
    maxWallClockMs: 1 << 30,
  );

  bool get isUnlimited => maxIterations >= (1 << 20);

  RunBudget copyWith({
    int? maxIterations,
    int? maxToolCalls,
    int? maxWallClockMs,
  }) {
    return RunBudget(
      maxIterations: maxIterations ?? this.maxIterations,
      maxToolCalls: maxToolCalls ?? this.maxToolCalls,
      maxWallClockMs: maxWallClockMs ?? this.maxWallClockMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'maxIterations': maxIterations,
    'maxToolCalls': maxToolCalls,
    'maxWallClockMs': maxWallClockMs,
  };

  factory RunBudget.fromJson(Map<String, dynamic> json) {
    const defaults = RunBudget();
    return RunBudget(
      maxIterations:
          (json['maxIterations'] as num?)?.toInt() ?? defaults.maxIterations,
      maxToolCalls:
          (json['maxToolCalls'] as num?)?.toInt() ?? defaults.maxToolCalls,
      maxWallClockMs:
          (json['maxWallClockMs'] as num?)?.toInt() ??
          defaults.maxWallClockMs,
    );
  }
}

/// When the agent must pause for human approval before running a tool.
enum ApprovalPolicy {
  /// Ask before every tool call that is not strictly read-only.
  alwaysAsk,

  /// Auto-approve read-only tools; ask for anything that writes or is unknown.
  autoApproveReads,

  /// Run everything without asking. Only safe for trusted, curated tools.
  trusted,
}

extension ApprovalPolicyX on ApprovalPolicy {
  String get name => switch (this) {
    ApprovalPolicy.alwaysAsk => 'alwaysAsk',
    ApprovalPolicy.autoApproveReads => 'autoApproveReads',
    ApprovalPolicy.trusted => 'trusted',
  };

  String get label => switch (this) {
    ApprovalPolicy.alwaysAsk => 'Ask for every action',
    ApprovalPolicy.autoApproveReads => 'Ask for writes only',
    ApprovalPolicy.trusted => 'Run everything',
  };

  String get description => switch (this) {
    ApprovalPolicy.alwaysAsk =>
      'Every tool call pauses for your approval before it runs.',
    ApprovalPolicy.autoApproveReads =>
      'Read-only tools run automatically; anything that writes or is unknown asks first.',
    ApprovalPolicy.trusted =>
      'No prompts. Use only with tools you fully trust.',
  };

  static ApprovalPolicy fromName(String? value) {
    return switch (value) {
      'trusted' => ApprovalPolicy.trusted,
      'autoApproveReads' => ApprovalPolicy.autoApproveReads,
      _ => ApprovalPolicy.alwaysAsk,
    };
  }
}

/// Risk classification for one tool call, used by the approval gate.
enum ToolRiskLevel { readOnly, write, destructive, unknown }

extension ToolRiskLevelX on ToolRiskLevel {
  String get name => switch (this) {
    ToolRiskLevel.readOnly => 'readOnly',
    ToolRiskLevel.write => 'write',
    ToolRiskLevel.destructive => 'destructive',
    ToolRiskLevel.unknown => 'unknown',
  };

  String get label => switch (this) {
    ToolRiskLevel.readOnly => 'Read only',
    ToolRiskLevel.write => 'Writes data',
    ToolRiskLevel.destructive => 'Destructive',
    ToolRiskLevel.unknown => 'Unknown',
  };

  /// Whether this risk level always needs explicit approval.
  bool requiresApprovalUnder(ApprovalPolicy policy) {
    return switch (policy) {
      ApprovalPolicy.trusted => false,
      ApprovalPolicy.alwaysAsk => true,
      ApprovalPolicy.autoApproveReads => this != ToolRiskLevel.readOnly,
    };
  }

  static ToolRiskLevel fromName(String? value) {
    return switch (value) {
      'readOnly' => ToolRiskLevel.readOnly,
      'write' => ToolRiskLevel.write,
      'destructive' => ToolRiskLevel.destructive,
      _ => ToolRiskLevel.unknown,
    };
  }
}
