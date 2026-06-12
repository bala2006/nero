import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/agent/application/agent_task_store.dart';
import 'package:nero/features/agent/domain/agent_task.dart';
import 'package:nero/features/memory/application/memory_store.dart';
import 'package:nero/features/memory/application/semantic_fact_store.dart';
import 'package:nero/features/memory/application/working_memory_store.dart';
import 'package:nero/features/memory/domain/memory_entry.dart';
import 'package:nero/features/memory/domain/semantic_fact.dart';
import 'package:nero/features/memory/domain/working_memory_snapshot.dart';
import 'package:nero/features/workspace/application/workspace_store.dart';
import 'package:nero/features/workspace/domain/workspace_item.dart';
import 'package:nero/platform/database/app_database.dart' as db;

void main() {
  late db.AppDatabase database;

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('MemoryStore upserts, filters, and deletes memory entries', () async {
    final store = MemoryStore(database: database);
    const entry = MemoryEntry(
      id: 'memory_1',
      kind: MemoryEntryKind.episodic,
      scope: 'conversation',
      title: 'Previous build request',
      content: <String, Object?>{'summary': 'User asked for Flutter'},
      summary: 'User asked for Flutter',
      tags: <String>['flutter', 'build'],
      conversationId: 'conversation_1',
      taskId: 'task_1',
      importanceScore: 0.8,
      createdAtEpochMs: 1,
      updatedAtEpochMs: 2,
    );

    await store.upsertEntry(entry);

    final listed = await store.listEntries(
      kind: MemoryEntryKind.episodic,
      conversationId: 'conversation_1',
    );
    expect(listed, hasLength(1));
    expect(listed.single.title, 'Previous build request');
    expect(listed.single.content['summary'], 'User asked for Flutter');

    await store.deleteEntry(entry.id);
    expect(await store.listEntries(), isEmpty);
  });

  test('SemanticFactStore upserts, lists, and deletes facts', () async {
    final store = SemanticFactStore(database: database);
    const fact = SemanticFact(
      id: 'fact_1',
      scope: 'user',
      scopeId: 'default_user',
      key: 'preferred_stack',
      value: <String, Object?>{'value': 'flutter'},
      confidence: 0.9,
      createdAtEpochMs: 1,
      updatedAtEpochMs: 2,
    );

    await store.upsertFact(fact);

    final listed = await store.listFacts(
      scope: 'user',
      scopeId: 'default_user',
    );
    expect(listed, hasLength(1));
    expect(listed.single.key, 'preferred_stack');
    expect(listed.single.value['value'], 'flutter');

    await store.deleteFact(fact.id);
    expect(
      await store.listFacts(scope: 'user', scopeId: 'default_user'),
      isEmpty,
    );
  });

  test('WorkingMemoryStore stores and reloads latest snapshot by task', () async {
    final store = WorkingMemoryStore(database: database);
    const snapshot = WorkingMemorySnapshot(
      id: 'snapshot_1',
      conversationId: 'conversation_1',
      taskId: 'task_1',
      summary: 'Planning a Flutter app build',
      assumptions: <String>['Use Flutter', 'Target Android first'],
      focusFilePaths: <String>['lib/main.dart', 'pubspec.yaml'],
      metadata: <String, Object?>{'phase': 'planning'},
      createdAtEpochMs: 1,
      updatedAtEpochMs: 2,
    );

    await store.upsertSnapshot(snapshot);

    final loaded = await store.latestSnapshotForTask('task_1');
    expect(loaded, isNotNull);
    expect(loaded!.summary, 'Planning a Flutter app build');
    expect(loaded.assumptions, contains('Use Flutter'));
    expect(loaded.focusFilePaths, contains('lib/main.dart'));
    expect(loaded.metadata['phase'], 'planning');

    await store.deleteSnapshot(snapshot.id);
    expect(await store.latestSnapshotForTask('task_1'), isNull);
  });

  test('AgentTaskStore captures only terminal tasks into memory entries', () async {
    final taskStore = AgentTaskStore(database: database);
    final memoryStore = MemoryStore(database: database);

    const runningTask = AgentTask(
      id: 'task_running',
      conversationId: 'conversation_1',
      prompt: 'Plan the app',
      status: AgentTaskStatus.running,
      createdAtEpochMs: 10,
      updatedAtEpochMs: 11,
      steps: <AgentStep>[],
    );
    const completedTask = AgentTask(
      id: 'task_completed',
      conversationId: 'conversation_1',
      prompt: 'Build the app',
      status: AgentTaskStatus.completed,
      createdAtEpochMs: 20,
      updatedAtEpochMs: 21,
      steps: <AgentStep>[
        AgentStep(
          id: 'step_1',
          kind: AgentStepKinds.planTask,
          title: 'Plan',
          status: AgentStepStatus.completed,
        ),
      ],
    );

    await taskStore.upsertTask(runningTask);
    expect(await memoryStore.listEntries(taskId: runningTask.id), isEmpty);

    await taskStore.upsertTask(completedTask);
    final memories = await memoryStore.listEntries(taskId: completedTask.id);
    expect(memories, hasLength(1));
    expect(memories.single.kind, MemoryEntryKind.episodic);
    expect(memories.single.sourceEntityType, 'agent_task');
    expect(memories.single.sourceEntityId, completedTask.id);
    expect(memories.single.content['status'], 'completed');
    expect(memories.single.content['stepCount'], 1);
  });

  test('AgentTaskStore also captures failed and cancelled tasks', () async {
    final taskStore = AgentTaskStore(database: database);
    final memoryStore = MemoryStore(database: database);

    const failedTask = AgentTask(
      id: 'task_failed',
      conversationId: 'conversation_1',
      prompt: 'Build the app',
      status: AgentTaskStatus.failed,
      createdAtEpochMs: 30,
      updatedAtEpochMs: 31,
      steps: <AgentStep>[],
      error: 'network',
    );
    const cancelledTask = AgentTask(
      id: 'task_cancelled',
      conversationId: 'conversation_1',
      prompt: 'Cancel the app build',
      status: AgentTaskStatus.cancelled,
      createdAtEpochMs: 40,
      updatedAtEpochMs: 41,
      steps: <AgentStep>[],
      error: 'cancelled by user',
    );

    await taskStore.upsertTask(failedTask);
    await taskStore.upsertTask(cancelledTask);

    final failedMemories = await memoryStore.listEntries(taskId: failedTask.id);
    final cancelledMemories = await memoryStore.listEntries(
      taskId: cancelledTask.id,
    );

    expect(failedMemories, hasLength(1));
    expect(failedMemories.single.content['status'], 'failed');
    expect(cancelledMemories, hasLength(1));
    expect(cancelledMemories.single.content['status'], 'cancelled');
  });

  test('WorkspaceStore captures and removes derived workspace memory', () async {
    final workspaceStore = WorkspaceStore(database: database);
    final memoryStore = MemoryStore(database: database);

    const item = WorkspaceItem(
      id: 'artifact_1',
      conversationId: 'conversation_1',
      type: WorkspaceItemType.generatedArtifact,
      title: 'build.zip',
      createdAtEpochMs: 100,
      updatedAtEpochMs: 110,
      mimeType: 'application/zip',
      extension: 'zip',
      sizeBytes: 2048,
    );

    await workspaceStore.upsertItem(item);

    final stored = await memoryStore.listEntries(
      conversationId: item.conversationId,
    );
    expect(stored, hasLength(1));
    expect(stored.single.kind, MemoryEntryKind.artifact);
    expect(stored.single.sourceEntityType, 'workspace_item');
    expect(stored.single.sourceEntityId, item.id);
    expect(stored.single.content['type'], 'generatedArtifact');

    await workspaceStore.deleteItem(item.id);
    expect(
      await memoryStore.listEntries(conversationId: item.conversationId),
      isEmpty,
    );
  });
}
