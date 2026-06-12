import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/runtime/application/runtime_run_store.dart';
import 'package:nero/features/runtime/domain/runtime_run_node.dart';
import 'package:nero/platform/database/app_database.dart' as db;

void main() {
  late db.AppDatabase database;
  late RuntimeRunStore store;

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    store = RuntimeRunStore(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  test('upsertNode persists and updates runtime run nodes', () async {
    final node = RuntimeRunNode(
      id: 'run_1:assistant_round:1',
      runId: 'run_1',
      parentNodeId: 'run_1:root:0',
      phaseKey: 'assistant_round',
      title: 'Assistant round',
      status: RuntimeRunNodeStatus.running,
      ordinal: 2,
      attempt: 1,
      capabilityKey: 'chat.turn',
      request: const <String, Object?>{
        'selected_tools': <String>['search_web'],
      },
      metadata: const <String, Object?>{'source': 'test'},
      startedAtEpochMs: 100,
      updatedAtEpochMs: 100,
    );

    await store.upsertNode(node);
    await store.upsertNode(
      node.copyWith(
        status: RuntimeRunNodeStatus.completed,
        result: const <String, Object?>{'outcome': 'direct_response_emitted'},
        updatedAtEpochMs: 200,
        completedAtEpochMs: 200,
      ),
    );

    final persisted = await store.getNode(node.id);
    expect(persisted, isNotNull);
    expect(persisted!.status, RuntimeRunNodeStatus.completed);
    expect(persisted.result?['outcome'], 'direct_response_emitted');

    final nodes = await store.listNodes('run_1');
    expect(nodes, hasLength(1));
    expect(nodes.single.attempt, 1);
  });

  test('listNodes returns nodes in ordinal order', () async {
    await store.upsertNode(
      RuntimeRunNode(
        id: 'run_2:tool_batch:2',
        runId: 'run_2',
        phaseKey: 'tool_batch',
        title: 'Tool batch',
        status: RuntimeRunNodeStatus.running,
        ordinal: 3,
        attempt: 1,
        startedAtEpochMs: 300,
        updatedAtEpochMs: 300,
      ),
    );
    await store.upsertNode(
      RuntimeRunNode(
        id: 'run_2:root:1',
        runId: 'run_2',
        phaseKey: 'root',
        title: 'Run root',
        status: RuntimeRunNodeStatus.running,
        ordinal: 0,
        attempt: 1,
        startedAtEpochMs: 100,
        updatedAtEpochMs: 100,
      ),
    );
    await store.upsertNode(
      RuntimeRunNode(
        id: 'run_2:assistant_round:1',
        runId: 'run_2',
        phaseKey: 'assistant_round',
        title: 'Assistant round',
        status: RuntimeRunNodeStatus.completed,
        ordinal: 2,
        attempt: 1,
        startedAtEpochMs: 200,
        updatedAtEpochMs: 250,
        completedAtEpochMs: 250,
      ),
    );

    final nodes = await store.listNodes('run_2');
    expect(nodes.map((node) => node.phaseKey).toList(), <String>[
      'root',
      'assistant_round',
      'tool_batch',
    ]);
  });
}
