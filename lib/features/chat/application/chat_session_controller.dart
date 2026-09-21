import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../app/app_error_reporter.dart';
import '../../agent/application/agent_task_planner.dart';
import '../../agent/application/agent_task_runtime_adapter.dart';
import '../../agent/application/agent_task_run_progress_bridge.dart';
import '../../agent/application/agent_task_store.dart';
import '../../agent/domain/agent_task.dart';
import '../../audit/application/audit_log_store.dart';
import '../../audit/domain/app_capability.dart';
import '../../audit/domain/audit_log_entry.dart';
import '../../capabilities/capabilities.dart';
import '../../docs/application/artifact_request_policy.dart';
import '../../docs/application/artifact_result_adapter.dart';
import '../../docs/application/doc_block_parser.dart';
import '../../docs/application/doc_generation_service.dart';
import '../../docs/application/inline_artifact_generator.dart';
import '../../memory/application/semantic_fact_store.dart';
import '../../memory/application/working_memory_store.dart';
import '../../runtime/application/approval_gate.dart';
import '../../runtime/application/run_coordinator.dart';
import '../../runtime/application/tool_risk_classifier.dart';
import '../../runtime/domain/agent_policy.dart';
import '../../runtime/domain/runtime_progress_snapshot.dart';
import '../../runtime/domain/runtime_run.dart';
import '../../settings/advanced_settings.dart';
import '../../settings/app_settings.dart';
import '../../settings/nero_model_catalog.dart';
import '../../tools/application/local_tool_runtime_service.dart';
import '../../../platform/device/native_bridge_service.dart';
import '../domain/chat_message.dart';
import '../domain/reasoning_state.dart';
import 'agent_orchestrator.dart';
import 'artifact_strict_failure_handler.dart';
import 'active_agent_task_session.dart';
import 'active_request_session.dart';
import 'active_run_session.dart';
import 'assistant_thinking_session.dart';
import 'auto_continuation_policy.dart';
import 'chat_message_state_store.dart';
import 'chat_run_lifecycle_bridge.dart';
import 'conversation_memory_capture_builder.dart';
import 'context_engine.dart';
import 'diagram_render_result_handler.dart';
import 'document_artifact_tool_executor.dart';
import 'generated_artifact_attachment_mutator.dart';
import 'legacy_tool_call_recovery_adapter.dart';
import 'model_message_adapter.dart';
import 'native_docx_tool_bridge.dart';
import 'native_output_tool_bridge.dart';
import 'prompt_registry.dart';
import 'prompt_variants.dart';
import 'response_repair_coordinator.dart';
import 'response_guard.dart';
import 'repeated_tool_loop_recovery_handler.dart';
import 'runtime_debug_signal_recorder.dart';
import 'sarvam_api_client.dart';
import 'sarvam_stream_client.dart';
import 'reasoning_delta_merger.dart';
import 'reasoning_session.dart';
import 'streaming_assistant_round_executor.dart';
import 'streaming_assistant_round_recovery.dart';
import 'streaming_run_completion_coordinator.dart';
import 'task_hint_policy.dart';
import 'tool_dispatcher.dart';
import 'tool_execution_coordinator.dart';
import 'tool_executor_registry.dart';
import 'tool_selector.dart';
import 'web_tools.dart';

class ChatSessionController extends ChangeNotifier {
  static final String _outputToolsPrompt = PromptRegistry.outputToolsPrompt;

  static final _mermaidDiagramRegex = RegExp(
    r'(^|\n)\s*(flowchart|graph|sequenceDiagram|classDiagram|stateDiagram(?:-v2)?|erDiagram)\b',
    caseSensitive: false,
  );
  static const _docBlockParser = DocBlockParser();
  static const _modelCatalog = NeroModelCatalog();

  ChatSessionController({
    required ChatCompletionClient client,
    WebToolService? webToolService,
    DocGenerationService? docGenerationService,
    AgentTaskStore? agentTaskStore,
    AgentTaskPlanner? agentTaskPlanner,
    AgentTaskRuntimeAdapter? agentTaskRuntimeAdapter,
    AgentTaskRunProgressBridge? agentTaskRunProgressBridge,
    AuditLogStore? auditLogStore,
    ChatStreamingClient? streamingClient,
    ToolSelector? toolSelector,
    ContextEngine? contextEngine,
    PromptVariantSelector? promptVariantSelector,
    ToolDispatcher? toolDispatcher,
    ResponseGuard? responseGuard,
    WorkingMemoryStore? workingMemoryStore,
    SemanticFactStore? semanticFactStore,
    LocalToolRuntimeService? localToolRuntimeService,
    AgentOrchestrator? agentOrchestrator,
    RunCoordinator? runCoordinator,
    CapabilityCatalog? capabilityCatalog,
  }) : _catalog = capabilityCatalog ?? CapabilityCatalog.instance,
       _client = client,
       _webToolService = webToolService ?? WebToolService(),
       _docGenerationService = docGenerationService ?? DocGenerationService(),
       _agentTaskStore = agentTaskStore ?? AgentTaskStore(),
       _agentTaskRuntimeAdapter =
           agentTaskRuntimeAdapter ??
           AgentTaskRuntimeAdapter(
             planner: agentTaskPlanner ?? const AgentTaskPlanner(),
           ),
       _agentTaskRunProgressBridge =
           agentTaskRunProgressBridge ?? const AgentTaskRunProgressBridge(),
       _auditLogStore = auditLogStore ?? AuditLogStore(),
       _streamingClient = streamingClient,
       _toolSelector = toolSelector ?? ToolSelector(client: client),
       _contextEngine = contextEngine ?? ContextEngine(),
       _promptVariantSelector =
           promptVariantSelector ?? const PromptVariantSelector(),
       _toolDispatcher = toolDispatcher ?? ToolDispatcher(),
       _responseGuard = responseGuard ?? const ResponseGuard(),
       _workingMemoryStore = workingMemoryStore ?? WorkingMemoryStore(),
       _semanticFactStore = semanticFactStore ?? SemanticFactStore(),
       _localToolRuntimeService =
           localToolRuntimeService ??
           LocalToolRuntimeService(nativeBridgeService: NativeBridgeService()) {
    final resolvedOrchestrator =
        agentOrchestrator ??
        AgentOrchestrator(
          toolSelector: _toolSelector,
          contextEngine: _contextEngine,
          promptVariantSelector: _promptVariantSelector,
          toolDispatcher: _toolDispatcher,
          responseGuard: _responseGuard,
        );
    _runCoordinator =
        runCoordinator ??
        RunCoordinator(
          orchestrator: resolvedOrchestrator,
          responseRepairCoordinator: ResponseRepairCoordinator(client: _client),
        );
  }

