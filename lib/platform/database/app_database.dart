import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class ChatConversationEntries extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get messagesJson => text().withDefault(const Constant('[]'))();
  IntColumn get updatedAtEpochMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class AgentTaskEntries extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text()();
  TextColumn get prompt => text()();
  TextColumn get status => text()();
  IntColumn get createdAtEpochMs => integer()();
  IntColumn get updatedAtEpochMs => integer()();
  TextColumn get stepsJson => text().withDefault(const Constant('[]'))();
  TextColumn get error => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class AppSettingsEntries extends Table {
  IntColumn get id => integer()();
  TextColumn get sarvamApiKey => text()();
  TextColumn get selectedModelId => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class AppMetadataEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

class AuditLogEntries extends Table {
  TextColumn get id => text()();
  IntColumn get createdAtEpochMs => integer()();
  TextColumn get capabilityKey => text()();
  TextColumn get title => text()();
  TextColumn get detail => text().nullable()();
  TextColumn get status => text()();
  TextColumn get conversationId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class WorkspaceItemEntries extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text()();
  TextColumn get type => text()();
  TextColumn get title => text()();
  IntColumn get createdAtEpochMs => integer()();
  IntColumn get updatedAtEpochMs => integer()();
  TextColumn get sourceUri => text().nullable()();
  TextColumn get localPath => text().nullable()();
  TextColumn get mimeType => text().nullable()();
  TextColumn get extension => text().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  TextColumn get metadataJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class MemoryEntries extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get scope => text()();
  TextColumn get title => text()();
  TextColumn get contentJson => text().withDefault(const Constant('{}'))();
  TextColumn get summary => text().nullable()();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  TextColumn get conversationId => text().nullable()();
  TextColumn get taskId => text().nullable()();
  TextColumn get sourceEntityType => text().nullable()();
  TextColumn get sourceEntityId => text().nullable()();
  RealColumn get importanceScore => real().withDefault(const Constant(0))();
  IntColumn get createdAtEpochMs => integer()();
  IntColumn get updatedAtEpochMs => integer()();
  IntColumn get lastAccessedAtEpochMs => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class SemanticFactEntries extends Table {
  TextColumn get id => text()();
  TextColumn get scope => text()();
  TextColumn get scopeId => text().nullable()();
  TextColumn get key => text()();
  TextColumn get valueJson => text()();
  RealColumn get confidence => real().withDefault(const Constant(1))();
  IntColumn get createdAtEpochMs => integer()();
  IntColumn get updatedAtEpochMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class WorkingMemorySnapshotEntries extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().nullable()();
  TextColumn get taskId => text()();
  TextColumn get summary => text()();
  TextColumn get assumptionsJson => text().withDefault(const Constant('[]'))();
  TextColumn get focusFilePathsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get metadataJson => text().nullable()();
  IntColumn get createdAtEpochMs => integer()();
  IntColumn get updatedAtEpochMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class RuntimeRunEntries extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get status => text()();
  TextColumn get title => text()();
  TextColumn get conversationId => text().nullable()();
  TextColumn get taskId => text().nullable()();
  TextColumn get parentRunId => text().nullable()();
  TextColumn get capabilityKey => text().nullable()();
  TextColumn get requestJson => text().withDefault(const Constant('{}'))();
  TextColumn get resultJson => text().nullable()();
  TextColumn get error => text().nullable()();
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))();
  IntColumn get createdAtEpochMs => integer()();
  IntColumn get updatedAtEpochMs => integer()();
  IntColumn get completedAtEpochMs => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class RuntimeRunEventEntries extends Table {
  TextColumn get id => text()();
  TextColumn get runId => text()();
  TextColumn get kind => text()();
  TextColumn get title => text()();
  TextColumn get detail => text().nullable()();
  TextColumn get payloadJson => text().withDefault(const Constant('{}'))();
  IntColumn get createdAtEpochMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class RuntimeOperationLedgerEntries extends Table {
  TextColumn get id => text()();
  TextColumn get runId => text()();
  TextColumn get operationKey => text()();
  TextColumn get kind => text()();
  TextColumn get status => text()();
  TextColumn get requestJson => text().withDefault(const Constant('{}'))();
  TextColumn get resultJson => text().nullable()();
  TextColumn get error => text().nullable()();
  IntColumn get createdAtEpochMs => integer()();
  IntColumn get updatedAtEpochMs => integer()();
  IntColumn get completedAtEpochMs => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class RuntimeRunNodeEntries extends Table {
  TextColumn get id => text()();
  TextColumn get runId => text()();
  TextColumn get parentNodeId => text().nullable()();
  TextColumn get phaseKey => text()();
  TextColumn get title => text()();
  TextColumn get status => text()();
  IntColumn get ordinal => integer()();
  IntColumn get attempt => integer().withDefault(const Constant(1))();
  TextColumn get capabilityKey => text().nullable()();
  TextColumn get toolName => text().nullable()();
  TextColumn get toolCallId => text().nullable()();
  TextColumn get operationKey => text().nullable()();
  TextColumn get requestJson => text().withDefault(const Constant('{}'))();
  TextColumn get resultJson => text().nullable()();
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))();
  TextColumn get error => text().nullable()();
  IntColumn get startedAtEpochMs => integer()();
  IntColumn get updatedAtEpochMs => integer()();
  IntColumn get completedAtEpochMs => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}nero_app.sqlite',
    );
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(
  tables: <Type>[
    ChatConversationEntries,
    AgentTaskEntries,
    AppSettingsEntries,
    AppMetadataEntries,
    AuditLogEntries,
    WorkspaceItemEntries,
    MemoryEntries,
    SemanticFactEntries,
    WorkingMemorySnapshotEntries,
    RuntimeRunEntries,
    RuntimeRunEventEntries,
    RuntimeOperationLedgerEntries,
    RuntimeRunNodeEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  static final AppDatabase instance = AppDatabase._internal();

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createIndexes(m);
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2 && !await _tableExists('audit_log_entries')) {
        await m.createTable(auditLogEntries);
      }
      if (from < 3 && !await _tableExists('workspace_item_entries')) {
        await m.createTable(workspaceItemEntries);
      }
      if (from < 4) {
        await _createIndexes(m);
      }
      if (from < 5 && !await _tableExists('memory_entries')) {
        await m.createTable(memoryEntries);
      }
      if (from < 5 && !await _tableExists('semantic_fact_entries')) {
        await m.createTable(semanticFactEntries);
      }
      if (from < 5) {
        await _createIndexes(m);
      }
      if (from < 6 && !await _tableExists('working_memory_snapshot_entries')) {
        await m.createTable(workingMemorySnapshotEntries);
      }
      if (from < 6) {
        await _createIndexes(m);
      }
      if (from < 7 && !await _tableExists('runtime_run_entries')) {
        await m.createTable(runtimeRunEntries);
      }
      if (from < 7 && !await _tableExists('runtime_run_event_entries')) {
        await m.createTable(runtimeRunEventEntries);
      }
      if (from < 7 && !await _tableExists('runtime_operation_ledger_entries')) {
        await m.createTable(runtimeOperationLedgerEntries);
      }
      if (from < 7) {
        await _createIndexes(m);
      }
      if (from < 8 && !await _tableExists('runtime_run_node_entries')) {
        await m.createTable(runtimeRunNodeEntries);
      }
      if (from < 8) {
        await _createIndexes(m);
      }
    },
  );

  Future<void> _createIndexes(Migrator m) async {
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS "chat_conversation_entries_updated_at_idx" '
      'ON "chat_conversation_entries" ("updated_at_epoch_ms")',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS "agent_task_entries_updated_at_idx" '
      'ON "agent_task_entries" ("updated_at_epoch_ms")',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS "audit_log_entries_created_at_idx" '
      'ON "audit_log_entries" ("created_at_epoch_ms")',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS "workspace_item_entries_conversation_updated_idx" '
      'ON "workspace_item_entries" ("conversation_id", "updated_at_epoch_ms")',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS "memory_entries_kind_updated_idx" '
      'ON "memory_entries" ("kind", "updated_at_epoch_ms")',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS "memory_entries_conversation_updated_idx" '
      'ON "memory_entries" ("conversation_id", "updated_at_epoch_ms")',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS "semantic_fact_entries_scope_key_idx" '
      'ON "semantic_fact_entries" ("scope", "scope_id", "key")',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS "working_memory_snapshot_entries_task_updated_idx" '
      'ON "working_memory_snapshot_entries" ("task_id", "updated_at_epoch_ms")',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS "runtime_run_entries_conversation_updated_idx" '
      'ON "runtime_run_entries" ("conversation_id", "updated_at_epoch_ms")',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS "runtime_run_entries_task_updated_idx" '
      'ON "runtime_run_entries" ("task_id", "updated_at_epoch_ms")',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS "runtime_run_entries_status_updated_idx" '
      'ON "runtime_run_entries" ("status", "updated_at_epoch_ms")',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS "runtime_run_entries_kind_updated_idx" '
      'ON "runtime_run_entries" ("kind", "updated_at_epoch_ms")',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS "runtime_run_event_entries_run_created_idx" '
      'ON "runtime_run_event_entries" ("run_id", "created_at_epoch_ms")',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS "runtime_run_event_entries_kind_created_idx" '
      'ON "runtime_run_event_entries" ("kind", "created_at_epoch_ms")',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS "runtime_operation_ledger_entries_run_updated_idx" '
      'ON "runtime_operation_ledger_entries" ("run_id", "updated_at_epoch_ms")',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS "runtime_operation_ledger_entries_status_updated_idx" '
      'ON "runtime_operation_ledger_entries" ("status", "updated_at_epoch_ms")',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS "runtime_run_node_entries_run_ordinal_idx" '
      'ON "runtime_run_node_entries" ("run_id", "ordinal", "updated_at_epoch_ms")',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS "runtime_run_node_entries_parent_ordinal_idx" '
      'ON "runtime_run_node_entries" ("parent_node_id", "ordinal", "updated_at_epoch_ms")',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS "runtime_run_node_entries_phase_status_idx" '
      'ON "runtime_run_node_entries" ("phase_key", "status", "updated_at_epoch_ms")',
    );
  }

  Future<bool> _tableExists(String tableName) async {
    final result = await customSelect(
      'SELECT name FROM sqlite_master WHERE type = ? AND name = ? LIMIT 1',
      variables: <Variable<Object>>[
        const Variable<String>('table'),
        Variable<String>(tableName),
      ],
    ).getSingleOrNull();
    return result != null;
  }
}
