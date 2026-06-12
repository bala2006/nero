import '../../agent/domain/agent_task.dart';
import '../../workspace/domain/workspace_item.dart';
import '../../../platform/database/app_database.dart' as db;
import '../domain/memory_entry.dart';
import 'memory_store.dart';

class MemoryWriteCoordinator {
  MemoryWriteCoordinator({
    db.AppDatabase? database,
    MemoryStore? memoryStore,
  }) : _memoryStore = memoryStore ?? MemoryStore(database: database);

  final MemoryStore _memoryStore;

  Future<void> captureTerminalTask(AgentTask task) async {
    final isTerminal = task.status == AgentTaskStatus.completed ||
        task.status == AgentTaskStatus.failed ||
        task.status == AgentTaskStatus.cancelled;
    if (!isTerminal) {
      return;
    }
    await _memoryStore.upsertEntry(
      MemoryEntry(
        id: 'task_memory_${task.id}',
        kind: MemoryEntryKind.episodic,
        scope: 'task',
        title: task.prompt,
        content: <String, Object?>{
          'taskId': task.id,
          'status': task.status.name,
          'stepCount': task.steps.length,
          'error': task.error,
        },
        summary: '${task.status.name} task: ${task.prompt}',
        tags: <String>['task', task.status.name],
        conversationId: task.conversationId,
        taskId: task.id,
        sourceEntityType: 'agent_task',
        sourceEntityId: task.id,
        importanceScore: task.status == AgentTaskStatus.completed ? 0.7 : 0.85,
        createdAtEpochMs: task.createdAtEpochMs,
        updatedAtEpochMs: task.updatedAtEpochMs,
      ),
    );
  }

  Future<void> captureWorkspaceItem(WorkspaceItem item) async {
    await _memoryStore.upsertEntry(
      MemoryEntry(
        id: 'workspace_memory_${item.id}',
        kind: item.type == WorkspaceItemType.generatedArtifact
            ? MemoryEntryKind.artifact
            : MemoryEntryKind.episodic,
        scope: 'workspace',
        title: item.title,
        content: <String, Object?>{
          'workspaceItemId': item.id,
          'type': workspaceItemTypeToJson(item.type),
          'mimeType': item.mimeType,
          'extension': item.extension,
          'sizeBytes': item.sizeBytes,
        },
        summary:
            '${item.type == WorkspaceItemType.generatedArtifact ? 'Generated artifact' : 'Workspace import'}: ${item.title}',
        tags: <String>[
          'workspace',
          workspaceItemTypeToJson(item.type),
          if (item.extension != null && item.extension!.trim().isNotEmpty)
            item.extension!.trim().toLowerCase(),
        ],
        conversationId: item.conversationId,
        sourceEntityType: 'workspace_item',
        sourceEntityId: item.id,
        importanceScore:
            item.type == WorkspaceItemType.generatedArtifact ? 0.8 : 0.55,
        createdAtEpochMs: item.createdAtEpochMs,
        updatedAtEpochMs: item.updatedAtEpochMs,
      ),
    );
  }

  Future<void> removeWorkspaceItemCapture(String itemId) {
    return _memoryStore.deleteEntriesBySource(
      sourceEntityType: 'workspace_item',
      sourceEntityId: itemId,
    );
  }
}
