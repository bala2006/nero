import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/agent/application/agent_task_planner.dart';
import 'package:nero/features/agent/application/agent_task_runtime_adapter.dart';
import 'package:nero/features/agent/domain/agent_task.dart';
import 'package:nero/features/chat/application/agent_orchestrator.dart';
import 'package:nero/features/chat/application/chat_run_lifecycle_bridge.dart';
import 'package:nero/features/chat/application/context_engine.dart';
import 'package:nero/features/chat/application/sarvam_api_client.dart';
import 'package:nero/features/chat/domain/chat_message.dart';
import 'package:nero/features/runtime/application/run_coordinator.dart';
import 'package:nero/features/runtime/domain/runtime_progress_snapshot.dart';
import 'package:nero/features/runtime/domain/runtime_run.dart';
import 'package:nero/features/runtime/domain/runtime_run_node.dart';

const runtimeAdapter = AgentTaskRuntimeAdapter(
  planner: AgentTaskPlanner(),
);

void main() {
  const bridge = ChatRunLifecycleBridge();

  test('prepared hook updates selected tools, prompt tokens, and task progress', () async {
    final hooks = _createHooks(bridge);
    final turn = AgentOrchestratorTurn(
      selectedTools: const <String>['search_web'],
      contextAssembly: const ContextEngineResult(
        messages: <ChatMessage>[],
        workingMemory: null,
        episodicMemories: [],
        semanticFacts: [],
        artifactReferences: [],
      ),
      requestMessages: const <ChatMessage>[
        ChatMessage(id: 'u1', role: ChatRole.user, content: 'research this'),
      ],
      activeToolDefinitions: const <SarvamToolDefinition>[],
    );

    await hooks.onPrepared!(
      _run(),
      turn,
    );

    expect(_capturedRun, isNotNull);
    expect(_selectedTools, ['search_web']);
    expect(_promptTokens, 1);
    expect(
      _task!.steps.firstWhere((step) => step.kind == AgentStepKinds.interpretPrompt).status,
      AgentStepStatus.completed,
    );
    expect(
      _task!.steps.firstWhere((step) => step.kind == AgentStepKinds.planTask).status,
      AgentStepStatus.running,
    );
  });

  test('tool batch and auto continue hooks update status and request token count', () async {
    final hooks = _createHooks(bridge);
    await hooks.onProgress!(
      _run(),
      const RuntimeProgressSnapshot(
        runId: 'run_1',
        runStatus: RuntimeRunStatus.runningModel,
        phases: <RuntimePhaseSnapshot>[
          RuntimePhaseSnapshot(
            phaseKey: 'assistant_round',
            title: 'Assistant round',
            status: RuntimeRunNodeStatus.running,
          ),
        ],
        currentPhase: RuntimePhaseSnapshot(
          phaseKey: 'assistant_round',
          title: 'Assistant round',
          status: RuntimeRunNodeStatus.running,
        ),
      ),
    );
    expect(_capturedSnapshot?.currentPhase?.phaseKey, 'assistant_round');

    await hooks.onToolBatchStarting!(
      _run(),
      const <SarvamToolCall>[
        SarvamToolCall(id: '1', name: 'search_web', arguments: <String, dynamic>{'query': 'x'}),
      ],
    );
    expect(_status, 'Running tools');

    await hooks.onAutoContinue!(_run());
    expect(_status, 'Continuing response');

    await hooks.onRequestMessagesMutated!(
      _run(),
      const <ChatMessage>[
        ChatMessage(id: 'u1', role: ChatRole.user, content: 'a'),
        ChatMessage(id: 'u2', role: ChatRole.user, content: 'b'),
      ],
    );
    expect(_promptTokens, 2);
    expect(_notifyCount, 1);
  });
}

AgentTask? _task;
RuntimeRun? _capturedRun;
RuntimeProgressSnapshot? _capturedSnapshot;
List<String> _selectedTools = const <String>[];
String _status = '';
int _promptTokens = 0;
int _notifyCount = 0;

RunCoordinatorHooks _createHooks(ChatRunLifecycleBridge bridge) {
  _task = runtimeAdapter.startTask(
    conversationId: 'conversation_1',
    prompt: 'research this',
  );
  _capturedRun = null;
  _capturedSnapshot = null;
  _selectedTools = const <String>[];
  _status = '';
  _promptTokens = 0;
  _notifyCount = 0;

  return bridge.createHooks(
    applyRunUpdate: (run) => _capturedRun = run,
    applyRuntimeProgressUpdate: (run, snapshot) {
      _capturedRun = run;
      _capturedSnapshot = snapshot;
    },
    updateActiveTask: (update) => _task = update(_task!),
    setThought: (_) {},
    setStatus: (status) => _status = status,
    setPromptTokens: (promptTokens) => _promptTokens = promptTokens,
    setSelectedTools: (selectedTools) => _selectedTools = selectedTools,
    estimateMessagesTokenCount: (requestMessages) => requestMessages.length,
    notifyListeners: () => _notifyCount += 1,
  );
}

RuntimeRun _run() {
  return const RuntimeRun(
    id: 'run_1',
    kind: RuntimeRunKind.conversation,
    title: 'Test',
    status: RuntimeRunStatus.runningModel,
    createdAtEpochMs: 1,
    updatedAtEpochMs: 1,
  );
}
