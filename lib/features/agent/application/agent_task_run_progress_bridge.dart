import '../../chat/application/sarvam_api_client.dart';
import '../../chat/application/tool_dispatcher.dart';
import '../domain/agent_task.dart';
import 'agent_task_planner.dart';
import 'agent_task_runtime_adapter.dart';

class AgentTaskRunProgressBridge {
  const AgentTaskRunProgressBridge({
    AgentTaskRuntimeAdapter taskRuntimeAdapter =
        const AgentTaskRuntimeAdapter(),
  }) : _taskRuntimeAdapter = taskRuntimeAdapter;

  final AgentTaskRuntimeAdapter _taskRuntimeAdapter;

  AgentTask onPrepared(
    AgentTask task, {
    required List<String> selectedTools,
  }) {
    var nextTask = _taskRuntimeAdapter.replanForSelection(
      task: task,
      selectedTools: selectedTools,
    );
    nextTask = _taskRuntimeAdapter.markStepCompleted(
      nextTask,
      AgentStepKinds.interpretPrompt,
      detail: 'User goal interpreted successfully.',
    );
    if (_taskRuntimeAdapter.hasStep(nextTask, AgentStepKinds.planTask)) {
      return _taskRuntimeAdapter.markStepRunning(
        nextTask,
        AgentStepKinds.planTask,
        detail: 'Assembling the execution path for this response.',
      );
    }
    final draftingKind = _taskRuntimeAdapter.primaryDraftingStepKind(nextTask);
    if (draftingKind == null) {
      return nextTask;
    }
    return _taskRuntimeAdapter.markStepRunning(
      nextTask,
      draftingKind,
      detail: 'Preparing the answer directly from the conversation context.',
    );
  }

  AgentTask onToolBatchStarting(
    AgentTask task, {
    required List<SarvamToolCall> toolCalls,
  }) {
    var nextTask = task;
    if (_taskRuntimeAdapter.hasStep(nextTask, AgentStepKinds.planTask)) {
      nextTask = _taskRuntimeAdapter.markStepCompleted(
        nextTask,
        AgentStepKinds.planTask,
        detail: 'Execution plan finalized with tool work.',
      );
    }
    if (toolCalls.any(_isWebTool) &&
        _taskRuntimeAdapter.hasStep(nextTask, AgentStepKinds.toolResearch)) {
      nextTask = _taskRuntimeAdapter.markStepRunning(
        nextTask,
        AgentStepKinds.toolResearch,
        detail: 'Executing ${toolCalls.length} tool call(s).',
      );
    }
    if (toolCalls.any(_isOutputTool) &&
        _taskRuntimeAdapter.hasStep(nextTask, AgentStepKinds.generateDocument)) {
      nextTask = _taskRuntimeAdapter.markStepRunning(
        nextTask,
        AgentStepKinds.generateDocument,
        detail: 'Generating the requested file artifact.',
      );
    }
    return nextTask;
  }

  AgentTask onToolBatchCompleted(
    AgentTask task, {
    required List<ToolDispatchResult> results,
  }) {
    var nextTask = _taskRuntimeAdapter.replanForToolOutcomes(
      task: task,
      selectedTools: results.map((result) => result.call.name).toList(),
      outcomes: results
          .map(
            (result) => AgentToolOutcome(
              toolName: result.call.name,
              success: result.result.success,
              detail: result.result.summary,
            ),
          )
          .toList(growable: false),
    );
    if (results.any((result) => _isWebTool(result.call))) {
      final hadWebFailure = results.any(
        (result) => _isWebTool(result.call) && !result.result.success,
      );
      if (_taskRuntimeAdapter.hasStep(nextTask, AgentStepKinds.toolResearch)) {
        nextTask = _taskRuntimeAdapter.markStepCompleted(
          nextTask,
          AgentStepKinds.toolResearch,
          detail: hadWebFailure
              ? 'External context was partial or unavailable. Proceeding with a degraded synthesis.'
              : 'External context collected successfully.',
        );
      }
    }
    if (results.any((result) => _isOutputTool(result.call))) {
      final docFailure = results.any(
        (result) => _isOutputTool(result.call) && !result.result.success,
      );
      if (_taskRuntimeAdapter.hasStep(nextTask, AgentStepKinds.generateDocument)) {
        nextTask = docFailure
            ? _taskRuntimeAdapter.markStepFailed(
                nextTask,
                AgentStepKinds.generateDocument,
                error: 'File artifact generation failed.',
              )
            : _taskRuntimeAdapter.markStepCompleted(
                nextTask,
                AgentStepKinds.generateDocument,
                detail: 'File artifact generated successfully.',
              );
      }
      if (docFailure) {
        return nextTask;
      }
    }
    final draftingKind = _taskRuntimeAdapter.primaryDraftingStepKind(nextTask);
    if (draftingKind != null) {
      nextTask = _taskRuntimeAdapter.markStepRunning(
        nextTask,
        draftingKind,
        detail: draftingKind == AgentStepKinds.synthesizeResponse
            ? 'Synthesizing tool results into the answer.'
            : 'Preparing the final response for chat delivery.',
      );
    }
    return nextTask;
  }

  AgentTask onAutoContinue(AgentTask task) {
    var nextTask = task;
    final draftingKind = _taskRuntimeAdapter.primaryDraftingStepKind(nextTask);
    if (draftingKind != null) {
      nextTask = _taskRuntimeAdapter.markStepCompleted(
        nextTask,
        draftingKind,
        detail: 'Partial response prepared. Requesting continuation.',
      );
    }
    if (_taskRuntimeAdapter.hasStep(nextTask, AgentStepKinds.streamResponse)) {
      nextTask = _taskRuntimeAdapter.markStepRunning(
        nextTask,
        AgentStepKinds.streamResponse,
        detail:
            'Model reached the response limit. Continuing from the same point.',
      );
    }
    return nextTask;
  }

  AgentTask onFinalResponseReady(AgentTask task) {
    var nextTask = task;
    if (_taskRuntimeAdapter.hasStep(nextTask, AgentStepKinds.planTask)) {
      nextTask = _taskRuntimeAdapter.markStepCompleted(
        nextTask,
        AgentStepKinds.planTask,
        detail: 'Execution plan finalized.',
      );
    }
    final draftingKind = _taskRuntimeAdapter.primaryDraftingStepKind(nextTask);
    if (draftingKind != null) {
      nextTask = _taskRuntimeAdapter.markStepCompleted(
        nextTask,
        draftingKind,
        detail: 'Response draft is ready.',
      );
    }
    if (_taskRuntimeAdapter.hasStep(nextTask, AgentStepKinds.streamResponse)) {
      nextTask = _taskRuntimeAdapter.markStepRunning(
        nextTask,
        AgentStepKinds.streamResponse,
        detail: 'Streaming the answer into chat.',
      );
    }
    return nextTask;
  }

  bool _isWebTool(SarvamToolCall toolCall) {
    return toolCall.name == 'search_web' ||
        toolCall.name == 'read_url' ||
        toolCall.name == 'extract_article';
  }

  bool _isOutputTool(SarvamToolCall toolCall) {
    return toolCall.name == 'generate_docx' ||
        toolCall.name == 'generate_xlsx' ||
        toolCall.name == 'generate_report_pdf';
  }
}
