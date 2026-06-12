import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/agent_orchestrator.dart';
import 'package:nero/features/chat/application/context_engine.dart';
import 'package:nero/features/chat/application/prompt_variants.dart';
import 'package:nero/features/chat/application/response_guard.dart';
import 'package:nero/features/chat/application/sarvam_api_client.dart';
import 'package:nero/features/chat/application/tool_dispatcher.dart';
import 'package:nero/features/chat/application/tool_selector.dart';
import 'package:nero/features/chat/application/web_tools.dart';
import 'package:nero/features/chat/domain/chat_message.dart';
import 'package:nero/features/settings/app_settings.dart';

void main() {
  test('run starts context assembly in parallel with tool selection', () async {
    final selectorStarted = Completer<void>();
    final selectorRelease = Completer<void>();
    final contextStarted = Completer<void>();
    final contextRelease = Completer<void>();

    final selector = _DelayedToolSelector(
      started: selectorStarted,
      release: selectorRelease,
      selectedTools: const <String>['search_web'],
    );
    final contextEngine = _DelayedContextEngine(
      started: contextStarted,
      release: contextRelease,
    );
    final promptVariantSelector = const PromptVariantSelector();
    final orchestrator = AgentOrchestrator(
      toolSelector: selector,
      contextEngine: contextEngine,
      promptVariantSelector: promptVariantSelector,
      toolDispatcher: ToolDispatcher(),
      responseGuard: const ResponseGuard(),
    );

    final runFuture = orchestrator.run(
      apiKey: 'sk_test',
      settings: const NeroSettings(
        sarvamApiKey: 'sk_test',
        selectedModelId: 'sarvam-30b',
      ),
      prompt: 'Find the latest docs',
      conversationId: 'conv',
      taskId: 'task_1',
      modelHistory: const <ChatMessage>[],
      allToolDefinitions: const <SarvamToolDefinition>[
        SarvamToolDefinition(
          name: 'search_web',
          description: 'Search',
          parameters: <String, dynamic>{},
        ),
      ],
      outputToolsPrompt: 'Output tools prompt',
      taskHint: null,
      executeAssistantRound: ({
        required List<ChatMessage> requestMessages,
        required List<SarvamToolDefinition> tools,
        required StringBuffer responseBuffer,
      }) async {
        return const SarvamChatResult(
          content: 'Grounded answer.',
          model: 'sarvam-30b',
        );
      },
      executeToolCall: (_) async => const ToolExecutionResult(
        success: true,
        summary: 'unused',
        formattedOutput: 'unused',
      ),
      shouldAutoContinue: ({
        required String prompt,
        required SarvamChatResult result,
        required String accumulatedResponse,
        required int roundsUsed,
        bool expectsArtifact = false,
        bool artifactProduced = false,
      }) {
        return false;
      },
    );

    await selectorStarted.future.timeout(const Duration(milliseconds: 200));
    await contextStarted.future.timeout(const Duration(milliseconds: 200));
    contextRelease.complete();
    selectorRelease.complete();

    final result = await runFuture;
    expect(result.selectedTools, const <String>['search_web']);
    expect(
      result.requestMessages.first.content,
      promptVariantSelector.select(const <String>['search_web']),
    );
  });

  test('generate_docx is not offered again after the first tool round', () async {
    final orchestrator = AgentOrchestrator(
      toolSelector: _FixedToolSelector(const <String>['generate_docx']),
      contextEngine: _ImmediateContextEngine(),
      promptVariantSelector: const PromptVariantSelector(),
      toolDispatcher: ToolDispatcher(),
      responseGuard: const ResponseGuard(),
    );

    var roundCount = 0;
    final toolsSeenPerRound = <List<String>>[];

    final result = await orchestrator.run(
      apiKey: 'sk_test',
      settings: const NeroSettings(
        sarvamApiKey: 'sk_test',
        selectedModelId: 'sarvam-30b',
      ),
      prompt: 'Generate a DOCX report',
      conversationId: 'conv',
      taskId: 'task_1',
      modelHistory: const <ChatMessage>[],
      allToolDefinitions: const <SarvamToolDefinition>[
        SarvamToolDefinition(
          name: 'generate_docx',
          description: 'Generate DOCX',
          parameters: <String, dynamic>{},
        ),
      ],
      outputToolsPrompt: 'Output tools prompt',
      taskHint: null,
      executeAssistantRound: ({
        required List<ChatMessage> requestMessages,
        required List<SarvamToolDefinition> tools,
        required StringBuffer responseBuffer,
      }) async {
        roundCount += 1;
        toolsSeenPerRound.add(
          tools.map((tool) => tool.name).toList(growable: false),
        );
        if (roundCount == 1) {
          return const SarvamChatResult(
            content: '',
            model: 'sarvam-30b',
            toolCalls: <SarvamToolCall>[
              SarvamToolCall(
                id: 'tool_doc',
                name: 'generate_docx',
                arguments: <String, dynamic>{
                  'title': 'Test Doc',
                  'markdown_content': '# Test',
                },
              ),
            ],
          );
        }
        return const SarvamChatResult(
          content: 'The document is ready.',
          model: 'sarvam-30b',
        );
      },
      executeToolCall: (_) async => const ToolExecutionResult(
        success: true,
        summary: 'Created DOCX document "Test Doc".',
        formattedOutput: 'Created and attached `Test Doc.docx`.',
      ),
      shouldAutoContinue: ({
        required String prompt,
        required SarvamChatResult result,
        required String accumulatedResponse,
        required int roundsUsed,
        bool expectsArtifact = false,
        bool artifactProduced = false,
      }) {
        return false;
      },
    );

    expect(roundCount, 2);
    expect(toolsSeenPerRound, const <List<String>>[
      <String>['generate_docx'],
      <String>[],
    ]);
    expect(result.finalRound.content, 'The document is ready.');
  });

  test('empty post-tool round is retried until a direct answer is emitted', () async {
    final orchestrator = AgentOrchestrator(
      toolSelector: _FixedToolSelector(const <String>['search_web']),
      contextEngine: _ImmediateContextEngine(),
      promptVariantSelector: const PromptVariantSelector(),
      toolDispatcher: ToolDispatcher(),
      responseGuard: const ResponseGuard(),
    );

    var roundCount = 0;
    final result = await orchestrator.run(
      apiKey: 'sk_test',
      settings: const NeroSettings(
        sarvamApiKey: 'sk_test',
        selectedModelId: 'sarvam-30b',
      ),
      prompt: 'Research model comparison',
      conversationId: 'conv',
      taskId: 'task_1',
      modelHistory: const <ChatMessage>[],
      allToolDefinitions: const <SarvamToolDefinition>[
        SarvamToolDefinition(
          name: 'search_web',
          description: 'Search',
          parameters: <String, dynamic>{},
        ),
      ],
      outputToolsPrompt: 'Output tools prompt',
      taskHint: null,
      executeAssistantRound: ({
        required List<ChatMessage> requestMessages,
        required List<SarvamToolDefinition> tools,
        required StringBuffer responseBuffer,
      }) async {
        roundCount += 1;
        if (roundCount == 1) {
          return const SarvamChatResult(
            content: '',
            model: 'sarvam-30b',
            toolCalls: <SarvamToolCall>[
              SarvamToolCall(
                id: 'tool_search',
                name: 'search_web',
                arguments: <String, dynamic>{'query': 'kimi k2.5 vs minimax m2.7'},
              ),
            ],
          );
        }
        if (roundCount == 2) {
          return const SarvamChatResult(
            content: '',
            model: 'sarvam-30b',
          );
        }
        responseBuffer.write('Kimi K2.5 is stronger overall based on the gathered evidence.');
        return const SarvamChatResult(
          content: 'Kimi K2.5 is stronger overall based on the gathered evidence.',
          model: 'sarvam-30b',
        );
      },
      executeToolCall: (_) async => const ToolExecutionResult(
        success: true,
        summary: 'Search completed.',
        formattedOutput: 'Kimi and Minimax comparison notes.',
      ),
      shouldAutoContinue: ({
        required String prompt,
        required SarvamChatResult result,
        required String accumulatedResponse,
        required int roundsUsed,
        bool expectsArtifact = false,
        bool artifactProduced = false,
      }) {
        return false;
      },
    );

    expect(roundCount, 3);
    expect(
      result.validatedResponse.content,
      'Kimi K2.5 is stronger overall based on the gathered evidence.',
    );
  });

  test('awaits async prepared hook before executing the first round', () async {
    final orchestrator = AgentOrchestrator(
      toolSelector: _FixedToolSelector(const <String>['search_web']),
      contextEngine: _ImmediateContextEngine(),
      promptVariantSelector: const PromptVariantSelector(),
      toolDispatcher: ToolDispatcher(),
      responseGuard: const ResponseGuard(),
    );

    var prepared = false;
    var executeRoundSawPrepared = false;

    await orchestrator.run(
      apiKey: 'sk_test',
      settings: const NeroSettings(
        sarvamApiKey: 'sk_test',
        selectedModelId: 'sarvam-30b',
      ),
      prompt: 'Find the latest docs',
      conversationId: 'conv',
      taskId: 'task_1',
      modelHistory: const <ChatMessage>[],
      allToolDefinitions: const <SarvamToolDefinition>[
        SarvamToolDefinition(
          name: 'search_web',
          description: 'Search',
          parameters: <String, dynamic>{},
        ),
      ],
      outputToolsPrompt: 'Output tools prompt',
      taskHint: null,
      hooks: AgentOrchestratorHooks(
        onPrepared: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          prepared = true;
        },
      ),
      executeAssistantRound: ({
        required List<ChatMessage> requestMessages,
        required List<SarvamToolDefinition> tools,
        required StringBuffer responseBuffer,
      }) async {
        executeRoundSawPrepared = prepared;
        return const SarvamChatResult(
          content: 'Grounded answer.',
          model: 'sarvam-30b',
        );
      },
      executeToolCall: (_) async => const ToolExecutionResult(
        success: true,
        summary: 'unused',
        formattedOutput: 'unused',
      ),
      shouldAutoContinue: ({
        required String prompt,
        required SarvamChatResult result,
        required String accumulatedResponse,
        required int roundsUsed,
        bool expectsArtifact = false,
        bool artifactProduced = false,
      }) {
        return false;
      },
    );

    expect(prepared, isTrue);
    expect(executeRoundSawPrepared, isTrue);
  });
}

