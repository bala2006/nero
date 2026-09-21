import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/capabilities/capabilities.dart';
import 'package:nero/features/chat/application/agent_orchestrator.dart';
import 'package:nero/features/chat/application/context_engine.dart';
import 'package:nero/features/chat/application/prompt_variants.dart';
import 'package:nero/features/chat/application/response_repair_coordinator.dart';
import 'package:nero/features/chat/application/response_guard.dart';
import 'package:nero/features/chat/application/sarvam_api_client.dart';
import 'package:nero/features/chat/application/tool_dispatcher.dart';
import 'package:nero/features/chat/application/tool_selector.dart';
import 'package:nero/features/chat/application/web_tools.dart';
import 'package:nero/features/chat/domain/chat_message.dart';
import 'package:nero/features/memory/application/memory_store.dart';
import 'package:nero/features/memory/application/semantic_fact_store.dart';
import 'package:nero/features/memory/application/working_memory_store.dart';
import 'package:nero/features/memory/application/memory_write_coordinator.dart';
import 'package:nero/features/memory/domain/artifact_reference.dart';
import 'package:nero/features/memory/domain/memory_entry.dart';
import 'package:nero/features/memory/domain/semantic_fact.dart';
import 'package:nero/features/runtime/application/run_coordinator.dart';
import 'package:nero/features/runtime/application/runtime_ledger_service.dart';
import 'package:nero/features/runtime/application/runtime_run_store.dart';
import 'package:nero/features/runtime/domain/agent_policy.dart';
import 'package:nero/features/runtime/domain/runtime_operation_ledger_record.dart';
import 'package:nero/features/runtime/domain/runtime_run.dart';
import 'package:nero/features/runtime/domain/runtime_run_node.dart';
import 'package:nero/features/settings/app_settings.dart';
import 'package:nero/features/skills/skills.dart';
import 'package:nero/features/workspace/application/workspace_store.dart';
import 'package:nero/platform/database/app_database.dart' as db;

