import 'dart:async';

import '../../runtime/domain/agent_policy.dart';
import '../../settings/app_settings.dart';
import '../domain/chat_message.dart';
import 'context_engine.dart';
import 'prompt_variants.dart';
import 'response_guard.dart';
import 'sarvam_api_client.dart';
import 'tool_dispatcher.dart';
import 'tool_selector.dart';
import 'web_tools.dart';

typedef AssistantRoundExecutor =
    Future<SarvamChatResult> Function({
      required List<ChatMessage> requestMessages,
      required List<SarvamToolDefinition> tools,
      required StringBuffer responseBuffer,
    });

typedef AutoContinueDecider =
    bool Function({
      required String prompt,
      required SarvamChatResult result,
      required String accumulatedResponse,
      required int roundsUsed,
      bool expectsArtifact,
      bool artifactProduced,
    });

class AgentOrchestratorTurn {
  const AgentOrchestratorTurn({
    required this.selectedTools,
    required this.contextAssembly,
    required this.requestMessages,
    required this.activeToolDefinitions,
    this.toolSelectionDecision,
  });

  final List<String> selectedTools;
  final ContextEngineResult contextAssembly;
  final List<ChatMessage> requestMessages;
  final List<SarvamToolDefinition> activeToolDefinitions;
  final ToolSelectionDecision? toolSelectionDecision;
}

class AgentOrchestratorResult {
  const AgentOrchestratorResult({
    required this.finalRound,
    required this.validatedResponse,
    required this.requestMessages,
    required this.selectedTools,
    required this.contextAssembly,
    this.toolSelectionDecision,
    this.artifactProduced = false,
    this.stopReason,
  });

  final SarvamChatResult finalRound;
  final ValidatedResponse validatedResponse;
  final List<ChatMessage> requestMessages;
  final List<String> selectedTools;
  final ContextEngineResult contextAssembly;
  final ToolSelectionDecision? toolSelectionDecision;
  final bool artifactProduced;

  /// Set when the run was cut short by its [RunBudget] rather than finishing.
  ///
  /// The partial answer is still returned, so the user sees everything the
  /// agent managed to produce before the limit hit.
  final String? stopReason;

  bool get budgetExhausted => stopReason != null;
}

class AgentOrchestratorHooks {
  const AgentOrchestratorHooks({
    this.onPrepared,
    this.onThought,
    this.onToolBatchStarting,
    this.onToolBatchCompleted,
    this.onAutoContinue,
    this.onRequestMessagesMutated,
  });

  final FutureOr<void> Function(AgentOrchestratorTurn turn)? onPrepared;
  final FutureOr<void> Function(String thought)? onThought;
  final FutureOr<void> Function(List<SarvamToolCall> toolCalls)?
  onToolBatchStarting;
  final FutureOr<void> Function(List<ToolDispatchResult> results)?
  onToolBatchCompleted;
  final FutureOr<void> Function()? onAutoContinue;
  final FutureOr<void> Function(List<ChatMessage> requestMessages)?
  onRequestMessagesMutated;
}

class AgentOrchestrator {
  AgentOrchestrator({
    required ToolSelector toolSelector,
    required ContextEngine contextEngine,
    required PromptVariantSelector promptVariantSelector,
    required ToolDispatcher toolDispatcher,
    required ResponseGuard responseGuard,
  }) : _toolSelector = toolSelector,
       _contextEngine = contextEngine,
       _promptVariantSelector = promptVariantSelector,
       _toolDispatcher = toolDispatcher,
       _responseGuard = responseGuard;

