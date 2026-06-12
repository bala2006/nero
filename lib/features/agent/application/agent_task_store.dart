import 'dart:convert';

import 'package:drift/drift.dart' as drift;

import '../../memory/application/memory_write_coordinator.dart';
import '../../../platform/database/app_database.dart';
import '../domain/agent_task.dart';

class AgentTaskStore {
  AgentTaskStore({
    AppDatabase? database,
    MemoryWriteCoordinator? memoryWriteCoordinator,
  }) : _database = database ?? AppDatabase.instance,
       _memoryWriteCoordinator =
           memoryWriteCoordinator ??
           MemoryWriteCoordinator(database: database ?? AppDatabase.instance);

  final AppDatabase _database;
  final MemoryWriteCoordinator _memoryWriteCoordinator;

  Future<void> upsertTask(AgentTask task) async {
    await _database
        .into(_database.agentTaskEntries)
        .insertOnConflictUpdate(_taskToCompanion(task));
    await _memoryWriteCoordinator.captureTerminalTask(task);
  }

  Future<List<AgentTask>> listRecent({
    int limit = 100,
    String? conversationId,
  }) async {
    final query = _database.select(_database.agentTaskEntries)
      ..orderBy([(table) => drift.OrderingTerm.desc(table.updatedAtEpochMs)])
      ..limit(limit);
    if (conversationId != null && conversationId.trim().isNotEmpty) {
      query.where(
        (table) => table.conversationId.equals(conversationId.trim()),
      );
    }
    final rows = await query.get();
    return rows.map(_taskFromRow).toList(growable: false);
  }

  AgentTaskEntriesCompanion _taskToCompanion(AgentTask task) {
    return AgentTaskEntriesCompanion(
      id: drift.Value(task.id),
      conversationId: drift.Value(task.conversationId),
      prompt: drift.Value(task.prompt),
      status: drift.Value(agentTaskStatusToJson(task.status)),
      createdAtEpochMs: drift.Value(task.createdAtEpochMs),
      updatedAtEpochMs: drift.Value(task.updatedAtEpochMs),
      stepsJson: drift.Value(
        jsonEncode(
          task.steps.map((step) => step.toJson()).toList(growable: false),
        ),
      ),
      error: drift.Value(task.error),
    );
  }

  AgentTask _taskFromRow(AgentTaskEntry row) {
    final decodedSteps = jsonDecode(row.stepsJson);
    return AgentTask(
      id: row.id,
      conversationId: row.conversationId,
      prompt: row.prompt,
      status: agentTaskStatusFromJson(row.status),
      createdAtEpochMs: row.createdAtEpochMs,
      updatedAtEpochMs: row.updatedAtEpochMs,
      steps: decodedSteps is List
          ? decodedSteps
                .whereType<Map>()
                .map(
                  (item) => AgentStep.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const <AgentStep>[],
      error: row.error,
    );
  }
}