void main() {
  late db.AppDatabase database;
  late RuntimeRunStore runStore;
  late RuntimeLedgerService ledgerService;

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    runStore = RuntimeRunStore(database: database);
    ledgerService = RuntimeLedgerService(store: runStore);
  });

  tearDown(() async {
    await database.close();
  });

  test('runTurn persists a completed lifecycle and tool operation', () async {
    final coordinator = RunCoordinator(
      orchestrator: _FakeAgentOrchestrator.successful(database),
      runtimeLedgerService: ledgerService,
      runIdFactory: () => 'run_test_1',
    );
    final progressSnapshots = <Object?>[];

    final result = await coordinator.runTurn(
      apiKey: 'sk_test',
      settings: const NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-105b',
      ),
      prompt: 'Generate a document',
      conversationId: 'conversation_1',
      taskId: 'task_1',
      modelHistory: const <ChatMessage>[],
      allToolDefinitions: CapabilityToolAdapter.modelVisibleToolDefinitions(),
      outputToolsPrompt: 'Output tools prompt',
      taskHint: null,
      executeAssistantRound:
          ({
            required List<ChatMessage> requestMessages,
            required List<SarvamToolDefinition> tools,
            required StringBuffer responseBuffer,
          }) async => throw UnimplementedError(),
      executeToolCall: (_) async => throw UnimplementedError(),
      shouldAutoContinue:
          ({
            required String prompt,
            required SarvamChatResult result,
            required String accumulatedResponse,
            required int roundsUsed,
            bool expectsArtifact = false,
            bool artifactProduced = false,
          }) => false,
      hooks: RunCoordinatorHooks(
        onProgress: (_, snapshot) {
          progressSnapshots.add(snapshot.toJson());
        },
      ),
    );

    expect(result.run.status, RuntimeRunStatus.completed);
    expect(
      result.orchestrationResult.validatedResponse.content,
      'Final answer.',
    );
    expect(result.selectedSkill, isNotNull);
    expect(result.selectedSkill!.skill.skillId, 'document_generation_skill');
    expect(result.skillRun, isNotNull);
    expect(result.skillRun!.status, SkillRunStatus.completed);
    expect(result.skillRun!.completedStepIds, isNotEmpty);
    expect(result.responseEnvelope.displayText, 'Final answer.');
    expect(result.responseVerification, isNotNull);
    expect(result.progressSnapshot, isNotNull);
    expect(result.progressSnapshot!.phases, isNotEmpty);
    expect(progressSnapshots, isNotEmpty);
    expect(
      progressSnapshots.any(
        (snapshot) => ((snapshot as Map)['phases'] as List).any(
          (phase) => (phase as Map)['phaseKey'] == 'skill_execution',
        ),
      ),
      isTrue,
    );

    final persistedRun = await runStore.getRun('run_test_1');
    expect(persistedRun, isNotNull);
    expect(persistedRun!.status, RuntimeRunStatus.completed);
    expect(persistedRun.result?['selected_tools'], contains('generate_docx'));
    expect(
      persistedRun.metadata['selected_skill_id'],
      'document_generation_skill',
    );
    expect(persistedRun.metadata['selected_skill_status'], 'completed');
    expect(persistedRun.metadata['selected_skill_output'], isA<Map>());
    expect(persistedRun.metadata['progress_snapshot'], isA<Map>());
    expect(persistedRun.metadata['debug_counters'], isA<Map>());
    expect(persistedRun.metadata['debug_metadata'], isA<Map>());
    expect(persistedRun.result?['response_envelope'], isA<Map>());

    final events = await runStore.listEvents('run_test_1');
    expect(events.map((event) => event.kind.name), contains('completed'));

    final operations = await runStore.listOperations('run_test_1');
    expect(operations, hasLength(1));
    expect(operations.single.kind, 'generate_docx');

    final nodes = await runStore.listNodes('run_test_1');
    expect(
      nodes.map((node) => node.phaseKey),
      containsAll(<String>[
        'root',
        'skill_selection',
        'skill_execution',
        'skill_step',
        'prepare_context',
        'assistant_round',
        'tool_batch',
        'tool_call',
        'response_verification',
      ]),
    );
    expect(
      nodes.firstWhere((node) => node.phaseKey == 'root').status,
      RuntimeRunNodeStatus.completed,
    );
    expect(
      nodes.firstWhere((node) => node.phaseKey == 'skill_execution').status,
      RuntimeRunNodeStatus.completed,
    );
    expect(
      nodes.firstWhere((node) => node.phaseKey == 'tool_call').toolName,
      'generate_docx',
    );
  });

  test('runTurn allows recoverable empty responses for artifact requests', () async {
    final coordinator = RunCoordinator(
      orchestrator: _FakeAgentOrchestrator.emptyArtifactResponse(database),
      runtimeLedgerService: ledgerService,
      runIdFactory: () => 'run_test_empty_artifact',
    );

    final result = await coordinator.runTurn(
      apiKey: 'sk_test',
      settings: const NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-105b',
      ),
      prompt: 'Generate a docx about capabilities',
      conversationId: 'conversation_1',
      taskId: 'task_1',
      modelHistory: const <ChatMessage>[],
      allToolDefinitions: CapabilityToolAdapter.modelVisibleToolDefinitions(),
      outputToolsPrompt: 'Output tools prompt',
      taskHint: null,
      executeAssistantRound:
          ({
            required List<ChatMessage> requestMessages,
            required List<SarvamToolDefinition> tools,
            required StringBuffer responseBuffer,
          }) async => throw UnimplementedError(),
      executeToolCall: (_) async => throw UnimplementedError(),
      shouldAutoContinue:
          ({
            required String prompt,
            required SarvamChatResult result,
            required String accumulatedResponse,
            required int roundsUsed,
            bool expectsArtifact = false,
            bool artifactProduced = false,
          }) => false,
    );

    expect(result.run.status, RuntimeRunStatus.completed);
    expect(result.responseVerification, isNotNull);
    expect(
      result.responseVerification!.blockingIssues.map((issue) => issue.code),
      contains('response.empty'),
    );
    expect(result.orchestrationResult.selectedTools, contains('generate_docx'));
    expect(
      result.progressSnapshot?.phases.map((phase) => phase.phaseKey),
      contains('response_repair'),
    );

    final persistedRun = await runStore.getRun('run_test_empty_artifact');
    expect(
      ((persistedRun!.result?['response_verification'] as Map)['recoverable_issue_codes']
              as List)
          .contains('response.empty'),
      isTrue,
    );
    expect(
      ((persistedRun.metadata['debug_counters'] as Map)['response_empty_count']),
      1,
    );
  });

  test('runTurn blocks replay of a completed side-effecting operation', () async {
    await ledgerService.recordOperation(
      runId: 'run_test_replay_block',
      operationKey: _stableOperationKey(
        'generate_report_pdf',
        const <String, Object?>{
          'title': 'Capabilities PDF',
          'markdown_content': '# Capabilities',
        },
      ),
      kind: 'generate_report_pdf',
      status: RuntimeOperationStatus.completed,
      request: const <String, Object?>{
        'title': 'Capabilities PDF',
        'markdown_content': '# Capabilities',
      },
      completedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );

    final coordinator = RunCoordinator(
      orchestrator: _FakeAgentOrchestrator.completedPdfReplay(database),
      runtimeLedgerService: ledgerService,
      runIdFactory: () => 'run_test_replay_block',
    );

    expect(
      () => coordinator.runTurn(
        apiKey: 'sk_test',
        settings: const NeroSettings(
          azureApiKey: 'sk_test',
          selectedModelId: 'sarvam-105b',
        ),
        prompt: 'Generate a PDF about capabilities',
        conversationId: 'conversation_1',
        taskId: 'task_1',
        modelHistory: const <ChatMessage>[],
        allToolDefinitions: CapabilityToolAdapter.modelVisibleToolDefinitions(),
        outputToolsPrompt: 'Output tools prompt',
        taskHint: null,
        executeAssistantRound:
            ({
              required List<ChatMessage> requestMessages,
              required List<SarvamToolDefinition> tools,
              required StringBuffer responseBuffer,
            }) async => throw UnimplementedError(),
        executeToolCall: (_) async => throw UnimplementedError(),
        shouldAutoContinue:
            ({
              required String prompt,
              required SarvamChatResult result,
              required String accumulatedResponse,
              required int roundsUsed,
              bool expectsArtifact = false,
              bool artifactProduced = false,
            }) => false,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('replay a completed generate_report_pdf operation'),
        ),
      ),
    );
  });

  test('runTurn treats raw tool markers as recoverable for artifact requests', () async {
    final coordinator = RunCoordinator(
      orchestrator: _FakeAgentOrchestrator.toolMarkerArtifactResponse(database),
      runtimeLedgerService: ledgerService,
      runIdFactory: () => 'run_test_tool_marker_recoverable',
    );

    final result = await coordinator.runTurn(
      apiKey: 'sk_test',
      settings: const NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-105b',
      ),
      prompt: 'Create a docx about capabilities',
      conversationId: 'conversation_1',
      taskId: 'task_1',
      modelHistory: const <ChatMessage>[],
      allToolDefinitions: CapabilityToolAdapter.modelVisibleToolDefinitions(),
      outputToolsPrompt: 'Output tools prompt',
      taskHint: null,
      executeAssistantRound:
          ({
            required List<ChatMessage> requestMessages,
            required List<SarvamToolDefinition> tools,
            required StringBuffer responseBuffer,
          }) async => throw UnimplementedError(),
      executeToolCall: (_) async => throw UnimplementedError(),
      shouldAutoContinue:
          ({
            required String prompt,
            required SarvamChatResult result,
            required String accumulatedResponse,
            required int roundsUsed,
            bool expectsArtifact = false,
            bool artifactProduced = false,
          }) => false,
    );

    expect(result.run.status, RuntimeRunStatus.completed);
    expect(result.responseVerification, isNotNull);
    expect(
      result.responseVerification!.blockingIssues.map((issue) => issue.code),
      contains('response.tool_marker_leak'),
    );
  });

  test('runTurn repairs empty responses for research routes', () async {
    final coordinator = RunCoordinator(
      orchestrator: _FakeAgentOrchestrator.emptyResearchResponse(database),
      runtimeLedgerService: ledgerService,
      responseRepairCoordinator: ResponseRepairCoordinator(
        client: _RepairingChatCompletionClient(
          repairedContent: 'Claude and OpenAI differ in tool design, model behavior, and ecosystem focus.',
        ),
      ),
      runIdFactory: () => 'run_test_empty_research',
    );

    final result = await coordinator.runTurn(
      apiKey: 'sk_test',
      settings: const NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-105b',
      ),
      prompt: 'research and compare claude vs openai',
      conversationId: 'conversation_1',
      taskId: 'task_1',
      modelHistory: const <ChatMessage>[],
      allToolDefinitions: CapabilityToolAdapter.modelVisibleToolDefinitions(),
      outputToolsPrompt: 'Output tools prompt',
      taskHint: null,
      executeAssistantRound:
          ({
            required List<ChatMessage> requestMessages,
            required List<SarvamToolDefinition> tools,
            required StringBuffer responseBuffer,
          }) async => throw UnimplementedError(),
      executeToolCall: (_) async => throw UnimplementedError(),
      shouldAutoContinue:
          ({
            required String prompt,
            required SarvamChatResult result,
            required String accumulatedResponse,
            required int roundsUsed,
            bool expectsArtifact = false,
            bool artifactProduced = false,
          }) => false,
    );

    expect(result.run.status, RuntimeRunStatus.completed);
    expect(
      result.orchestrationResult.validatedResponse.content,
      contains('Claude and OpenAI differ'),
    );
    expect(result.responseVerification, isNotNull);
    expect(
      result.responseVerification!.blockingIssues.map((issue) => issue.code),
      isNot(contains('response.empty')),
    );
    expect(
      result.progressSnapshot?.phases.map((phase) => phase.phaseKey),
      contains('response_repair'),
    );
    final repairPhase = result.progressSnapshot!.phases.firstWhere(
      (phase) => phase.phaseKey == 'response_repair',
    );
    expect(repairPhase.status, RuntimeRunNodeStatus.completed);
    final persistedRun = await runStore.getRun('run_test_empty_research');
    expect(
      ((persistedRun!.metadata['debug_counters'] as Map)['response_repair_attempt_count']),
      1,
    );
    expect(
      ((persistedRun.metadata['debug_counters'] as Map)['response_repair_success_count']),
      1,
    );
    expect(
      (((persistedRun.metadata['debug_metadata'] as Map)['selector'] as Map)),
      isA<Map>(),
    );
    expect(
      ((persistedRun.metadata['debug_metadata'] as Map)['selector_strategy_details']
          as Map),
      isA<Map>(),
    );
  });

  test('runTurn repairs empty responses for direct routes via fallback policy', () async {
    final coordinator = RunCoordinator(
      orchestrator: _FakeAgentOrchestrator.emptyDirectResponse(database),
      runtimeLedgerService: ledgerService,
      responseRepairCoordinator: ResponseRepairCoordinator(
        client: _RepairingChatCompletionClient(
          repairedContent: 'Recursion is a function calling itself until a base case is reached.',
        ),
      ),
      runIdFactory: () => 'run_test_empty_direct',
    );

    final result = await coordinator.runTurn(
      apiKey: 'sk_test',
      settings: const NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-105b',
      ),
      prompt: 'What is recursion?',
      conversationId: 'conversation_1',
      taskId: 'task_1',
      modelHistory: const <ChatMessage>[],
      allToolDefinitions: CapabilityToolAdapter.modelVisibleToolDefinitions(),
      outputToolsPrompt: 'Output tools prompt',
      taskHint: null,
      executeAssistantRound:
          ({
            required List<ChatMessage> requestMessages,
            required List<SarvamToolDefinition> tools,
            required StringBuffer responseBuffer,
          }) async => throw UnimplementedError(),
      executeToolCall: (_) async => throw UnimplementedError(),
      shouldAutoContinue:
          ({
            required String prompt,
            required SarvamChatResult result,
            required String accumulatedResponse,
            required int roundsUsed,
            bool expectsArtifact = false,
            bool artifactProduced = false,
          }) => false,
    );

    expect(result.run.status, RuntimeRunStatus.completed);
    expect(
      result.orchestrationResult.validatedResponse.content,
      contains('base case'),
    );
    expect(
      result.progressSnapshot?.phases.map((phase) => phase.phaseKey),
      contains('response_repair'),
    );
    final persistedRun = await runStore.getRun('run_test_empty_direct');
    expect(
      ((persistedRun!.metadata['debug_counters'] as Map)['response_repair_attempt_count']),
      1,
    );
    expect(
      persistedRun.metadata['fallback_policy'],
      'repairDirectAnswer',
    );
  });

  test('appendDebugSignals merges counters and metadata', () async {
    final coordinator = RunCoordinator(
      orchestrator: _FakeAgentOrchestrator.successful(database),
      runtimeLedgerService: ledgerService,
      runIdFactory: () => 'run_test_debug_append',
    );
    final run = await ledgerService.startRun(
      id: 'run_test_debug_append',
      kind: RuntimeRunKind.conversation,
      title: 'Debug append',
      metadata: const <String, Object?>{
        'debug_counters': <String, Object?>{'compatibility_recovery_count': 1},
        'debug_metadata': <String, Object?>{'existing': true},
      },
    );

    final updated = await coordinator.appendDebugSignals(
      run: run,
      counterDeltas: const <String, int>{
        'compatibility_recovery_count': 1,
        'compatibility_tool_call_recovery_count': 2,
      },
      metadataPatch: const <String, Object?>{
        'compatibility_recovery_last': <String, Object?>{'recovered': true},
      },
    );

    expect(
      (updated.metadata['debug_counters'] as Map)['compatibility_recovery_count'],
      2,
    );
    expect(
      (updated.metadata['debug_counters'] as Map)['compatibility_tool_call_recovery_count'],
      2,
    );
    expect((updated.metadata['debug_metadata'] as Map)['existing'], isTrue);
    expect(
      ((updated.metadata['debug_metadata'] as Map)['compatibility_recovery_last']
          as Map)['recovered'],
      isTrue,
    );
  });
}