class _DelayedToolSelector extends ToolSelector {
  _DelayedToolSelector({
    required this.started,
    required this.release,
    required this.selectedTools,
  }) : super(client: _NoopChatCompletionClient());

  final Completer<void> started;
  final Completer<void> release;
  final List<String> selectedTools;

  @override
  Future<List<String>> selectTools({
    required String apiKey,
    required String prompt,
    required List<ChatMessage> recentMessages,
  }) async {
    if (!started.isCompleted) {
      started.complete();
    }
    await release.future;
    return selectedTools;
  }
}

class _DelayedContextEngine extends ContextEngine {
  _DelayedContextEngine({
    required this.started,
    required this.release,
  });

  final Completer<void> started;
  final Completer<void> release;

  @override
  Future<ContextEngineResult> assemble({
    required String conversationId,
    required String? taskId,
    required List<ChatMessage> history,
    required String systemPrompt,
    required String outputToolsPrompt,
    String? taskHint,
  }) async {
    if (!started.isCompleted) {
      started.complete();
    }
    await release.future;
    return ContextEngineResult(
      messages: <ChatMessage>[
        const ChatMessage(
          id: 'system_variant',
          role: ChatRole.system,
          content: '',
        ),
        const ChatMessage(
          id: 'output_tools',
          role: ChatRole.system,
          content: 'Output tools prompt',
        ),
      ],
      workingMemory: null,
      episodicMemories: const [],
      semanticFacts: const [],
      artifactReferences: const [],
    );
  }
}

