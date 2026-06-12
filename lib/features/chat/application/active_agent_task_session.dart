import 'dart:async';

import '../../agent/application/agent_task_runtime_adapter.dart';
import '../../agent/application/agent_task_store.dart';
import '../../agent/domain/agent_task.dart';

typedef AgentTaskChangedCallback = void Function(AgentTask? task);

class ActiveAgentTaskSession {
  ActiveAgentTaskSession({
    required AgentTaskRuntimeAdapter runtimeAdapter,
    required AgentTaskStore taskStore,
    AgentTaskChangedCallback? onTaskChanged,
  }) : _runtimeAdapter = runtimeAdapter,
       _taskStore = taskStore,
       _onTaskChanged = onTaskChanged;

  final AgentTaskRuntimeAdapter _runtimeAdapter;
  final AgentTaskStore _taskStore;
  final AgentTaskChangedCallback? _onTaskChanged;

  AgentTask? _task;
  Future<void> _persistQueue = Future<void>.value();

  AgentTask? get task => _task;

  void clear() {
    _task = null;
    _onTaskChanged?.call(null);
  }

  Future<void> startTask({
    required String conversationId,
    required String prompt,
  }) async {
    _task = _runtimeAdapter.startTask(
      conversationId: conversationId,
      prompt: prompt,
    );
    _onTaskChanged?.call(_task);
    await persist();
  }

  bool hasStep(String kind) {
    final task = _task;
    if (task == null) {
      return false;
    }
    return _runtimeAdapter.hasStep(task, kind);
  }

  String? primaryDraftingStepKind() {
    final task = _task;
    if (task == null) {
      return null;
    }
    return _runtimeAdapter.primaryDraftingStepKind(task);
  }

  void markStepRunningIfPresent(String kind, {required String detail}) {
    if (hasStep(kind)) {
      markStepRunning(kind, detail: detail);
    }
  }

  void markStepCompletedIfPresent(String kind, {required String detail}) {
    if (hasStep(kind)) {
      markStepCompleted(kind, detail: detail);
    }
  }

  void markStepRunning(String kind, {String? detail}) {
    apply((task) => _runtimeAdapter.markStepRunning(task, kind, detail: detail));
  }

  void markStepCompleted(String kind, {String? detail}) {
    apply(
      (task) => _runtimeAdapter.markStepCompleted(task, kind, detail: detail),
    );
  }

  void markStepFailed(String kind, {required String error}) {
    apply((task) => _runtimeAdapter.markStepFailed(task, kind, error: error));
  }

  void completeTask() {
    apply(_runtimeAdapter.completeTask);
  }

  void failTask(String error) {
    apply((task) => _runtimeAdapter.failTask(task, error));
  }

  void cancelTask() {
    apply(_runtimeAdapter.cancelTask);
  }

  void refreshTaskStatus() {
    apply(_runtimeAdapter.refreshTaskStatus);
  }

  void apply(AgentTask Function(AgentTask task) update) {
    final task = _task;
    if (task == null) {
      return;
    }
    final nextTask = update(task);
    _task = nextTask;
    _onTaskChanged?.call(nextTask);
    unawaited(persist(task: nextTask));
  }

  Future<void> persist({AgentTask? task}) async {
    final snapshot = task ?? _task;
    if (snapshot == null) {
      return;
    }
    _persistQueue = _persistQueue
        .catchError((Object _) {})
        .then((_) => _taskStore.upsertTask(snapshot));
    await _persistQueue;
  }
}