class _FakeAgentOrchestrator extends AgentOrchestrator {
  _FakeAgentOrchestrator._(this._handler, db.AppDatabase database)
    : super(
        toolSelector: _NoopToolSelector(),
        contextEngine: _NoopContextEngine(database),
        promptVariantSelector: const PromptVariantSelector(),
        toolDispatcher: ToolDispatcher(),
        responseGuard: const ResponseGuard(),
      );

  final Future<AgentOrchestratorResult> Function(AgentOrchestratorHooks hooks)
  _handler;

  factory _FakeAgentOrchestrator.successful(db.AppDatabase database) {
    return _FakeAgentOrchestrator._((hooks) async {
      const toolCall = SarvamToolCall(
        id: 'tool_doc',
        name: 'generate_docx',
        arguments: <String, dynamic>{
          'title': 'Capabilities',
          'markdown_content': '# Capabilities',
        },
      );
      hooks.onPrepared?.call(
        AgentOrchestratorTurn(
          selectedTools: <String>['generate_docx'],
          contextAssembly: const ContextEngineResult(
            messages: <ChatMessage>[],
            workingMemory: null,
            episodicMemories: <MemoryEntry>[],
            semanticFacts: <SemanticFact>[],
            artifactReferences: <ArtifactReference>[],
          ),
          requestMessages: <ChatMessage>[],
          activeToolDefinitions: <SarvamToolDefinition>[
            SarvamToolDefinition(
              name: 'generate_docx',
              description: 'Generate DOCX',
              parameters: <String, dynamic>{},
            ),
          ],
        ),
      );
      hooks.onToolBatchStarting?.call(const <SarvamToolCall>[toolCall]);
      hooks.onToolBatchCompleted?.call(const <ToolDispatchResult>[
        ToolDispatchResult(
          call: toolCall,
          result: ToolExecutionResult(
            success: true,
            summary: 'Created document.',
            formattedOutput: 'Created and attached the document.',
          ),
          compactSummary: 'Created document.',
        ),
      ]);
      return const AgentOrchestratorResult(
        finalRound: SarvamChatResult(
          content: 'Final answer.',
          model: 'sarvam-105b',
          completionTokens: 12,
        ),
        validatedResponse: ValidatedResponse(
          content: 'Final answer.',
          didMutate: false,
        ),
        requestMessages: <ChatMessage>[],
        selectedTools: <String>['generate_docx'],
        contextAssembly: ContextEngineResult(
          messages: <ChatMessage>[],
          workingMemory: null,
          episodicMemories: <MemoryEntry>[],
          semanticFacts: <SemanticFact>[],
          artifactReferences: <ArtifactReference>[],
        ),
      );
    }, database);
  }

