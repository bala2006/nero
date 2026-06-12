import 'package:drift/drift.dart' as drift;

import '../../../platform/database/app_database.dart';
import '../domain/audit_log_entry.dart' as audit_domain;

class AuditLogStore {
  AuditLogStore({
    AppDatabase? database,
  }) : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<void> record({
    required String capabilityKey,
    required String title,
    required audit_domain.AuditLogStatus status,
    String? detail,
    String? conversationId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.into(_database.auditLogEntries).insert(
          AuditLogEntriesCompanion(
            id: drift.Value('audit_${DateTime.now().microsecondsSinceEpoch}'),
            createdAtEpochMs: drift.Value(now),
            capabilityKey: drift.Value(capabilityKey),
            title: drift.Value(title),
            detail: drift.Value(detail),
            status: drift.Value(audit_domain.auditLogStatusToJson(status)),
            conversationId: drift.Value(conversationId),
          ),
        );
  }

  Future<List<audit_domain.AuditLogEntry>> listRecent({int limit = 20}) async {
    final rows = await (_database.select(_database.auditLogEntries)
          ..orderBy([
            (table) => drift.OrderingTerm.desc(table.createdAtEpochMs),
          ])
          ..limit(limit))
        .get();
    return rows
        .map(
          (row) => audit_domain.AuditLogEntry(
            id: row.id,
            createdAtEpochMs: row.createdAtEpochMs,
            capabilityKey: row.capabilityKey,
            title: row.title,
            status: audit_domain.auditLogStatusFromJson(row.status),
            detail: row.detail,
            conversationId: row.conversationId,
          ),
        )
        .toList(growable: false);
  }
}
