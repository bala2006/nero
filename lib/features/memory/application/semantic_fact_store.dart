import 'dart:convert';

import 'package:drift/drift.dart' as drift;

import '../../../platform/database/app_database.dart';
import '../domain/semantic_fact.dart';

class SemanticFactStore {
  SemanticFactStore({
    AppDatabase? database,
  }) : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<void> upsertFact(SemanticFact fact) async {
    await _database
        .into(_database.semanticFactEntries)
        .insertOnConflictUpdate(_factToCompanion(fact));
  }

  Future<List<SemanticFact>> listFacts({
    required String scope,
    String? scopeId,
    int limit = 100,
  }) async {
    final query = _database.select(_database.semanticFactEntries)
      ..where((table) => table.scope.equals(scope))
      ..orderBy([
        (table) => drift.OrderingTerm.desc(table.updatedAtEpochMs),
      ])
      ..limit(limit);
    if (scopeId != null && scopeId.trim().isNotEmpty) {
      query.where((table) => table.scopeId.equals(scopeId.trim()));
    }
    final rows = await query.get();
    return rows.map(_factFromRow).toList(growable: false);
  }

  Future<void> deleteFact(String factId) async {
    await (_database.delete(_database.semanticFactEntries)
          ..where((table) => table.id.equals(factId)))
        .go();
  }

  SemanticFactEntriesCompanion _factToCompanion(SemanticFact fact) {
    return SemanticFactEntriesCompanion(
      id: drift.Value(fact.id),
      scope: drift.Value(fact.scope),
      scopeId: drift.Value(fact.scopeId),
      key: drift.Value(fact.key),
      valueJson: drift.Value(jsonEncode(fact.value)),
      confidence: drift.Value(fact.confidence),
      createdAtEpochMs: drift.Value(fact.createdAtEpochMs),
      updatedAtEpochMs: drift.Value(fact.updatedAtEpochMs),
    );
  }

  SemanticFact _factFromRow(SemanticFactEntry row) {
    final decodedValue = jsonDecode(row.valueJson);
    return SemanticFact(
      id: row.id,
      scope: row.scope,
      scopeId: row.scopeId,
      key: row.key,
      value: decodedValue is Map
          ? Map<String, Object?>.from(decodedValue)
          : const <String, Object?>{},
      confidence: row.confidence,
      createdAtEpochMs: row.createdAtEpochMs,
      updatedAtEpochMs: row.updatedAtEpochMs,
    );
  }
}