  /// Dynamic tool source: built-ins plus any registered MCP/sandbox provider.
  final CapabilityCatalog _catalog;
  final ChatCompletionClient _client;
  final WebToolService _webToolService;
  final DocGenerationService _docGenerationService;
  final ArtifactRequestPolicy _artifactRequestPolicy =
      const ArtifactRequestPolicy();
  final ArtifactStrictFailureHandler _artifactStrictFailureHandler =
      const ArtifactStrictFailureHandler();
  final ConversationMemoryCaptureBuilder _conversationMemoryCaptureBuilder =
      const ConversationMemoryCaptureBuilder();
  final DiagramRenderResultHandler _diagramRenderResultHandler =
      const DiagramRenderResultHandler();
  final RepeatedToolLoopRecoveryHandler _repeatedToolLoopRecoveryHandler =
      const RepeatedToolLoopRecoveryHandler();
  final RuntimeDebugSignalRecorder _runtimeDebugSignalRecorder =
      const RuntimeDebugSignalRecorder();
  final ModelMessageAdapter _modelMessageAdapter = const ModelMessageAdapter();
  final TaskHintPolicy _taskHintPolicy = const TaskHintPolicy();
  final ArtifactResultAdapter _artifactResultAdapter =
      const ArtifactResultAdapter();
  final AutoContinuationPolicy _autoContinuationPolicy =
      const AutoContinuationPolicy();
  late final ResponseRepairCoordinator _responseRepairCoordinator =
      ResponseRepairCoordinator(client: _client);
  late final StreamingRunCompletionCoordinator
  _streamingRunCompletionCoordinator = StreamingRunCompletionCoordinator(
    responseRepairCoordinator: _responseRepairCoordinator,
    repeatedToolLoopRecoveryHandler: _repeatedToolLoopRecoveryHandler,
  );
  late final StreamingAssistantRoundRecovery _streamingAssistantRoundRecovery =
      StreamingAssistantRoundRecovery(
        client: _client,
        onCompatibilityRecovery: _recordCompatibilityRecovery,
      );
  late final StreamingAssistantRoundExecutor _assistantRoundExecutor =
      StreamingAssistantRoundExecutor(
        client: _client,
        streamingClient: _streamingClient,
        roundRecovery: _streamingAssistantRoundRecovery,
      );
  final ReasoningDeltaMerger _reasoningDeltaMerger = const ReasoningDeltaMerger();
  late final InlineArtifactGenerator _inlineArtifactGenerator =
      InlineArtifactGenerator(
        docGenerationService: _docGenerationService,
        localToolRuntimeService: _localToolRuntimeService,
        artifactResultAdapter: _artifactResultAdapter,
      );
  final AgentTaskRuntimeAdapter _agentTaskRuntimeAdapter;
  final AgentTaskRunProgressBridge _agentTaskRunProgressBridge;
  final AuditLogStore _auditLogStore;
  final ChatStreamingClient? _streamingClient;
  final ToolSelector _toolSelector;
  final ContextEngine _contextEngine;
  final PromptVariantSelector _promptVariantSelector;
  final ToolDispatcher _toolDispatcher;
  final GeneratedArtifactAttachmentMutator _generatedArtifactAttachmentMutator =
      const GeneratedArtifactAttachmentMutator();
  final ChatRunLifecycleBridge _chatRunLifecycleBridge =
      const ChatRunLifecycleBridge();
  late final NativeOutputToolBridge _nativeOutputToolBridge =
      NativeOutputToolBridge(
        localToolRuntimeService: _localToolRuntimeService,
        artifactResultAdapter: _artifactResultAdapter,
      );
  late final NativeDocxToolBridge _nativeDocxToolBridge = NativeDocxToolBridge(
    docGenerationService: _docGenerationService,
    artifactResultAdapter: _artifactResultAdapter,
  );
  late final DocumentArtifactToolExecutor _documentArtifactToolExecutor =
      DocumentArtifactToolExecutor(
        nativeDocxToolBridge: _nativeDocxToolBridge,
        nativeOutputToolBridge: _nativeOutputToolBridge,
      );
  final ToolExecutorRegistry _toolExecutorRegistry = ToolExecutorRegistry();
  late final ToolExecutionCoordinator _toolExecutionCoordinator =
      ToolExecutionCoordinator(
        webToolService: _webToolService,
        auditLogStore: _auditLogStore,
        documentArtifactToolExecutor: _documentArtifactToolExecutor,
        nativeOutputToolBridge: _nativeOutputToolBridge,
        externalExecutorRegistry: _toolExecutorRegistry,
      );
  final ResponseGuard _responseGuard;
  final WorkingMemoryStore _workingMemoryStore;
  final SemanticFactStore _semanticFactStore;
  final LocalToolRuntimeService _localToolRuntimeService;
  final ActiveRunSession _activeRunSession = ActiveRunSession();
  late final ActiveAgentTaskSession _activeTaskSession = ActiveAgentTaskSession(
    runtimeAdapter: _agentTaskRuntimeAdapter,
    taskStore: _agentTaskStore,
    onTaskChanged: (_) => _syncActiveAssistantThinking(),
  );
  final AgentTaskStore _agentTaskStore;
  late final RunCoordinator _runCoordinator;
  final AssistantThinkingSession _assistantThinkingSession =
      AssistantThinkingSession();

  /// Settings that control agent autonomy, approvals and budgets.
  AdvancedSettings _advancedSettings = const AdvancedSettings();
  bool _agentModeOverrideSet = false;
  AgentMode _agentModeOverride = AgentMode.chat;

  /// Gate in front of every model-requested tool call. See [ApprovalGate].
  late final ApprovalGate _approvalGate = ApprovalGate(
    policyResolver: (toolName) => _advancedSettings.policyForTool(toolName),
    riskResolver: _riskClassifier.classify,
    overrideResolver: (toolName) =>
        _externalApprovalOverrideResolver?.call(toolName),
  )..onChanged = _handleApprovalGateChanged;
  final ToolRiskClassifier _riskClassifier = ToolRiskClassifier();
  ApprovalOverrideResolver? _externalApprovalOverrideResolver;
  bool _approvalHeldTask = false;

  /// Reasoning (extended thinking) accumulator for the active assistant turn.
  final ReasoningSession _reasoningSession = ReasoningSession();
  final ChatMessageStateStore _messageStateStore = ChatMessageStateStore();