  factory _FakeAgentOrchestrator.emptyArtifactResponse(db.AppDatabase database) {
    return _FakeAgentOrchestrator._((hooks) async {
      hooks.onPrepared?.call(
        AgentOrchestratorTurn(
          selectedTools: const <String>['generate_docx'],
          contextAssembly: const ContextEngineResult(
            messages: <ChatMessage>[],
            workingMemory: null,
            episodicMemories: <MemoryEntry>[],
            semanticFacts: <SemanticFact>[],
            artifactReferences: <ArtifactReference>[],
          ),
          requestMessages: <ChatMessage>[],
          activeToolDefinitions: const <SarvamToolDefinition>[
            SarvamToolDefinition(
              name: 'generate_docx',
              description: 'Generate DOCX',
              parameters: <String, dynamic>{},
            ),
          ],
        ),
      );
      return const AgentOrchestratorResult(
        finalRound: SarvamChatResult(
          content: '',
          model: 'sarvam-105b',
          completionTokens: 0,
        ),
        validatedResponse: ValidatedResponse(
          content: '',
          didMutate: false,
        ),
        requestMessages: <ChatMessage>[],
        selectedTools: <String>['generate_docx'],
        contextAssembly: ContextEngineResult(
          messages: <ChatMessage>[],
          workingMemory: null,
          episodicMemories: <MemoryEntry>[],
          semanticFacts: <SemanticFact>[],
          artifactReferences: <ArtifactReference>[],
        ),
      );
    }, database);
  }

