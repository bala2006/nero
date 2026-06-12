import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/runtime/application/runtime_ledger_service.dart';
import 'package:nero/features/runtime/application/runtime_run_store.dart';
import 'package:nero/features/runtime/domain/runtime_operation_ledger_record.dart';
import 'package:nero/features/runtime/domain/runtime_run_node.dart';
import 'package:nero/features/runtime/domain/runtime_run.dart';
import 'package:nero/features/runtime/domain/runtime_run_event.dart';
import 'package:nero/platform/database/app_database.dart' as db;

void main() {
  late db.AppDatabase database;

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('RuntimeLedgerService persists runs, events, and operations', () async {
    final service = RuntimeLedgerService(
      store: RuntimeRunStore(database: database),
    );

    final run = await service.startRun(
      id: 'run_1',
      kind: RuntimeRunKind.conversation,
      title: 'Chat turn',
      conversationId: 'conversation_1',
      taskId: 'task_1',
      capabilityKey: 'chat.turn',
      request: <String, Object?>{'prompt': 'Generate a doc'},
    );

    final updated = await service.updateRun(
      run: run,
      status: RuntimeRunStatus.runningModel,
      metadata: <String, Object?>{'phase': 'planning'},
    );
    await service.recordEvent(
      runId: updated.id,
      kind: RuntimeRunEventKind.note,
      title: 'Planner note',
      detail: 'Preparing tool selection',
      payload: <String, Object?>{'step': 1},
    );
    await service.recordOperation(
      runId: updated.id,
      operationKey: 'generate_docx',
      kind: 'tool',
      status: RuntimeOperationStatus.completed,
      request: <String, Object?>{'title': 'Doc'},
      result: <String, Object?>{'path': '/tmp/doc.docx'},
      completedAtEpochMs: 3,
    );
    await service.completeRun(
      run: updated,
      status: RuntimeRunStatus.completed,
      result: <String, Object?>{'artifactPath': '/tmp/doc.docx'},
      eventTitle: 'Chat turn completed',
    );

    final store = RuntimeRunStore(database: database);
    final loadedRun = await store.getRun('run_1');
    expect(loadedRun, isNotNull);
    expect(loadedRun!.status, RuntimeRunStatus.completed);
    expect(loadedRun.conversationId, 'conversation_1');
    expect(loadedRun.request['prompt'], 'Generate a doc');
    expect(loadedRun.metadata['phase'], 'planning');
    expect(loadedRun.result?['artifactPath'], '/tmp/doc.docx');

    final events = await store.listEvents('run_1');
    expect(events, hasLength(3));
    expect(events.first.kind, RuntimeRunEventKind.created);
    expect(events.last.kind, RuntimeRunEventKind.completed);

    final operations = await store.listOperations('run_1');
    expect(operations, hasLength(1));
    expect(operations.single.status, RuntimeOperationStatus.completed);
    expect(operations.single.result?['path'], '/tmp/doc.docx');
  });

  test('RuntimeRunStore filters runs by conversation and task', () async {
    final store = RuntimeRunStore(database: database);
    await store.upsertRun(
      const RuntimeRun(
        id: 'run_a',
        kind: RuntimeRunKind.tool,
        title: 'Tool run',
        status: RuntimeRunStatus.runningTools,
        conversationId: 'conversation_1',
        taskId: 'task_1',
        createdAtEpochMs: 1,
        updatedAtEpochMs: 1,
      ),
    );
    await store.upsertRun(
      const RuntimeRun(
        id: 'run_b',
        kind: RuntimeRunKind.workflow,
        title: 'Workflow run',
        status: RuntimeRunStatus.completed,
        conversationId: 'conversation_2',
        taskId: 'task_2',
        createdAtEpochMs: 2,
        updatedAtEpochMs: 2,
        completedAtEpochMs: 3,
      ),
    );

    final conversationRuns = await store.listRuns(
      conversationId: 'conversation_1',
    );
    expect(conversationRuns, hasLength(1));
    expect(conversationRuns.single.id, 'run_a');

    final taskRuns = await store.listRuns(taskId: 'task_2');
    expect(taskRuns, hasLength(1));
    expect(taskRuns.single.id, 'run_b');
  });

  test(
    'RuntimeOperationRecord is idempotent on upsert by run and key',
    () async {
      final store = RuntimeRunStore(database: database);

      await store.upsertOperation(
        const RuntimeOperationRecord(
          id: 'run_1_generate_docx',
          runId: 'run_1',
          operationKey: 'generate_docx',
          kind: 'tool',
          status: RuntimeOperationStatus.running,
          request: <String, Object?>{'title': 'Doc'},
          createdAtEpochMs: 1,
          updatedAtEpochMs: 1,
        ),
      );
      await store.upsertOperation(
        const RuntimeOperationRecord(
          id: 'run_1_generate_docx',
          runId: 'run_1',
          operationKey: 'generate_docx',
          kind: 'tool',
          status: RuntimeOperationStatus.completed,
          request: <String, Object?>{'title': 'Doc'},
          result: <String, Object?>{'path': '/tmp/doc.docx'},
          createdAtEpochMs: 1,
          updatedAtEpochMs: 2,
          completedAtEpochMs: 2,
        ),
      );

      final operations = await store.listOperations('run_1');
      expect(operations, hasLength(1));
      expect(operations.single.status, RuntimeOperationStatus.completed);
      expect(operations.single.result?['path'], '/tmp/doc.docx');
    },
  );

  test(
    'RuntimeRunStore builds a resumable snapshot for incomplete runs',
    () async {
      final store = RuntimeRunStore(database: database);
      await store.upsertRun(
        const RuntimeRun(
          id: 'run_resume',
          kind: RuntimeRunKind.conversation,
          title: 'Resume me',
          status: RuntimeRunStatus.runningModel,
          conversationId: 'conversation_resume',
          createdAtEpochMs: 1,
          updatedAtEpochMs: 2,
        ),
      );
      await store.upsertNode(
        const RuntimeRunNode(
          id: 'run_resume:root:1',
          runId: 'run_resume',
          phaseKey: 'root',
          title: 'Run root',
          status: RuntimeRunNodeStatus.running,
          ordinal: 0,
          attempt: 1,
          startedAtEpochMs: 1,
          updatedAtEpochMs: 2,
        ),
      );
      await store.upsertNode(
        const RuntimeRunNode(
          id: 'run_resume:assistant_round:2',
          runId: 'run_resume',
          parentNodeId: 'run_resume:root:1',
          phaseKey: 'assistant_round',
          title: 'Assistant round',
          status: RuntimeRunNodeStatus.running,
          ordinal: 1,
          attempt: 1,
          startedAtEpochMs: 2,
          updatedAtEpochMs: 3,
        ),
      );

      final latest = await store.latestResumableRun(
        conversationId: 'conversation_resume',
      );
      expect(latest, isNotNull);
      expect(latest!.id, 'run_resume');

      final snapshot = await store.buildResumeSnapshot('run_resume');
      expect(snapshot, isNotNull);
      expect(snapshot!.canResume, isTrue);
      expect(snapshot.activeNodes, isNotEmpty);
      expect(snapshot.activeNodes.first.phaseKey, 'assistant_round');
    },
  );

  test(
    'RuntimeRunStore does not mark waiting or blocked runs as resumable',
    () async {
      final store = RuntimeRunStore(database: database);
      await store.upsertRun(
        const RuntimeRun(
          id: 'run_waiting',
          kind: RuntimeRunKind.conversation,
          title: 'Waiting run',
          status: RuntimeRunStatus.waitingUser,
          conversationId: 'conversation_waiting',
          createdAtEpochMs: 1,
          updatedAtEpochMs: 2,
        ),
      );
      await store.upsertNode(
        const RuntimeRunNode(
          id: 'run_waiting:root:1',
          runId: 'run_waiting',
          phaseKey: 'root',
          title: 'Run root',
          status: RuntimeRunNodeStatus.waiting,
          ordinal: 0,
          attempt: 1,
          startedAtEpochMs: 1,
          updatedAtEpochMs: 2,
        ),
      );

      final waitingSnapshot = await store.buildResumeSnapshot('run_waiting');
      expect(waitingSnapshot, isNotNull);
      expect(waitingSnapshot!.canResume, isFalse);
      expect(
        waitingSnapshot.resumeReason,
        contains('cannot resume automatically'),
      );

      await store.upsertRun(
        const RuntimeRun(
          id: 'run_blocked',
          kind: RuntimeRunKind.conversation,
          title: 'Blocked run',
          status: RuntimeRunStatus.blocked,
          conversationId: 'conversation_waiting',
          createdAtEpochMs: 3,
          updatedAtEpochMs: 4,
        ),
      );
      await store.upsertNode(
        const RuntimeRunNode(
          id: 'run_blocked:root:1',
          runId: 'run_blocked',
          phaseKey: 'root',
          title: 'Run root',
          status: RuntimeRunNodeStatus.blocked,
          ordinal: 0,
          attempt: 1,
          startedAtEpochMs: 3,
          updatedAtEpochMs: 4,
        ),
      );

      final latest = await store.latestResumableRun(
        conversationId: 'conversation_waiting',
      );
      expect(latest, isNull);
    },
  );
}