  final ToolSelector _toolSelector;
  final ContextEngine _contextEngine;
  final PromptVariantSelector _promptVariantSelector;
  final ToolDispatcher _toolDispatcher;
  final ResponseGuard _responseGuard;

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
  }) async {
    final recentMessages = modelHistory.reversed.take(2).toList(growable: false);
    final toolSelectionDecisionFuture = _toolSelector.selectDecision(
      apiKey: apiKey,
      prompt: prompt,
      recentMessages: recentMessages,
    );
    final contextAssemblyFuture = _contextEngine.assemble(
      conversationId: conversationId,
      taskId: taskId,
      history: modelHistory,
      systemPrompt: '',
      outputToolsPrompt: outputToolsPrompt,
      taskHint: taskHint,
    );
    final toolSelectionDecision = await toolSelectionDecisionFuture;
    final selectedTools = toolSelectionDecision.selectedTools;
    final systemPrompt = _promptVariantSelector.select(selectedTools);
    final assembledContext = await contextAssemblyFuture;
    final requestMessages = _withSystemPrompt(
      assembledContext.messages,
      systemPrompt,
    ).toList(growable: true);
    final contextAssembly = ContextEngineResult(
      messages: List<ChatMessage>.unmodifiable(requestMessages),
      workingMemory: assembledContext.workingMemory,
      episodicMemories: assembledContext.episodicMemories,
      semanticFacts: assembledContext.semanticFacts,
      artifactReferences: assembledContext.artifactReferences,
    );
    var activeToolDefinitions = _toolDefinitionsFor(
      allToolDefinitions,
      selectedTools,
    );
    await Future<void>.value(hooks.onPrepared?.call(
      AgentOrchestratorTurn(
        selectedTools: selectedTools,
        contextAssembly: contextAssembly,
        requestMessages: List<ChatMessage>.unmodifiable(requestMessages),
        activeToolDefinitions: activeToolDefinitions,
        toolSelectionDecision: toolSelectionDecision,
      ),
    ));

    var autoContinuationRounds = 0;
    var forcedDirectAnswerRounds = 0;
    final responseBuffer = StringBuffer();
    final toolBatchCounts = <String, int>{};
    var hadToolResults = false;
    var artifactProduced = false;
    var iterations = 0;
    var toolCallCount = 0;
    SarvamChatResult? lastCompletedRound;
    final runStartedAt = DateTime.now();

    while (true) {
      iterations += 1;
      // Check the budget before spending another model call. A budget can only
      // be exhausted once at least one round has completed, so `finalRound` is
      // always available on this path.
      final previousRound = lastCompletedRound;
      if (previousRound != null) {
        final budgetStopReason = _budgetStopReason(
          iterations: iterations,
          toolCalls: toolCallCount,
          elapsedMs: DateTime.now().difference(runStartedAt).inMilliseconds,
          budget: budget,
        );
        if (budgetStopReason != null) {
          final partial = responseBuffer.toString().trim().isNotEmpty
              ? responseBuffer.toString()
              : previousRound.content;
          return AgentOrchestratorResult(
            finalRound: previousRound,
            validatedResponse: _responseGuard.validate(partial),
            requestMessages: List<ChatMessage>.unmodifiable(requestMessages),
            selectedTools: selectedTools,
            contextAssembly: contextAssembly,
            toolSelectionDecision: toolSelectionDecision,
            artifactProduced: artifactProduced,
            stopReason: budgetStopReason,
          );
        }
      }
      final result = await executeAssistantRound(
        requestMessages: requestMessages,
        tools: activeToolDefinitions,
        responseBuffer: responseBuffer,
      );
      lastCompletedRound = result;
      if (result.reasoningContent != null && result.reasoningContent!.isNotEmpty) {
        await Future<void>.value(hooks.onThought?.call(result.reasoningContent!));
      }

      if (result.toolCalls.isNotEmpty) {
        final allowedToolNames = activeToolDefinitions
            .map((tool) => tool.name)
            .toSet();
        final executableToolCalls = result.toolCalls
            .where((toolCall) => allowedToolNames.contains(toolCall.name))
            .toList(growable: false);
        if (executableToolCalls.isEmpty) {
          requestMessages.add(
            ChatMessage(
              id: 'tool_rejection_${requestMessages.length}',
              role: ChatRole.system,
              content:
                  'Do not call any more tools for this request. Use the existing tool outputs and answer the user directly.',
            ),
          );
          await Future<void>.value(hooks.onRequestMessagesMutated?.call(
            List<ChatMessage>.unmodifiable(requestMessages),
          ));
          continue;
        }
        final batchSignature = _toolBatchSignature(executableToolCalls);
        final nextCount = (toolBatchCounts[batchSignature] ?? 0) + 1;
        toolBatchCounts[batchSignature] = nextCount;
        if (nextCount >= 3) {
          throw StateError(
            'Model is repeating the same tool calls without making progress.',
          );
        }

        await Future<void>.value(
          hooks.onToolBatchStarting?.call(executableToolCalls),
        );
        if (result.content.trim().isNotEmpty) {
          requestMessages.add(
            ChatMessage(
              id: 'assistant_tool_context_${requestMessages.length}',
              role: ChatRole.assistant,
              content: result.content.trim(),
            ),
          );
        }
        toolCallCount += executableToolCalls.length;
        final dispatchResults = await _toolDispatcher.dispatch(
          executableToolCalls,
          executor: executeToolCall,
        );
        hadToolResults = hadToolResults || dispatchResults.isNotEmpty;
        artifactProduced = artifactProduced ||
            dispatchResults.any((r) => _isOutputToolName(r.call.name));
        final consumedSingleUseTools = dispatchResults
            .map((dispatchResult) => dispatchResult.call.name)
            .where(_isSingleUseTool)
            .toSet();
        for (final dispatchResult in dispatchResults) {
          requestMessages.add(
            ChatMessage(
              id: 'tool_result_${requestMessages.length}',
              role: ChatRole.system,
              content: dispatchResult.compactSummary,
            ),
          );
        }
        if (consumedSingleUseTools.isNotEmpty) {
          activeToolDefinitions = activeToolDefinitions
              .where((tool) => !consumedSingleUseTools.contains(tool.name))
              .toList(growable: false);
          final consumedOutputTools = consumedSingleUseTools
              .where(_isSingleUseTool)
              .toList(growable: false);
          if (consumedOutputTools.isNotEmpty) {
            requestMessages.add(
              ChatMessage(
                id: 'single_use_tool_guard_${requestMessages.length}',
                role: ChatRole.system,
                content:
                    'An output file tool (${consumedOutputTools.join(", ")}) has already been used for this request. '
                    'Do not call the same output tool again. Use the created artifact or the fallback content already returned by the tool, then answer the user directly.',
              ),
            );
          }
        }
        requestMessages.add(
          const ChatMessage(
            id: 'tool_follow_up',
            role: ChatRole.system,
            content:
                'The tool results are now available. Answer the user directly using those results. '
                'Do not output tool placeholders, tool status messages, or internal execution notes.',
          ),
        );
        if (nextCount >= 2) {
          requestMessages.add(
            ChatMessage(
              id: 'tool_repeat_guard_${requestMessages.length}',
              role: ChatRole.system,
              content:
                  'You are repeating the same tool-call pattern. Do not call the same tools again unless there is clearly new information to fetch. Use the existing tool results and answer directly.',
            ),
          );
        }
        await Future<void>.value(hooks.onToolBatchCompleted?.call(dispatchResults));
        await Future<void>.value(hooks.onRequestMessagesMutated?.call(
          List<ChatMessage>.unmodifiable(requestMessages),
        ));
        continue;
      }

      final roundContent = result.content.trim();
      final accumulatedResponse = responseBuffer.toString().trim();

      if (hadToolResults &&
          roundContent.isEmpty &&
          accumulatedResponse.isEmpty &&
          forcedDirectAnswerRounds < 2) {
        forcedDirectAnswerRounds += 1;
        requestMessages.add(
          ChatMessage(
            id: 'force_direct_answer_${requestMessages.length}',
            role: ChatRole.system,
            content:
                'You have already received the tool results. Answer the user now in plain language using those results. '
                'Do not call tools again. Do not describe what you plan to do. Emit the final answer directly.',
          ),
        );
        await Future<void>.value(hooks.onRequestMessagesMutated?.call(
          List<ChatMessage>.unmodifiable(requestMessages),
        ));
        continue;
      }

      if (shouldAutoContinue(
        prompt: prompt,
        result: result,
        accumulatedResponse: responseBuffer.toString(),
        roundsUsed: autoContinuationRounds,
        expectsArtifact: toolSelectionDecision.expectsArtifact,
        artifactProduced: artifactProduced,
      )) {
        autoContinuationRounds += 1;
        requestMessages.add(
          ChatMessage(
            id: 'continuation_context_${requestMessages.length}',
            role: ChatRole.assistant,
            content: responseBuffer.toString(),
          ),
        );
        requestMessages.add(
          ChatMessage(
            id: 'continuation_prompt_${requestMessages.length}',
            role: ChatRole.system,
            content:
                'Continue exactly from where you stopped. Do not restart, do not repeat headings or prior text, and finish the same response in the same format. If you are inside a [[NERO_BLOCK:...]] section or fenced artifact block, continue inside that same block and close it correctly before moving on.',
          ),
        );
        await Future<void>.value(hooks.onAutoContinue?.call());
        await Future<void>.value(hooks.onRequestMessagesMutated?.call(
          List<ChatMessage>.unmodifiable(requestMessages),
        ));
        continue;
      }

      final validatedContent = responseBuffer.toString().trim().isNotEmpty
          ? responseBuffer.toString()
          : result.content;
      return AgentOrchestratorResult(
        finalRound: result,
        validatedResponse: _responseGuard.validate(validatedContent),
        requestMessages: List<ChatMessage>.unmodifiable(requestMessages),
        selectedTools: selectedTools,
        contextAssembly: contextAssembly,
        toolSelectionDecision: toolSelectionDecision,
      );
    }
  }

  /// Returns a human-readable reason when [budget] is spent, else null.
  String? _budgetStopReason({
    required int iterations,
    required int toolCalls,
    required int elapsedMs,
    required RunBudget budget,
  }) {
    if (iterations > budget.maxIterations) {
      return 'Stopped after ${budget.maxIterations} model rounds because the run '
          'budget was reached. Raise it in Settings › Agent to keep going.';
    }
    if (toolCalls > budget.maxToolCalls) {
      return 'Stopped after ${budget.maxToolCalls} tool calls because the run '
          'budget was reached. Raise it in Settings › Agent to keep going.';
    }
    if (elapsedMs > budget.maxWallClockMs) {
      return 'Stopped after ${budget.maxWallClockMs ~/ 1000}s because the run '
          'time limit was reached. Raise it in Settings › Agent to keep going.';
    }
    return null;
  }

  List<SarvamToolDefinition> _toolDefinitionsFor(
    List<SarvamToolDefinition> allDefinitions,
    List<String> selectedTools,
  ) {
    if (selectedTools.isEmpty) {
      return const <SarvamToolDefinition>[];
    }
    final selected = selectedTools.toSet();
    return allDefinitions
        .where((tool) => selected.contains(tool.name))
        .toList(growable: false);
  }

  String _toolBatchSignature(List<SarvamToolCall> toolCalls) {
    final parts = toolCalls
        .map(
          (toolCall) =>
              '${toolCall.name}:${_stableMapString(toolCall.arguments)}',
        )
        .toList(growable: false)
      ..sort();
    return parts.join('|');
  }

  String _stableMapString(Map<String, dynamic> value) {
    final keys = value.keys.toList(growable: false)..sort();
    final pairs = <String>[];
    for (final key in keys) {
      pairs.add('$key=${value[key]}');
    }
    return pairs.join(',');
  }

  bool _isSingleUseTool(String toolName) {
    return _isOutputToolName(toolName);
  }

  bool _isOutputToolName(String toolName) {
    return toolName == 'generate_docx' ||
        toolName == 'generate_xlsx' ||
        toolName == 'generate_report_pdf';
  }

  List<ChatMessage> _withSystemPrompt(
    List<ChatMessage> messages,
    String systemPrompt,
  ) {
    return messages.map((message) {
      if (message.id != 'system_variant') {
        return message;
      }
      return message.copyWith(content: systemPrompt);
    }).toList(growable: false);
  }
}
