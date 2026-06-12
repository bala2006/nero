import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/runtime/application/runtime_progress_snapshot_metadata_adapter.dart';
import 'package:nero/features/runtime/domain/runtime_progress_snapshot.dart';
import 'package:nero/features/runtime/domain/runtime_run.dart';
import 'package:nero/features/runtime/domain/runtime_run_node.dart';

void main() {
  const adapter = RuntimeProgressSnapshotMetadataAdapter();
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

  test('writeToMetadata stores progress snapshot under canonical key', () {
    final metadata = adapter.writeToMetadata(
      metadata: const <String, Object?>{'artifact_count': 1},
      snapshot: snapshot,
    );

    expect(metadata['artifact_count'], 1);
    expect(metadata[RuntimeProgressSnapshotMetadataAdapter.progressSnapshotKey], isA<Map>());
  });

  test('readFromMetadata restores snapshot from canonical key', () {
    final metadata = adapter.writeToMetadata(
      metadata: const <String, Object?>{},
      snapshot: snapshot,
    );

    final restored = adapter.readFromMetadata(metadata);

    expect(restored, isNotNull);
    expect(restored!.runId, snapshot.runId);
    expect(restored.currentPhase?.phaseKey, 'assistant_round');
  });

  test('readFromMetadataValue returns null for non-map values', () {
    expect(adapter.readFromMetadataValue('nope'), isNull);
  });
}
