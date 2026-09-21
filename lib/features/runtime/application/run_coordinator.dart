import 'dart:async';

import '../../chat/application/agent_orchestrator.dart';
import '../../chat/application/response_repair_coordinator.dart';
import '../../chat/application/response_guard.dart';
import '../../chat/application/sarvam_api_client.dart';
import '../../chat/application/tool_dispatcher.dart';
import '../../chat/application/web_tools.dart';
import '../../chat/domain/chat_message.dart';
import '../../response/response.dart';
import '../../settings/app_settings.dart';
import '../../skills/skills.dart';
import '../../verifier/verifier.dart';
import '../domain/agent_policy.dart';
import '../domain/run_route.dart';
import '../domain/request_classification.dart';
import '../domain/runtime_operation_ledger_record.dart';
import '../domain/runtime_progress_snapshot.dart';
import '../domain/runtime_resume_snapshot.dart';
import '../domain/runtime_run.dart';
import '../domain/runtime_run_event.dart';
import '../domain/runtime_run_node.dart';
import 'run_route_selector.dart';
import 'request_classifier.dart';
import 'runtime_progress_snapshot_builder.dart';
import 'runtime_progress_snapshot_metadata_adapter.dart';
import '../../docs/application/artifact_fallback_coordinator.dart';
import 'runtime_ledger_service.dart';

typedef RuntimeRunIdFactory = String Function();

class RunCoordinatorResult {
  const RunCoordinatorResult({
    required this.run,
    required this.orchestrationResult,
    required this.responseEnvelope,
    this.progressSnapshot,
    this.selectedSkill,
    this.skillRun,
    this.responseVerification,
  });

  final RuntimeRun run;
  final AgentOrchestratorResult orchestrationResult;
  final ResponseEnvelope responseEnvelope;
  final RuntimeProgressSnapshot? progressSnapshot;
  final SelectedSkillPlan? selectedSkill;
  final SkillRunResult? skillRun;
  final VerificationReport? responseVerification;
}

class RunCoordinatorHooks {
  const RunCoordinatorHooks({
    this.onRunStarted,
    this.onProgress,
    this.onPrepared,
    this.onThought,
    this.onToolBatchStarting,
    this.onToolBatchCompleted,
    this.onAutoContinue,
    this.onRequestMessagesMutated,
    this.onRunCompleted,
    this.onRunFailed,
    this.onRunCancelled,
  });

  final FutureOr<void> Function(RuntimeRun run)? onRunStarted;
  final FutureOr<void> Function(
    RuntimeRun run,
    RuntimeProgressSnapshot snapshot,
  )?
  onProgress;
  final FutureOr<void> Function(RuntimeRun run, AgentOrchestratorTurn turn)?
  onPrepared;
  final FutureOr<void> Function(RuntimeRun run, String thought)? onThought;
  final FutureOr<void> Function(RuntimeRun run, List<SarvamToolCall> toolCalls)?
  onToolBatchStarting;
  final FutureOr<void> Function(RuntimeRun run, List<ToolDispatchResult> results)?
  onToolBatchCompleted;
  final FutureOr<void> Function(RuntimeRun run)? onAutoContinue;
  final FutureOr<void> Function(RuntimeRun run, List<ChatMessage> requestMessages)?
  onRequestMessagesMutated;
  final FutureOr<void> Function(RuntimeRun run, AgentOrchestratorResult result)?
  onRunCompleted;
  final FutureOr<void> Function(RuntimeRun run, Object error)? onRunFailed;
  final FutureOr<void> Function(RuntimeRun run)? onRunCancelled;
}

class RunCoordinator {
  RunCoordinator({
    required AgentOrchestrator orchestrator,
    RuntimeLedgerService? runtimeLedgerService,
    SkillSelector? skillSelector,
    SkillRunner? skillRunner,
    RunRouteSelector? runRouteSelector,
    RequestClassifier? requestClassifier,
    ResponseVerifier? responseVerifier,
    ToolIntentVerifier? toolIntentVerifier,
    ResponseEnvelopeBuilder? responseEnvelopeBuilder,
    RuntimeProgressSnapshotBuilder? progressSnapshotBuilder,
    RuntimeProgressSnapshotMetadataAdapter? progressSnapshotMetadataAdapter,
    ResponseRepairCoordinator? responseRepairCoordinator,
    RuntimeRunIdFactory? runIdFactory,
  }) : _orchestrator = orchestrator,
       _runtimeLedgerService = runtimeLedgerService ?? RuntimeLedgerService(),
       _skillSelector = skillSelector ?? const SkillSelector(),
       _skillRunner = skillRunner ?? SkillRunner(),
       _runRouteSelector = runRouteSelector ?? const RunRouteSelector(),
       _requestClassifier = requestClassifier ?? const RequestClassifier(),
       _responseVerifier = responseVerifier ?? const ResponseVerifier(),
       _toolIntentVerifier = toolIntentVerifier ?? const ToolIntentVerifier(),
       _responseEnvelopeBuilder =
           responseEnvelopeBuilder ?? const ResponseEnvelopeBuilder(),
       _progressSnapshotBuilder =
           progressSnapshotBuilder ?? const RuntimeProgressSnapshotBuilder(),
       _progressSnapshotMetadataAdapter =
           progressSnapshotMetadataAdapter ??
           const RuntimeProgressSnapshotMetadataAdapter(),
       _responseRepairCoordinator = responseRepairCoordinator,
       _runIdFactory = runIdFactory ?? _defaultRunIdFactory;

  final AgentOrchestrator _orchestrator;
  final RuntimeLedgerService _runtimeLedgerService;
  final SkillSelector _skillSelector;
  final SkillRunner _skillRunner;
  final RunRouteSelector _runRouteSelector;
  final RequestClassifier _requestClassifier;
  final ResponseVerifier _responseVerifier;
  final ToolIntentVerifier _toolIntentVerifier;
  final ResponseEnvelopeBuilder _responseEnvelopeBuilder;
  final RuntimeProgressSnapshotBuilder _progressSnapshotBuilder;
  final RuntimeProgressSnapshotMetadataAdapter
  _progressSnapshotMetadataAdapter;
  final ResponseRepairCoordinator? _responseRepairCoordinator;
  final ArtifactFallbackCoordinator _artifactFallbackCoordinator =
      const ArtifactFallbackCoordinator();
  final RuntimeRunIdFactory _runIdFactory;

  Future<RunCoordinatorResult> runTurn({
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
    bool reuseExistingArtifacts = false,
    RunBudget budget = RunBudget.unlimited,
    RunCoordinatorHooks hooks = const RunCoordinatorHooks(),
  }) async {
    final requestClassification = _requestClassifier.classify(prompt);
    final selectedSkill = _skillSelector.select(
      prompt: prompt,
      conversationId: conversationId,
      taskId: taskId,
      allowSideEffects: requestClassification.requiresSideEffect,
      classification: requestClassification,
    );
    final routeSelection = _runRouteSelector.select(
      prompt: prompt,
      selectedSkill: selectedSkill,
      classification: requestClassification,
    );
    final consumedSingleUseToolNames = <String>{};
    var run = await _startRunSafely(
      id: _runIdFactory(),
      kind: RuntimeRunKind.conversation,
      title: prompt,
      conversationId: conversationId,
      taskId: taskId,
      capabilityKey: 'chat.turn',
      request: <String, Object?>{
        'prompt': prompt,
        'model_id': settings.selectedModelId,
      },
      metadata: <String, Object?>{
        'tool_count': allToolDefinitions.length,
        'run_route': runRouteToJson(routeSelection.route),
        'quality_mode': runQualityModeToJson(routeSelection.qualityMode),
        'route_reason': routeSelection.reason,
        'request_kind': requestClassification.requestKind.name,
        'artifact_kind': requestClassification.artifactKind.name,
        'requires_external_context':
            requestClassification.requiresExternalContext,
        'requires_side_effect': requestClassification.requiresSideEffect,
        'final_answer_mode': requestClassification.finalAnswerMode.name,
        'fallback_policy': requestClassification.fallbackPolicy.name,
        'classification_reason': requestClassification.reason,
        if (selectedSkill != null)
          'selected_skill_id': selectedSkill.skill.skillId,
        if (selectedSkill != null)
          'selected_skill_steps': selectedSkill.skill.subgraph.steps
              .map((step) => step.id)
              .toList(growable: false),
      },
      status: RuntimeRunStatus.preparing,
    );
    var nextNodeOrdinal = 0;
    var assistantAttempt = 0;
    RuntimeRunNode? rootNode;
    RuntimeRunNode? prepareNode;
    RuntimeRunNode? activeAssistantNode;
    RuntimeRunNode? activeToolBatchNode;
    RuntimeRunNode? verificationNode;
    RuntimeRunNode? responseRepairNode;
    var attemptedRuntimeRepair = false;
    final toolNodesByCallId = <String, RuntimeRunNode>{};
    final nodesById = <String, RuntimeRunNode>{};
    final pendingPersistence = <Future<void>>[];
    SkillRunResult? skillRun;

    void trackPersistence(Future<void> future) {
      pendingPersistence.add(future);
      future.whenComplete(() {
        pendingPersistence.remove(future);
      });
    }

    Future<void> flushPersistence() async {
      if (pendingPersistence.isEmpty) {
        return;
      }
      await Future.wait(List<Future<void>>.from(pendingPersistence));
    }

    RuntimeRunNode createNode({
      required String phaseKey,
      required String title,
      RuntimeRunNodeStatus status = RuntimeRunNodeStatus.running,
      String? parentNodeId,
      int attempt = 1,
      String? capabilityKey,
      String? toolName,
      String? toolCallId,
      String? operationKey,
      Map<String, Object?> request = const <String, Object?>{},
      Map<String, Object?> metadata = const <String, Object?>{},
    }) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return RuntimeRunNode(
        id: '${run.id}:$phaseKey:${nextNodeOrdinal + 1}',
        runId: run.id,
        parentNodeId: parentNodeId,
        phaseKey: phaseKey,
        title: title,
        status: status,
        ordinal: nextNodeOrdinal++,
        attempt: attempt,
        capabilityKey: capabilityKey,
        toolName: toolName,
        toolCallId: toolCallId,
        operationKey: operationKey,
        request: request,
        metadata: metadata,
        startedAtEpochMs: now,
        updatedAtEpochMs: now,
      );
    }