  String? _activeAssistantId;
  DateTime? _requestStartedAt;
  DateTime? _thinkingStartedAt;
  StreamSubscription<AgentStreamEvent>? _streamSubscription;
  int _accumulatedThinkingMs = 0;
  int _messageCounter = 0;
  bool _isGenerating = false;
  String _status = 'Idle';
  String? _blockingReason;
  String _modelName = 'Sarvam 30B';
  double? _tokensPerSecond;
  int? _promptTokens;
  int? _generatedTokens;
  Map<String, dynamic> _nativeStats = const <String, dynamic>{};
  String _conversationId = 'standalone';
  final ActiveRequestSession _activeRequestSession = ActiveRequestSession();
  int _generationEpoch = 0;
  List<ChatMessage> get messages => _messageStateStore.messages;
  List<String> get messageIds =>
      List<String>.unmodifiable(messages.map((message) => message.id));
  ValueListenable<int> get messageListVersionListenable =>
      _messageStateStore.messageListVersionListenable;
  bool get isGenerating => _isGenerating;
  String get status => _status;
  String get modelName => _modelName;
  String? get blockingReason => _blockingReason;
  String? get currentThought => _assistantThinkingSession.currentThought;
  List<String> get completedThoughts =>
      _assistantThinkingSession.completedThoughts;
  double? get tokensPerSecond => _tokensPerSecond;
  int? get promptTokens => _promptTokens;
  int? get generatedTokens => _generatedTokens;
  Map<String, dynamic> get nativeStats => _nativeStats;
  int get currentContextTokens =>
      _promptTokens ?? _estimateConversationTokens();
  AgentTask? get activeTask => _activeTaskSession.task;
  AgentTask? get _activeTask => _activeTaskSession.task;
  RuntimeProgressSnapshot? get runtimeProgressSnapshot =>
      _activeRunSession.progressSnapshot;

  /// Live reasoning state for the in-flight turn, used by the composer strip.
  ReasoningState get activeReasoning => _reasoningSession.snapshot();

  /// The tool call the agent is currently blocked on, if any.
  PendingApproval? get pendingApproval => _approvalGate.pending;

  bool get isWaitingForApproval => _approvalGate.isWaiting;

  /// Agent mode in force for the next turn: the composer's override when the
  /// user picked one, otherwise the persisted default.
  AgentMode get agentMode =>
      _agentModeOverrideSet ? _agentModeOverride : _advancedSettings.agentMode;

  bool get hasAgentModeOverride => _agentModeOverrideSet;

  RunBudget get runBudget => _advancedSettings.budget;

  ApprovalPolicy get approvalPolicy => _advancedSettings.approvalPolicy;

  /// Applied by the shell whenever settings change.
  void configureAgentSettings(AdvancedSettings settings) {
    _advancedSettings = settings;
  }

  /// Composer-level mode switch for the next turn only.
  void setAgentMode(AgentMode mode) {
    _agentModeOverrideSet = mode != _advancedSettings.agentMode;
    _agentModeOverride = mode;
    notifyListeners();
  }

  /// Lets the shell contribute tool-specific approval overrides (MCP uses this
  /// so a per-tool "always ask" beats the global policy).
  set externalApprovalOverrideResolver(ApprovalOverrideResolver? resolver) {
    _externalApprovalOverrideResolver = resolver;
  }

  void approvePendingToolCall() => _approvalGate.resolve(true);

  void rejectPendingToolCall() => _approvalGate.resolve(false);

