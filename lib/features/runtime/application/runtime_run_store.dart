import 'dart:convert';

import 'package:drift/drift.dart' as drift;

import '../../../platform/database/app_database.dart';
import '../domain/runtime_operation_ledger_record.dart';
import '../domain/runtime_resume_snapshot.dart';
import '../domain/runtime_run.dart';
import '../domain/runtime_run_event.dart';
import '../domain/runtime_run_node.dart';

class RuntimeRunStore {
  RuntimeRunStore({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<T> transaction<T>(Future<T> Function() action) {
    return _database.transaction(action);
  }

  Future<void> upsertRun(RuntimeRun run) async {
    await _database
        .into(_database.runtimeRunEntries)
        .insertOnConflictUpdate(_runToCompanion(run));
  }

  Future<RuntimeRun?> getRun(String runId) async {
    final query = _database.select(_database.runtimeRunEntries)
      ..where((table) => table.id.equals(runId))
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _runFromRow(row);
  }

  Future<List<RuntimeRun>> listRuns({
    int limit = 100,
    String? conversationId,
    String? taskId,
    RuntimeRunStatus? status,
    RuntimeRunKind? kind,
  }) async {
    final query = _database.select(_database.runtimeRunEntries)
      ..orderBy([(table) => drift.OrderingTerm.desc(table.updatedAtEpochMs)])
      ..limit(limit);
    if (conversationId != null && conversationId.trim().isNotEmpty) {
      query.where(
        (table) => table.conversationId.equals(conversationId.trim()),
      );
    }
    if (taskId != null && taskId.trim().isNotEmpty) {
      query.where((table) => table.taskId.equals(taskId.trim()));
    }
    if (status != null) {
      query.where(
        (table) => table.status.equals(runtimeRunStatusToJson(status)),
      );
    }
    if (kind != null) {
      query.where((table) => table.kind.equals(runtimeRunKindToJson(kind)));
    }
    final rows = await query.get();
    return rows.map(_runFromRow).toList(growable: false);
  }

  Future<List<RuntimeRun>> listActiveRuns({
    int limit = 100,
    String? conversationId,
  }) {
    return listRuns(limit: limit, conversationId: conversationId).then(
      (runs) => runs
          .where(
            (run) =>
                run.status != RuntimeRunStatus.completed &&
                run.status != RuntimeRunStatus.failed &&
                run.status != RuntimeRunStatus.cancelled,
          )
          .toList(growable: false),
    );
  }

  Future<RuntimeRun?> latestResumableRun({String? conversationId}) async {
    final runs = await listRuns(limit: 20, conversationId: conversationId);
    for (final run in runs) {
      final snapshot = await buildResumeSnapshot(run.id);
      if (snapshot?.canResume == true) {
        return run;
      }
    }
    return null;
  }

  Future<void> appendEvent(RuntimeRunEvent event) async {
    await _database
        .into(_database.runtimeRunEventEntries)
        .insertOnConflictUpdate(_eventToCompanion(event));
  }

  Future<List<RuntimeRunEvent>> listEvents(
    String runId, {
    int limit = 200,
  }) async {
    final query = _database.select(_database.runtimeRunEventEntries)
      ..where((table) => table.runId.equals(runId))
      ..orderBy([(table) => drift.OrderingTerm.asc(table.createdAtEpochMs)])
      ..limit(limit);
    final rows = await query.get();
    return rows.map(_eventFromRow).toList(growable: false);
  }

  Future<void> upsertOperation(RuntimeOperationRecord entry) async {
    await _database
        .into(_database.runtimeOperationLedgerEntries)
        .insertOnConflictUpdate(_operationToCompanion(entry));
  }

  Future<RuntimeOperationRecord?> getOperation(
    String runId,
    String operationKey,
  ) async {
    final query = _database.select(_database.runtimeOperationLedgerEntries)
      ..where(
        (table) =>
            table.runId.equals(runId) &
            table.operationKey.equals(operationKey),
      )
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _operationFromRow(row);
  }

  Future<void> upsertNode(RuntimeRunNode node) async {
    await _database
        .into(_database.runtimeRunNodeEntries)
        .insertOnConflictUpdate(_nodeToCompanion(node));
  }

  Future<RuntimeRunNode?> getNode(String nodeId) async {
    final query = _database.select(_database.runtimeRunNodeEntries)
      ..where((table) => table.id.equals(nodeId))
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _nodeFromRow(row);
  }

  Future<List<RuntimeRunNode>> listNodes(
    String runId, {
    int limit = 500,
  }) async {
    final query = _database.select(_database.runtimeRunNodeEntries)
      ..where((table) => table.runId.equals(runId))
      ..orderBy([
        (table) => drift.OrderingTerm.asc(table.ordinal),
        (table) => drift.OrderingTerm.asc(table.startedAtEpochMs),
      ])
      ..limit(limit);
    final rows = await query.get();
    return rows.map(_nodeFromRow).toList(growable: false);
  }

  Future<RuntimeResumeSnapshot?> buildResumeSnapshot(String runId) async {
    final run = await getRun(runId);
    if (run == null) {
      return null;
    }
    final nodes = await listNodes(runId);
    final activeNodes = _selectResumableActiveNodes(nodes);
    final canResume = _isResumableRunStatus(run.status) && activeNodes.isNotEmpty;
    final reason = _buildResumeReason(run: run, activeNodes: activeNodes);
    return RuntimeResumeSnapshot(
      run: run,
      nodes: nodes,
      activeNodes: activeNodes,
      canResume: canResume,
      resumeReason: reason,
    );
  }

  List<RuntimeRunNode> _selectResumableActiveNodes(List<RuntimeRunNode> nodes) {
    if (nodes.isEmpty) {
      return const <RuntimeRunNode>[];
    }
    final nonTerminal = nodes
        .where((node) => !_isTerminalNodeStatus(node.status))
        .toList(growable: false);
    if (nonTerminal.isEmpty) {
      return const <RuntimeRunNode>[];
    }
    final parentIdsWithActiveChildren = nonTerminal
        .map((node) => node.parentNodeId)
        .whereType<String>()
        .toSet();
    final leafNodes = nonTerminal
        .where((node) => !parentIdsWithActiveChildren.contains(node.id))
        .toList(growable: false)
      ..sort((a, b) => a.ordinal.compareTo(b.ordinal));
    return leafNodes;
  }

  bool _isTerminalNodeStatus(RuntimeRunNodeStatus status) {
    return status == RuntimeRunNodeStatus.completed ||
        status == RuntimeRunNodeStatus.failed ||
        status == RuntimeRunNodeStatus.cancelled ||
        status == RuntimeRunNodeStatus.blocked ||
        status == RuntimeRunNodeStatus.skipped;
  }

  bool _isResumableRunStatus(RuntimeRunStatus status) {
    return status == RuntimeRunStatus.queued ||
        status == RuntimeRunStatus.preparing ||
        status == RuntimeRunStatus.runningModel ||
        status == RuntimeRunStatus.runningTools ||
        status == RuntimeRunStatus.finalizing;
  }

  String _buildResumeReason({
    required RuntimeRun run,
    required List<RuntimeRunNode> activeNodes,
  }) {
    if (run.status == RuntimeRunStatus.completed ||
        run.status == RuntimeRunStatus.failed ||
        run.status == RuntimeRunStatus.cancelled) {
      return 'Run is already terminal.';
    }
    if (run.status == RuntimeRunStatus.waitingUser) {
      return 'Run is waiting for user input and cannot resume automatically.';
    }
    if (run.status == RuntimeRunStatus.blocked) {
      return 'Run is blocked and requires intervention before it can resume.';
    }
    if (activeNodes.isEmpty) {
      return 'Run is incomplete but has no resumable active leaf nodes.';
    }
    return 'Run can resume from ${activeNodes.first.phaseKey}.';
  }

  Future<List<RuntimeOperationRecord>> listOperations(
    String runId, {
    int limit = 200,
  }) async {
    final query = _database.select(_database.runtimeOperationLedgerEntries)
      ..where((table) => table.runId.equals(runId))
      ..orderBy([(table) => drift.OrderingTerm.desc(table.updatedAtEpochMs)])
      ..limit(limit);
    final rows = await query.get();
    return rows.map(_operationFromRow).toList(growable: false);
  }

  RuntimeRunEntriesCompanion _runToCompanion(RuntimeRun run) {
    return RuntimeRunEntriesCompanion(
      id: drift.Value(run.id),
      kind: drift.Value(runtimeRunKindToJson(run.kind)),
      status: drift.Value(runtimeRunStatusToJson(run.status)),
      title: drift.Value(run.title),
      conversationId: drift.Value(run.conversationId),
      taskId: drift.Value(run.taskId),
      parentRunId: drift.Value(run.parentRunId),
      capabilityKey: drift.Value(run.capabilityKey),
      requestJson: drift.Value(jsonEncode(run.request)),
      resultJson: drift.Value(run.resultJson),
      error: drift.Value(run.error),
      metadataJson: drift.Value(jsonEncode(run.metadata)),
      createdAtEpochMs: drift.Value(run.createdAtEpochMs),
      updatedAtEpochMs: drift.Value(run.updatedAtEpochMs),
      completedAtEpochMs: drift.Value(run.completedAtEpochMs),
    );
  }

  RuntimeRun _runFromRow(RuntimeRunEntry row) {
    return RuntimeRun(
      id: row.id,
      kind: runtimeRunKindFromJson(row.kind),
      title: row.title,
      status: runtimeRunStatusFromJson(row.status),
      conversationId: row.conversationId,
      taskId: row.taskId,
      parentRunId: row.parentRunId,
      capabilityKey: row.capabilityKey,
      request: _decodeMap(row.requestJson),
      result: row.resultJson == null ? null : _decodeMap(row.resultJson!),
      error: row.error,
      metadata: _decodeMap(row.metadataJson),
      createdAtEpochMs: row.createdAtEpochMs,
      updatedAtEpochMs: row.updatedAtEpochMs,
      completedAtEpochMs: row.completedAtEpochMs,
    );
  }

  RuntimeRunEventEntriesCompanion _eventToCompanion(RuntimeRunEvent event) {
    return RuntimeRunEventEntriesCompanion(
      id: drift.Value(event.id),
      runId: drift.Value(event.runId),
      kind: drift.Value(runtimeRunEventKindToJson(event.kind)),
      title: drift.Value(event.title),
      detail: drift.Value(event.detail),
      payloadJson: drift.Value(jsonEncode(event.payload)),
      createdAtEpochMs: drift.Value(event.createdAtEpochMs),
    );
  }

  RuntimeRunEvent _eventFromRow(RuntimeRunEventEntry row) {
    return RuntimeRunEvent(
      id: row.id,
      runId: row.runId,
      kind: runtimeRunEventKindFromJson(row.kind),
      title: row.title,
      detail: row.detail,
      payload: _decodeMap(row.payloadJson),
      createdAtEpochMs: row.createdAtEpochMs,
    );
  }

  RuntimeOperationLedgerEntriesCompanion _operationToCompanion(
    RuntimeOperationRecord entry,
  ) {
    return RuntimeOperationLedgerEntriesCompanion(
      id: drift.Value(entry.id),
      runId: drift.Value(entry.runId),
      operationKey: drift.Value(entry.operationKey),
      kind: drift.Value(entry.kind),
      status: drift.Value(runtimeOperationStatusToJson(entry.status)),
      requestJson: drift.Value(jsonEncode(entry.request)),
      resultJson: drift.Value(entry.resultJson),
      error: drift.Value(entry.error),
      createdAtEpochMs: drift.Value(entry.createdAtEpochMs),
      updatedAtEpochMs: drift.Value(entry.updatedAtEpochMs),
      completedAtEpochMs: drift.Value(entry.completedAtEpochMs),
    );
  }

  RuntimeOperationRecord _operationFromRow(RuntimeOperationLedgerEntry row) {
    return RuntimeOperationRecord(
      id: row.id,
      runId: row.runId,
      operationKey: row.operationKey,
      kind: row.kind,
      status: runtimeOperationStatusFromJson(row.status),
      request: _decodeMap(row.requestJson),
      result: row.resultJson == null ? null : _decodeMap(row.resultJson!),
      error: row.error,
      createdAtEpochMs: row.createdAtEpochMs,
      updatedAtEpochMs: row.updatedAtEpochMs,
      completedAtEpochMs: row.completedAtEpochMs,
    );
  }

  RuntimeRunNodeEntriesCompanion _nodeToCompanion(RuntimeRunNode node) {
    return RuntimeRunNodeEntriesCompanion(
      id: drift.Value(node.id),
      runId: drift.Value(node.runId),
      parentNodeId: drift.Value(node.parentNodeId),
      phaseKey: drift.Value(node.phaseKey),
      title: drift.Value(node.title),
      status: drift.Value(runtimeRunNodeStatusToJson(node.status)),
      ordinal: drift.Value(node.ordinal),
      attempt: drift.Value(node.attempt),
      capabilityKey: drift.Value(node.capabilityKey),
      toolName: drift.Value(node.toolName),
      toolCallId: drift.Value(node.toolCallId),
      operationKey: drift.Value(node.operationKey),
      requestJson: drift.Value(jsonEncode(node.request)),
      resultJson: drift.Value(node.resultJson),
      metadataJson: drift.Value(jsonEncode(node.metadata)),
      error: drift.Value(node.error),
      startedAtEpochMs: drift.Value(node.startedAtEpochMs),
      updatedAtEpochMs: drift.Value(node.updatedAtEpochMs),
      completedAtEpochMs: drift.Value(node.completedAtEpochMs),
    );
  }

  RuntimeRunNode _nodeFromRow(RuntimeRunNodeEntry row) {
    return RuntimeRunNode(
      id: row.id,
      runId: row.runId,
      parentNodeId: row.parentNodeId,
      phaseKey: row.phaseKey,
      title: row.title,
      status: runtimeRunNodeStatusFromJson(row.status),
      ordinal: row.ordinal,
      attempt: row.attempt,
      capabilityKey: row.capabilityKey,
      toolName: row.toolName,
      toolCallId: row.toolCallId,
      operationKey: row.operationKey,
      request: _decodeMap(row.requestJson),
      result: row.resultJson == null ? null : _decodeMap(row.resultJson!),
      metadata: _decodeMap(row.metadataJson),
      error: row.error,
      startedAtEpochMs: row.startedAtEpochMs,
      updatedAtEpochMs: row.updatedAtEpochMs,
      completedAtEpochMs: row.completedAtEpochMs,
    );
  }

  Map<String, Object?> _decodeMap(String jsonString) {
    final decoded = jsonDecode(jsonString);
    return decoded is Map
        ? Map<String, Object?>.from(decoded)
        : const <String, Object?>{};
  }
}
