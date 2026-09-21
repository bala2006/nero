import 'dart:async';

import '../domain/agent_policy.dart';
import 'tool_risk_classifier.dart';

/// A tool call waiting for the user's decision.
class PendingApproval {
  const PendingApproval({
    required this.toolCallId,
    required this.toolName,
    required this.title,
    required this.argumentsSummary,
    required this.risk,
    required this.policy,
    required this.requestedAtEpochMs,
    this.rationale,
  });

  final String toolCallId;
  final String toolName;

  /// Human label (capability display name when known, else the raw name).
  final String title;

  final String argumentsSummary;
  final ToolRiskLevel risk;
  final ApprovalPolicy policy;
  final int requestedAtEpochMs;

  /// Why approval is being asked for, shown to the user.
  final String? rationale;
}

/// Resolves the effective approval policy for a tool name.
typedef ApprovalPolicyResolver = ApprovalPolicy Function(String toolName);

/// Tool-specific overrides that beat the global policy.
///
/// `true` forces a prompt, `false` suppresses it, `null` defers to the policy.
/// MCP uses this to honour per-tool "always ask"/"never ask" choices.
typedef ApprovalOverrideResolver = bool? Function(String toolName);

/// A human-in-the-loop gate in front of every tool call.
///
/// The gate is the single place where "may this run?" is decided, which is why
/// it lives next to the orchestration layer rather than inside each executor.
/// A run that hits the gate simply suspends: the future returned by [request]
/// does not complete until [resolve] is called, so the agent loop is genuinely
/// paused rather than polling.
class ApprovalGate {
  ApprovalGate({
    required ApprovalPolicyResolver policyResolver,
    required ToolRiskResolver riskResolver,
    ApprovalOverrideResolver? overrideResolver,
    DateTime Function()? clock,
  }) : _policyResolver = policyResolver,
       _riskResolver = riskResolver,
       _overrideResolver = overrideResolver,
       _clock = clock ?? DateTime.now;

  final ApprovalPolicyResolver _policyResolver;
  final ToolRiskResolver _riskResolver;
  final ApprovalOverrideResolver? _overrideResolver;
  final DateTime Function() _clock;

  PendingApproval? _pending;
  Completer<bool>? _completer;
  int _requestCount = 0;

  /// Notified whenever a prompt appears or is resolved.
  void Function()? onChanged;

  /// Whether the gate is holding a tool call.
  bool get isWaiting => _pending != null;

  PendingApproval? get pending => _pending;

  /// Number of prompts shown this session, surfaced in the audit trail.
  int get requestCount => _requestCount;

  /// Decides whether [toolName] may run, and waits for the user when needed.
  ///
  /// Returns true to proceed. An explicit override wins; otherwise the risk
  /// level is tested against the effective policy.
  Future<bool> request({
    required String toolCallId,
    required String toolName,
    required Map<String, dynamic> arguments,
    String? title,
    String? rationale,
  }) async {
    final override = _overrideResolver?.call(toolName);
    if (override == false) {
      return true;
    }
    final policy = _policyResolver(toolName);
    final risk = _riskResolver(toolName);
    final needsApproval = override == true || risk.requiresApprovalUnder(policy);
    if (!needsApproval) {
      return true;
    }

    // A second call while one is pending must not silently overwrite the first
    // prompt; decline it rather than running unreviewed.
    if (_pending != null) {
      return false;
    }

    final completer = Completer<bool>();
    _requestCount += 1;
    _pending = PendingApproval(
      toolCallId: toolCallId,
      toolName: toolName,
      title: title ?? toolName,
      argumentsSummary: ToolRiskClassifier.summarizeArguments(arguments),
      risk: risk,
      policy: policy,
      requestedAtEpochMs: _clock().millisecondsSinceEpoch,
      rationale: rationale ?? _defaultRationale(risk, policy, override == true),
    );
    _completer = completer;
    onChanged?.call();

    try {
      return await completer.future;
    } finally {
      _pending = null;
      _completer = null;
      onChanged?.call();
    }
  }

  /// Answers the outstanding prompt.
  void resolve(bool approved) {
    final completer = _completer;
    if (completer == null || completer.isCompleted) {
      return;
    }
    completer.complete(approved);
  }

  /// Releases any outstanding prompt as a rejection (stop button, dispose).
  void cancel() {
    final completer = _completer;
    _pending = null;
    _completer = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(false);
    }
    onChanged?.call();
  }

  String _defaultRationale(
    ToolRiskLevel risk,
    ApprovalPolicy policy,
    bool forced,
  ) {
    if (forced) {
      return 'This tool is set to always ask before it runs.';
    }
    return switch (policy) {
      ApprovalPolicy.alwaysAsk =>
        'Your approval policy asks for every tool call.',
      ApprovalPolicy.autoApproveReads => risk == ToolRiskLevel.destructive
          ? 'This tool is marked destructive, so it always asks first.'
          : 'This tool can change data, so it asks before running.',
      ApprovalPolicy.trusted =>
        'This tool requires approval even though Nero generally runs tools '
            'without asking.',
    };
  }
}
