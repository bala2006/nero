import '../domain/runtime_operation_ledger_record.dart';
import '../domain/runtime_resume_snapshot.dart';
import '../domain/runtime_run.dart';
import '../domain/runtime_run_event.dart';
import '../domain/runtime_run_node.dart';
import 'runtime_run_store.dart';

class RuntimeLedgerService {
  RuntimeLedgerService({RuntimeRunStore? store})
    : _store = store ?? RuntimeRunStore();

  final RuntimeRunStore _store;
  static int _eventSequence = 0;

  Future<RuntimeRun> startRun({
    required String id,
    required RuntimeRunKind kind,
    required String title,
    String? conversationId,
    String? taskId,
    String? parentRunId,
    String? capabilityKey,
    Map<String, Object?> request = const <String, Object?>{},
    Map<String, Object?> metadata = const <String, Object?>{},
    RuntimeRunStatus status = RuntimeRunStatus.preparing,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final run = RuntimeRun(
      id: id,
      kind: kind,
      title: title,
      status: status,
      conversationId: conversationId,
      taskId: taskId,
      parentRunId: parentRunId,
      capabilityKey: capabilityKey,
      request: request,
      metadata: metadata,
      createdAtEpochMs: now,
      updatedAtEpochMs: now,
    );
    await _store.transaction(() async {
      await _store.upsertRun(run);
      await _store.appendEvent(
        RuntimeRunEvent(
          id: _nextEventId(run.id, RuntimeRunEventKind.created),
          runId: run.id,
          kind: RuntimeRunEventKind.created,
          title: title,
          detail: 'Run created',
          createdAtEpochMs: now,
        ),
      );
    });
    return run;
  }

  Future<RuntimeRun> updateRun({
    required RuntimeRun run,
    RuntimeRunStatus? status,
    String? title,
    String? conversationId,
    bool clearConversationId = false,
    String? taskId,
    bool clearTaskId = false,
    String? parentRunId,
    bool clearParentRunId = false,
    String? capabilityKey,
    bool clearCapabilityKey = false,
    Map<String, Object?>? request,
    Map<String, Object?>? result,
    bool clearResult = false,
    String? error,
    bool clearError = false,
    Map<String, Object?>? metadata,
    bool clearCompletedAtEpochMs = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = run.copyWith(
      status: status,
      title: title,
      conversationId: conversationId,
      clearConversationId: clearConversationId,
      taskId: taskId,
      clearTaskId: clearTaskId,
      parentRunId: parentRunId,
      clearParentRunId: clearParentRunId,
      capabilityKey: capabilityKey,
      clearCapabilityKey: clearCapabilityKey,
      request: request,
      result: result,
      clearResult: clearResult,
      error: error,
      clearError: clearError,
      metadata: metadata,
      updatedAtEpochMs: now,
      completedAtEpochMs: clearCompletedAtEpochMs
          ? null
          : run.completedAtEpochMs,
      clearCompletedAtEpochMs: clearCompletedAtEpochMs,
    );
    await _store.upsertRun(updated);
    return updated;
  }

  Future<RuntimeRun> completeRun({
    required RuntimeRun run,
    required RuntimeRunStatus status,
    Map<String, Object?>? result,
    String? error,
    String? detail,
    String? eventTitle,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final completed = run.copyWith(
      status: status,
      result: result,
      error: error,
      updatedAtEpochMs: now,
      completedAtEpochMs: now,
    );
    final eventKind = switch (status) {
      RuntimeRunStatus.completed => RuntimeRunEventKind.completed,
      RuntimeRunStatus.failed => RuntimeRunEventKind.failed,
      RuntimeRunStatus.cancelled => RuntimeRunEventKind.cancelled,
      _ => RuntimeRunEventKind.statusChanged,
    };
    await _store.transaction(() async {
      await _store.upsertRun(completed);
      await _store.appendEvent(
        RuntimeRunEvent(
          id: _nextEventId(run.id, eventKind),
          runId: run.id,
          kind: eventKind,
          title: eventTitle ?? run.title,
          detail: detail ?? error,
          payload: <String, Object?>{
            if (result != null) 'result': result,
            if (error != null) 'error': error,
          },
          createdAtEpochMs: now,
        ),
      );
    });
    return completed;
  }

  Future<void> recordEvent({
    required String runId,
    required RuntimeRunEventKind kind,
    required String title,
    String? detail,
    Map<String, Object?> payload = const <String, Object?>{},
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _store.appendEvent(
      RuntimeRunEvent(
        id: _nextEventId(runId, kind),
        runId: runId,
        kind: kind,
        title: title,
        detail: detail,
        payload: payload,
        createdAtEpochMs: now,
      ),
    );
  }

  Future<void> recordOperation({
    required String runId,
    required String operationKey,
    required String kind,
    required RuntimeOperationStatus status,
    Map<String, Object?> request = const <String, Object?>{},
    Map<String, Object?>? result,
    String? error,
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
    int? completedAtEpochMs,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final stamp = updatedAtEpochMs ?? now;
    final entry = RuntimeOperationRecord(
      id: '${runId}_$operationKey',
      runId: runId,
      operationKey: operationKey,
      kind: kind,
      status: status,
      request: request,
      result: result,
      error: error,
      createdAtEpochMs: createdAtEpochMs ?? now,
      updatedAtEpochMs: stamp,
      completedAtEpochMs: completedAtEpochMs,
    );
    await _store.upsertOperation(entry);
  }

  Future<RuntimeOperationRecord?> getOperation({
    required String runId,
    required String operationKey,
  }) {
    return _store.getOperation(runId, operationKey);
  }

  Future<RuntimeRunNode> startNode({
    required String id,
    required String runId,
    required String phaseKey,
    required String title,
    required int ordinal,
    String? parentNodeId,
    int attempt = 1,
    String? capabilityKey,
    String? toolName,
    String? toolCallId,
    String? operationKey,
    Map<String, Object?> request = const <String, Object?>{},
    Map<String, Object?> metadata = const <String, Object?>{},
    RuntimeRunNodeStatus status = RuntimeRunNodeStatus.running,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final node = RuntimeRunNode(
      id: id,
      runId: runId,
      parentNodeId: parentNodeId,
      phaseKey: phaseKey,
      title: title,
      status: status,
      ordinal: ordinal,
      attempt: attempt,
      capabilityKey: capabilityKey,
      toolName: toolName,
      toolCallId: toolCallId,
      operationKey: operationKey,
      request: request,
      metadata: metadata,
      startedAtEpochMs: now,
      updatedAtEpochMs: now,
    );
    await _store.upsertNode(node);
    return node;
  }

  Future<RuntimeRunNode> updateNode({
    required RuntimeRunNode node,
    RuntimeRunNodeStatus? status,
    String? title,
    Map<String, Object?>? request,
    Map<String, Object?>? result,
    bool clearResult = false,
    Map<String, Object?>? metadata,
    String? error,
    bool clearError = false,
    int? attempt,
    bool clearCompletedAtEpochMs = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = node.copyWith(
      status: status,
      title: title,
      request: request,
      result: result,
      clearResult: clearResult,
      metadata: metadata,
      error: error,
      clearError: clearError,
      attempt: attempt,
      updatedAtEpochMs: now,
      completedAtEpochMs: clearCompletedAtEpochMs
          ? null
          : node.completedAtEpochMs,
      clearCompletedAtEpochMs: clearCompletedAtEpochMs,
    );
    await _store.upsertNode(updated);
    return updated;
  }

  Future<RuntimeRunNode> completeNode({
    required RuntimeRunNode node,
    required RuntimeRunNodeStatus status,
    Map<String, Object?>? result,
    String? error,
    Map<String, Object?>? metadata,
    String? title,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final completed = node.copyWith(
      status: status,
      title: title,
      result: result,
      error: error,
      metadata: metadata,
      updatedAtEpochMs: now,
      completedAtEpochMs: now,
    );
    await _store.upsertNode(completed);
    return completed;
  }

  Future<List<RuntimeRunNode>> listNodes(String runId, {int limit = 500}) {
    return _store.listNodes(runId, limit: limit);
  }

  Future<void> upsertNode(RuntimeRunNode node) {
    return _store.upsertNode(node);
  }

  Future<RuntimeRun?> latestResumableRun({String? conversationId}) {
    return _store.latestResumableRun(conversationId: conversationId);
  }

  Future<RuntimeResumeSnapshot?> buildResumeSnapshot(String runId) {
    return _store.buildResumeSnapshot(runId);
  }

  String _nextEventId(String runId, RuntimeRunEventKind kind) {
    _eventSequence += 1;
    return 'event_${runId}_${kind.name}_${DateTime.now().microsecondsSinceEpoch}_$_eventSequence';
  }
}
