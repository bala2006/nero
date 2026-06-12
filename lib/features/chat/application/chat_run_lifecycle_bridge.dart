import '../../agent/application/agent_task_run_progress_bridge.dart';
import '../../agent/domain/agent_task.dart';
import '../../runtime/application/run_coordinator.dart';
import '../../runtime/domain/runtime_progress_snapshot.dart';
import '../../runtime/domain/runtime_run.dart';
import '../domain/chat_message.dart';

typedef RunTaskUpdater = void Function(AgentTask Function(AgentTask task) update);
typedef RunThoughtSetter = void Function(String thought);
typedef RunStatusSetter = void Function(String status);
typedef RunPromptTokenSetter = void Function(int promptTokens);
typedef RunSelectedToolsSetter = void Function(List<String> selectedTools);
typedef RunNotifier = void Function();
typedef RunUpdateApplier = void Function(RuntimeRun run);
typedef RunProgressApplier =
    void Function(RuntimeRun run, RuntimeProgressSnapshot snapshot);
typedef RequestTokenEstimator = int Function(List<ChatMessage> requestMessages);

class ChatRunLifecycleBridge {
  const ChatRunLifecycleBridge({
    AgentTaskRunProgressBridge progressBridge =
        const AgentTaskRunProgressBridge(),
  }) : _progressBridge = progressBridge;

  final AgentTaskRunProgressBridge _progressBridge;

  RunCoordinatorHooks createHooks({
    required RunUpdateApplier applyRunUpdate,
    required RunProgressApplier applyRuntimeProgressUpdate,
    required RunTaskUpdater updateActiveTask,
    required RunThoughtSetter setThought,
    required RunStatusSetter setStatus,
    required RunPromptTokenSetter setPromptTokens,
    required RunSelectedToolsSetter setSelectedTools,
    required RequestTokenEstimator estimateMessagesTokenCount,
    required RunNotifier notifyListeners,
  }) {
    return RunCoordinatorHooks(
      onRunStarted: applyRunUpdate,
      onProgress: applyRuntimeProgressUpdate,
      onPrepared: (run, turn) {
        applyRunUpdate(run);
        setSelectedTools(List<String>.unmodifiable(turn.selectedTools));
        updateActiveTask(
          (task) => _progressBridge.onPrepared(
            task,
            selectedTools: turn.selectedTools,
          ),
        );
        setPromptTokens(estimateMessagesTokenCount(turn.requestMessages));
      },
      onThought: (_, thought) => setThought(thought),
      onToolBatchStarting: (run, toolCalls) {
        applyRunUpdate(run);
        setStatus('Running tools');
        updateActiveTask(
          (task) => _progressBridge.onToolBatchStarting(
            task,
            toolCalls: toolCalls,
          ),
        );
      },
      onToolBatchCompleted: (run, results) {
        applyRunUpdate(run);
        updateActiveTask(
          (task) => _progressBridge.onToolBatchCompleted(
            task,
            results: results,
          ),
        );
      },
      onAutoContinue: (_) {
        setStatus('Continuing response');
        updateActiveTask(_progressBridge.onAutoContinue);
      },
      onRequestMessagesMutated: (_, requestMessages) {
        setPromptTokens(estimateMessagesTokenCount(requestMessages));
        notifyListeners();
      },
      onRunCompleted: (run, _) => applyRunUpdate(run),
      onRunFailed: (run, _) => applyRunUpdate(run),
      onRunCancelled: applyRunUpdate,
    );
  }
}