  void _handleApprovalGateChanged() {
    final pending = _approvalGate.pending;
    if (pending != null) {
      _status = 'Waiting for approval';
      _setCurrentThought('Waiting for you to allow ${pending.title}');
      // The task — and therefore the run dock — reports the pause, which is
      // what `AgentTaskStatus.waitingUser` exists for.
      _approvalHeldTask = true;
      _activeTaskSession.apply(
        (task) => task.copyWith(
          status: AgentTaskStatus.waitingUser,
          updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } else if (_approvalHeldTask) {
      _approvalHeldTask = false;
      _status = _isGenerating ? 'Working' : 'Ready';
      _activeTaskSession.refreshTaskStatus();
    }
    notifyListeners();
  }

  /// Registers an executor for tool names outside the built-in switch
  /// (`mcp__*`, `sandbox_*`). Safe to call repeatedly.
  void registerToolExecutor(ExternalToolExecutor executor) {
    _toolExecutorRegistry.register(executor);
  }

  void unregisterToolExecutor(ExternalToolExecutor executor) {
    _toolExecutorRegistry.unregister(executor);
  }

  ValueListenable<ChatMessage>? messageListenable(String messageId) {
    return _messageStateStore.messageListenable(messageId);
  }

  ChatMessage? messageById(String messageId) {
    return _messageStateStore.messageById(messageId);
  }

  void setConversationContext(String? conversationId) {
    final normalized = conversationId?.trim();
    _conversationId = normalized == null || normalized.isEmpty
        ? 'standalone'
        : normalized;
  }

  void replaceMessages(List<ChatMessage> messages) {
    _invalidateGeneration();
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _streamingClient?.cancel();
    _client.cancel();
    _activeAssistantId = null;
    _requestStartedAt = null;
    _thinkingStartedAt = null;
    _accumulatedThinkingMs = 0;
    _isGenerating = false;
    _blockingReason = null;
    _status = 'Ready';
    _assistantThinkingSession.clear();
    _activeTaskSession.clear();
    _activeRequestSession.clear();
    _activeRunSession.clear();
    _resetGenerationTelemetry();
    _replaceAllMessages(messages);
    _syncMessageCounterWithHistory(messages);
    notifyListeners();
  }

  void attachGeneratedArtifact(
    String messageId,
    GeneratedArtifactReference artifact,
  ) {
    final currentMessages = messages;
    final index = _messageStateStore.indexOfMessageId(messageId);
    if (index == -1) {
      return;
    }
    _replaceMessageAt(
      index,
      _generatedArtifactAttachmentMutator.attachArtifact(
        currentMessages[index],
        artifact,
      ),
    );
    notifyListeners();
  }

  String _resolveApiKey(NeroSettings settings) {
    return settings.azureApiKey.trim();
  }

  String _providerLabel(NeroSettings settings) {
    return _modelCatalog.isAzureModel(settings.selectedModelId)
        ? 'Azure AI'
        : 'the configured provider';
  }

  void configureForSettings(NeroSettings settings, String modelName) {
    _modelName = modelName;
    if (_resolveApiKey(settings).isEmpty) {
      _blockingReason = 'Add your ${_providerLabel(settings)} API key in Settings.';
      _status = _blockingReason!;
    } else {
      _blockingReason = null;
      _status = 'Ready';
    }
    notifyListeners();
  }

  Future<void> sendPrompt(
    String prompt,
    NeroSettings settings, {
    List<ChatAttachment> attachments = const <ChatAttachment>[],
  }) async {
    final generationEpoch = _generationEpoch;
    final trimmed = prompt.trim();
    if (trimmed.isEmpty || _isGenerating) {
      return;
    }
    final apiKey = _resolveApiKey(settings);
    if (apiKey.isEmpty) {
      _blockingReason =
          'Add your ${_providerLabel(settings)} API key in Settings.';
      _status = _blockingReason!;
      notifyListeners();
      return;
    }

    _activeRequestSession.begin(
      apiKey: apiKey,
      settings: settings,
      prompt: trimmed,
    );
    _activeRunSession.clearProgressSnapshot();

    _appendMessages(<ChatMessage>[
      ChatMessage(
        id: _nextId(),
        role: ChatRole.user,
        content: trimmed,
        sentAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        attachments: List<ChatAttachment>.unmodifiable(attachments),
      ),
    ], notifyController: false);
    unawaited(
      _auditLogStore.record(
        capabilityKey: AppCapabilities.chatPrompt.key,
        title: AppCapabilities.chatPrompt.label,
        detail: trimmed.length > 120
            ? '${trimmed.substring(0, 120)}...'
            : trimmed,
        status: AuditLogStatus.started,
        conversationId: _conversationId,
      ),
    );

    final assistantId = _nextId();
    _activeAssistantId = assistantId;
    _appendMessages(<ChatMessage>[
      ChatMessage(
        id: assistantId,
        role: ChatRole.assistant,
        content: '',
        sentAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        isStreaming: true,
        tokensPerSecond: null,
        averageTokensPerSecond: null,
        thinkingSteps: const <String>[],
        thinkingDurationMs: 0,
        thinkingStartedAtEpochMs: null,
        activities: const <ChatActivity>[],
      ),
    ], notifyController: false);

    _isGenerating = true;
    _status = 'Contacting Sarvam AI';
    _blockingReason = null;
    _assistantThinkingSession.clear();
    _reasoningSession.begin();
    _requestStartedAt = DateTime.now();
    _accumulatedThinkingMs = 0;
    _lastBroadcastProgressPhaseKey = null; // ensure first progress tick re-renders
    _resumeThinkingClock();
    _resetGenerationTelemetry();
    // Chat mode answers directly, so nothing is planned or tracked. Plan and
    // Agent modes create the task that the plan dock and step statuses hang
    // off; every task mutation is a no-op when no task exists.
    if (agentMode.requiresPlan) {
      await _startTask(trimmed);
      _markStepRunning(
        AgentStepKinds.interpretPrompt,
        detail: 'Extracting intent, constraints, and expected output.',
      );
    } else {
      _activeRequestSession.clearSelectedTools();
      _activeTaskSession.clear();
    }
    _syncActiveAssistantThinking();
    notifyListeners();

    try {
      final modelHistory = messages
          .where((message) => !message.isStreaming)
          .map(_messageForModel)
          .toList(growable: false);
      final coordinatorResult = await _runCoordinator.runTurn(
        apiKey: apiKey,
        settings: settings,
        budget: _advancedSettings.budget,
        prompt: trimmed,
        conversationId: _conversationId,
        taskId: _activeTaskSession.task?.id,
        modelHistory: modelHistory,
        allToolDefinitions: _toolDefinitions,
        outputToolsPrompt: _outputToolsPrompt,
        taskHint: _taskHintFor(trimmed),
        executeAssistantRound:
            ({
              required List<ChatMessage> requestMessages,
              required List<SarvamToolDefinition> tools,
              required StringBuffer responseBuffer,
            }) => _executeAssistantRound(
              apiKey: apiKey,
              settings: settings,
              requestMessages: requestMessages,
              tools: tools,
              responseBuffer: responseBuffer,
              assistantId: assistantId,
            ),
        executeToolCall: _executeToolCall,
        shouldAutoContinue: _shouldAutoContinue,
        hooks: _chatRunLifecycleBridge.createHooks(
          applyRunUpdate: _applyRunUpdate,
          applyRuntimeProgressUpdate: _applyRuntimeProgressUpdate,
          updateActiveTask: _updateActiveTask,
          setThought: _setCurrentThought,
          setStatus: _setStatusText,
          setPromptTokens: _setPromptTokens,
          setSelectedTools: _setActiveSelectedTools,
          estimateMessagesTokenCount: _estimateMessagesTokenCount,
          notifyListeners: notifyListeners,
        ),
      );

      final orchestrationResult = coordinatorResult.orchestrationResult;
      final stopReason = orchestrationResult.stopReason;
      if (stopReason != null) {
        // The run hit its budget: the partial answer still renders, and the
        // reason stays visible instead of the turn silently appearing complete.
        _status = 'Stopped early';
        _blockingReason = stopReason;
        _setCurrentThought(stopReason);
      }
      if (coordinatorResult.progressSnapshot != null) {
        _activeRunSession.applyProgressUpdate(
          coordinatorResult.run,
          coordinatorResult.progressSnapshot!,
        );
      } else {
        _activeRunSession.applyRunUpdate(coordinatorResult.run);
      }
      if (!_isCurrentGeneration(generationEpoch)) {
        return;
      }
      final result = orchestrationResult.finalRound;
      final finalResponseContent = orchestrationResult.validatedResponse.content;
      final activeArtifacts =
          messageById(assistantId)?.generatedArtifacts ??
          const <GeneratedArtifactReference>[];
      final strictArtifactFailureResponse =
          _strictArtifactFailureResponseIfNeeded(
            prompt: trimmed,
            generatedArtifacts: activeArtifacts,
          );
      final deliveredResponseContent =
          strictArtifactFailureResponse ?? finalResponseContent;
      final run = _activeRunSession.run;
      if (run != null) {
        final completedRun = await _runCoordinator.finalizeCompletedRun(
          run: run,
          finalResponse: deliveredResponseContent,
          artifacts: activeArtifacts,
          modelId: result.model,
          prompt: trimmed,
        );
        _activeRunSession.applyCompletedRun(completedRun);
      }
      if (!_isCurrentGeneration(generationEpoch)) {
        return;
      }
      _modelName = result.model;
      _promptTokens = result.promptTokens ?? _promptTokens;
      _generatedTokens = result.completionTokens;
      _nativeStats = <String, dynamic>{
        'provider': 'sarvam_ai',
        'model': result.model,
        'prompt_tokens': result.promptTokens,
        'completion_tokens': result.completionTokens,
        'total_tokens': result.totalTokens,
      };
      _status = 'Streaming response';
      _updateActiveTask(_agentTaskRunProgressBridge.onFinalResponseReady);
      if (_hasStep(AgentStepKinds.renderDiagram)) {
        if (_containsMermaid(deliveredResponseContent)) {
          _markStepCompleted(
            AgentStepKinds.renderDiagram,
            detail: 'Diagram source emitted. Expand to render or validate it.',
          );
        } else {
          _markStepFailed(
            AgentStepKinds.renderDiagram,
            error:
                'A diagram was requested, but no Mermaid block was returned.',
          );
        }
      }
      _replaceActiveAssistantContent(
        deliveredResponseContent,
        isStreaming: true,
        clearAverageTokensPerSecond: true,
      );
      _completeActiveTask();
      await _persistActiveTask();
      await _captureConversationMemory(
        prompt: trimmed,
        finalResponse: deliveredResponseContent,
      );
      _finishStreamingSuccess();
      return;
    } catch (error) {
      if (!_isCurrentGeneration(generationEpoch)) {
        return;
      }
      final recovered = await _recoverFromRepeatedToolLoop(error);
      if (recovered) {
        return;
      }
      _isGenerating = false;
      _status = 'Cloud request failed';
      _blockingReason = error.toString();
      unawaited(
        _auditLogStore.record(
          capabilityKey: AppCapabilities.chatPrompt.key,
          title: AppCapabilities.chatPrompt.label,
          detail: error.toString(),
          status: AuditLogStatus.failed,
          conversationId: _conversationId,
        ),
      );
      _failActiveTask(error.toString());
      _pauseThinkingClock();
      _setCurrentThought(null, completeCurrent: true);
      _finalizeStreamingMessage(
        fallbackSuffix: '\n\n[Cloud request failed: ${error.toString()}]',
      );
      notifyListeners();
    } finally {
      _clearActiveRequestContext();
    }
  }

  void _reportNativeDocxGenerationFailure(Object error) {
    AppErrorReporter.instance.report(
      error,
      message:
          'DOCX generation failed in the native Apache POI pipeline. $error',
    );
  }

  void _recordCompatibilityRecovery(LegacyToolCallRecoveryStats stats) {
    _runtimeDebugSignalRecorder.recordCompatibilityRecovery(
      run: _activeRunSession.run,
      stats: stats,
      appendDebugSignals: _runCoordinator.appendDebugSignals,
      shouldApplyUpdatedRun: _shouldApplyUpdatedRun,
      applyRunUpdate: _activeRunSession.applyRunUpdate,
    );
  }

  String? _strictArtifactFailureResponseIfNeeded({
    required String prompt,
    required List<GeneratedArtifactReference> generatedArtifacts,
  }) {
    return _artifactStrictFailureHandler.apply(
      resolution: _artifactRequestPolicy.strictFailureIfNeeded(
        prompt: prompt,
        selectedTools: _activeRequestSession.selectedTools,
        hasGeneratedArtifacts: generatedArtifacts.isNotEmpty,
      ),
      hasDocumentStep: _hasStep(AgentStepKinds.generateDocument),
      onDocumentStepFailed: (error) {
        _markStepFailed(AgentStepKinds.generateDocument, error: error);
      },
      onError: (errorMessage) {
        AppErrorReporter.instance.report(
          errorMessage,
          message: errorMessage,
        );
      },
    );
  }

  Future<bool> _recoverFromRepeatedToolLoop(Object error) async {
    final activeMessage = _activeAssistantId == null
        ? null
        : messageById(_activeAssistantId!);
    _isGenerating = false;
    return _streamingRunCompletionCoordinator.recoverFromRepeatedToolLoop(
      error: error,
      task: _activeTask,
      hasArtifact: activeMessage?.generatedArtifacts.isNotEmpty == true,
      setStatus: (value) => _status = value,
      setBlockingReason: (value) => _blockingReason = value,
      markPrimaryDraftingStepCompleted: (detail) =>
          _markPrimaryDraftingStepCompleted(detail: detail),
      markStepCompletedIfPresent: _markStepCompletedIfPresent,
      completeActiveTask: _completeActiveTask,
      clearThinking: () {
        _pauseThinkingClock();
        _setCurrentThought(null, completeCurrent: true);
      },
      replaceActiveAssistantContent: _replaceActiveAssistantContent,
      clearRequestStartedAt: () => _requestStartedAt = null,
      run: _activeRunSession.run,
      completeRecoveredRun: (run, response) =>
          _runCoordinator.completeRecoveredRun(run: run, response: response),
      applyRunUpdate: _activeRunSession.applyRunUpdate,
      notifyListeners: notifyListeners,
    );
  }

  Future<void> cancel() async {
    if (!_isGenerating) {
      _invalidateGeneration();
      return;
    }

    _invalidateGeneration();
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _streamingClient?.cancel();
    _client.cancel();
    _isGenerating = false;
    _status = 'Stopped';
    _blockingReason = null;
    final run = _activeRunSession.run;
    if (run != null) {
      final cancelledRun = await _runCoordinator.cancelRun(run);
      _activeRunSession.applyRunUpdate(cancelledRun);
    }
    _cancelActiveTask();
    _pauseThinkingClock();
    _setCurrentThought(null, completeCurrent: true);
    _requestStartedAt = null;
    // Stopping while the gate is open would otherwise leave the agent loop
    // suspended forever on a prompt nobody can answer.
    _approvalGate.cancel();
    _finalizeStreamingMessage(cancelled: true);
    notifyListeners();
  }

  @override
  void dispose() {
    _approvalGate.cancel();
    _streamSubscription?.cancel();
    _streamingClient?.cancel();
    _client.cancel();
    _messageStateStore.dispose();
    super.dispose();
  }

  Future<GeneratedArtifactReference?> generateInlineDocxArtifact({
    required String messageId,
    required String title,
    required String markdownContent,
  }) async {
    final artifact = await _inlineArtifactGenerator.generateDocxArtifact(
      conversationId: _conversationId,
      messageId: messageId,
      title: title,
      markdownContent: markdownContent,
      blocks: _docBlockParser.parseMarkdown(markdownContent),
    );
    if (artifact == null) {
      return null;
    }
    attachGeneratedArtifact(messageId, artifact);
    return artifact;
  }

  Future<GeneratedArtifactReference?> generateInlinePdfArtifact({
    required String messageId,
    required String title,
    required String markdownContent,
  }) async {
    final artifact = await _inlineArtifactGenerator.generatePdfArtifact(
      conversationId: _conversationId,
      messageId: messageId,
      title: title,
      markdownContent: markdownContent,
      blocks: _docBlockParser.parseMarkdown(markdownContent),
    );
    if (artifact == null) {
      return null;
    }
    attachGeneratedArtifact(messageId, artifact);
    return artifact;
  }

  ChatMessage _messageForModel(ChatMessage message) {
    return _modelMessageAdapter.adapt(message);
  }

  String? _taskHintFor(String prompt) {
    return _taskHintPolicy.buildHint(prompt);
  }

  void _finishStreamingSuccess() {
    _streamSubscription = null;
    _isGenerating = false;
    _streamingRunCompletionCoordinator.finishSuccess(
      conversationId: _conversationId,
      auditLogStore: _auditLogStore,
      chatPromptCapabilityKey: AppCapabilities.chatPrompt.key,
      chatPromptCapabilityLabel: AppCapabilities.chatPrompt.label,
      setStatus: (value) => _status = value,
      setBlockingReason: (value) => _blockingReason = value,
      markStepCompleted: _markStepCompleted,
      completeActiveTask: _completeActiveTask,
      clearThinking: () {
        _pauseThinkingClock();
        _setCurrentThought(null, completeCurrent: true);
      },
      calculateAverageTokensPerSecond: _calculateAverageTokensPerSecond,
      setTokensPerSecond: (value) => _tokensPerSecond = value,
      finalizeStreamingMessage: _finalizeStreamingMessage,
      clearRequestStartedAt: () => _requestStartedAt = null,
      notifyListeners: notifyListeners,
    );
  }

  Future<SarvamChatResult> _executeAssistantRound({
    required String apiKey,
    required NeroSettings settings,
    required List<ChatMessage> requestMessages,
    required List<SarvamToolDefinition> tools,
    required StringBuffer responseBuffer,
    required String assistantId,
  }) async {
    // Delegate to the extracted executor.  The executor owns the streaming
    // subscription lifecycle, tool-call deduplication, content staging, and
    // bootstrap-error fallback; the controller only wires UI callbacks.
    return _assistantRoundExecutor.execute(
      apiKey: apiKey,
      settings: settings,
      requestMessages: requestMessages,
      tools: tools,
      responseBuffer: responseBuffer,
      onContentRevealed: (content) => _replaceActiveAssistantContent(
        content,
        isStreaming: true,
        clearAverageTokensPerSecond: true,
      ),
      onReasoningDelta: (delta) {
        _reasoningSession.appendDelta(delta);
        _syncActiveAssistantThinking();
        notifyListeners();
      },
      onReasoningPartBoundary: _reasoningSession.beginSegment,
      onReasoningTokens: (tokens) => _reasoningSession.setReasoningTokens(
        tokens,
      ),
      onSubscriptionCreated: (subscription) {
        _streamSubscription = subscription;
      },
    );
  }

  // _mergeReasoningDelta, _stableToolCallKey, _hasRequiredToolArguments,
  // and _toolCallArgumentScore have been moved to ReasoningDeltaMerger and
  // StreamingAssistantRoundExecutor (static helpers) respectively.

  void _resetGenerationTelemetry() {
    _tokensPerSecond = null;
    _promptTokens = null;
    _generatedTokens = null;
    _nativeStats = const <String, dynamic>{};
  }

  void _clearActiveRequestContext() {
    _activeRequestSession.clear();
  }

  void _applyRunUpdate(RuntimeRun run) {
    _activeRunSession.applyRunUpdate(run);
  }

  void _setStatusText(String status) {
    _status = status;
  }

  void _setPromptTokens(int promptTokens) {
    _promptTokens = promptTokens;
  }

  void _setActiveSelectedTools(List<String> selectedTools) {
    _activeRequestSession.setSelectedTools(selectedTools);
  }

  /// Updated whenever a new runtime progress snapshot is broadcast
  /// so we can skip redundant [notifyListeners] calls on high-frequency
  /// progress ticks where nothing visible has changed.
  String? _lastBroadcastProgressPhaseKey;

  void _applyRuntimeProgressUpdate(
    RuntimeRun run,
    RuntimeProgressSnapshot snapshot,
  ) {
    _activeRunSession.applyProgressUpdate(run, snapshot);
    // Only re-render if the current phase actually shifted.  Progress updates
    // fire very frequently during tool execution; skipping no-op notifies
    // avoids unnecessary widget subtree rebuilds.
    final newPhaseKey = snapshot.currentPhase?.phaseKey;
    if (newPhaseKey == _lastBroadcastProgressPhaseKey &&
        snapshot.phases.length ==
            _activeRunSession.progressSnapshot?.phases.length) {
      return;
    }
    _lastBroadcastProgressPhaseKey = newPhaseKey;
    // The runtime phase is a good coarse caption for the reasoning block
    // ("Searching the web…", "Writing…") while the agent works.
    _reasoningSession.setPhase(
      snapshot.currentPhase?.title ?? snapshot.nextPhase?.title,
    );
    _syncActiveAssistantThinking();
    notifyListeners();
  }

  Future<ToolExecutionResult> _executeToolCall(SarvamToolCall toolCall) async {
    // Every model-requested tool call passes the gate first. When it decides a
    // prompt is needed this future does not complete until the user answers, so
    // the agent loop is paused rather than spinning.
    final approved = await _approvalGate.request(
      toolCallId: toolCall.id,
      toolName: toolCall.name,
      arguments: toolCall.arguments,
      title: _approvalTitleFor(toolCall.name),
    );
    if (!approved) {
      _setCurrentThought('Skipped ${toolCall.name}');
      return ToolExecutionResult(
        success: false,
        summary: 'The user declined to run ${toolCall.name}.',
        formattedOutput:
            'The user declined this tool call. Do not retry it. Either answer '
            'with what you already have or explain what you need instead.',
      );
    }
    return _toolExecutionCoordinator.execute(
      toolCall,
      conversationId: () => _conversationId,
      activeRequestPrompt: () => _activeRequestSession.prompt,
      latestUserPrompt: _latestUserPrompt,
      activeAssistantId: () => _activeAssistantId,
      onThought: (thought) => _setCurrentThought(thought),
      onActivity: _recordToolActivity,
      onArtifact: _applyGeneratedArtifactIfActive,
      onDocxFailure: _reportNativeDocxGenerationFailure,
    );
  }

  /// Human label for the approval prompt, taken from the capability catalog so
  /// MCP and sandbox tools read the same as built-ins.
  String _approvalTitleFor(String toolName) {
    return CapabilityCatalog.instance.byToolName(toolName)?.displayName ??
        toolName;
  }

  /// Returns the content of the most recently sent user message in O(1).
  String? _latestUserPrompt() => _messageStateStore.latestUserContent;


  

  /// Handles a coarse progress thought emitted around tool calls.
  ///
  /// These are status labels, not reasoning, so they become the reasoning
  /// block's phase caption rather than fake reasoning text.
  void _setCurrentThought(String? nextThought, {bool completeCurrent = false}) {
    if (completeCurrent) {
      _reasoningSession.complete();
      _pauseThinkingClock();
    }
    if (nextThought != null && nextThought.trim().isNotEmpty) {
      _reasoningSession.setPhase(nextThought.trim());
      _resumeThinkingClock();
    }
    _syncActiveAssistantThinking();
    notifyListeners();
  }

  void _finalizeStreamingMessage({
    bool cancelled = false,
    String? fallbackSuffix,
    double? averageTokensPerSecond,
  }) {
    final id = _activeAssistantId;
    final currentMessages = messages;
    final index = id == null ? -1 : _messageStateStore.indexOfMessageId(id);
    if (index == -1) {
      return;
    }

    final existing = currentMessages[index];
    final fallbackContent = fallbackSuffix?.trim();
    final content = existing.content.isEmpty
        ? (cancelled
              ? 'Generation cancelled.'
              : (fallbackContent?.isNotEmpty == true
                    ? fallbackContent!
                    : 'No response emitted.'))
        : '${existing.content}${fallbackSuffix ?? ''}';
    _reasoningSession.complete();
    _replaceMessageAt(
      index,
      existing.copyWith(
        content: content,
        isStreaming: false,
        reasoning: _reasoningSession.snapshot(),
        thinkingDurationMs: _finalThinkingDurationMs(),
        clearThinkingStartedAtEpochMs: true,
        activities: _visibleActivities(isStreaming: false),
        clearTokensPerSecond: true,
        averageTokensPerSecond: averageTokensPerSecond,
      ),
    );
    _activeAssistantId = null;
  }

  void _replaceActiveAssistantContent(
    String content, {
    required bool isStreaming,
    bool clearAverageTokensPerSecond = false,
  }) {
    final id = _activeAssistantId;
    if (id == null) {
      return;
    }
    final currentMessages = messages;
    final index = _messageStateStore.indexOfMessageId(id);
    if (index == -1) {
      return;
    }
    final existing = currentMessages[index];
    final currentTokensPerSecond = isStreaming
        ? _calculateLiveTokensPerSecond(revealedLength: content.length)
        : null;
    _replaceMessageAt(
      index,
      existing.copyWith(
        content: content,
        isStreaming: isStreaming,
        tokensPerSecond: currentTokensPerSecond,
        reasoning: _reasoningSession.snapshot(),
        thinkingDurationMs: isStreaming
            ? _streamingThinkingBaseDurationMs()
            : _finalThinkingDurationMs(),
        thinkingStartedAtEpochMs: isStreaming
            ? _thinkingStartedAt?.millisecondsSinceEpoch
            : null,
        activities: _visibleActivities(isStreaming: isStreaming),
        clearAverageTokensPerSecond: clearAverageTokensPerSecond,
        clearThinkingStartedAtEpochMs: !isStreaming,
      ),
    );
    _tokensPerSecond = currentTokensPerSecond ?? _tokensPerSecond;
    notifyListeners();
  }

  void _syncActiveAssistantThinking() {
    final id = _activeAssistantId;
    if (id == null) {
      return;
    }
    final currentMessages = messages;
    final index = _messageStateStore.indexOfMessageId(id);
    if (index == -1) {
      return;
    }
    final existing = currentMessages[index];
    _replaceMessageAt(
      index,
      existing.copyWith(
        reasoning: _reasoningSession.snapshot(),
        thinkingDurationMs: _streamingThinkingBaseDurationMs(),
        thinkingStartedAtEpochMs: _thinkingStartedAt?.millisecondsSinceEpoch,
        activities: _visibleActivities(isStreaming: true),
      ),
    );
  }

  void _recordToolActivity(ChatActivity activity) {
    _assistantThinkingSession.recordToolActivity(activity);
    _syncActiveAssistantThinking();
    notifyListeners();
  }

  void _applyGeneratedArtifactIfActive(GeneratedArtifactReference artifact) {
    final activeAssistantId = _activeAssistantId;
    if (activeAssistantId == null) {
      return;
    }
    attachGeneratedArtifact(activeAssistantId, artifact);
  }

  /// Tool activities only. Reasoning is rendered by `ReasoningBlock` from
  /// [ChatMessage.reasoning], so the synthetic `thought` activity that used to
  /// carry reasoning chunks is filtered out here.
  List<ChatActivity> _visibleActivities({required bool isStreaming}) {
    return _assistantThinkingSession
        .visibleActivities(
          isStreaming: isStreaming,
          thoughtTitle: _formatThoughtTitle(isStreaming: isStreaming),
        )
        .where((activity) => activity.type != ChatActivityType.thought)
        .toList(growable: false);
  }

  String _formatThoughtTitle({required bool isStreaming}) {
    if (isStreaming) {
      return 'Reasoning';
    }
    final durationMs = _finalThinkingDurationMs();
    if (durationMs == null || durationMs <= 0) {
      return 'Reasoning';
    }
    final seconds = durationMs / 1000;
    if (seconds >= 10) {
      return 'Reasoning • ${seconds.toStringAsFixed(0)}s';
    }
    return 'Reasoning • ${seconds.toStringAsFixed(1)}s';
  }

  int? _finalThinkingDurationMs() {
    final total = _accumulatedThinkingMs;
    return total <= 0 ? null : total;
  }

  int? _streamingThinkingBaseDurationMs() {
    final total = _accumulatedThinkingMs;
    return total <= 0 ? null : total;
  }

  void _pauseThinkingClock() {
    final thinkingStartedAt = _thinkingStartedAt;
    if (thinkingStartedAt == null) {
      return;
    }
    _accumulatedThinkingMs += DateTime.now()
        .difference(thinkingStartedAt)
        .inMilliseconds;
    _thinkingStartedAt = null;
  }

  void _resumeThinkingClock() {
    if (_thinkingStartedAt != null) {
      return;
    }
    _thinkingStartedAt = DateTime.now();
  }


  double? _calculateLiveTokensPerSecond({required int revealedLength}) {
    return _reasoningDeltaMerger.liveTokensPerSecond(
      revealedLength: revealedLength,
      requestStartedAt: _requestStartedAt,
    );
  }

  double? _calculateAverageTokensPerSecond() {
    return _reasoningDeltaMerger.averageTokensPerSecond(
      generatedTokens: _generatedTokens,
      requestStartedAt: _requestStartedAt,
    );
  }

  String _nextId() {
    _messageCounter += 1;
    return 'message_$_messageCounter';
  }

  void _syncMessageCounterWithHistory(List<ChatMessage> messages) {
    var maxSeenCounter = 0;
    for (final message in messages) {
      final id = message.id;
      if (!id.startsWith('message_')) {
        continue;
      }
      final parsed = int.tryParse(id.substring('message_'.length));
      if (parsed != null && parsed > maxSeenCounter) {
        maxSeenCounter = parsed;
      }
    }
    _messageCounter = maxSeenCounter;
  }

  int _estimateConversationTokens() {
    return _messageStateStore.conversationTokenEstimate;
  }

  int _estimateMessagesTokenCount(List<ChatMessage> messages) {
    var totalTokens = 0;
    for (final message in messages) {
      totalTokens += _estimatedTokensForMessage(message);
    }
    return totalTokens;
  }

  bool _shouldAutoContinue({
    required String prompt,
    required SarvamChatResult result,
    required String accumulatedResponse,
    required int roundsUsed,
    bool expectsArtifact = false,
    bool artifactProduced = false,
  }) {
    return _autoContinuationPolicy.shouldAutoContinue(
      prompt: prompt,
      result: result,
      accumulatedResponse: accumulatedResponse,
      roundsUsed: roundsUsed,
      containsMermaid: _containsMermaid,
      expectsArtifact: expectsArtifact,
      artifactProduced: artifactProduced,
    );
  }

  /// Model-visible tool definitions, resolved from the capability catalog so
  /// runtime-registered tools (MCP servers, the sandbox) are included.
  List<SarvamToolDefinition> get _toolDefinitions =>
      CapabilityToolAdapter.modelVisibleToolDefinitions(catalog: _catalog);

  Future<void> _startTask(String prompt) async {
    _activeRequestSession.clearSelectedTools();
    await _activeTaskSession.startTask(
      conversationId: _conversationId,
      prompt: prompt,
    );
  }

  String? _primaryDraftingStepKind() {
    return _activeTaskSession.primaryDraftingStepKind();
  }

  void _markPrimaryDraftingStepCompleted({required String detail}) {
    final kind = _primaryDraftingStepKind();
    if (kind != null) {
      _markStepCompleted(kind, detail: detail);
    }
  }


  void _markStepCompletedIfPresent(String kind, {required String detail}) {
    _activeTaskSession.markStepCompletedIfPresent(kind, detail: detail);
  }

  void _markStepRunning(String kind, {String? detail}) {
    _activeTaskSession.markStepRunning(kind, detail: detail);
  }

  void _markStepCompleted(String kind, {String? detail}) {
    _activeTaskSession.markStepCompleted(kind, detail: detail);
  }

  void _markStepFailed(String kind, {required String error}) {
    _activeTaskSession.markStepFailed(kind, error: error);
  }

  void _completeActiveTask() {
    _activeTaskSession.completeTask();
  }

  void _failActiveTask(String error) {
    _activeTaskSession.failTask(error);
  }

  void _cancelActiveTask() {
    _activeTaskSession.cancelTask();
  }

  void _updateActiveTask(AgentTask Function(AgentTask task) update) {
    _activeTaskSession.apply(update);
  }

  Future<void> _persistActiveTask({AgentTask? task}) async {
    await _activeTaskSession.persist(task: task);
  }

  bool _hasStep(String kind) {
    return _activeTaskSession.hasStep(kind);
  }

  bool _containsMermaid(String content) {
    return content.contains('```mermaid') ||
        _mermaidDiagramRegex.hasMatch(content);
  }

  void reportDiagramRenderResult({
    required String messageId,
    required bool success,
    String? error,
  }) {
    final action = _diagramRenderResultHandler.buildAction(
      hasTask: _activeTask != null,
      hasRenderStep: _hasStep(AgentStepKinds.renderDiagram),
      matchesActiveAssistant:
          _activeAssistantId == null || _activeAssistantId == messageId,
      success: success,
      error: error,
    );
    if (action == null) {
      return;
    }
    if (action.status == DiagramRenderOutcomeStatus.completed) {
      unawaited(
        _auditLogStore.record(
          capabilityKey: action.capabilityKey,
          title: action.capabilityTitle,
          detail: action.detail,
          status: AuditLogStatus.success,
          conversationId: _conversationId,
        ),
      );
      _markStepCompleted(
        AgentStepKinds.renderDiagram,
        detail: action.detail,
      );
      _refreshActiveTaskStatus();
      return;
    }
    _markStepFailed(
      AgentStepKinds.renderDiagram,
      error: action.detail,
    );
    unawaited(
      _auditLogStore.record(
        capabilityKey: action.capabilityKey,
        title: action.capabilityTitle,
        detail: action.detail,
        status: AuditLogStatus.failed,
        conversationId: _conversationId,
      ),
    );
    _refreshActiveTaskStatus();
  }

  void _refreshActiveTaskStatus() {
    _activeTaskSession.refreshTaskStatus();
  }

  Future<void> _captureConversationMemory({
    required String prompt,
    required String finalResponse,
  }) async {
    final task = _activeTask;
    if (task == null) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final capture = _conversationMemoryCaptureBuilder.build(
      task: task,
      conversationId: _conversationId,
      prompt: prompt,
      finalResponse: finalResponse,
      currentThought: _assistantThinkingSession.currentThought,
      visibleActivityCount: _assistantThinkingSession.activities.length,
      messageCount: messages.length,
      nowEpochMs: now,
    );
    await _workingMemoryStore.upsertSnapshot(capture.snapshot);
    await _semanticFactStore.upsertFact(capture.fact);
  }

  void _appendMessages(
    Iterable<ChatMessage> messages, {
    required bool notifyController,
  }) {
    _messageStateStore.appendMessages(
      messages,
      estimateTokens: _estimateFreshTokensForMessage,
    );
    if (notifyController) {
      notifyListeners();
    }
  }

  void _replaceAllMessages(List<ChatMessage> messages) {
    _messageStateStore.replaceAllMessages(
      messages,
      estimateTokens: _estimateFreshTokensForMessage,
    );
  }

  void _invalidateGeneration() {
    _generationEpoch += 1;
  }

  bool _isCurrentGeneration(int generationEpoch) {
    return generationEpoch == _generationEpoch;
  }

  bool _shouldApplyUpdatedRun(RuntimeRun originalRun) {
    return identical(_activeRunSession.run, originalRun) ||
        _activeRunSession.run?.id == originalRun.id;
  }

  void _replaceMessageAt(int index, ChatMessage message) {
    _messageStateStore.replaceMessageAt(
      index,
      message,
      estimateTokens: _estimateFreshTokensForMessage,
    );
  }

  int _estimatedTokensForMessage(ChatMessage message) {
    return _messageStateStore.estimatedTokensForMessage(
      message,
      estimateTokens: _estimateFreshTokensForMessage,
    );
  }

  int _estimateFreshTokensForMessage(ChatMessage message) {
    return ((message.content.length + 12) / 4).ceil().clamp(0, 1 << 30);
  }
}