  factory _FakeAgentOrchestrator.completedPdfReplay(db.AppDatabase database) {
    return _FakeAgentOrchestrator._((hooks) async {
      const toolCall = SarvamToolCall(
        id: 'tool_pdf_replay',
        name: 'generate_report_pdf',
        arguments: <String, dynamic>{
          'title': 'Capabilities PDF',
          'markdown_content': '# Capabilities',
        },
      );
      hooks.onPrepared?.call(
        AgentOrchestratorTurn(
          selectedTools: const <String>['generate_report_pdf'],
          contextAssembly: const ContextEngineResult(
            messages: <ChatMessage>[],
            workingMemory: null,
            episodicMemories: <MemoryEntry>[],
            semanticFacts: <SemanticFact>[],
            artifactReferences: <ArtifactReference>[],
          ),
          requestMessages: const <ChatMessage>[],
          activeToolDefinitions: const <SarvamToolDefinition>[
            SarvamToolDefinition(
              name: 'generate_report_pdf',
              description: 'Generate PDF',
              parameters: <String, dynamic>{},
            ),
          ],
        ),
      );
      await Future<void>.value(
        hooks.onToolBatchStarting?.call(const <SarvamToolCall>[toolCall]),
      );
      throw StateError('Expected replay protection to abort before execution.');
    }, database);
  }

