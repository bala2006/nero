import '../../runtime/application/runtime_progress_snapshot_metadata_adapter.dart';
import '../../runtime/domain/runtime_progress_snapshot.dart';
import '../../runtime/domain/runtime_run.dart';

class ActiveRunSession {
  ActiveRunSession({
    RuntimeProgressSnapshotMetadataAdapter metadataAdapter =
        const RuntimeProgressSnapshotMetadataAdapter(),
  }) : _metadataAdapter = metadataAdapter;

  final RuntimeProgressSnapshotMetadataAdapter _metadataAdapter;

  RuntimeRun? _run;
  RuntimeProgressSnapshot? _progressSnapshot;

  RuntimeRun? get run => _run;
  RuntimeProgressSnapshot? get progressSnapshot => _progressSnapshot;

  void clear() {
    _run = null;
    _progressSnapshot = null;
  }

  void clearProgressSnapshot() {
    _progressSnapshot = null;
  }

  void applyRunUpdate(RuntimeRun run) {
    _run = run;
  }

  void applyProgressUpdate(RuntimeRun run, RuntimeProgressSnapshot snapshot) {
    _run = run;
    _progressSnapshot = snapshot;
  }

  void applyCompletedRun(RuntimeRun run) {
    _run = run;
    _progressSnapshot = _metadataAdapter.readFromMetadata(run.metadata);
  }
}
