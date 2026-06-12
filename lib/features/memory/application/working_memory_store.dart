import 'dart:convert';

import 'package:drift/drift.dart' as drift;

import '../../../platform/database/app_database.dart';
import '../domain/working_memory_snapshot.dart';

class WorkingMemoryStore {
  WorkingMemoryStore({
    AppDatabase? database,
  }) : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<void> upsertSnapshot(WorkingMemorySnapshot snapshot) async {
    await _database
        .into(_database.workingMemorySnapshotEntries)
        .insertOnConflictUpdate(_snapshotToCompanion(snapshot));
  }

  Future<WorkingMemorySnapshot?> latestSnapshotForTask(String taskId) async {
    final query = _database.select(_database.workingMemorySnapshotEntries)
      ..where((table) => table.taskId.equals(taskId))
      ..orderBy([
        (table) => drift.OrderingTerm.desc(table.updatedAtEpochMs),
      ])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _snapshotFromRow(row);
  }

  Future<void> deleteSnapshot(String snapshotId) async {
    await (_database.delete(_database.workingMemorySnapshotEntries)
          ..where((table) => table.id.equals(snapshotId)))
        .go();
  }

  WorkingMemorySnapshotEntriesCompanion _snapshotToCompanion(
    WorkingMemorySnapshot snapshot,
  ) {
    return WorkingMemorySnapshotEntriesCompanion(
      id: drift.Value(snapshot.id),
      conversationId: drift.Value(snapshot.conversationId),
      taskId: drift.Value(snapshot.taskId),
      summary: drift.Value(snapshot.summary),
      assumptionsJson: drift.Value(jsonEncode(snapshot.assumptions)),
      focusFilePathsJson: drift.Value(jsonEncode(snapshot.focusFilePaths)),
      metadataJson: drift.Value(jsonEncode(snapshot.metadata)),
      createdAtEpochMs: drift.Value(snapshot.createdAtEpochMs),
      updatedAtEpochMs: drift.Value(snapshot.updatedAtEpochMs),
    );
  }

  WorkingMemorySnapshot _snapshotFromRow(WorkingMemorySnapshotEntry row) {
    final assumptions = jsonDecode(row.assumptionsJson);
    final focusFilePaths = jsonDecode(row.focusFilePathsJson);
    final metadata = row.metadataJson == null ? null : jsonDecode(row.metadataJson!);
    return WorkingMemorySnapshot(
      id: row.id,
      conversationId: row.conversationId,
      taskId: row.taskId,
      summary: row.summary,
      assumptions: assumptions is List
          ? assumptions.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      focusFilePaths: focusFilePaths is List
          ? focusFilePaths
              .map((item) => item.toString())
              .toList(growable: false)
          : const <String>[],
      metadata: metadata is Map
          ? Map<String, Object?>.from(metadata)
          : const <String, Object?>{},
      createdAtEpochMs: row.createdAtEpochMs,
      updatedAtEpochMs: row.updatedAtEpochMs,
    );
  }
}