  factory _FakeAgentOrchestrator.toolMarkerArtifactResponse(
    db.AppDatabase database,
  ) {
    return _FakeAgentOrchestrator._((hooks) async {
      hooks.onPrepared?.call(
        AgentOrchestratorTurn(
          selectedTools: const <String>['generate_docx'],
          contextAssembly: const ContextEngineResult(
            messages: <ChatMessage>[],
            workingMemory: null,
            episodicMemories: <MemoryEntry>[],
            semanticFacts: <SemanticFact>[],
            artifactReferences: <ArtifactReference>[],
          ),
          requestMessages: const <ChatMessage>[],
          activeToolDefinitions: const <SarvamToolDefinition>[
            SarvamToolDefinition(
              name: 'generate_docx',
              description: 'Generate DOCX',
              parameters: <String, dynamic>{},
            ),
          ],
        ),
      );
      return const AgentOrchestratorResult(
        finalRound: SarvamChatResult(
          content:
              'Created the document. <tool_call>generate_docx</tool_call><arg_key>title</arg_key>',
          model: 'sarvam-105b',
          completionTokens: 10,
        ),
        validatedResponse: ValidatedResponse(
          content:
              'Created the document. <tool_call>generate_docx</tool_call><arg_key>title</arg_key>',
          didMutate: false,
        ),
        requestMessages: <ChatMessage>[],
        selectedTools: <String>['generate_docx'],
        contextAssembly: ContextEngineResult(
          messages: <ChatMessage>[],
          workingMemory: null,
          episodicMemories: <MemoryEntry>[],
          semanticFacts: <SemanticFact>[],
          artifactReferences: <ArtifactReference>[],
        ),
      );
    }, database);
  }