class _ImmediateContextEngine extends ContextEngine {
  @override
  Future<ContextEngineResult> assemble({
    required String conversationId,
    required String? taskId,
    required List<ChatMessage> history,
    required String systemPrompt,
    required String outputToolsPrompt,
    String? taskHint,
  }) async {
    return ContextEngineResult(
      messages: <ChatMessage>[
        const ChatMessage(
          id: 'system_variant',
          role: ChatRole.system,
          content: '',
        ),
        const ChatMessage(
          id: 'output_tools',
          role: ChatRole.system,
          content: 'Output tools prompt',
        ),
      ],
      workingMemory: null,
      episodicMemories: const [],
      semanticFacts: const [],
      artifactReferences: const [],
    );
  }
}

class _FixedToolSelector extends ToolSelector {
  _FixedToolSelector(this._selectedTools)
      : super(client: _NoopChatCompletionClient());

  final List<String> _selectedTools;

  @override
  Future<List<String>> selectTools({
    required String apiKey,
    required String prompt,
    required List<ChatMessage> recentMessages,
  }) async {
    return _selectedTools;
  }
}

class _NoopChatCompletionClient implements ChatCompletionClient {
  @override
  Future<SarvamChatResult> completeChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  }) async {
    return const SarvamChatResult(content: '[]', model: 'sarvam-m');
  }

  @override
  void cancel() {}
}
