import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/active_run_session.dart';
import 'package:nero/features/runtime/domain/runtime_progress_snapshot.dart';
import 'package:nero/features/runtime/domain/runtime_run.dart';
import 'package:nero/features/runtime/domain/runtime_run_node.dart';

void main() {
  test('applyProgressUpdate stores run and snapshot together', () {
    final mutableSession = ActiveRunSession();
    const run = RuntimeRun(
      id: 'run_1',
      kind: RuntimeRunKind.conversation,
      title: 'Run',
      status: RuntimeRunStatus.runningModel,
      createdAtEpochMs: 1,
      updatedAtEpochMs: 1,
    );
    const snapshot = RuntimeProgressSnapshot(
      runId: 'run_1',
      runStatus: RuntimeRunStatus.runningModel,
      phases: <RuntimePhaseSnapshot>[
        RuntimePhaseSnapshot(
          phaseKey: 'assistant_round',
          title: 'Assistant round',
          status: RuntimeRunNodeStatus.running,
        ),
      ],
      currentPhase: RuntimePhaseSnapshot(
        phaseKey: 'assistant_round',
        title: 'Assistant round',
        status: RuntimeRunNodeStatus.running,
      ),
    );

    mutableSession.applyProgressUpdate(run, snapshot);

    expect(mutableSession.run?.id, 'run_1');
    expect(mutableSession.progressSnapshot?.currentPhase?.phaseKey, 'assistant_round');
  });

  test('applyCompletedRun hydrates persisted progress snapshot from metadata', () {
    final mutableSession = ActiveRunSession();
    const run = RuntimeRun(
      id: 'run_2',
      kind: RuntimeRunKind.conversation,
      title: 'Completed run',
      status: RuntimeRunStatus.completed,
      createdAtEpochMs: 1,
      updatedAtEpochMs: 2,
      metadata: <String, Object?>{
        'progress_snapshot': <String, Object?>{
          'runId': 'run_2',
          'runStatus': 'completed',
          'phases': <Object?>[
            <String, Object?>{
              'phaseKey': 'response_verification',
              'title': 'Verify response',
              'status': 'completed',
              'error': null,
            },
          ],
          'currentPhase': <String, Object?>{
            'phaseKey': 'response_verification',
            'title': 'Verify response',
            'status': 'completed',
            'error': null,
          },
          'nextPhase': null,
          'blockingPhase': null,
        },
      },
    );

    mutableSession.applyCompletedRun(run);

    expect(mutableSession.run?.status, RuntimeRunStatus.completed);
    expect(
      mutableSession.progressSnapshot?.currentPhase?.phaseKey,
      'response_verification',
    );
  });

  test('clear and clearProgressSnapshot reset session state predictably', () {
    final mutableSession = ActiveRunSession();
    const run = RuntimeRun(
      id: 'run_3',
      kind: RuntimeRunKind.conversation,
      title: 'Run',
      status: RuntimeRunStatus.runningModel,
      createdAtEpochMs: 1,
      updatedAtEpochMs: 1,
    );
    const snapshot = RuntimeProgressSnapshot(
      runId: 'run_3',
      runStatus: RuntimeRunStatus.runningModel,
      phases: <RuntimePhaseSnapshot>[],
    );

    mutableSession.applyProgressUpdate(run, snapshot);
    mutableSession.clearProgressSnapshot();

    expect(mutableSession.run?.id, 'run_3');
    expect(mutableSession.progressSnapshot, isNull);

    mutableSession.clear();

    expect(mutableSession.run, isNull);
    expect(mutableSession.progressSnapshot, isNull);
  });
}