  factory _FakeAgentOrchestrator.emptyResearchResponse(db.AppDatabase database) {
    return _FakeAgentOrchestrator._((hooks) async {
      hooks.onPrepared?.call(
        AgentOrchestratorTurn(
          selectedTools: const <String>['search_web'],
          contextAssembly: const ContextEngineResult(
            messages: <ChatMessage>[],
            workingMemory: null,
            episodicMemories: <MemoryEntry>[],
            semanticFacts: <SemanticFact>[],
            artifactReferences: <ArtifactReference>[],
          ),
          requestMessages: const <ChatMessage>[],
          activeToolDefinitions: const <SarvamToolDefinition>[
            SarvamToolDefinition(
              name: 'search_web',
              description: 'Search web',
              parameters: <String, dynamic>{},
            ),
          ],
        ),
      );
      return const AgentOrchestratorResult(
        finalRound: SarvamChatResult(
          content: '',
          model: 'sarvam-105b',
          completionTokens: 0,
        ),
        validatedResponse: ValidatedResponse(content: '', didMutate: false),
        requestMessages: <ChatMessage>[],
        selectedTools: <String>['search_web'],
        contextAssembly: ContextEngineResult(
          messages: <ChatMessage>[],
          workingMemory: null,
          episodicMemories: <MemoryEntry>[],
          semanticFacts: <SemanticFact>[],
          artifactReferences: <ArtifactReference>[],
        ),
      );
    }, database);
  }

  factory _FakeAgentOrchestrator.emptyDirectResponse(db.AppDatabase database) {
    return _FakeAgentOrchestrator._((hooks) async {
      hooks.onPrepared?.call(
        AgentOrchestratorTurn(
          selectedTools: const <String>[],
          contextAssembly: const ContextEngineResult(
            messages: <ChatMessage>[],
            workingMemory: null,
            episodicMemories: <MemoryEntry>[],
            semanticFacts: <SemanticFact>[],
            artifactReferences: <ArtifactReference>[],
          ),
          requestMessages: const <ChatMessage>[],
          activeToolDefinitions: const <SarvamToolDefinition>[],
        ),
      );
      return const AgentOrchestratorResult(
        finalRound: SarvamChatResult(
          content: '',
          model: 'sarvam-105b',
          completionTokens: 0,
        ),
        validatedResponse: ValidatedResponse(content: '', didMutate: false),
        requestMessages: <ChatMessage>[],
        selectedTools: <String>[],
        contextAssembly: ContextEngineResult(
          messages: <ChatMessage>[],
          workingMemory: null,
          episodicMemories: <MemoryEntry>[],
          semanticFacts: <SemanticFact>[],
          artifactReferences: <ArtifactReference>[],
        ),
      );
    }, database);
  }

