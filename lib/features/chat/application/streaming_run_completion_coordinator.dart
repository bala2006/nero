import 'dart:async';

import '../../agent/domain/agent_task.dart';
import '../../audit/application/audit_log_store.dart';
import '../../audit/domain/audit_log_entry.dart';
import '../../runtime/domain/runtime_run.dart';
import 'repeated_tool_loop_recovery_handler.dart';
import 'response_repair_coordinator.dart';

typedef StreamingStatusSetter = void Function(String status);
typedef StreamingBlockingReasonSetter = void Function(String? reason);
typedef StreamingStepCompleted = void Function(String kind, {String? detail});
typedef StreamingStepCompletedIfPresent =
    void Function(String kind, {required String detail});
typedef StreamingTaskCompleter = void Function();
typedef StreamingThinkingResetter = void Function();
typedef StreamingResponseReplacer =
    void Function(
      String content, {
      required bool isStreaming,
      bool clearAverageTokensPerSecond,
    });
typedef StreamingMessageFinalizer =
    void Function({
      bool cancelled,
      String? fallbackSuffix,
      double? averageTokensPerSecond,
    });
typedef StreamingNotifier = void Function();
typedef StreamingAverageTokensProvider = double? Function();
typedef StreamingRunUpdater = void Function(RuntimeRun run);
typedef StreamingRecoveredRunCompleter =
    Future<RuntimeRun> Function(RuntimeRun run, String response);

class StreamingRunCompletionCoordinator {
  const StreamingRunCompletionCoordinator({
    required ResponseRepairCoordinator responseRepairCoordinator,
    RepeatedToolLoopRecoveryHandler repeatedToolLoopRecoveryHandler =
        const RepeatedToolLoopRecoveryHandler(),
  }) : _responseRepairCoordinator = responseRepairCoordinator,
       _repeatedToolLoopRecoveryHandler = repeatedToolLoopRecoveryHandler;

  final ResponseRepairCoordinator _responseRepairCoordinator;
  final RepeatedToolLoopRecoveryHandler _repeatedToolLoopRecoveryHandler;

  void finishSuccess({
    required String conversationId,
    required AuditLogStore auditLogStore,
    required String chatPromptCapabilityKey,
    required String chatPromptCapabilityLabel,
    required StreamingStatusSetter setStatus,
    required StreamingBlockingReasonSetter setBlockingReason,
    required StreamingStepCompleted markStepCompleted,
    required StreamingTaskCompleter completeActiveTask,
    required StreamingThinkingResetter clearThinking,
    required StreamingAverageTokensProvider calculateAverageTokensPerSecond,
    required void Function(double? value) setTokensPerSecond,
    required StreamingMessageFinalizer finalizeStreamingMessage,
    required void Function() clearRequestStartedAt,
    required StreamingNotifier notifyListeners,
  }) {
    setStatus('Done');
    setBlockingReason(null);
    unawaited(
      auditLogStore.record(
        capabilityKey: chatPromptCapabilityKey,
        title: chatPromptCapabilityLabel,
        detail: 'Generated response successfully.',
        status: AuditLogStatus.success,
        conversationId: conversationId,
      ),
    );
    markStepCompleted(
      AgentStepKinds.streamResponse,
      detail: 'Final answer delivered.',
    );
    completeActiveTask();
    clearThinking();
    final averageTokensPerSecond = calculateAverageTokensPerSecond();
    setTokensPerSecond(averageTokensPerSecond);
    finalizeStreamingMessage(
      averageTokensPerSecond: averageTokensPerSecond,
    );
    clearRequestStartedAt();
    notifyListeners();
  }

  Future<bool> recoverFromRepeatedToolLoop({
    required Object error,
    required AgentTask? task,
    required bool hasArtifact,
    required StreamingStatusSetter setStatus,
    required StreamingBlockingReasonSetter setBlockingReason,
    required void Function(String detail) markPrimaryDraftingStepCompleted,
    required StreamingStepCompletedIfPresent markStepCompletedIfPresent,
    required StreamingTaskCompleter completeActiveTask,
    required StreamingThinkingResetter clearThinking,
    required StreamingResponseReplacer replaceActiveAssistantContent,
    required void Function() clearRequestStartedAt,
    required RuntimeRun? run,
    required StreamingRecoveredRunCompleter completeRecoveredRun,
    required StreamingRunUpdater applyRunUpdate,
    required StreamingNotifier notifyListeners,
  }) async {
    if (!_responseRepairCoordinator.shouldRecoverFromRepeatedToolLoop(
      error,
      task,
    )) {
      return false;
    }

    final recoveryMessage = _responseRepairCoordinator
        .repeatedToolLoopRecoveryMessage(hasArtifact: hasArtifact);
    final recoveryPlan = _repeatedToolLoopRecoveryHandler.createPlan(
      recoveryMessage: recoveryMessage,
    );

    setStatus(recoveryPlan.finalStatus);
    setBlockingReason(null);
    markPrimaryDraftingStepCompleted(recoveryPlan.primaryDraftingDetail);
    markStepCompletedIfPresent(
      AgentStepKinds.streamResponse,
      detail: recoveryPlan.streamResponseDetail,
    );
    completeActiveTask();
    clearThinking();
    replaceActiveAssistantContent(
      recoveryPlan.recoveryMessage,
      isStreaming: false,
      clearAverageTokensPerSecond: true,
    );
    clearRequestStartedAt();
    if (run != null) {
      final recoveredRun = await completeRecoveredRun(
        run,
        recoveryPlan.recoveryMessage,
      );
      applyRunUpdate(recoveredRun);
    }
    notifyListeners();
    return true;
  }
}
