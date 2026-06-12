import 'package:drift/drift.dart' as drift;

import '../../memory/application/memory_write_coordinator.dart';
import '../../../platform/database/app_database.dart';
import '../domain/workspace_item.dart';

class WorkspaceStore {
  WorkspaceStore({
    AppDatabase? database,
    MemoryWriteCoordinator? memoryWriteCoordinator,
  }) : _database = database ?? AppDatabase.instance,
       _memoryWriteCoordinator =
           memoryWriteCoordinator ??
           MemoryWriteCoordinator(database: database ?? AppDatabase.instance);

  final AppDatabase _database;
  final MemoryWriteCoordinator _memoryWriteCoordinator;

  Future<List<WorkspaceItem>> listRecent({
    int limit = 200,
    String? conversationId,
  }) async {
    final query = _database.select(_database.workspaceItemEntries)
      ..orderBy([(table) => drift.OrderingTerm.desc(table.updatedAtEpochMs)])
      ..limit(limit);
    if (conversationId != null && conversationId.trim().isNotEmpty) {
      query.where(
        (table) => table.conversationId.equals(conversationId.trim()),
      );
    }
    final rows = await query.get();
    return rows.map(_itemFromRow).toList(growable: false);
  }

  Future<void> upsertItem(WorkspaceItem item) async {
    await _database
        .into(_database.workspaceItemEntries)
        .insertOnConflictUpdate(_itemToCompanion(item));
    await _memoryWriteCoordinator.captureWorkspaceItem(item);
  }

  Future<void> insertItems(Iterable<WorkspaceItem> items) async {
    final normalized = items.toList(growable: false);
    if (normalized.isEmpty) {
      return;
    }
    await _database.batch((batch) {
      batch.insertAll(
        _database.workspaceItemEntries,
        normalized.map(_itemToCompanion).toList(growable: false),
        mode: drift.InsertMode.insertOrReplace,
      );
    });
    for (final item in normalized) {
      await _memoryWriteCoordinator.captureWorkspaceItem(item);
    }
  }

  Future<void> deleteItem(String itemId) async {
    await (_database.delete(
      _database.workspaceItemEntries,
    )..where((table) => table.id.equals(itemId))).go();
    await _memoryWriteCoordinator.removeWorkspaceItemCapture(itemId);
  }

  WorkspaceItemEntriesCompanion _itemToCompanion(WorkspaceItem item) {
    return WorkspaceItemEntriesCompanion(
      id: drift.Value(item.id),
      conversationId: drift.Value(item.conversationId),
      type: drift.Value(workspaceItemTypeToJson(item.type)),
      title: drift.Value(item.title),
      createdAtEpochMs: drift.Value(item.createdAtEpochMs),
      updatedAtEpochMs: drift.Value(item.updatedAtEpochMs),
      sourceUri: drift.Value(item.sourceUri),
      localPath: drift.Value(item.localPath),
      mimeType: drift.Value(item.mimeType),
      extension: drift.Value(item.extension),
      sizeBytes: drift.Value(item.sizeBytes),
      metadataJson: drift.Value(item.metadataJson),
    );
  }

  WorkspaceItem _itemFromRow(WorkspaceItemEntry row) {
    return WorkspaceItem(
      id: row.id,
      conversationId: row.conversationId,
      type: workspaceItemTypeFromJson(row.type),
      title: row.title,
      createdAtEpochMs: row.createdAtEpochMs,
      updatedAtEpochMs: row.updatedAtEpochMs,
      sourceUri: row.sourceUri,
      localPath: row.localPath,
      mimeType: row.mimeType,
      extension: row.extension,
      sizeBytes: row.sizeBytes,
      metadataJson: row.metadataJson,
    );
  }
}
