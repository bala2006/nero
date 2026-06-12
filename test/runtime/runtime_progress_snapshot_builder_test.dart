import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/runtime/application/runtime_progress_snapshot_builder.dart';
import 'package:nero/features/runtime/domain/runtime_progress_snapshot.dart';
import 'package:nero/features/runtime/domain/runtime_run.dart';
import 'package:nero/features/runtime/domain/runtime_run_node.dart';

void main() {
  const builder = RuntimeProgressSnapshotBuilder();

  test('build selects running phase as current and next ordinal phase as next', () {
    const run = RuntimeRun(
      id: 'run_1',
      kind: RuntimeRunKind.conversation,
      title: 'Test run',
      status: RuntimeRunStatus.runningModel,
      createdAtEpochMs: 1,
      updatedAtEpochMs: 2,
    );
    const nodes = <RuntimeRunNode>[
      RuntimeRunNode(
        id: 'root',
        runId: 'run_1',
        phaseKey: 'root',
        title: 'Run root',
        status: RuntimeRunNodeStatus.running,
        ordinal: 0,
        attempt: 1,
        startedAtEpochMs: 1,
        updatedAtEpochMs: 1,
      ),
      RuntimeRunNode(
        id: 'prepare',
        runId: 'run_1',
        phaseKey: 'prepare_context',
        title: 'Prepare context',
        status: RuntimeRunNodeStatus.completed,
        ordinal: 1,
        attempt: 1,
        startedAtEpochMs: 1,
        updatedAtEpochMs: 1,
      ),
      RuntimeRunNode(
        id: 'assistant',
        runId: 'run_1',
        phaseKey: 'assistant_round',
        title: 'Assistant round',
        status: RuntimeRunNodeStatus.running,
        ordinal: 2,
        attempt: 1,
        startedAtEpochMs: 1,
        updatedAtEpochMs: 1,
      ),
      RuntimeRunNode(
        id: 'verify',
        runId: 'run_1',
        phaseKey: 'response_verification',
        title: 'Verify response',
        status: RuntimeRunNodeStatus.queued,
        ordinal: 3,
        attempt: 1,
        startedAtEpochMs: 1,
        updatedAtEpochMs: 1,
      ),
    ];

    final snapshot = builder.build(run: run, nodes: nodes);

    expect(snapshot.currentPhase?.phaseKey, 'assistant_round');
    expect(snapshot.nextPhase?.phaseKey, 'response_verification');
  });

  test('build surfaces failed phase as blocking phase', () {
    const run = RuntimeRun(
      id: 'run_2',
      kind: RuntimeRunKind.conversation,
      title: 'Test run',
      status: RuntimeRunStatus.failed,
      createdAtEpochMs: 1,
      updatedAtEpochMs: 2,
    );
    const nodes = <RuntimeRunNode>[
      RuntimeRunNode(
        id: 'root',
        runId: 'run_2',
        phaseKey: 'root',
        title: 'Run root',
        status: RuntimeRunNodeStatus.failed,
        ordinal: 0,
        attempt: 1,
        startedAtEpochMs: 1,
        updatedAtEpochMs: 1,
      ),
      RuntimeRunNode(
        id: 'verify',
        runId: 'run_2',
        phaseKey: 'response_verification',
        title: 'Verify response',
        status: RuntimeRunNodeStatus.failed,
        ordinal: 1,
        attempt: 1,
        startedAtEpochMs: 1,
        updatedAtEpochMs: 1,
        error: 'The response is empty.',
      ),
    ];

    final snapshot = builder.build(run: run, nodes: nodes);

    expect(snapshot.blockingPhase?.phaseKey, 'response_verification');
    expect(snapshot.currentPhase?.phaseKey, 'response_verification');
  });

  test('build aggregates repeated nodes into one canonical phase', () {
    const run = RuntimeRun(
      id: 'run_repeat',
      kind: RuntimeRunKind.conversation,
      title: 'Repeated phases',
      status: RuntimeRunStatus.runningTools,
      createdAtEpochMs: 1,
      updatedAtEpochMs: 2,
    );
    const nodes = <RuntimeRunNode>[
      RuntimeRunNode(
        id: 'assistant_1',
        runId: 'run_repeat',
        phaseKey: 'assistant_round',
        title: 'Assistant round 1',
        status: RuntimeRunNodeStatus.completed,
        ordinal: 1,
        attempt: 1,
        startedAtEpochMs: 1,
        updatedAtEpochMs: 1,
      ),
      RuntimeRunNode(
        id: 'tool_batch',
        runId: 'run_repeat',
        phaseKey: 'tool_batch',
        title: 'Run tools',
        status: RuntimeRunNodeStatus.completed,
        ordinal: 2,
        attempt: 1,
        startedAtEpochMs: 1,
        updatedAtEpochMs: 1,
      ),
      RuntimeRunNode(
        id: 'assistant_2',
        runId: 'run_repeat',
        phaseKey: 'assistant_round',
        title: 'Assistant round 2',
        status: RuntimeRunNodeStatus.running,
        ordinal: 3,
        attempt: 2,
        startedAtEpochMs: 1,
        updatedAtEpochMs: 1,
      ),
      RuntimeRunNode(
        id: 'verify',
        runId: 'run_repeat',
        phaseKey: 'response_verification',
        title: 'Verify response',
        status: RuntimeRunNodeStatus.queued,
        ordinal: 4,
        attempt: 1,
        startedAtEpochMs: 1,
        updatedAtEpochMs: 1,
      ),
    ];

    final snapshot = builder.build(run: run, nodes: nodes);

    expect(
      snapshot.phases.map((phase) => phase.phaseKey),
      <String>['assistant_round', 'tool_batch', 'response_verification'],
    );
    expect(snapshot.currentPhase?.phaseKey, 'assistant_round');
    expect(snapshot.currentPhase?.title, 'Assistant round 2');
    expect(snapshot.nextPhase?.phaseKey, 'response_verification');
  });

  test('build rolls child tool calls into tool batch phase', () {
    const run = RuntimeRun(
      id: 'run_tools',
      kind: RuntimeRunKind.conversation,
      title: 'Tool phases',
      status: RuntimeRunStatus.runningTools,
      createdAtEpochMs: 1,
      updatedAtEpochMs: 2,
    );
    const nodes = <RuntimeRunNode>[
      RuntimeRunNode(
        id: 'batch',
        runId: 'run_tools',
        phaseKey: 'tool_batch',
        title: 'Run tools',
        status: RuntimeRunNodeStatus.running,
        ordinal: 1,
        attempt: 1,
        startedAtEpochMs: 1,
        updatedAtEpochMs: 1,
      ),
      RuntimeRunNode(
        id: 'call_1',
        runId: 'run_tools',
        phaseKey: 'tool_call',
        title: 'Search web',
        status: RuntimeRunNodeStatus.completed,
        ordinal: 2,
        attempt: 1,
        startedAtEpochMs: 1,
        updatedAtEpochMs: 1,
      ),
      RuntimeRunNode(
        id: 'call_2',
        runId: 'run_tools',
        phaseKey: 'tool_call',
        title: 'Generate document',
        status: RuntimeRunNodeStatus.running,
        ordinal: 3,
        attempt: 1,
        startedAtEpochMs: 1,
        updatedAtEpochMs: 1,
      ),
    ];

    final snapshot = builder.build(run: run, nodes: nodes);

    expect(snapshot.phases, hasLength(1));
    expect(snapshot.phases.single.phaseKey, 'tool_batch');
    expect(snapshot.phases.single.nodeCount, 3);
    expect(snapshot.phases.single.completedCount, 1);
    expect(snapshot.phases.single.activeDetail, 'Generate document');
  });

  test('build leaves terminal completed run without current or next phase', () {
    const run = RuntimeRun(
      id: 'run_done',
      kind: RuntimeRunKind.conversation,
      title: 'Done',
      status: RuntimeRunStatus.completed,
      createdAtEpochMs: 1,
      updatedAtEpochMs: 2,
    );
    const nodes = <RuntimeRunNode>[
      RuntimeRunNode(
        id: 'prepare',
        runId: 'run_done',
        phaseKey: 'prepare_context',
        title: 'Prepare context',
        status: RuntimeRunNodeStatus.completed,
        ordinal: 1,
        attempt: 1,
        startedAtEpochMs: 1,
        updatedAtEpochMs: 1,
      ),
    ];

    final snapshot = builder.build(run: run, nodes: nodes);

    expect(snapshot.currentPhase, isNull);
    expect(snapshot.nextPhase, isNull);
  });

  test('runtime progress snapshot round-trips through json metadata', () {
    const snapshot = RuntimeProgressSnapshot(
      runId: 'run_3',
      runStatus: RuntimeRunStatus.completed,
      phases: <RuntimePhaseSnapshot>[
        RuntimePhaseSnapshot(
          phaseKey: 'prepare_context',
          title: 'Prepare context',
          status: RuntimeRunNodeStatus.completed,
        ),
        RuntimePhaseSnapshot(
          phaseKey: 'assistant_round',
          title: 'Assistant round',
          status: RuntimeRunNodeStatus.completed,
        ),
      ],
      currentPhase: RuntimePhaseSnapshot(
        phaseKey: 'assistant_round',
        title: 'Assistant round',
        status: RuntimeRunNodeStatus.completed,
      ),
    );

    final restored = RuntimeProgressSnapshot.fromJson(snapshot.toJson());

    expect(restored.runId, snapshot.runId);
    expect(restored.runStatus, snapshot.runStatus);
    expect(restored.phases.length, 2);
    expect(restored.currentPhase?.phaseKey, 'assistant_round');
    expect(restored.phases.first.phaseKey, 'prepare_context');
  });
}
