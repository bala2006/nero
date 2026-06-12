import 'dart:async';

import '../../docs/application/artifact_fallback_coordinator.dart';
import '../../runtime/domain/runtime_run.dart';
import 'legacy_tool_call_recovery_adapter.dart';

typedef RuntimeDebugSignalAppender =
    Future<RuntimeRun> Function({
      required RuntimeRun run,
      Map<String, int> counterDeltas,
      Map<String, Object?> metadataPatch,
    });
typedef RuntimeDebugSignalActiveRunPredicate =
    bool Function(RuntimeRun originalRun);
typedef RuntimeDebugSignalRunApplier = void Function(RuntimeRun run);

class RuntimeDebugSignalRecorder {
  const RuntimeDebugSignalRecorder();

  Future<void> recordArtifactRepair({
    required RuntimeRun? run,
    required String outputTool,
    required ArtifactFallbackResult fallbackResult,
    required RuntimeDebugSignalAppender appendDebugSignals,
    required RuntimeDebugSignalActiveRunPredicate shouldApplyUpdatedRun,
    required RuntimeDebugSignalRunApplier applyRunUpdate,
  }) async {
    if (run == null) {
      return;
    }
    final succeeded = fallbackResult.errorMessage == null;
    await _appendAndApply(
      run: run,
      counterDeltas: <String, int>{
        'artifact_repair_attempt_count': 1,
        if (succeeded)
          'artifact_repair_success_count': 1
        else
          'artifact_repair_failure_count': 1,
      },
      metadataPatch: <String, Object?>{
        'artifact_repair_last': <String, Object?>{
          'output_tool': outputTool,
          'success': succeeded,
          'step_detail': fallbackResult.stepDetail,
          'error_message': fallbackResult.errorMessage,
        },
      },
      appendDebugSignals: appendDebugSignals,
      shouldApplyUpdatedRun: shouldApplyUpdatedRun,
      applyRunUpdate: applyRunUpdate,
    );
  }

  void recordCompatibilityRecovery({
    required RuntimeRun? run,
    required LegacyToolCallRecoveryStats stats,
    required RuntimeDebugSignalAppender appendDebugSignals,
    required RuntimeDebugSignalActiveRunPredicate shouldApplyUpdatedRun,
    required RuntimeDebugSignalRunApplier applyRunUpdate,
  }) {
    if (run == null || !stats.usedCompatibilityRecovery) {
      return;
    }
    unawaited(
      _appendAndApply(
        run: run,
        counterDeltas: <String, int>{
          'compatibility_recovery_count': 1,
          if (stats.recoveredToolCallCount > 0)
            'compatibility_tool_call_recovery_count':
                stats.recoveredToolCallCount,
        },
        metadataPatch: <String, Object?>{
          'compatibility_recovery_last': <String, Object?>{
            'markup_detected': stats.compatibilityMarkupDetected,
            'stripped_markup': stats.strippedCompatibilityMarkup,
            'recovered_tool_call_count': stats.recoveredToolCallCount,
          },
        },
        appendDebugSignals: appendDebugSignals,
        shouldApplyUpdatedRun: shouldApplyUpdatedRun,
        applyRunUpdate: applyRunUpdate,
      ),
    );
  }

  Future<void> _appendAndApply({
    required RuntimeRun run,
    required Map<String, int> counterDeltas,
    required Map<String, Object?> metadataPatch,
    required RuntimeDebugSignalAppender appendDebugSignals,
    required RuntimeDebugSignalActiveRunPredicate shouldApplyUpdatedRun,
    required RuntimeDebugSignalRunApplier applyRunUpdate,
  }) async {
    final updatedRun = await appendDebugSignals(
      run: run,
      counterDeltas: counterDeltas,
      metadataPatch: metadataPatch,
    );
    if (shouldApplyUpdatedRun(run)) {
      applyRunUpdate(updatedRun);
    }
  }
}