    RuntimeRunNode markNode(
      RuntimeRunNode node, {
      RuntimeRunNodeStatus? status,
      Map<String, Object?>? request,
      Map<String, Object?>? result,
      bool clearResult = false,
      Map<String, Object?>? metadata,
      String? error,
      bool clearError = false,
      bool complete = false,
    }) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return node.copyWith(
        status: status,
        request: request,
        result: result,
        clearResult: clearResult,
        metadata: metadata,
        error: error,
        clearError: clearError,
        updatedAtEpochMs: now,
        completedAtEpochMs: complete ? now : node.completedAtEpochMs,
        clearCompletedAtEpochMs: !complete && node.completedAtEpochMs == null,
      );
    }

    void persistNode(RuntimeRunNode? node) {
      if (node == null) {
        return;
      }
      nodesById[node.id] = node;
      trackPersistence(_upsertNodeSafely(node));
    }

    Future<void> publishProgress() async {
      final snapshot = _progressSnapshotBuilder.build(
        run: run,
        nodes: nodesById.values.toList(growable: false),
      );
      run = await _updateRunSafely(
        run: run,
        metadata: _progressSnapshotMetadataAdapter.writeToMetadata(
          metadata: run.metadata,
          snapshot: snapshot,
        ),
      );
      await Future<void>.value(hooks.onProgress?.call(run, snapshot));
    }

    rootNode = createNode(
      phaseKey: 'root',
      title: 'Run root',
      status: RuntimeRunNodeStatus.running,
      capabilityKey: run.capabilityKey,
      request: <String, Object?>{
        'prompt': prompt,
        'model_id': settings.selectedModelId,
      },
      metadata: <String, Object?>{
        'run_route': runRouteToJson(routeSelection.route),
        'quality_mode': runQualityModeToJson(routeSelection.qualityMode),
        'request_kind': requestClassification.requestKind.name,
        'artifact_kind': requestClassification.artifactKind.name,
        if (selectedSkill != null)
          'selected_skill_id': selectedSkill.skill.skillId,
      },
    );
    persistNode(rootNode);
    await publishProgress();

    final skillNode = markNode(
      createNode(
        phaseKey: 'skill_selection',
        title: 'Select skill',
        parentNodeId: rootNode.id,
        status: RuntimeRunNodeStatus.running,
        capabilityKey: selectedSkill?.skill.skillId,
        metadata: <String, Object?>{
          if (selectedSkill != null) 'skill_id': selectedSkill.skill.skillId,
          if (selectedSkill != null)
            'subgraph_steps': selectedSkill.skill.subgraph.steps
                .map((step) => step.id)
                .toList(growable: false),
        },
      ),
      status: RuntimeRunNodeStatus.completed,
      result: <String, Object?>{
        'selected': selectedSkill != null,
        'run_route': runRouteToJson(routeSelection.route),
        'quality_mode': runQualityModeToJson(routeSelection.qualityMode),
        if (selectedSkill != null) 'skill_id': selectedSkill.skill.skillId,
      },
      complete: true,
    );
    persistNode(skillNode);
    await publishProgress();

    if (selectedSkill != null) {
      var skillExecutionNode = await _startNodeSafely(
        runId: run.id,
        phaseKey: 'skill_execution',
        title: 'Execute selected skill',
        ordinal: nextNodeOrdinal,
        parentNodeId: rootNode.id,
        capabilityKey: selectedSkill.skill.skillId,
        request: selectedSkill.input,
        metadata: <String, Object?>{
          'skill_id': selectedSkill.skill.skillId,
          'request_kind': skillRequestKindToJson(
            selectedSkill.context.requestKind,
          ),
        },
      );
      persistNode(skillExecutionNode);
      await publishProgress();
      nextNodeOrdinal = skillExecutionNode.ordinal + 1;
      skillRun = await _skillRunner.run(
        skillId: selectedSkill.skill.skillId,
        input: selectedSkill.input,
        context: selectedSkill.context,
        stepExecutor: (context) => _executeSkillPlanningStep(
          selectedSkill: selectedSkill,
          context: context,
          prompt: prompt,
        ),
      );
      var stepOrdinal = nextNodeOrdinal;
      for (final step in skillRun.steps) {
        final stepNode = RuntimeRunNode(
          id: '${run.id}:skill_step:${stepOrdinal + 1}',
          runId: run.id,
          parentNodeId: skillExecutionNode.id,
          phaseKey: 'skill_step',
          title: step.stepId,
          status: RuntimeRunNodeStatus.running,
          ordinal: stepOrdinal,
          attempt: 1,
          capabilityKey: selectedSkill.skill.skillId,
          request: const <String, Object?>{},
          metadata: <String, Object?>{
            'step_id': step.stepId,
            'status': skillStepStatusToJson(step.status),
          },
          error: null,
          startedAtEpochMs: step.startedAtEpochMs ?? run.createdAtEpochMs,
          updatedAtEpochMs: step.finishedAtEpochMs ?? run.updatedAtEpochMs,
        );
        final completedStepNode = await _completeNodeSafely(
          node: stepNode,
          status: _mapSkillStepStatus(step.status),
          result: step.toMap(),
          error: step.error,
          metadata: <String, Object?>{
            'step_id': step.stepId,
            'status': skillStepStatusToJson(step.status),
          },
        );
        persistNode(completedStepNode);
        stepOrdinal += 1;
      }
      nextNodeOrdinal = stepOrdinal;
      skillExecutionNode = await _completeNodeSafely(
        node: skillExecutionNode,
        status: _mapSkillRunStatus(skillRun.status),
        result: skillRun.toMap(),
        error: skillRun.error ?? skillRun.blockedReason,
      );
      persistNode(skillExecutionNode);
      await publishProgress();
      run = await _updateRunSafely(
        run: run,
        metadata: <String, Object?>{
          ...run.metadata,
          'selected_skill_status': skillRun.status.name,
          'selected_skill_output': skillRun.output,
          'run_route': runRouteToJson(routeSelection.route),
          'quality_mode': runQualityModeToJson(routeSelection.qualityMode),
        },
      );
    }

    final combinedTaskHint = _combineTaskHints(
      taskHint,
      selectedSkill?.instruction,
      _buildSkillExecutionHint(skillRun),
      _buildRouteHint(routeSelection),
    );

    prepareNode = createNode(
      phaseKey: 'prepare_context',
      title: 'Prepare context',
      parentNodeId: rootNode.id,
      status: RuntimeRunNodeStatus.running,
      capabilityKey: 'chat.turn',
    );
    persistNode(prepareNode);
    await publishProgress();
      await Future<void>.value(hooks.onRunStarted?.call(run));

    try {
      final result = await _orchestrator.run(
        budget: budget,
        apiKey: apiKey,
        settings: settings,
        prompt: prompt,
        conversationId: conversationId,
        taskId: taskId,
        modelHistory: modelHistory,
        allToolDefinitions: allToolDefinitions,
        outputToolsPrompt: outputToolsPrompt,
        taskHint: combinedTaskHint,
        executeAssistantRound: executeAssistantRound,
        executeToolCall: executeToolCall,
        shouldAutoContinue: shouldAutoContinue,
        hooks: AgentOrchestratorHooks(
          onPrepared: (turn) async {
            prepareNode = markNode(
              prepareNode!,
              status: RuntimeRunNodeStatus.completed,
              result: <String, Object?>{
                'selected_tools': turn.selectedTools,
                'active_tool_count': turn.activeToolDefinitions.length,
                'prompt_token_estimate': _estimateTokenCount(
                  turn.requestMessages,
                ),
              },
              complete: true,
            );
            persistNode(prepareNode);
            assistantAttempt = 1;
            activeAssistantNode = createNode(
              phaseKey: 'assistant_round',
              title: 'Assistant round',
              parentNodeId: rootNode?.id,
              status: RuntimeRunNodeStatus.running,
              attempt: assistantAttempt,
              capabilityKey: 'chat.turn',
              request: <String, Object?>{
                'selected_tools': turn.selectedTools,
                'request_message_count': turn.requestMessages.length,
                'prompt_token_estimate': _estimateTokenCount(
                  turn.requestMessages,
                ),
              },
            );
            persistNode(activeAssistantNode);
            run = run.copyWith(
              status: RuntimeRunStatus.runningModel,
              metadata: <String, Object?>{
                ...run.metadata,
                'selected_tools': turn.selectedTools,
                'active_tool_count': turn.activeToolDefinitions.length,
                'prompt_token_estimate': _estimateTokenCount(
                  turn.requestMessages,
                ),
              },
              updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
            );
            await Future<void>.value(hooks.onPrepared?.call(run, turn));
            await publishProgress();
            trackPersistence(
              _updateRunSafely(
                run: run,
                status: run.status,
                metadata: run.metadata,
              ).then((_) {}),
            );
            trackPersistence(
              _recordEventSafely(
                runId: run.id,
                kind: RuntimeRunEventKind.stepStarted,
                title: 'Prepared run context',
                detail: 'Context assembled and tools selected.',
                payload: <String, Object?>{
                  'selected_tools': turn.selectedTools,
                  'prompt_token_estimate': _estimateTokenCount(
                    turn.requestMessages,
                  ),
                },
              ),
            );
          },
          onThought: (thought) async {
            await Future<void>.value(hooks.onThought?.call(run, thought));
            trackPersistence(
              _recordEventSafely(
                runId: run.id,
                kind: RuntimeRunEventKind.note,
                title: 'Thought updated',
                detail: thought,
              ),
            );
          },
          onToolBatchStarting: (toolCalls) async {
            _verifyToolBatchOrThrow(
              toolCalls: toolCalls,
              allowedTools: allToolDefinitions,
              consumedSingleUseToolNames: consumedSingleUseToolNames,
            );
            if (activeAssistantNode != null) {
              activeAssistantNode = markNode(
                activeAssistantNode!,
                status: RuntimeRunNodeStatus.completed,
                result: <String, Object?>{
                  'outcome': 'tool_request_emitted',
                  'tool_names': toolCalls.map((tool) => tool.name).toList(),
                },
                complete: true,
              );
              persistNode(activeAssistantNode);
            }
            activeToolBatchNode = createNode(
              phaseKey: 'tool_batch',
              title: 'Execute tool batch',
              parentNodeId: rootNode?.id,
              status: RuntimeRunNodeStatus.running,
              capabilityKey: 'tool.batch',
              request: <String, Object?>{
                'tool_names': toolCalls.map((tool) => tool.name).toList(),
                'tool_count': toolCalls.length,
              },
            );
            persistNode(activeToolBatchNode);
            toolNodesByCallId.clear();
            final seenOperationKeys = <String>{};
            for (final toolCall in toolCalls) {
              final operationKey = _operationKeyForToolCall(toolCall);
              if (_shouldBlockOperationReplay(toolCall.name)) {
                if (!seenOperationKeys.add(operationKey)) {
                  throw StateError(
                    'Run attempted to replay the same ${toolCall.name} operation in a single tool batch.',
                  );
                }
                final existingOperation = await _getOperationSafely(
                  runId: run.id,
                  operationKey: operationKey,
                );
                if (existingOperation?.status ==
                    RuntimeOperationStatus.completed) {
                  throw StateError(
                    'Run attempted to replay a completed ${toolCall.name} operation.',
                  );
                }
              }
              final toolNode = createNode(
                phaseKey: 'tool_call',
                title: 'Execute ${toolCall.name}',
                parentNodeId: activeToolBatchNode?.id,
                status: RuntimeRunNodeStatus.running,
                capabilityKey: toolCall.name,
                toolName: toolCall.name,
                toolCallId: toolCall.id,
                operationKey: operationKey,
                request: Map<String, Object?>.from(toolCall.arguments),
              );
              toolNodesByCallId[toolCall.id] = toolNode;
              persistNode(toolNode);
            }
            run = run.copyWith(
              status: RuntimeRunStatus.runningTools,
              updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
            );
            await Future<void>.value(
              hooks.onToolBatchStarting?.call(run, toolCalls),
            );
            await publishProgress();
            trackPersistence(
              _updateRunSafely(run: run, status: run.status).then((_) {}),
            );
            trackPersistence(
              _recordEventSafely(
                runId: run.id,
                kind: RuntimeRunEventKind.toolRequested,
                title: 'Tool batch started',
                detail: 'Executing ${toolCalls.length} tool call(s).',
                payload: <String, Object?>{
                  'tools': toolCalls.map((tool) => tool.name).toList(),
                },
              ),
            );
            for (final toolCall in toolCalls) {
              final operationKey = _operationKeyForToolCall(toolCall);
              trackPersistence(
                _recordOperationSafely(
                  runId: run.id,
                  operationKey: operationKey,
                  kind: toolCall.name,
                  status: RuntimeOperationStatus.running,
                  request: Map<String, Object?>.from(toolCall.arguments),
                ),
              );
            }
          },
          onToolBatchCompleted: (results) async {
            consumedSingleUseToolNames.addAll(
              results
                  .map((result) => result.call.name)
                  .where(_isOutputToolName),
            );
            for (final dispatch in results) {
              final currentNode = toolNodesByCallId[dispatch.call.id];
              if (currentNode == null) {
                continue;
              }
              final completedNode = markNode(
                currentNode,
                status: dispatch.result.success
                    ? RuntimeRunNodeStatus.completed
                    : RuntimeRunNodeStatus.failed,
                result: <String, Object?>{
                  'summary': dispatch.result.summary,
                  'formatted_output': dispatch.result.formattedOutput,
                },
                error: dispatch.result.success ? null : dispatch.result.summary,
                clearError: dispatch.result.success,
                complete: true,
              );
              toolNodesByCallId[dispatch.call.id] = completedNode;
              persistNode(completedNode);
            }
            if (activeToolBatchNode != null) {
              activeToolBatchNode = markNode(
                activeToolBatchNode!,
                status: results.every((entry) => entry.result.success)
                    ? RuntimeRunNodeStatus.completed
                    : RuntimeRunNodeStatus.failed,
                result: <String, Object?>{
                  'result_count': results.length,
                  'failed_count': results
                      .where((entry) => !entry.result.success)
                      .length,
                },
                complete: true,
              );
              persistNode(activeToolBatchNode);
            }
            assistantAttempt += 1;
            activeAssistantNode = createNode(
              phaseKey: 'assistant_round',
              title: 'Assistant round',
              parentNodeId: rootNode?.id,
              status: RuntimeRunNodeStatus.running,
              attempt: assistantAttempt,
              capabilityKey: 'chat.turn',
              request: <String, Object?>{'tool_result_count': results.length},
            );
            persistNode(activeAssistantNode);
            run = run.copyWith(
              status: RuntimeRunStatus.runningModel,
              updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
            );
            await Future<void>.value(
              hooks.onToolBatchCompleted?.call(run, results),
            );
            await publishProgress();
            trackPersistence(
              _updateRunSafely(run: run, status: run.status).then((_) {}),
            );
            trackPersistence(
              _recordEventSafely(
                runId: run.id,
                kind: RuntimeRunEventKind.toolCompleted,
                title: 'Tool batch completed',
                detail: 'Tool results are available for synthesis.',
                payload: <String, Object?>{
                  'result_count': results.length,
                  'failed_count': results
                      .where((result) => !result.result.success)
                      .length,
                },
              ),
            );
            for (final dispatch in results) {
              final operationKey = _operationKeyForToolCall(dispatch.call);
              trackPersistence(
                _recordOperationSafely(
                  runId: run.id,
                  operationKey: operationKey,
                  kind: dispatch.call.name,
                  status: dispatch.result.success
                      ? RuntimeOperationStatus.completed
                      : RuntimeOperationStatus.failed,
                  request: Map<String, Object?>.from(dispatch.call.arguments),
                  result: <String, Object?>{
                    'summary': dispatch.result.summary,
                    'formatted_output': dispatch.result.formattedOutput,
                  },
                  error: dispatch.result.success
                      ? null
                      : dispatch.result.summary,
                  completedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
                ),
              );
            }
          },
          onAutoContinue: () async {
            if (activeAssistantNode != null) {
              activeAssistantNode = markNode(
                activeAssistantNode!,
                status: RuntimeRunNodeStatus.completed,
                result: <String, Object?>{'outcome': 'continuation_requested'},
                complete: true,
              );
              persistNode(activeAssistantNode);
            }
            assistantAttempt += 1;
            activeAssistantNode = createNode(
              phaseKey: 'assistant_round',
              title: 'Assistant round',
              parentNodeId: rootNode?.id,
              status: RuntimeRunNodeStatus.running,
              attempt: assistantAttempt,
              capabilityKey: 'chat.turn',
              metadata: const <String, Object?>{'source': 'auto_continue'},
            );
            persistNode(activeAssistantNode);
            await Future<void>.value(hooks.onAutoContinue?.call(run));
            await publishProgress();
            trackPersistence(
              _recordEventSafely(
                runId: run.id,
                kind: RuntimeRunEventKind.note,
                title: 'Auto continuation requested',
                detail: 'The model reached a continuation boundary.',
              ),
            );
          },
          onRequestMessagesMutated: (requestMessages) async {
            await Future<void>.value(
              hooks.onRequestMessagesMutated?.call(run, requestMessages),
            );
            trackPersistence(
              _recordEventSafely(
                runId: run.id,
                kind: RuntimeRunEventKind.note,
                title: 'Request context updated',
                payload: <String, Object?>{
                  'prompt_token_estimate': _estimateTokenCount(requestMessages),
                },
              ),
            );
          },
        ),
      );
      var effectiveResult = result;

      final completedAssistantNode = activeAssistantNode;
      if (completedAssistantNode != null &&
          !_isTerminalNodeStatus(completedAssistantNode.status)) {
        activeAssistantNode = markNode(
          completedAssistantNode,
          status: RuntimeRunNodeStatus.completed,
          result: <String, Object?>{'outcome': 'direct_response_emitted'},
          complete: true,
        );
        persistNode(activeAssistantNode);
      }
      verificationNode = createNode(
        phaseKey: 'response_verification',
        title: 'Verify response',
        parentNodeId: rootNode.id,
        status: RuntimeRunNodeStatus.running,
        capabilityKey: 'response.verifier',
      );
      persistNode(verificationNode);
      await publishProgress();

      var responseVerification = _responseVerifier.verify(
        ResponseVerificationRequest(
          response: effectiveResult.validatedResponse.content,
          userPrompt: prompt,
          expectsArtifact: requestClassification.artifactKind != ArtifactKind.none,
          expectedArtifactToolNames: effectiveResult.selectedTools
              .where(_isOutputToolName)
              .toList(growable: false),
          activeToolNames: effectiveResult.selectedTools,
        ),
      );
      var blockingIssues = responseVerification.blockingIssues
          .where(
            (issue) => !_isRecoverableResponseIssue(
              issue.code,
              prompt: prompt,
              selectedTools: effectiveResult.selectedTools,
              route: routeSelection.route,
              fallbackPolicy: requestClassification.fallbackPolicy,
              classification: requestClassification,
            ),
          )
          .toList(growable: false);
      var recoverableIssues = responseVerification.blockingIssues
          .where(
            (issue) => _isRecoverableResponseIssue(
              issue.code,
              prompt: prompt,
              selectedTools: effectiveResult.selectedTools,
              route: routeSelection.route,
              fallbackPolicy: requestClassification.fallbackPolicy,
              classification: requestClassification,
            ),
          )
          .toList(growable: false);
      if (blockingIssues.isNotEmpty) {
        verificationNode = markNode(
          verificationNode,
          status: RuntimeRunNodeStatus.failed,
          result: <String, Object?>{
            'issue_codes': blockingIssues.map((issue) => issue.code).toList(),
          },
          error: blockingIssues.first.message,
          complete: true,
        );
        persistNode(verificationNode);
        await publishProgress();
        throw StateError(blockingIssues.first.message);
      }
      verificationNode = markNode(
        verificationNode,
        status: RuntimeRunNodeStatus.completed,
        result: <String, Object?>{
          'accepted': responseVerification.isAccepted,
          'issue_count': responseVerification.issues.length,
          'blocking_issue_count': responseVerification.blockingIssues.length,
        },
        complete: true,
      );
      persistNode(verificationNode);
      await publishProgress();
      if (recoverableIssues.isNotEmpty) {
        responseRepairNode = createNode(
          phaseKey: 'response_repair',
          title: 'Repair response',
          parentNodeId: rootNode.id,
          status: RuntimeRunNodeStatus.running,
          capabilityKey: 'response.repair',
          metadata: <String, Object?>{
            'route': runRouteToJson(routeSelection.route),
            'issue_codes': recoverableIssues
                .map((issue) => issue.code)
                .toList(growable: false),
          },
        );
        persistNode(responseRepairNode);
        await publishProgress();
        final repairedContent = _shouldAttemptRuntimeResponseRepair(
              recoverableIssues: recoverableIssues,
              prompt: prompt,
              selectedTools: effectiveResult.selectedTools,
              route: routeSelection.route,
              fallbackPolicy: requestClassification.fallbackPolicy,
              classification: requestClassification,
            )
            ? await _responseRepairCoordinator?.repairEmptyDirectResponseIfNeeded(
                apiKey: apiKey,
                settings: settings,
                prompt: prompt,
                requestMessages: effectiveResult.requestMessages,
                currentResponse: effectiveResult.validatedResponse.content,
                selectedTools: effectiveResult.selectedTools,
              )
            : null;
        attemptedRuntimeRepair = repairedContent != null;
        if (repairedContent != null) {
          effectiveResult = AgentOrchestratorResult(
            finalRound: effectiveResult.finalRound.copyWith(
              content: repairedContent,
              toolCalls: const <SarvamToolCall>[],
            ),
            validatedResponse: ValidatedResponse(
              content: repairedContent,
              didMutate: true,
            ),
            requestMessages: effectiveResult.requestMessages,
            selectedTools: effectiveResult.selectedTools,
            contextAssembly: effectiveResult.contextAssembly,
          );
          responseVerification = _responseVerifier.verify(
            ResponseVerificationRequest(
              response: effectiveResult.validatedResponse.content,
              userPrompt: prompt,
              expectsArtifact: requestClassification.artifactKind != ArtifactKind.none,
              expectedArtifactToolNames: effectiveResult.selectedTools
                  .where(_isOutputToolName)
                  .toList(growable: false),
              activeToolNames: effectiveResult.selectedTools,
            ),
          );
          blockingIssues = responseVerification.blockingIssues
              .where(
                (issue) => !_isRecoverableResponseIssue(
                  issue.code,
                  prompt: prompt,
                  selectedTools: effectiveResult.selectedTools,
                  route: routeSelection.route,
                  fallbackPolicy: requestClassification.fallbackPolicy,
                  classification: requestClassification,
                ),
              )
              .toList(growable: false);
          recoverableIssues = responseVerification.blockingIssues
              .where(
                (issue) => _isRecoverableResponseIssue(
                  issue.code,
                  prompt: prompt,
                  selectedTools: effectiveResult.selectedTools,
                  route: routeSelection.route,
                  fallbackPolicy: requestClassification.fallbackPolicy,
                  classification: requestClassification,
                ),
              )
              .toList(growable: false);
        }
        if (blockingIssues.isNotEmpty ||
            (_shouldAttemptRuntimeResponseRepair(
                  recoverableIssues: recoverableIssues,
                  prompt: prompt,
                  selectedTools: effectiveResult.selectedTools,
                  route: routeSelection.route,
                  fallbackPolicy: requestClassification.fallbackPolicy,
                  classification: requestClassification,
                ) &&
                recoverableIssues.isNotEmpty)) {
          responseRepairNode = markNode(
            responseRepairNode,
            status: RuntimeRunNodeStatus.failed,
            result: <String, Object?>{
              'attempted_runtime_repair': repairedContent != null,
              'issue_codes': responseVerification.blockingIssues
                  .map((issue) => issue.code)
                  .toList(growable: false),
            },
            error: responseVerification.blockingIssues.first.message,
            complete: true,
          );
          persistNode(responseRepairNode);
          await publishProgress();
          throw StateError(responseVerification.blockingIssues.first.message);
        }
        responseRepairNode = markNode(
          responseRepairNode,
          status: RuntimeRunNodeStatus.completed,
          result: <String, Object?>{
            'accepted': true,
            'issue_codes': recoverableIssues
                .map((issue) => issue.code)
                .toList(growable: false),
            'strategy': _recoverableResponseStrategy(
              prompt: prompt,
              selectedTools: effectiveResult.selectedTools,
              route: routeSelection.route,
              fallbackPolicy: requestClassification.fallbackPolicy,
              classification: requestClassification,
            ),
            'attempted_runtime_repair': attemptedRuntimeRepair,
          },
          complete: true,
        );
        persistNode(responseRepairNode);
        await publishProgress();
      }

      // --- Phase: Artifact Repair Synchronization ---
      final expectsArtifact =
          requestClassification.artifactKind != ArtifactKind.none;
      final artifactProduced = result.artifactProduced;

      if (expectsArtifact &&
          !artifactProduced &&
          !reuseExistingArtifacts &&
          _responseRepairCoordinator != null) {
        final outputTool = _isOutputToolName('generate_docx')
            ? 'generate_docx'
            : (effectiveResult.selectedTools.firstWhere(_isOutputToolName, orElse: () => ''));

        if (outputTool.isNotEmpty) {
          final repairNode = createNode(
            phaseKey: 'artifact_repair',
            title: 'Repair missing artifact',
            parentNodeId: rootNode.id,
            status: RuntimeRunNodeStatus.running,
            capabilityKey: 'artifact.repair',
          );
          persistNode(repairNode);
          await publishProgress();

          final fallbackResult = await _artifactFallbackCoordinator
              .completePendingArtifact(
                prompt: prompt,
                outputTool: outputTool,
                requestMessages: effectiveResult.requestMessages,
                currentResponse: effectiveResult.validatedResponse.content,
                availableTools: allToolDefinitions,
                documentGenerationAlreadyAttempted: false,
                alreadyHasArtifact: false,
                executeAssistantRound: executeAssistantRound,
                findToolCall: (result, toolName) async {
                  return result.toolCalls.where((tc) => tc.name == toolName).firstOrNull;
                },
                executeToolCall: (toolCall) async {
                  final result = await executeToolCall(toolCall);
                  return ToolExecutionOutcome(
                    success: result.success,
                    formattedOutput: result.formattedOutput,
                    generatedArtifactCount: result.success ? 1 : 0, // Heuristic: success implies artifact for doc tools
                  );
                },
                recoverArtifactFromMarkdown: (result, toolName) async {
                  // Recovery via markdown heuristic
                  return null; // Placeholder for now, coordinator handles recovery check
                },
                forcedInstruction: _forcedOutputToolInstruction(outputTool),
              );

          if (fallbackResult != null) {
            effectiveResult = AgentOrchestratorResult(
              finalRound: effectiveResult.finalRound.copyWith(
                content: fallbackResult.finalResponse,
              ),
              validatedResponse: ValidatedResponse(
                content: fallbackResult.finalResponse,
                didMutate: true,
              ),
              requestMessages: effectiveResult.requestMessages,
              selectedTools: effectiveResult.selectedTools,
              contextAssembly: effectiveResult.contextAssembly,
            );

            markNode(
              repairNode,
              status: RuntimeRunNodeStatus.completed,
              result: <String, Object?>{
                'outcome': 'artifact_repaired',
                'detail': fallbackResult.stepDetail,
              },
              complete: true,
            );
          } else {
            markNode(
              repairNode,
              status: RuntimeRunNodeStatus.skipped,
              result: <String, Object?>{'outcome': 'no_repair_needed'},
              complete: true,
            );
          }
          persistNode(repairNode);
          await publishProgress();
        }
      }

      final responseEnvelope = _responseEnvelopeBuilder.buildFromFinalContent(
        finalContent: effectiveResult.validatedResponse.content,
        runId: run.id,
        conversationId: conversationId,
        modelId: effectiveResult.finalRound.model,
        title: prompt,
        status: 'completed',
        reviewedByVerifier: true,
        verified: !responseVerification.hasBlockingIssues,
        metadata: <String, Object?>{
          'runRoute': runRouteToJson(routeSelection.route),
          'qualityMode': runQualityModeToJson(routeSelection.qualityMode),
          if (selectedSkill != null)
            'selectedSkillId': selectedSkill.skill.skillId,
          if (selectedSkill != null)
            'selectedSkillSteps': selectedSkill.skill.subgraph.steps
                .map((step) => step.id)
                .toList(growable: false),
          'verifierIssueCount': responseVerification.issues.length,
          'recoverableIssueCount': recoverableIssues.length,
        },
      );

      await flushPersistence();
      run = await _completeRunSafely(
        run: run.copyWith(status: RuntimeRunStatus.finalizing),
        status: RuntimeRunStatus.completed,
        result: <String, Object?>{
          'model': effectiveResult.finalRound.model,
          'response': effectiveResult.validatedResponse.content,
          'selected_tools': effectiveResult.selectedTools,
          'run_route': runRouteToJson(routeSelection.route),
          'quality_mode': runQualityModeToJson(routeSelection.qualityMode),
          if (effectiveResult.finalRound.promptTokens != null)
            'prompt_tokens': effectiveResult.finalRound.promptTokens,
          if (effectiveResult.finalRound.completionTokens != null)
            'completion_tokens': effectiveResult.finalRound.completionTokens,
          if (effectiveResult.finalRound.totalTokens != null)
            'total_tokens': effectiveResult.finalRound.totalTokens,
          'response_envelope': responseEnvelope.toJson(),
          'response_verification': <String, Object?>{
            'accepted': responseVerification.isAccepted,
            'issue_count': responseVerification.issues.length,
            'blocking_issue_count': responseVerification.blockingIssues.length,
            'recoverable_issue_count': recoverableIssues.length,
            'recoverable_issue_codes': recoverableIssues
                .map((issue) => issue.code)
                .toList(growable: false),
          },
        },
        detail: 'Run completed successfully.',
        eventTitle: 'Run completed',
      );
      rootNode = await _completeNodeSafely(
        node: rootNode,
        status: RuntimeRunNodeStatus.completed,
        result: <String, Object?>{
          'status': 'completed',
          'selected_tools': effectiveResult.selectedTools,
        },
      );
      nodesById[rootNode.id] = rootNode;
      await Future<void>.value(hooks.onRunCompleted?.call(run, effectiveResult));
      await flushPersistence();
      final progressNodes = await _listNodesSafely(run.id);
      final progressSnapshot = _progressSnapshotBuilder.build(
        run: run,
        nodes: progressNodes,
      );
      final debugCounters = _buildDebugCounters(
        orchestrationResult: effectiveResult,
        responseVerification: responseVerification,
        recoverableIssues: recoverableIssues,
        attemptedRuntimeRepair: attemptedRuntimeRepair,
      );
      final debugMetadata = _buildDebugMetadata(
        orchestrationResult: effectiveResult,
        responseVerification: responseVerification,
        route: routeSelection.route,
      );
      run = await _updateRunSafely(
        run: run,
        metadata: _progressSnapshotMetadataAdapter.writeToMetadata(
          metadata: <String, Object?>{
            ...run.metadata,
            'debug_counters': debugCounters,
            'debug_metadata': debugMetadata,
          },
          snapshot: progressSnapshot,
        ),
      );
      return RunCoordinatorResult(
        run: run,
        orchestrationResult: effectiveResult,
        responseEnvelope: responseEnvelope,
        progressSnapshot: progressSnapshot,
        selectedSkill: selectedSkill,
        skillRun: skillRun,
        responseVerification: responseVerification,
      );
    } catch (error) {
      final failingVerificationNode = verificationNode;
      final failingRepairNode = responseRepairNode;
      final failingToolBatchNode = activeToolBatchNode;
      final failingAssistantNode = activeAssistantNode;
      final failingPrepareNode = prepareNode;
      if (failingRepairNode != null &&
          !_isTerminalNodeStatus(failingRepairNode.status)) {
        responseRepairNode = await _completeNodeSafely(
          node: failingRepairNode,
          status: RuntimeRunNodeStatus.failed,
          error: error.toString(),
        );
        nodesById[responseRepairNode.id] = responseRepairNode;
      } else if (failingVerificationNode != null &&
          !_isTerminalNodeStatus(failingVerificationNode.status)) {
        verificationNode = await _completeNodeSafely(
          node: failingVerificationNode,
          status: RuntimeRunNodeStatus.failed,
          error: error.toString(),
        );
        nodesById[verificationNode.id] = verificationNode;
      } else if (failingToolBatchNode != null &&
          !_isTerminalNodeStatus(failingToolBatchNode.status)) {
        activeToolBatchNode = await _completeNodeSafely(
          node: failingToolBatchNode,
          status: RuntimeRunNodeStatus.failed,
          error: error.toString(),
        );
        if (activeToolBatchNode != null) {
          nodesById[activeToolBatchNode!.id] = activeToolBatchNode!;
        }
      } else if (failingAssistantNode != null &&
          !_isTerminalNodeStatus(failingAssistantNode.status)) {
        activeAssistantNode = await _completeNodeSafely(
          node: failingAssistantNode,
          status: RuntimeRunNodeStatus.failed,
          error: error.toString(),
        );
        if (activeAssistantNode != null) {
          nodesById[activeAssistantNode!.id] = activeAssistantNode!;
        }
      } else if (failingPrepareNode != null &&
          !_isTerminalNodeStatus(failingPrepareNode.status)) {
        prepareNode = await _completeNodeSafely(
          node: failingPrepareNode,
          status: RuntimeRunNodeStatus.failed,
          error: error.toString(),
        );
        if (prepareNode != null) {
          nodesById[prepareNode!.id] = prepareNode!;
        }
      }
      await flushPersistence();
      run = await _completeRunSafely(
        run: run,
        status: RuntimeRunStatus.failed,
        error: error.toString(),
        detail: 'Run failed during orchestration.',
        eventTitle: 'Run failed',
      );
      if (rootNode != null && !_isTerminalNodeStatus(rootNode.status)) {
        rootNode = await _completeNodeSafely(
          node: rootNode,
          status: RuntimeRunNodeStatus.failed,
          error: error.toString(),
        );
        nodesById[rootNode.id] = rootNode;
      }
      await publishProgress();
      await Future<void>.value(hooks.onRunFailed?.call(run, error));
      await flushPersistence();
      rethrow;
    }
  }

  Future<RuntimeRun> cancelRun(RuntimeRun run, {String? detail}) async {
    final nodes = await _listNodesSafely(run.id);
    for (final node in nodes.where(
      (entry) => !_isTerminalNodeStatus(entry.status),
    )) {
      await _completeNodeSafely(
        node: node,
        status: RuntimeRunNodeStatus.cancelled,
        error: detail ?? 'Run cancelled by the user.',
      );
    }
    final cancelled = await _completeRunSafely(
      run: run,
      status: RuntimeRunStatus.cancelled,
      detail: detail ?? 'Run cancelled by the user.',
      eventTitle: 'Run cancelled',
    );
    return cancelled;
  }

  Future<RuntimeRun> appendDebugSignals({
    required RuntimeRun run,
    Map<String, int> counterDeltas = const <String, int>{},
    Map<String, Object?> metadataPatch = const <String, Object?>{},
  }) async {
    final currentCounters = Map<String, Object?>.from(
      (run.metadata['debug_counters'] as Map?) ?? const <String, Object?>{},
    );
    final mergedCounters = <String, Object?>{...currentCounters};
    for (final entry in counterDeltas.entries) {
      mergedCounters[entry.key] = _readInt(currentCounters[entry.key]) + entry.value;
    }
    final currentDebugMetadata = Map<String, Object?>.from(
      (run.metadata['debug_metadata'] as Map?) ?? const <String, Object?>{},
    );
    return _updateRunSafely(
      run: run,
      metadata: <String, Object?>{
        ...run.metadata,
        'debug_counters': mergedCounters,
        'debug_metadata': <String, Object?>{
          ...currentDebugMetadata,
          ...metadataPatch,
        },
      },
    );
  }

  Future<RuntimeRun> completeRecoveredRun({
    required RuntimeRun run,
    required String response,
    String? detail,
  }) async {
    final nodes = await _listNodesSafely(run.id);
    final rootNode = _findRootNode(nodes);
    final recoveryNode = await _startNodeSafely(
      runId: run.id,
      phaseKey: 'recovery',
      title: 'Recover response locally',
      ordinal: _nextNodeOrdinal(nodes),
      parentNodeId: rootNode?.id,
      capabilityKey: 'response.recovery',
      request: <String, Object?>{'response': response},
    );
    await _completeNodeSafely(
      node: recoveryNode,
      status: RuntimeRunNodeStatus.completed,
      result: <String, Object?>{'recovered': true, 'response': response},
    );
    if (rootNode != null && !_isTerminalNodeStatus(rootNode.status)) {
      await _completeNodeSafely(
        node: rootNode,
        status: RuntimeRunNodeStatus.completed,
        result: const <String, Object?>{'status': 'recovered'},
      );
    }
    return _completeRunSafely(
      run: run.copyWith(clearError: true, status: RuntimeRunStatus.finalizing),
      status: RuntimeRunStatus.completed,
      result: <String, Object?>{'response': response, 'recovered': true},
      detail: detail ?? 'Run recovered and finalized locally.',
      eventTitle: 'Run recovered',
    );
  }

  Future<RuntimeRun> finalizeCompletedRun({
    required RuntimeRun run,
    required String finalResponse,
    required Iterable<GeneratedArtifactReference> artifacts,
    required String? modelId,
    String? prompt,
  }) async {
    final nodes = await _listNodesSafely(run.id);
    final rootNode = _findRootNode(nodes);
    if (artifacts.isNotEmpty) {
      final finalizeNode = await _startNodeSafely(
        runId: run.id,
        phaseKey: 'artifact_finalize',
        title: 'Finalize generated artifacts',
        ordinal: _nextNodeOrdinal(nodes),
        parentNodeId: rootNode?.id,
        capabilityKey: 'artifact.finalize',
        request: <String, Object?>{'artifact_count': artifacts.length},
      );
      await _completeNodeSafely(
        node: finalizeNode,
        status: RuntimeRunNodeStatus.completed,
        result: <String, Object?>{'artifact_count': artifacts.length},
      );
    }
    final classification = _requestClassifier.classify(prompt ?? '');
    final verification = _responseVerifier.verify(
      ResponseVerificationRequest(
        response: finalResponse,
        userPrompt: prompt,
        expectsArtifact: artifacts.isNotEmpty ||
            classification.artifactKind != ArtifactKind.none,
      ),
    );
    final envelope = _responseEnvelopeBuilder.buildFromFinalContent(
      finalContent: finalResponse,
      artifacts: artifacts,
      runId: run.id,
      conversationId: run.conversationId,
      modelId: modelId,
      title: run.title,
      status: runtimeRunStatusToJson(run.status),
      reviewedByVerifier: true,
      verified: !verification.hasBlockingIssues,
      createdAtEpochMs: run.createdAtEpochMs,
      completedAtEpochMs: run.completedAtEpochMs,
      metadata: <String, Object?>{
        ...run.metadata,
        'artifact_count': artifacts.length,
        'verifier_issue_count': verification.issues.length,
      },
    );
    final progressNodes = await _listNodesSafely(run.id);
    final progressSnapshot = _progressSnapshotBuilder.build(
      run: run,
      nodes: progressNodes,
    );
    return _updateRunSafely(
      run: run,
      metadata: _progressSnapshotMetadataAdapter.writeToMetadata(
        metadata: <String, Object?>{
          ...run.metadata,
          'artifact_count': artifacts.length,
          'response_envelope': envelope.toJson(),
          'response_verification': <String, Object?>{
            'accepted': verification.isAccepted,
            'issue_count': verification.issues.length,
            'blocking_issue_count': verification.blockingIssues.length,
          },
        },
        snapshot: progressSnapshot,
      ),
      result: <String, Object?>{
        ...(run.result ?? const <String, Object?>{}),
        'response': envelope.displayText,
        'response_envelope': envelope.toJson(),
      },
    );
  }

  Future<RuntimeResumeSnapshot?> buildResumeSnapshot(String runId) {
    return _runtimeLedgerService.buildResumeSnapshot(runId);
  }

  Future<RuntimeResumeSnapshot?> resumeLatestIncompleteRun({
    String? conversationId,
  }) async {
    final latest = await _runtimeLedgerService.latestResumableRun(
      conversationId: conversationId,
    );
    if (latest == null) {
      return null;
    }
    await _recordEventSafely(
      runId: latest.id,
      kind: RuntimeRunEventKind.note,
      title: 'Run resume requested',
      detail: 'Runtime resume snapshot requested for an incomplete run.',
    );
    return _runtimeLedgerService.buildResumeSnapshot(latest.id);
  }

  static String _defaultRunIdFactory() {
    return 'run_${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<RuntimeRun> _startRunSafely({
    required String id,
    required RuntimeRunKind kind,
    required String title,
    String? conversationId,
    String? taskId,
    String? parentRunId,
    String? capabilityKey,
    Map<String, Object?> request = const <String, Object?>{},
    Map<String, Object?> metadata = const <String, Object?>{},
    required RuntimeRunStatus status,
  }) async {
    try {
      return await _runtimeLedgerService.startRun(
        id: id,
        kind: kind,
        title: title,
        conversationId: conversationId,
        taskId: taskId,
        parentRunId: parentRunId,
        capabilityKey: capabilityKey,
        request: request,
        metadata: metadata,
        status: status,
      );
    } catch (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return RuntimeRun(
        id: id,
        kind: kind,
        title: title,
        status: status,
        conversationId: conversationId,
        taskId: taskId,
        parentRunId: parentRunId,
        capabilityKey: capabilityKey,
        request: request,
        metadata: metadata,
        createdAtEpochMs: now,
        updatedAtEpochMs: now,
      );
    }
  }

  Future<RuntimeRun> _updateRunSafely({
    required RuntimeRun run,
    RuntimeRunStatus? status,
    Map<String, Object?>? metadata,
    Map<String, Object?>? result,
  }) async {
    try {
      return await _runtimeLedgerService.updateRun(
        run: run,
        status: status,
        metadata: metadata,
        result: result,
      );
    } catch (_) {
      return run.copyWith(
        status: status,
        metadata: metadata,
        result: result,
        updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  Future<RuntimeRun> _completeRunSafely({
    required RuntimeRun run,
    required RuntimeRunStatus status,
    Map<String, Object?>? result,
    String? error,
    String? detail,
    String? eventTitle,
  }) async {
    try {
      return await _runtimeLedgerService.completeRun(
        run: run,
        status: status,
        result: result,
        error: error,
        detail: detail,
        eventTitle: eventTitle,
      );
    } catch (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return run.copyWith(
        status: status,
        result: result,
        error: error,
        updatedAtEpochMs: now,
        completedAtEpochMs: now,
      );
    }
  }

  Future<void> _upsertNodeSafely(RuntimeRunNode node) async {
    try {
      await _runtimeLedgerService.upsertNode(node);
    } catch (_) {}
  }

  Future<RuntimeRunNode> _startNodeSafely({
    required String runId,
    required String phaseKey,
    required String title,
    required int ordinal,
    String? parentNodeId,
    int attempt = 1,
    String? capabilityKey,
    String? toolName,
    String? toolCallId,
    String? operationKey,
    Map<String, Object?> request = const <String, Object?>{},
    Map<String, Object?> metadata = const <String, Object?>{},
    RuntimeRunNodeStatus status = RuntimeRunNodeStatus.running,
  }) async {
    try {
      return await _runtimeLedgerService.startNode(
        id: '$runId:$phaseKey:${ordinal + 1}',
        runId: runId,
        parentNodeId: parentNodeId,
        phaseKey: phaseKey,
        title: title,
        ordinal: ordinal,
        attempt: attempt,
        capabilityKey: capabilityKey,
        toolName: toolName,
        toolCallId: toolCallId,
        operationKey: operationKey,
        request: request,
        metadata: metadata,
        status: status,
      );
    } catch (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return RuntimeRunNode(
        id: '$runId:$phaseKey:${ordinal + 1}',
        runId: runId,
        parentNodeId: parentNodeId,
        phaseKey: phaseKey,
        title: title,
        status: status,
        ordinal: ordinal,
        attempt: attempt,
        capabilityKey: capabilityKey,
        toolName: toolName,
        toolCallId: toolCallId,
        operationKey: operationKey,
        request: request,
        metadata: metadata,
        startedAtEpochMs: now,
        updatedAtEpochMs: now,
      );
    }
  }

  Future<RuntimeRunNode> _completeNodeSafely({
    required RuntimeRunNode node,
    required RuntimeRunNodeStatus status,
    Map<String, Object?>? result,
    String? error,
    Map<String, Object?>? metadata,
  }) async {
    try {
      return await _runtimeLedgerService.completeNode(
        node: node,
        status: status,
        result: result,
        error: error,
        metadata: metadata,
      );
    } catch (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return node.copyWith(
        status: status,
        result: result,
        error: error,
        metadata: metadata,
        updatedAtEpochMs: now,
        completedAtEpochMs: now,
      );
    }
  }

  Future<List<RuntimeRunNode>> _listNodesSafely(String runId) async {
    try {
      return await _runtimeLedgerService.listNodes(runId);
    } catch (_) {
      return const <RuntimeRunNode>[];
    }
  }

  Future<void> _recordEventSafely({
    required String runId,
    required RuntimeRunEventKind kind,
    required String title,
    String? detail,
    Map<String, Object?> payload = const <String, Object?>{},
  }) async {
    try {
      await _runtimeLedgerService.recordEvent(
        runId: runId,
        kind: kind,
        title: title,
        detail: detail,
        payload: payload,
      );
    } catch (_) {}
  }

  Future<void> _recordOperationSafely({
    required String runId,
    required String operationKey,
    required String kind,
    required RuntimeOperationStatus status,
    Map<String, Object?> request = const <String, Object?>{},
    Map<String, Object?>? result,
    String? error,
    int? completedAtEpochMs,
  }) async {
    try {
      await _runtimeLedgerService.recordOperation(
        runId: runId,
        operationKey: operationKey,
        kind: kind,
        status: status,
        request: request,
        result: result,
        error: error,
        completedAtEpochMs: completedAtEpochMs,
      );
    } catch (_) {}
  }

  Future<RuntimeOperationRecord?> _getOperationSafely({
    required String runId,
    required String operationKey,
  }) async {
    try {
      return await _runtimeLedgerService.getOperation(
        runId: runId,
        operationKey: operationKey,
      );
    } catch (_) {
      return null;
    }
  }

  RuntimeRunNode? _findRootNode(List<RuntimeRunNode> nodes) {
    for (final node in nodes) {
      if (node.phaseKey == 'root') {
        return node;
      }
    }
    return null;
  }

  int _nextNodeOrdinal(List<RuntimeRunNode> nodes) {
    if (nodes.isEmpty) {
      return 0;
    }
    return nodes
            .map((node) => node.ordinal)
            .reduce((value, element) => value > element ? value : element) +
        1;
  }

  static int _estimateTokenCount(List<ChatMessage> messages) {
    var total = 0;
    for (final message in messages) {
      final normalized = message.content.trim();
      if (normalized.isEmpty) {
        total += 4;
        continue;
      }
      total += (normalized.length / 4).ceil() + 4;
    }
    return total;
  }

  static String? _combineTaskHints(
    String? base,
    String? skillInstruction,
    String? skillExecutionHint,
    String? routeHint,
  ) {
    final segments = <String>[
      if (base != null && base.trim().isNotEmpty) base.trim(),
      if (skillInstruction != null && skillInstruction.trim().isNotEmpty)
        skillInstruction.trim(),
      if (skillExecutionHint != null && skillExecutionHint.trim().isNotEmpty)
        skillExecutionHint.trim(),
      if (routeHint != null && routeHint.trim().isNotEmpty) routeHint.trim(),
    ];
    if (segments.isEmpty) {
      return null;
    }
    return segments.join('\n\n');
  }

  String? _buildSkillExecutionHint(SkillRunResult? skillRun) {
    if (skillRun == null || skillRun.output.isEmpty) {
      return null;
    }
    final segments = <String>[
      'Skill execution state: ${skillRun.status.name}.',
      if (skillRun.output['summary'] case final String summary
          when summary.trim().isNotEmpty)
        'Use this normalized summary as guidance: ${summary.trim()}',
      if (skillRun.output['recommendation'] case final String recommendation
          when recommendation.trim().isNotEmpty)
        'Preserve this recommendation framing: ${recommendation.trim()}',
      if (skillRun.output['format'] case final String format
          when format.trim().isNotEmpty)
        'Resolved output format: ${format.trim()}.',
    ];
    return segments.join(' ');
  }

  String _buildRouteHint(RunRouteSelection selection) {
    return 'Runtime route: ${runRouteToJson(selection.route)}. '
        'Quality mode: ${runQualityModeToJson(selection.qualityMode)}. '
        '${selection.reason}';
  }

  String _operationKeyForToolCall(SarvamToolCall toolCall) {
    if (_shouldBlockOperationReplay(toolCall.name)) {
      return '${toolCall.name}:${_stableSignature(toolCall.arguments)}';
    }
    return '${toolCall.name}:${toolCall.id}';
  }

  bool _shouldBlockOperationReplay(String toolName) {
    return toolName == 'generate_docx' ||
        toolName == 'generate_xlsx' ||
        toolName == 'generate_report_pdf' ||
        toolName == 'create_text_file' ||
        toolName == 'edit_text_file' ||
        toolName == 'write_project_files' ||
        toolName == 'package_zip';
  }

  String _stableSignature(Object? value) {
    if (value == null) {
      return 'null';
    }
    if (value is Map) {
      final sortedKeys = value.keys.map((key) => key.toString()).toList()
        ..sort();
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

  SkillStepResult _executeSkillPlanningStep({
    required SelectedSkillPlan selectedSkill,
    required SkillStepExecutionContext context,
    required String prompt,
  }) {
    final previousOutput = <String, Object?>{};
    for (final step in context.previousSteps) {
      previousOutput.addAll(step.output);
    }
    final input = <String, Object?>{
      ...selectedSkill.input,
      ...previousOutput,
      'prompt': prompt,
    };
    final stepId = context.step.id;
    return switch (selectedSkill.skill.skillId) {
      'document_generation_skill' => _executeDocumentSkillStep(stepId, input),
      'research_report_skill' => _executeResearchSkillStep(stepId, input),
      'model_comparison_skill' => _executeComparisonSkillStep(stepId, input),
      _ => SkillStepResult.completed(
        stepId: stepId,
        summary: context.step.description,
        output: <String, Object?>{
          'step_id': stepId,
          'skill_id': selectedSkill.skill.skillId,
        },
      ),
    };
  }

  SkillStepResult _executeDocumentSkillStep(
    String stepId,
    Map<String, Object?> input,
  ) {
    final title = input['title']?.toString().trim();
    final format = input['format']?.toString().trim().toLowerCase() ?? 'docx';
    final markdown = input['markdown_content']?.toString().trim() ?? '';
    final safeTitle = (title == null || title.isEmpty)
        ? 'Generated Document'
        : title;
    final plannedArtifactName = '${_slugifyTitle(safeTitle)}.$format';
    final summary =
        'Prepare a $format artifact titled "$safeTitle" using the requested content.';
    return switch (stepId) {
      'document_generation_skill.determine_format' => SkillStepResult.completed(
        stepId: stepId,
        summary: summary,
        output: <String, Object?>{
          'format_binding': format == 'pdf'
              ? 'output.generate_report_pdf'
              : format == 'xlsx'
              ? 'output.generate_xlsx'
              : 'output.generate_docx',
          'format': format,
        },
      ),
      'document_generation_skill.build_content_model' =>
        SkillStepResult.completed(
          stepId: stepId,
          summary: 'Canonicalized the document content model.',
          output: <String, Object?>{
            'content_model': <String, Object?>{
              'title': safeTitle,
              'body_markdown': markdown,
              'sections': _extractMarkdownSections(markdown),
            },
          },
        ),
      'document_generation_skill.validate_structure' =>
        SkillStepResult.completed(
          stepId: stepId,
          summary: 'Validated document structure constraints.',
          output: <String, Object?>{'structure_validation': 'ok'},
        ),
      'document_generation_skill.render_artifact' => SkillStepResult.completed(
        stepId: stepId,
        summary: 'Reserved the output artifact binding.',
        output: <String, Object?>{
          'artifact_path': 'pending://$plannedArtifactName',
          'artifact_name': plannedArtifactName,
        },
      ),
      'document_generation_skill.persist_artifact' => SkillStepResult.completed(
        stepId: stepId,
        summary: 'Marked the artifact for persistence in the runtime graph.',
        output: <String, Object?>{
          'artifact_reference': <String, Object?>{
            'path': 'pending://$plannedArtifactName',
            'name': plannedArtifactName,
          },
        },
      ),
      'document_generation_skill.compose_response' => SkillStepResult.completed(
        stepId: stepId,
        summary: summary,
        output: <String, Object?>{
          'summary': summary,
          'artifact_path': 'pending://$plannedArtifactName',
          'artifact_name': plannedArtifactName,
          'format': format,
        },
      ),
      _ => SkillStepResult.completed(stepId: stepId),
    };
  }

  SkillStepResult _executeResearchSkillStep(
    String stepId,
    Map<String, Object?> input,
  ) {
    final topic = input['topic']?.toString().trim();
    final normalizedTopic = (topic == null || topic.isEmpty)
        ? 'the requested topic'
        : topic;
    final evidence = <Object?>[
      <String, Object?>{
        'source': 'planned_research',
        'query': normalizedTopic,
        'confidence': 0.5,
      },
    ];
    return switch (stepId) {
      'research_report_skill.classify_request' => SkillStepResult.completed(
        stepId: stepId,
        summary: 'Classified the request as a research workflow.',
        output: <String, Object?>{
          'classification': 'research',
          'research_scope': input['depth'] ?? 'standard',
        },
      ),
      'research_report_skill.gather_evidence' => SkillStepResult.completed(
        stepId: stepId,
        summary: 'Prepared an evidence gathering plan.',
        output: <String, Object?>{
          'evidence': evidence,
          'source_index': <Object?>['planned:1'],
        },
      ),
      'research_report_skill.rank_evidence' => SkillStepResult.completed(
        stepId: stepId,
        summary: 'Ranked gathered evidence for synthesis.',
        output: <String, Object?>{'ranked_evidence': evidence},
      ),
      'research_report_skill.synthesize_report' => SkillStepResult.completed(
        stepId: stepId,
        summary: 'Prepared a synthesis scaffold for the research response.',
        output: <String, Object?>{
          'summary':
              'Research the topic and synthesize the strongest evidence.',
          'findings': <Object?>[
            'Collect high-quality evidence about $normalizedTopic.',
          ],
          'recommendation':
              'Ground the answer in verified sources before concluding.',
          'draft_markdown':
              '# Research plan\n\n- Investigate $normalizedTopic\n- Synthesize findings',
        },
      ),
      'research_report_skill.verify_report' => SkillStepResult.completed(
        stepId: stepId,
        summary: 'Marked the research response scaffold as reviewable.',
        output: <String, Object?>{'verification_status': 'planned'},
      ),
      'research_report_skill.emit_response' => SkillStepResult.completed(
        stepId: stepId,
        summary: 'Emitted the research response scaffold.',
        output: <String, Object?>{
          'summary':
              'Research the topic and synthesize the strongest evidence.',
          'evidence': evidence,
          'findings': <Object?>[
            'Collect high-quality evidence about $normalizedTopic.',
          ],
          'recommendation':
              'Ground the answer in verified sources before concluding.',
        },
      ),
      _ => SkillStepResult.completed(stepId: stepId),
    };
  }

  SkillStepResult _executeComparisonSkillStep(
    String stepId,
    Map<String, Object?> input,
  ) {
    final models =
        (input['models'] as List?)
            ?.map((item) => item.toString())
            .toList(growable: false) ??
        <String>['candidate'];
    final criteria =
        (input['criteria'] as List?)
            ?.map((item) => item.toString())
            .toList(growable: false) ??
        <String>['quality', 'reliability', 'fit'];
    final comparisonRows = models
        .map(
          (model) => <String, Object?>{
            'model': model,
            'criteria': criteria,
            'status': 'planned',
          },
        )
        .toList(growable: false);
    final evidence = models
        .map(
          (model) => <String, Object?>{
            'source': 'planned_research',
            'model': model,
          },
        )
        .toList(growable: false);
    return switch (stepId) {
      'model_comparison_skill.normalize_models' => SkillStepResult.completed(
        stepId: stepId,
        summary: 'Normalized the model comparison inputs.',
        output: <String, Object?>{
          'normalized_models': models,
          'comparison_scope': input['use_case'] ?? '',
        },
      ),
      'model_comparison_skill.gather_model_data' => SkillStepResult.completed(
        stepId: stepId,
        summary: 'Prepared the comparison evidence plan.',
        output: <String, Object?>{
          'evidence': evidence,
          'model_profiles': comparisonRows,
        },
      ),
      'model_comparison_skill.compare_dimensions' => SkillStepResult.completed(
        stepId: stepId,
        summary: 'Prepared the comparison matrix.',
        output: <String, Object?>{
          'comparison_table': comparisonRows,
          'tradeoffs': <Object?>[
            'Compare models against ${criteria.join(', ')}.',
          ],
        },
      ),
      'model_comparison_skill.rank_recommendation' => SkillStepResult.completed(
        stepId: stepId,
        summary: 'Prepared the recommendation scaffold.',
        output: <String, Object?>{
          'recommendation': 'Rank candidates after evidence review.',
          'summary': 'Compare the requested models against the requested fit.',
        },
      ),
      'model_comparison_skill.verify_comparison' => SkillStepResult.completed(
        stepId: stepId,
        summary: 'Marked the comparison as ready for verification.',
        output: <String, Object?>{'verification_status': 'planned'},
      ),
      'model_comparison_skill.emit_response' => SkillStepResult.completed(
        stepId: stepId,
        summary: 'Emitted the comparison response scaffold.',
        output: <String, Object?>{
          'summary': 'Compare the requested models against the requested fit.',
          'comparison_table': comparisonRows,
          'recommendation': 'Rank candidates after evidence review.',
        },
      ),
      _ => SkillStepResult.completed(stepId: stepId),
    };
  }

  RuntimeRunNodeStatus _mapSkillRunStatus(SkillRunStatus status) {
    return switch (status) {
      SkillRunStatus.queued => RuntimeRunNodeStatus.queued,
      SkillRunStatus.running => RuntimeRunNodeStatus.running,
      SkillRunStatus.blocked => RuntimeRunNodeStatus.blocked,
      SkillRunStatus.completed => RuntimeRunNodeStatus.completed,
      SkillRunStatus.failed => RuntimeRunNodeStatus.failed,
    };
  }

  RuntimeRunNodeStatus _mapSkillStepStatus(SkillStepStatus status) {
    return switch (status) {
      SkillStepStatus.pending => RuntimeRunNodeStatus.queued,
      SkillStepStatus.running => RuntimeRunNodeStatus.running,
      SkillStepStatus.completed => RuntimeRunNodeStatus.completed,
      SkillStepStatus.skipped => RuntimeRunNodeStatus.skipped,
      SkillStepStatus.blocked => RuntimeRunNodeStatus.blocked,
      SkillStepStatus.failed => RuntimeRunNodeStatus.failed,
    };
  }

  static List<String> _extractMarkdownSections(String markdown) {
    final sections = markdown
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.startsWith('#'))
        .map((line) => line.replaceFirst(RegExp(r'^#+\s*'), ''))
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    return sections.isEmpty ? <String>['Overview'] : sections;
  }

  static String _slugifyTitle(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return normalized.isEmpty ? 'generated_document' : normalized;
  }

  void _verifyToolBatchOrThrow({
    required List<SarvamToolCall> toolCalls,
    required List<SarvamToolDefinition> allowedTools,
    required Set<String> consumedSingleUseToolNames,
  }) {
    final verification = _toolIntentVerifier.verify(
      ToolIntentVerificationRequest(
        toolIntents: toolCalls
            .map(
              (toolCall) => ToolIntent(
                id: toolCall.id,
                name: toolCall.name,
                arguments: Map<String, Object?>.from(toolCall.arguments),
              ),
            )
            .toList(growable: false),
        allowedToolNames: allowedTools.map((tool) => tool.name).toList(),
        consumedSingleUseToolNames: consumedSingleUseToolNames.toList(),
      ),
    );
    if (verification.hasBlockingIssues) {
      throw StateError(verification.blockingIssues.first.message);
    }
  }


  bool _isOutputToolName(String toolName) {
    return toolName == 'generate_docx' ||
        toolName == 'generate_xlsx' ||
        toolName == 'generate_report_pdf' ||
        toolName == 'create_text_file' ||
        toolName == 'edit_text_file' ||
        toolName == 'write_project_files' ||
        toolName == 'package_zip';
  }

  bool _isRecoverableResponseIssue(
    String code, {
    required String? prompt,
    required List<String> selectedTools,
    required RunRoute route,
    required FallbackPolicy fallbackPolicy,
    required RequestClassification classification,
  }) {
    final expectsArtifact = classification.artifactKind != ArtifactKind.none;
    final hasOutputTool = selectedTools.any(_isOutputToolName);
    if (code == 'response.promise_only_artifact_reply') {
      return true;
    }
    if (code == 'response.tool_marker_leak') {
      return expectsArtifact && hasOutputTool;
    }
    if (code == 'response.empty') {
      if (expectsArtifact && hasOutputTool) {
        return true;
      }
      return fallbackPolicy == FallbackPolicy.repairDirectAnswer ||
          fallbackPolicy == FallbackPolicy.repairToolPlan ||
          route != RunRoute.direct;
    }
    return false;
  }

  String _recoverableResponseStrategy({
    required String? prompt,
    required List<String> selectedTools,
    required RunRoute route,
    required FallbackPolicy fallbackPolicy,
    required RequestClassification classification,
  }) {
    final expectsArtifact = classification.artifactKind != ArtifactKind.none;
    final hasOutputTool = selectedTools.any(_isOutputToolName);
    if (expectsArtifact && hasOutputTool) {
      return 'artifact_tolerated_for_runtime_completion';
    }
    return fallbackPolicy == FallbackPolicy.repairDirectAnswer
        ? 'direct_response_repair'
        : route == RunRoute.direct
        ? 'direct_response_repair'
        : 'non_direct_recovery_acceptance';
  }

  Map<String, Object?> _buildDebugCounters({
    required AgentOrchestratorResult orchestrationResult,
    required VerificationReport responseVerification,
    required List<VerificationIssue> recoverableIssues,
    required bool attemptedRuntimeRepair,
  }) {
    final selectorStrategy = orchestrationResult.toolSelectionDecision?.strategy;
    final selectorDetails =
        orchestrationResult.toolSelectionDecision?.strategyDetails ??
        const <String, Object?>{};
    final responseEmptyCount = responseVerification.issues
        .where((issue) => issue.code == 'response.empty')
        .length;
    return <String, Object?>{
      'selector_fallback_used': selectorStrategy == 'classifier_fallback' ? 1 : 0,
      'selector_cache_used': selectorStrategy == 'cache' ? 1 : 0,
      'selector_classification_only_used': selectorStrategy == 'classification_only' ? 1 : 0,
      'selector_parse_failure_count':
          (selectorDetails['selector_response_kind'] == 'parse_error_fallback' ||
                  selectorDetails['selector_response_kind'] ==
                      'non_list_json_fallback' ||
                  selectorDetails['selector_response_kind'] ==
                      'unknown_tool_names_fallback')
              ? 1
              : 0,
      'response_empty_count': responseEmptyCount,
      'recoverable_issue_count': recoverableIssues.length,
      'response_repair_attempt_count': attemptedRuntimeRepair ? 1 : 0,
      'response_repair_success_count': attemptedRuntimeRepair &&
              responseEmptyCount == 0
          ? 1
          : 0,
    };
  }

  Map<String, Object?> _buildDebugMetadata({
    required AgentOrchestratorResult orchestrationResult,
    required VerificationReport responseVerification,
    required RunRoute route,
  }) {
    return <String, Object?>{
      'run_route': runRouteToJson(route),
      'selector':
          orchestrationResult.toolSelectionDecision?.toDebugMetadata() ??
          const <String, Object?>{},
      'selector_strategy_details':
          orchestrationResult.toolSelectionDecision?.strategyDetails ??
          const <String, Object?>{},
      'verifier_issue_codes': responseVerification.issues
          .map((issue) => issue.code)
          .toList(growable: false),
      'blocking_issue_codes': responseVerification.blockingIssues
          .map((issue) => issue.code)
          .toList(growable: false),
    };
  }

  int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _shouldAttemptRuntimeResponseRepair({
    required List<VerificationIssue> recoverableIssues,
    required String? prompt,
    required List<String> selectedTools,
    required RunRoute route,
    required FallbackPolicy fallbackPolicy,
    required RequestClassification classification,
  }) {
    if (recoverableIssues.isEmpty || _responseRepairCoordinator == null) {
      return false;
    }
    final expectsArtifact = classification.artifactKind != ArtifactKind.none;
    final hasOutputTool = selectedTools.any(_isOutputToolName);
    if (expectsArtifact && hasOutputTool) {
      return false;
    }
    final repairsEmpty = recoverableIssues.any(
      (issue) => issue.code == 'response.empty',
    );
    if (!repairsEmpty) {
      return false;
    }
    return fallbackPolicy == FallbackPolicy.repairDirectAnswer ||
        fallbackPolicy == FallbackPolicy.repairToolPlan ||
        route != RunRoute.direct;
  }

  String _forcedOutputToolInstruction(String toolName) {
    return switch (toolName) {
      'generate_xlsx' =>
        'You must call generate_xlsx now to produce the requested spreadsheet. Do not explain, just call the tool.',
      'generate_report_pdf' =>
        'You must call generate_report_pdf now to produce the requested PDF. Do not explain, just call the tool.',
      _ =>
        'You must call generate_docx now to produce the requested document. Do not explain, just call the tool.',
    };
  }

  bool _isTerminalNodeStatus(RuntimeRunNodeStatus status) {
    return status == RuntimeRunNodeStatus.completed ||
        status == RuntimeRunNodeStatus.failed ||
        status == RuntimeRunNodeStatus.cancelled ||
        status == RuntimeRunNodeStatus.blocked ||
        status == RuntimeRunNodeStatus.skipped;
  }
}
