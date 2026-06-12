import 'dart:convert';

import 'package:drift/drift.dart' as drift;

import '../../../platform/database/app_database.dart' as db;
import '../domain/memory_entry.dart' as memory_domain;

class MemoryStore {
  MemoryStore({db.AppDatabase? database})
    : _database = database ?? db.AppDatabase.instance;

  final db.AppDatabase _database;

  Future<void> upsertEntry(memory_domain.MemoryEntry entry) async {
    await _database
        .into(_database.memoryEntries)
        .insertOnConflictUpdate(_entryToCompanion(entry));
  }

  Future<List<memory_domain.MemoryEntry>> listEntries({
    memory_domain.MemoryEntryKind? kind,
    String? conversationId,
    String? taskId,
    int limit = 100,
  }) async {
    final query = _database.select(_database.memoryEntries)
      ..orderBy([(table) => drift.OrderingTerm.desc(table.updatedAtEpochMs)])
      ..limit(limit);
    if (kind != null) {
      query.where(
        (table) => table.kind.equals(memory_domain.memoryEntryKindToJson(kind)),
      );
    }
    if (conversationId != null && conversationId.trim().isNotEmpty) {
      query.where(
        (table) => table.conversationId.equals(conversationId.trim()),
      );
    }
    if (taskId != null && taskId.trim().isNotEmpty) {
      query.where((table) => table.taskId.equals(taskId.trim()));
    }
    final rows = await query.get();
    return rows.map(_entryFromRow).toList(growable: false);
  }

  Future<void> deleteEntry(String entryId) async {
    await (_database.delete(
      _database.memoryEntries,
    )..where((table) => table.id.equals(entryId))).go();
  }

  Future<void> deleteEntriesBySource({
    required String sourceEntityType,
    required String sourceEntityId,
  }) async {
    await (_database.delete(_database.memoryEntries)..where(
          (table) =>
              table.sourceEntityType.equals(sourceEntityType) &
              table.sourceEntityId.equals(sourceEntityId),
        ))
        .go();
  }

  db.MemoryEntriesCompanion _entryToCompanion(memory_domain.MemoryEntry entry) {
    return db.MemoryEntriesCompanion(
      id: drift.Value(entry.id),
      kind: drift.Value(memory_domain.memoryEntryKindToJson(entry.kind)),
      scope: drift.Value(entry.scope),
      title: drift.Value(entry.title),
      contentJson: drift.Value(jsonEncode(entry.content)),
      summary: drift.Value(entry.summary),
      tagsJson: drift.Value(jsonEncode(entry.tags)),
      conversationId: drift.Value(entry.conversationId),
      taskId: drift.Value(entry.taskId),
      sourceEntityType: drift.Value(entry.sourceEntityType),
      sourceEntityId: drift.Value(entry.sourceEntityId),
      importanceScore: drift.Value(entry.importanceScore),
      createdAtEpochMs: drift.Value(entry.createdAtEpochMs),
      updatedAtEpochMs: drift.Value(entry.updatedAtEpochMs),
      lastAccessedAtEpochMs: drift.Value(entry.lastAccessedAtEpochMs),
    );
  }

  memory_domain.MemoryEntry _entryFromRow(db.MemoryEntry row) {
    final decodedContent = jsonDecode(row.contentJson);
    final decodedTags = jsonDecode(row.tagsJson);
    return memory_domain.MemoryEntry(
      id: row.id,
      kind: memory_domain.memoryEntryKindFromJson(row.kind),
      scope: row.scope,
      title: row.title,
      content: decodedContent is Map
          ? Map<String, Object?>.from(decodedContent)
          : const <String, Object?>{},
      summary: row.summary,
      tags: decodedTags is List
          ? decodedTags.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      conversationId: row.conversationId,
      taskId: row.taskId,
      sourceEntityType: row.sourceEntityType,
      sourceEntityId: row.sourceEntityId,
      importanceScore: row.importanceScore,
      createdAtEpochMs: row.createdAtEpochMs,
      updatedAtEpochMs: row.updatedAtEpochMs,
      lastAccessedAtEpochMs: row.lastAccessedAtEpochMs,
    );
  }
}
