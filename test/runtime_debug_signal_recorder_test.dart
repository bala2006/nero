import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/legacy_tool_call_recovery_adapter.dart';
import 'package:nero/features/chat/application/runtime_debug_signal_recorder.dart';
import 'package:nero/features/docs/application/artifact_fallback_coordinator.dart';
import 'package:nero/features/runtime/domain/runtime_run.dart';

void main() {
  const recorder = RuntimeDebugSignalRecorder();

  test('recordArtifactRepair appends counters and metadata', () async {
    final runs = <RuntimeRun>[];
    RuntimeRun? appliedRun;
    await recorder.recordArtifactRepair(
      run: const RuntimeRun(
        id: 'run_1',
        kind: RuntimeRunKind.conversation,
        title: 'Generate doc',
        status: RuntimeRunStatus.runningModel,
        conversationId: 'conversation_1',
        createdAtEpochMs: 1,
        updatedAtEpochMs: 1,
      ),
      outputTool: 'generate_docx',
      fallbackResult: const ArtifactFallbackResult(
        finalResponse: 'Created it.',
        stepDetail: 'Recovered artifact generation.',
      ),
      appendDebugSignals: ({
        required RuntimeRun run,
        Map<String, int> counterDeltas = const <String, int>{},
        Map<String, Object?> metadataPatch = const <String, Object?>{},
      }) async {
        final updated = run.copyWith(
          metadata: <String, Object?>{
            'debug_counters': counterDeltas,
            'debug_metadata': metadataPatch,
          },
        );
        runs.add(updated);
        return updated;
      },
      shouldApplyUpdatedRun: (_) => true,
      applyRunUpdate: (run) => appliedRun = run,
    );

    expect(runs, hasLength(1));
    expect(appliedRun, isNotNull);
    expect(
      ((appliedRun!.metadata['debug_counters'] as Map)['artifact_repair_attempt_count']),
      1,
    );
    expect(
      ((appliedRun!.metadata['debug_metadata'] as Map)['artifact_repair_last']
          as Map)['output_tool'],
      'generate_docx',
    );
  });

  test('recordCompatibilityRecovery appends counters and metadata', () async {
    RuntimeRun? appliedRun;
    recorder.recordCompatibilityRecovery(
      run: const RuntimeRun(
        id: 'run_2',
        kind: RuntimeRunKind.conversation,
        title: 'Generate doc',
        status: RuntimeRunStatus.runningModel,
        conversationId: 'conversation_2',
        createdAtEpochMs: 1,
        updatedAtEpochMs: 1,
      ),
      stats: const LegacyToolCallRecoveryStats(
        compatibilityMarkupDetected: true,
        strippedCompatibilityMarkup: true,
        recoveredToolCallCount: 1,
      ),
      appendDebugSignals: ({
        required RuntimeRun run,
        Map<String, int> counterDeltas = const <String, int>{},
        Map<String, Object?> metadataPatch = const <String, Object?>{},
      }) async {
        return run.copyWith(
          metadata: <String, Object?>{
            'debug_counters': counterDeltas,
            'debug_metadata': metadataPatch,
          },
        );
      },
      shouldApplyUpdatedRun: (_) => true,
      applyRunUpdate: (run) => appliedRun = run,
    );
    await Future<void>.delayed(Duration.zero);

    expect(appliedRun, isNotNull);
    expect(
      ((appliedRun!.metadata['debug_counters'] as Map)['compatibility_recovery_count']),
      1,
    );
    expect(
      ((appliedRun!.metadata['debug_metadata'] as Map)['compatibility_recovery_last']
          as Map)['recovered_tool_call_count'],
      1,
    );
  });
}
