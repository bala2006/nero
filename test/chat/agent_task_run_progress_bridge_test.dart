import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/agent/application/agent_task_run_progress_bridge.dart';
import 'package:nero/features/agent/application/agent_task_runtime_adapter.dart';
import 'package:nero/features/agent/domain/agent_task.dart';
import 'package:nero/features/chat/application/sarvam_api_client.dart';
import 'package:nero/features/chat/application/tool_dispatcher.dart';
import 'package:nero/features/chat/application/web_tools.dart';

void main() {
  const bridge = AgentTaskRunProgressBridge();
  const adapter = AgentTaskRuntimeAdapter();

  test('onPrepared advances interpretation and planning steps', () {
    final task = adapter.startTask(
      conversationId: 'conv',
      prompt: 'Find the latest guidance',
    );

    final nextTask = bridge.onPrepared(
      task,
      selectedTools: const <String>['search_web'],
    );

    expect(
      nextTask.steps
          .firstWhere((step) => step.kind == AgentStepKinds.interpretPrompt)
          .status,
      AgentStepStatus.completed,
    );
    expect(
      nextTask.steps
          .firstWhere((step) => step.kind == AgentStepKinds.planTask)
          .status,
      AgentStepStatus.running,
    );
  });

  test('onToolBatchStarting marks document generation step as running', () {
    const task = AgentTask(
      id: 'task_2',
      conversationId: 'conv',
      prompt: 'Create a docx',
      status: AgentTaskStatus.running,
      createdAtEpochMs: 1,
      updatedAtEpochMs: 1,
      steps: <AgentStep>[
        AgentStep(
          id: 's1',
          kind: AgentStepKinds.planTask,
          title: 'Plan document',
          status: AgentStepStatus.running,
        ),
        AgentStep(
          id: 's2',
          kind: AgentStepKinds.generateDocument,
          title: 'Generate document',
          status: AgentStepStatus.pending,
        ),
      ],
    );

    final nextTask = bridge.onToolBatchStarting(
      task,
      toolCalls: const <SarvamToolCall>[
        SarvamToolCall(
          id: 'tool_doc',
          name: 'generate_docx',
          arguments: <String, dynamic>{
            'title': 'Doc',
            'markdown_content': '# Doc',
          },
        ),
      ],
    );

    expect(nextTask.steps.first.status, AgentStepStatus.completed);
    expect(nextTask.steps.last.status, AgentStepStatus.running);
  });

  test('onToolBatchCompleted moves to synthesis after research success', () {
    final initialTask = adapter.startTask(
      conversationId: 'conv',
      prompt: 'Find the latest guidance',
    );
    final preparedTask = bridge.onPrepared(
      initialTask,
      selectedTools: const <String>['search_web'],
    );
    final runningResearchTask = bridge.onToolBatchStarting(
      preparedTask,
      toolCalls: const <SarvamToolCall>[
        SarvamToolCall(
          id: 'tool_search',
          name: 'search_web',
          arguments: <String, dynamic>{'query': 'query'},
        ),
      ],
    );

    final nextTask = bridge.onToolBatchCompleted(
      runningResearchTask,
      results: const <ToolDispatchResult>[
        ToolDispatchResult(
          call: SarvamToolCall(
            id: 'tool_search',
            name: 'search_web',
            arguments: <String, dynamic>{'query': 'query'},
          ),
          result: ToolExecutionResult(
            success: true,
            summary: 'Done',
            formattedOutput: 'Done',
          ),
          compactSummary: 'Done',
        ),
      ],
    );

    expect(
      nextTask.steps
          .firstWhere((step) => step.kind == AgentStepKinds.toolResearch)
          .status,
      AgentStepStatus.completed,
    );
    expect(
      nextTask.steps
          .firstWhere((step) => step.kind == AgentStepKinds.synthesizeResponse)
          .status,
      AgentStepStatus.running,
    );
  });

  test('onToolBatchCompleted marks document generation failed without fallback', () {
    final initialTask = adapter.startTask(
      conversationId: 'conv',
      prompt: 'Create a docx about capabilities',
    );
    final preparedTask = bridge.onPrepared(
      initialTask,
      selectedTools: const <String>['generate_docx'],
    );
    final runningDocTask = bridge.onToolBatchStarting(
      preparedTask,
      toolCalls: const <SarvamToolCall>[
        SarvamToolCall(
          id: 'tool_doc',
          name: 'generate_docx',
          arguments: <String, dynamic>{
            'title': 'Doc',
            'markdown_content': '# Doc',
          },
        ),
      ],
    );

    final nextTask = bridge.onToolBatchCompleted(
      runningDocTask,
      results: const <ToolDispatchResult>[
        ToolDispatchResult(
          call: SarvamToolCall(
            id: 'tool_doc',
            name: 'generate_docx',
            arguments: <String, dynamic>{
              'title': 'Doc',
              'markdown_content': '# Doc',
            },
          ),
          result: ToolExecutionResult(
            success: false,
            summary: 'Failed',
            formattedOutput: 'DOCX failed',
          ),
          compactSummary: 'Failed',
        ),
      ],
    );

    final generateStep = nextTask.steps.firstWhere(
      (step) => step.kind == AgentStepKinds.generateDocument,
    );
    expect(generateStep.status, AgentStepStatus.failed);
    expect(
      nextTask.steps.any(
        (step) =>
            step.kind == AgentStepKinds.streamResponse &&
            step.status == AgentStepStatus.running,
      ),
      isFalse,
    );
  });
}
