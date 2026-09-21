import '../runtime/domain/agent_policy.dart';
import 'reasoning_settings.dart';

/// Settings that do not fit the single drift `app_settings_entries` row.
///
/// Persisted as one JSON blob in the key/value metadata table so adding a
/// preference never requires a database schema migration.
class AdvancedSettings {
  const AdvancedSettings({
    this.reasoning = const ReasoningPreferences(),
    this.agentMode = AgentMode.chat,
    this.approvalPolicy = ApprovalPolicy.autoApproveReads,
    this.budget = const RunBudget(),
    this.perToolApprovalOverrides = const <String, ApprovalPolicy>{},
  });

  final ReasoningPreferences reasoning;

  /// Mode preselected in the composer for new conversations.
  final AgentMode agentMode;

  final ApprovalPolicy approvalPolicy;

  /// Default budget applied to new runs.
  final RunBudget budget;

  /// Tool-name to policy overrides, e.g. `{'mcp__github__create_issue': ...}`.
  final Map<String, ApprovalPolicy> perToolApprovalOverrides;

  static const String storageKey = 'settings.advanced';

  /// Resolves the effective policy for [toolName], honouring per-tool overrides.
  ApprovalPolicy policyForTool(String toolName) {
    return perToolApprovalOverrides[toolName] ?? approvalPolicy;
  }

  AdvancedSettings copyWith({
    ReasoningPreferences? reasoning,
    AgentMode? agentMode,
    ApprovalPolicy? approvalPolicy,
    RunBudget? budget,
    Map<String, ApprovalPolicy>? perToolApprovalOverrides,
  }) {
    return AdvancedSettings(
      reasoning: reasoning ?? this.reasoning,
      agentMode: agentMode ?? this.agentMode,
      approvalPolicy: approvalPolicy ?? this.approvalPolicy,
      budget: budget ?? this.budget,
      perToolApprovalOverrides:
          perToolApprovalOverrides ?? this.perToolApprovalOverrides,
    );
  }

  AdvancedSettings withToolApprovalOverride(
    String toolName,
    ApprovalPolicy policy,
  ) {
    return copyWith(
      perToolApprovalOverrides: <String, ApprovalPolicy>{
        ...perToolApprovalOverrides,
        toolName: policy,
      },
    );
  }

  AdvancedSettings withoutToolApprovalOverride(String toolName) {
    final next = Map<String, ApprovalPolicy>.from(perToolApprovalOverrides)
      ..remove(toolName);
    return copyWith(perToolApprovalOverrides: next);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'reasoning': reasoning.toJson(),
    'agentMode': agentMode.name,
    'approvalPolicy': approvalPolicy.name,
    'budget': budget.toJson(),
    'perToolApprovalOverrides': <String, String>{
      for (final entry in perToolApprovalOverrides.entries)
        entry.key: entry.value.name,
    },
  };

  factory AdvancedSettings.fromJson(Map<String, dynamic> json) {
    final rawReasoning = json['reasoning'];
    final rawBudget = json['budget'];
    final rawOverrides = json['perToolApprovalOverrides'];
    return AdvancedSettings(
      reasoning: rawReasoning is Map
          ? ReasoningPreferences.fromJson(
              Map<String, dynamic>.from(rawReasoning),
            )
          : const ReasoningPreferences(),
      agentMode: AgentModeX.fromName(json['agentMode']?.toString()),
      approvalPolicy: ApprovalPolicyX.fromName(
        json['approvalPolicy']?.toString(),
      ),
      budget: rawBudget is Map
          ? RunBudget.fromJson(Map<String, dynamic>.from(rawBudget))
          : const RunBudget(),
      perToolApprovalOverrides: rawOverrides is Map
          ? <String, ApprovalPolicy>{
              for (final entry in rawOverrides.entries)
                entry.key.toString(): ApprovalPolicyX.fromName(
                  entry.value?.toString(),
                ),
            }
          : const <String, ApprovalPolicy>{},
    );
  }
}
