import '../domain/runtime_progress_snapshot.dart';

class RuntimeProgressSnapshotMetadataAdapter {
  const RuntimeProgressSnapshotMetadataAdapter();

  static const String progressSnapshotKey = 'progress_snapshot';

  RuntimeProgressSnapshot? readFromMetadataValue(Object? value) {
    if (value is! Map) {
      return null;
    }
    return RuntimeProgressSnapshot.fromJson(Map<Object?, Object?>.from(value));
  }

  RuntimeProgressSnapshot? readFromMetadata(Map<Object?, Object?>? metadata) {
    if (metadata == null) {
      return null;
    }
    return readFromMetadataValue(metadata[progressSnapshotKey]);
  }

  Map<String, Object?> writeToMetadata({
    required Map<String, Object?> metadata,
    required RuntimeProgressSnapshot snapshot,
  }) {
    return <String, Object?>{
      ...metadata,
      progressSnapshotKey: snapshot.toJson(),
    };
  }
}