  @override
  Future<AgentOrchestratorResult> run({
    required String apiKey,
    required NeroSettings settings,
    required String prompt,
    required String conversationId,
    required String? taskId,
    required List<ChatMessage> modelHistory,
    required List<SarvamToolDefinition> allToolDefinitions,
    required String outputToolsPrompt,
    required String? taskHint,
    required AssistantRoundExecutor executeAssistantRound,
    required Future<ToolExecutionResult> Function(SarvamToolCall toolCall)
    executeToolCall,
    required AutoContinueDecider shouldAutoContinue,
    RunBudget budget = RunBudget.unlimited,
    AgentOrchestratorHooks hooks = const AgentOrchestratorHooks(),
  }) {
    return _handler(hooks);
  }
}

String _stableOperationKey(String toolName, Map<String, Object?> arguments) {
  return '$toolName:${_stableSignature(arguments)}';
}

String _stableSignature(Object? value) {
  if (value == null) {
    return 'null';
  }
  if (value is Map) {
    final sortedKeys = value.keys.map((key) => key.toString()).toList()..sort();
    final buffer = StringBuffer('{');
    for (var index = 0; index < sortedKeys.length; index++) {
      final key = sortedKeys[index];
      if (index > 0) {
        buffer.write(',');
      }
      buffer
        ..write(key)
        ..write(':')
        ..write(_stableSignature(value[key]));
    }
    buffer.write('}');
    return buffer.toString();
  }
  if (value is List) {
    return '[${value.map(_stableSignature).join(',')}]';
  }
  return value.toString();
}

class _NoopToolSelector extends ToolSelector {
  _NoopToolSelector() : super(client: _NoopChatCompletionClient());

  @override
  Future<List<String>> selectTools({
    required String apiKey,
    required String prompt,
    required List<ChatMessage> recentMessages,
  }) async {
    return const <String>[];
  }
}

class _NoopContextEngine extends ContextEngine {
  _NoopContextEngine(db.AppDatabase database)
    : super(
        memoryStore: MemoryStore(database: database),
        semanticFactStore: SemanticFactStore(database: database),
        workingMemoryStore: WorkingMemoryStore(database: database),
        workspaceStore: WorkspaceStore(
          database: database,
          memoryWriteCoordinator: MemoryWriteCoordinator(database: database),
        ),
      );

  @override
  Future<ContextEngineResult> assemble({
    required String conversationId,
    required String? taskId,
    required List<ChatMessage> history,
    required String systemPrompt,
    required String outputToolsPrompt,
    String? taskHint,
  }) async {
    return const ContextEngineResult(
      messages: <ChatMessage>[],
      workingMemory: null,
      episodicMemories: <MemoryEntry>[],
      semanticFacts: <SemanticFact>[],
      artifactReferences: <ArtifactReference>[],
    );
  }
}

class _NoopChatCompletionClient implements ChatCompletionClient {
  @override
  void cancel() {}

  @override
  Future<SarvamChatResult> completeChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  }) async {
    return const SarvamChatResult(content: '[]', model: 'sarvam-m');
  }
}

class _RepairingChatCompletionClient implements ChatCompletionClient {
  _RepairingChatCompletionClient({required this.repairedContent});

  final String repairedContent;

  @override
  void cancel() {}

  @override
  Future<SarvamChatResult> completeChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  }) async {
    return SarvamChatResult(content: repairedContent, model: modelId);
  }
}
