import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nero/app/app_error_reporter.dart';
import 'package:nero/features/agent/domain/agent_task.dart';
import 'package:nero/features/chat/application/agent_orchestrator.dart';
import 'package:nero/features/chat/application/chat_session_controller.dart';
import 'package:nero/features/chat/application/context_engine.dart';
import 'package:nero/features/chat/application/prompt_variants.dart';
import 'package:nero/features/chat/application/response_guard.dart';
import 'package:nero/features/chat/application/sarvam_api_client.dart';
import 'package:nero/features/chat/application/sarvam_stream_client.dart';
import 'package:nero/features/chat/application/tool_dispatcher.dart';
import 'package:nero/features/chat/application/tool_selector.dart';
import 'package:nero/features/chat/application/web_tools.dart';
import 'package:nero/features/chat/domain/chat_message.dart';
import 'package:nero/features/agent/application/agent_task_store.dart';
import 'package:nero/features/docs/application/doc_generation_service.dart';
import 'package:nero/features/docs/domain/doc_models.dart';
import 'package:nero/features/memory/application/semantic_fact_store.dart';
import 'package:nero/features/memory/application/working_memory_store.dart';
import 'package:nero/features/memory/domain/semantic_fact.dart';
import 'package:nero/features/memory/domain/working_memory_snapshot.dart';
import 'package:nero/features/runtime/application/run_coordinator.dart';
import 'package:nero/features/runtime/application/runtime_ledger_service.dart';
import 'package:nero/features/runtime/application/runtime_run_store.dart';
import 'package:nero/features/settings/app_settings.dart';
import 'package:nero/features/tools/application/local_tool_runtime_service.dart';
import 'package:nero/features/tools/domain/tool_runtime_models.dart'
    as runtime;
import 'package:nero/features/tools/domain/tool_types.dart';
import 'package:nero/features/workspace/domain/workspace_item.dart';

import '../helpers/fakes.dart';
import 'package:nero/platform/database/app_database.dart' as db;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sendPrompt adds user message and reveals cloud response', () async {
    final client = FakeChatCompletionClient(
      result: const SarvamChatResult(
        content: 'Hello from Sarvam.',
        model: 'sarvam-30b',
        promptTokens: 10,
        completionTokens: 4,
        totalTokens: 14,
      ),
    );
    final controller = ChatSessionController(
      client: client,
      auditLogStore: FakeAuditLogStore(),
      agentTaskStore: FakeAgentTaskStore(),
      toolSelector: FakeToolSelector(),
      workingMemoryStore: FakeWorkingMemoryStore(),
      semanticFactStore: FakeSemanticFactStore(),
    );
    const settings = NeroSettings(
      azureApiKey: 'sk_test',
      selectedModelId: 'sarvam-30b',
    );

    controller.configureForSettings(settings, 'Sarvam 30B');
    await controller.sendPrompt('Say hello', settings);
    await waitForMessageCompletion(controller);

    expect(client.lastApiKey, 'sk_test');
    expect(client.lastModelId, 'sarvam-30b');
    expect(
      client.lastMessages.any(
        (message) =>
            message.role == ChatRole.system &&
            message.content.contains('Available output tools in this chat UI'),
      ),
      isTrue,
    );
    expect(controller.messages.length, 2);
    expect(controller.messages.first.content, 'Say hello');
    expect(controller.messages.last.content, 'Hello from Sarvam.');
    expect(controller.messages.last.isStreaming, isFalse);
    expect(controller.messages.last.averageTokensPerSecond, isNotNull);
    expect(
      controller.messages.last.thinkingSteps,
      contains('Planning response'),
    );
    expect(controller.status, 'Done');
    expect(controller.nativeStats['provider'], 'sarvam_ai');
  });

  test(
    'non-artifact prompts do not force a file tool even if selection is overly broad',
    () async {
      final client = FakeChatCompletionClient(
        result: const SarvamChatResult(
          content: 'Hello! How can I help you today?',
          model: 'sarvam-30b',
          promptTokens: 8,
          completionTokens: 7,
          totalTokens: 15,
        ),
      );
      final controller = ChatSessionController(
        client: client,
        auditLogStore: FakeAuditLogStore(),
        agentTaskStore: FakeAgentTaskStore(),
        toolSelector: FakeToolSelector(
          selectedTools: const <String>[
            'search_web',
            'read_url',
            'extract_article',
            'generate_docx',
            'generate_xlsx',
            'generate_report_pdf',
          ],
        ),
        workingMemoryStore: FakeWorkingMemoryStore(),
        semanticFactStore: FakeSemanticFactStore(),
      );
      const settings = NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-30b',
      );

      await controller.sendPrompt('hi', settings);
      await waitForMessageCompletion(controller);

      expect(
        controller.messages.last.content,
        'Hello! How can I help you today?',
      );
      expect(
        controller.messages.last.content.contains('generate_xlsx'),
        isFalse,
      );
      expect(controller.messages.last.generatedArtifacts, isEmpty);
    },
  );

  test('sendPrompt is blocked when API key is missing', () async {
    final client = FakeChatCompletionClient(
      result: const SarvamChatResult(content: 'unused', model: 'sarvam-30b'),
    );
    final controller = ChatSessionController(
      client: client,
      auditLogStore: FakeAuditLogStore(),
      agentTaskStore: FakeAgentTaskStore(),
      toolSelector: FakeToolSelector(),
      workingMemoryStore: FakeWorkingMemoryStore(),
      semanticFactStore: FakeSemanticFactStore(),
    );
    const settings = NeroSettings(
      azureApiKey: '',
      selectedModelId: 'sarvam-30b',
    );

    await controller.sendPrompt('Hi', settings);

    expect(controller.messages, isEmpty);
    expect(controller.blockingReason, 'Add your Sarvam API key in Settings.');
  });

  test(
    'replaceMessages clears stale blockingReason and cancels transports',
    () async {
      final client = CountingChatCompletionClient(
        result: const SarvamChatResult(content: 'unused', model: 'sarvam-30b'),
      );
      final streamingClient = CountingStreamingClient();
      final controller = ChatSessionController(
        client: client,
        streamingClient: streamingClient,
        auditLogStore: FakeAuditLogStore(),
        agentTaskStore: FakeAgentTaskStore(),
        toolSelector: FakeToolSelector(),
        workingMemoryStore: FakeWorkingMemoryStore(),
        semanticFactStore: FakeSemanticFactStore(),
      );
      const settings = NeroSettings(
        azureApiKey: '',
        selectedModelId: 'sarvam-30b',
      );

      await controller.sendPrompt('Hi', settings);
      expect(controller.blockingReason, isNotNull);

      controller.replaceMessages(const <ChatMessage>[]);

      expect(controller.blockingReason, isNull);
      expect(controller.status, 'Ready');
      expect(client.cancelCount, 1);
      expect(streamingClient.cancelCount, 1);
    },
  );

  test('cloud failures become recoverable controller state', () async {
    final client = FakeChatCompletionClient(error: StateError('403 forbidden'));
    final controller = ChatSessionController(
      client: client,
      auditLogStore: FakeAuditLogStore(),
      agentTaskStore: FakeAgentTaskStore(),
      toolSelector: FakeToolSelector(),
      workingMemoryStore: FakeWorkingMemoryStore(),
      semanticFactStore: FakeSemanticFactStore(),
    );
    const settings = NeroSettings(
      azureApiKey: 'sk_test',
      selectedModelId: 'sarvam-105b',
    );

    await controller.sendPrompt('Why?', settings);

    expect(controller.isGenerating, isFalse);
    expect(controller.status, 'Cloud request failed');
    expect(controller.blockingReason, contains('403 forbidden'));
    expect(
      controller.messages.last.content,
      contains('[Cloud request failed: Bad state: 403 forbidden]'),
    );
  });

  test('empty research responses trigger a direct repair pass instead of surfacing bad state', () async {
    final client = SequencedFakeChatCompletionClient(
      results: <SarvamChatResult>[
        const SarvamChatResult(
          content: '',
          model: 'sarvam-105b',
          completionTokens: 0,
        ),
        const SarvamChatResult(
          content:
              'Claude and OpenAI differ mainly in model behavior, ecosystem, and tool/runtime design.',
          model: 'sarvam-105b',
          completionTokens: 18,
        ),
      ],
    );
    final controller = ChatSessionController(
      client: client,
      auditLogStore: FakeAuditLogStore(),
      agentTaskStore: FakeAgentTaskStore(),
      toolSelector: FakeToolSelector(
        selectedTools: const <String>['search_web'],
      ),
      workingMemoryStore: FakeWorkingMemoryStore(),
      semanticFactStore: FakeSemanticFactStore(),
    );
    const settings = NeroSettings(
      azureApiKey: 'sk_test',
      selectedModelId: 'sarvam-105b',
    );

    await controller.sendPrompt(
      'research and find out the difference between claude and open ai',
      settings,
    );
    await waitForMessageCompletion(controller);

    expect(
      controller.messages.last.content,
      contains('Claude and OpenAI differ mainly'),
    );
    expect(
      controller.messages.last.content.contains('Cloud request failed'),
      isFalse,
    );
    expect(client.recordedCalls, hasLength(2));
  });

  test(
    'replaceMessages abandons stale in-flight completions from the previous conversation',
    () async {
      final client = DeferredChatCompletionClient();
      final controller = ChatSessionController(
        client: client,
        auditLogStore: FakeAuditLogStore(),
        agentTaskStore: FakeAgentTaskStore(),
        toolSelector: FakeToolSelector(),
        workingMemoryStore: FakeWorkingMemoryStore(),
        semanticFactStore: FakeSemanticFactStore(),
      );
      const settings = NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-30b',
      );

      final sendFuture = controller.sendPrompt('Hello', settings);
      await until(() => controller.isGenerating);
      controller.replaceMessages(const <ChatMessage>[]);
      client.complete(
        const SarvamChatResult(
          content: 'Late response from the abandoned turn.',
          model: 'sarvam-30b',
          completionTokens: 4,
        ),
      );
      await sendFuture;

      expect(controller.messages, isEmpty);
      expect(controller.isGenerating, isFalse);
      expect(controller.status, 'Ready');
      expect(client.cancelled, isTrue);
    },
  );

  test('diagram prompts inject a mermaid-specific task hint', () async {
    final client = FakeChatCompletionClient(
      result: const SarvamChatResult(
        content: '```mermaid\nflowchart TD\nA-->B\n```',
        model: 'sarvam-30b',
      ),
    );
    final controller = ChatSessionController(
      client: client,
      auditLogStore: FakeAuditLogStore(),
      agentTaskStore: FakeAgentTaskStore(),
      toolSelector: FakeToolSelector(),
      workingMemoryStore: FakeWorkingMemoryStore(),
      semanticFactStore: FakeSemanticFactStore(),
    );
    const settings = NeroSettings(
      azureApiKey: 'sk_test',
      selectedModelId: 'sarvam-30b',
    );

    controller.configureForSettings(settings, 'Sarvam 30B');
    await controller.sendPrompt(
      'Create a flowchart diagram for login',
      settings,
    );

    expect(
      client.lastMessages.any(
        (message) =>
            message.role == ChatRole.system &&
            message.content.contains('[[NERO_BLOCK:DIAGRAM lang=mermaid]]'),
      ),
      isTrue,
    );
  });

  test('streaming message exposes live tok/s before final average', () async {
    final client = FakeChatCompletionClient(
      result: const SarvamChatResult(
        content: 'unused fallback',
        model: 'sarvam-30b',
        completionTokens: 12,
      ),
    );
    final streamingClient = FakeStreamingClient(
      events: <AgentStreamEvent>[
        const ContentDeltaEvent('This is '),
        const ContentDeltaEvent('a streamed '),
        const ContentDeltaEvent('response.'),
        const UsageReportEvent(completionTokens: 12, totalTokens: 12),
        const StreamFinishedEvent(finishReason: 'stop', model: 'sarvam-30b'),
      ],
    );
    final controller = ChatSessionController(
      client: client,
      streamingClient: streamingClient,
      auditLogStore: FakeAuditLogStore(),
      agentTaskStore: FakeAgentTaskStore(),
      toolSelector: FakeToolSelector(),
      workingMemoryStore: FakeWorkingMemoryStore(),
      semanticFactStore: FakeSemanticFactStore(),
    );
    const settings = NeroSettings(
      azureApiKey: 'sk_test',
      selectedModelId: 'sarvam-30b',
    );

    unawaited(controller.sendPrompt('Explain quickly', settings));
    await Future<void>.delayed(const Duration(milliseconds: 60));

    final streamingMessage = controller.messages.last;
    expect(streamingMessage.isStreaming, isTrue);
    expect(streamingMessage.content, isNotEmpty);

    await waitForMessageCompletion(controller);
    final completedMessage = controller.messages.last;
    expect(completedMessage.isStreaming, isFalse);
    expect(completedMessage.averageTokensPerSecond, isNotNull);
    expect(completedMessage.content, 'This is a streamed response.');
  });

  test(
    'retryable stream socket reset falls back to buffered completion',
    () async {
      final client = FakeChatCompletionClient(
        result: const SarvamChatResult(
          content: 'Recovered through buffered completion.',
          model: 'sarvam-30b',
          completionTokens: 9,
        ),
      );
      final streamingClient = FakeStreamingClient(
        events: <AgentStreamEvent>[
          StreamErrorEvent(
            const SocketException('Connection reset by peer'),
            isRetryable: true,
          ),
        ],
      );
      final controller = ChatSessionController(
        client: client,
        streamingClient: streamingClient,
        auditLogStore: FakeAuditLogStore(),
        agentTaskStore: FakeAgentTaskStore(),
        toolSelector: FakeToolSelector(),
        workingMemoryStore: FakeWorkingMemoryStore(),
        semanticFactStore: FakeSemanticFactStore(),
      );
      const settings = NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-30b',
      );

      await controller.sendPrompt('Hello', settings);
      await waitForMessageCompletion(controller);

      expect(controller.status, 'Done');
      expect(controller.blockingReason, isNull);
      expect(
        controller.messages.last.content,
        'Recovered through buffered completion.',
      );
      expect(
        controller.messages.last.content.contains('Cloud request failed'),
        isFalse,
      );
    },
  );

  test(
    'reasoning-only stream reset still falls back to buffered completion',
    () async {
      final client = FakeChatCompletionClient(
        result: const SarvamChatResult(
          content: 'Recovered after reasoning-only stream failure.',
          model: 'sarvam-30b',
          completionTokens: 11,
        ),
      );
      final streamingClient = FakeStreamingClient(
        events: <AgentStreamEvent>[
          const ThinkingDeltaEvent('Planning response'),
          StreamErrorEvent(
            const SocketException('Connection reset by peer'),
            isRetryable: true,
          ),
        ],
      );
      final controller = ChatSessionController(
        client: client,
        streamingClient: streamingClient,
        auditLogStore: FakeAuditLogStore(),
        agentTaskStore: FakeAgentTaskStore(),
        toolSelector: FakeToolSelector(),
        workingMemoryStore: FakeWorkingMemoryStore(),
        semanticFactStore: FakeSemanticFactStore(),
      );
      const settings = NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-30b',
      );

      await controller.sendPrompt('Hello', settings);
      await waitForMessageCompletion(controller);

      expect(controller.status, 'Done');
      expect(
        controller.messages.last.content,
        'Recovered after reasoning-only stream failure.',
      );
    },
  );

  test(
    'tool calls execute and feed a final response back into the model',
    () async {
      final client = SequencedFakeChatCompletionClient(
        results: <SarvamChatResult>[
          const SarvamChatResult(
            content: '',
            model: 'sarvam-105b',
            reasoningContent: 'Searching authoritative sources.',
            toolCalls: <SarvamToolCall>[
              SarvamToolCall(
                id: 'tool_1',
                name: 'search_web',
                arguments: <String, dynamic>{
                  'query': 'nero app latest docs',
                  'limit': 3,
                },
              ),
            ],
          ),
          const SarvamChatResult(
            content: 'Final answer after tools.',
            model: 'sarvam-105b',
            completionTokens: 6,
          ),
        ],
      );
      final webTools = FakeWebToolService();
      final controller = ChatSessionController(
        client: client,
        webToolService: webTools,
        auditLogStore: FakeAuditLogStore(),
        agentTaskStore: FakeAgentTaskStore(),
        toolSelector: FakeToolSelector(
          selectedTools: const <String>['search_web'],
        ),
        workingMemoryStore: FakeWorkingMemoryStore(),
        semanticFactStore: FakeSemanticFactStore(),
      );
      const settings = NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-105b',
      );

      await controller.sendPrompt('Find the latest docs', settings);
      await waitForMessageCompletion(controller);

      expect(webTools.searchedQueries, contains('nero app latest docs'));
      expect(controller.messages.last.content, 'Final answer after tools.');
      expect(controller.completedThoughts, isNotEmpty);
      expect(controller.messages.last.thinkingSteps, isNotEmpty);
      expect(controller.messages.last.thinkingDurationMs, isNotNull);
      expect(
        client.recordedCalls
            .expand((messages) => messages)
            .any(
              (message) => message.content.contains(
                '[Assistant requested tool execution]',
              ),
            ),
        isFalse,
      );
    },
  );

  test('doc tool calls attach a generated docx artifact', () async {
    final client = SequencedFakeChatCompletionClient(
      results: <SarvamChatResult>[
        const SarvamChatResult(
          content: '',
          model: 'sarvam-105b',
          toolCalls: <SarvamToolCall>[
            SarvamToolCall(
              id: 'tool_doc',
              name: 'generate_docx',
              arguments: <String, dynamic>{
                'title': 'Tools and Capabilities',
                'markdown_content':
                    '# Tools and Capabilities\n\nNero can create document files.',
              },
            ),
          ],
        ),
        const SarvamChatResult(
          content: 'I created the document and attached it below.',
          model: 'sarvam-105b',
          completionTokens: 8,
        ),
      ],
    );
    final docGenerationService = FakeDocGenerationService();
    final controller = ChatSessionController(
      client: client,
      docGenerationService: docGenerationService,
      auditLogStore: FakeAuditLogStore(),
      agentTaskStore: FakeAgentTaskStore(),
      toolSelector: FakeToolSelector(
        selectedTools: const <String>['generate_docx'],
      ),
      workingMemoryStore: FakeWorkingMemoryStore(),
      semanticFactStore: FakeSemanticFactStore(),
    );
    const settings = NeroSettings(
      azureApiKey: 'sk_test',
      selectedModelId: 'sarvam-105b',
    );

    await controller.sendPrompt('Generate a doc about your tools', settings);
    await waitForMessageCompletion(controller);

    expect(
      docGenerationService.requests.single.title,
      'Tools and Capabilities',
    );
    expect(
      controller.messages.last.content,
      'I created the document and attached it below.',
    );
    expect(controller.messages.last.generatedArtifacts, hasLength(1));
    expect(
      controller.messages.last.generatedArtifacts.single.extension,
      'docx',
    );
    expect(
      client.recordedToolDefinitions
          .expand((tools) => tools)
          .map((tool) => tool.name),
      contains('generate_docx'),
    );
  });

  test(
    'doc tool calls recover when markdown_content contains planning text instead of document content',
    () async {
      final client = SequencedFakeChatCompletionClient(
        results: <SarvamChatResult>[
          const SarvamChatResult(
            content: '',
            model: 'sarvam-105b',
            toolCalls: <SarvamToolCall>[
              SarvamToolCall(
                id: 'tool_doc_bad_payload',
                name: 'generate_docx',
                arguments: <String, dynamic>{
                  'title': 'Generate a doc about your capabilities',
                  'markdown_content':
                      'We need to call generate_docx with title and markdown_content describing capabilities and use cases.',
                },
              ),
            ],
          ),
          const SarvamChatResult(
            content:
                '# Capability Brief\n\n## Use Cases\n\n- Answer questions\n- Summarize information\n- Generate files\n',
            model: 'sarvam-105b',
            completionTokens: 36,
          ),
          const SarvamChatResult(
            content: 'I created the document and attached it above.',
            model: 'sarvam-105b',
            completionTokens: 8,
          ),
        ],
      );
      final docGenerationService = FakeDocGenerationService();
      final controller = ChatSessionController(
        client: client,
        docGenerationService: docGenerationService,
        auditLogStore: FakeAuditLogStore(),
        agentTaskStore: FakeAgentTaskStore(),
        toolSelector: FakeToolSelector(
          selectedTools: const <String>['generate_docx'],
        ),
        workingMemoryStore: FakeWorkingMemoryStore(),
        semanticFactStore: FakeSemanticFactStore(),
      );
      const settings = NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-105b',
      );

      await controller.sendPrompt(
        'generate a doc about your capabilities and use cases',
        settings,
      );
      await waitForMessageCompletion(controller);

      final docText = docGenerationService.requests.single.blocks
          .map(
            (block) => switch (block) {
              HeadingBlock() => block.text,
              ParagraphBlock() => block.text,
              BulletListBlock() => block.items.join('\n'),
              NumberedListBlock() => block.items.join('\n'),
              TableBlock() => block.rows.expand((row) => row).join('\n'),
            },
          )
          .join('\n');
      expect(docGenerationService.requests, hasLength(1));
      expect(docGenerationService.requests.single.title, 'Capability Brief');
      expect(docText, contains('Answer questions'));
      expect(docText, isNot(contains('We need to call generate_docx')));
      expect(controller.messages.last.generatedArtifacts, hasLength(1));
    },
  );

  test(
    'pdf tool calls recover when markdown_content contains planning text instead of document content',
    () async {
      final client = SequencedFakeChatCompletionClient(
        results: <SarvamChatResult>[
          const SarvamChatResult(
            content: '',
            model: 'sarvam-105b',
            toolCalls: <SarvamToolCall>[
              SarvamToolCall(
                id: 'tool_pdf_bad_payload',
                name: 'generate_report_pdf',
                arguments: <String, dynamic>{
                  'title': 'Generate a pdf about your capabilities',
                  'markdown_content':
                      'We need to call generate_report_pdf with title and markdown_content for capabilities and tools.',
                },
              ),
            ],
          ),
          const SarvamChatResult(
            content:
                '# Capability PDF\n\n## Highlights\n\n- Generate documents\n- Explain code\n',
            model: 'sarvam-105b',
            completionTokens: 24,
          ),
          const SarvamChatResult(
            content: 'I created the PDF and attached it above.',
            model: 'sarvam-105b',
            completionTokens: 8,
          ),
        ],
      );
      final localToolRuntimeService = FakeLocalToolRuntimeService();
      final controller = ChatSessionController(
        client: client,
        localToolRuntimeService: localToolRuntimeService,
        auditLogStore: FakeAuditLogStore(),
        agentTaskStore: FakeAgentTaskStore(),
        toolSelector: FakeToolSelector(
          selectedTools: const <String>['generate_report_pdf'],
        ),
        workingMemoryStore: FakeWorkingMemoryStore(),
        semanticFactStore: FakeSemanticFactStore(),
      );
      const settings = NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-105b',
      );

      await controller.sendPrompt(
        'generate a pdf about your capabilities and tools',
        settings,
      );
      await waitForMessageCompletion(controller);

      expect(localToolRuntimeService.requests, hasLength(1));
      expect(
        localToolRuntimeService.requests.single.parameters['title'],
        'Capability PDF',
      );
      expect(
        localToolRuntimeService.requests.single.parameters['content'],
        contains('Generate documents'),
      );
      expect(
        localToolRuntimeService.requests.single.parameters['content'],
        isNot(contains('We need to call generate_report_pdf')),
      );
      expect(controller.messages.last.generatedArtifacts, hasLength(1));
    },
  );

  test('inline docx artifact generation attaches a generated artifact', () async {
    final docGenerationService = FakeDocGenerationService();
    final controller = ChatSessionController(
      client: FakeChatCompletionClient(
        result: const SarvamChatResult(content: 'unused', model: 'sarvam-105b'),
      ),
      docGenerationService: docGenerationService,
      auditLogStore: FakeAuditLogStore(),
      agentTaskStore: FakeAgentTaskStore(),
      toolSelector: FakeToolSelector(),
      workingMemoryStore: FakeWorkingMemoryStore(),
      semanticFactStore: FakeSemanticFactStore(),
    );

    controller.replaceMessages(const <ChatMessage>[
      ChatMessage(
        id: 'assistant_1',
        role: ChatRole.assistant,
        content:
            '[[NERO_BLOCK:DOCX title="Test Doc" markdown_content="# Hello World"]]',
      ),
    ]);

    final artifact = await controller.generateInlineDocxArtifact(
      messageId: 'assistant_1',
      title: 'Test Doc',
      markdownContent: '# Hello World',
    );

    expect(artifact, isNotNull);
    expect(docGenerationService.requests, hasLength(1));
    expect(docGenerationService.requests.single.title, 'Test Doc');
    expect(controller.messages.single.generatedArtifacts, hasLength(1));
    expect(
      controller.messages.single.generatedArtifacts.single.extension,
      'docx',
    );
  });

  test(
    'inline tool markup in streamed content is converted into a real doc tool call',
    () async {
      final client = FakeChatCompletionClient(
        result: const SarvamChatResult(
          content: 'unused fallback',
          model: 'sarvam-105b',
        ),
      );
      final streamingClient = SequencedFakeStreamingClient(
        rounds: <List<AgentStreamEvent>>[
          <AgentStreamEvent>[
            const ThinkingDeltaEvent('Planning response'),
            const ContentDeltaEvent(
              'I\'ll create a document about my tools and capabilities for you.\n'
              '<tool_call>generate_docx\n'
              '<arg_key>title</arg_key>\n'
              '<arg_value>Nero AI Assistant - Tools and Capabilities</arg_value>\n'
              '<arg_key>markdown_content</arg_key>\n'
              '<arg_value># Nero AI Assistant - Tools and Capabilities\n\n## Overview\n\nNero can generate files.</arg_value>',
            ),
            const StreamFinishedEvent(
              finishReason: 'stop',
              model: 'sarvam-105b',
            ),
          ],
          <AgentStreamEvent>[
            const ContentDeltaEvent(
              'I created the document and attached it above.',
            ),
            const StreamFinishedEvent(
              finishReason: 'stop',
              model: 'sarvam-105b',
            ),
          ],
        ],
      );
      final docGenerationService = FakeDocGenerationService();
      final controller = ChatSessionController(
        client: client,
        streamingClient: streamingClient,
        docGenerationService: docGenerationService,
        auditLogStore: FakeAuditLogStore(),
        agentTaskStore: FakeAgentTaskStore(),
        toolSelector: FakeToolSelector(
          selectedTools: const <String>['generate_docx'],
        ),
        workingMemoryStore: FakeWorkingMemoryStore(),
        semanticFactStore: FakeSemanticFactStore(),
      );
      const settings = NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-105b',
      );

      await controller.sendPrompt(
        'Generate a doc about your tools and capabilities in 1-2 pages.',
        settings,
      );
      await waitForMessageCompletion(controller);

      expect(docGenerationService.requests, hasLength(1));
      expect(
        docGenerationService.requests.single.title,
        'Nero AI Assistant - Tools and Capabilities',
      );
      expect(
        controller.messages.last.content,
        'I created the document and attached it above.',
      );
      expect(controller.messages.last.generatedArtifacts, hasLength(1));
      expect(controller.messages.last.content.contains('<tool_call>'), isFalse);
    },
  );

  test('doc generation failure reports error instead of markdown fallback', () async {
    final client = SequencedFakeChatCompletionClient(
      results: <SarvamChatResult>[
        const SarvamChatResult(
          content: '',
          model: 'sarvam-105b',
          toolCalls: <SarvamToolCall>[
            SarvamToolCall(
              id: 'tool_doc',
              name: 'generate_docx',
              arguments: <String, dynamic>{
                'title': 'Fallback Proposal',
                'markdown_content': '# Proposal\n\nFallback content.',
              },
            ),
          ],
        ),
        const SarvamChatResult(
          content: 'I will create the document now.',
          model: 'sarvam-105b',
          completionTokens: 6,
        ),
      ],
    );
    final taskStore = CapturingAgentTaskStore();
    final errorFuture = AppErrorReporter.instance.errors.first;
    final controller = ChatSessionController(
      client: client,
      docGenerationService: FailingDocGenerationService(),
      auditLogStore: FakeAuditLogStore(),
      agentTaskStore: taskStore,
      toolSelector: FakeToolSelector(
        selectedTools: const <String>['generate_docx'],
      ),
      workingMemoryStore: FakeWorkingMemoryStore(),
      semanticFactStore: FakeSemanticFactStore(),
    );
    const settings = NeroSettings(
      azureApiKey: 'sk_test',
      selectedModelId: 'sarvam-105b',
    );

    await controller.sendPrompt('Generate a proposal document', settings);
    await waitForMessageCompletion(controller);
    final errorMessage = await errorFuture;

    expect(controller.messages.last.generatedArtifacts, isEmpty);
    expect(errorMessage, contains('disk full'));
    expect(
      controller.activeTask?.steps.map((step) => step.kind),
      contains(AgentStepKinds.prepareResponse),
    );
    expect(
      taskStore.lastTask?.steps.map((step) => step.kind),
      contains(AgentStepKinds.prepareResponse),
    );
  });

  test(
    'document requests force generate_docx if the model only replies with intent',
    () async {
      final client = SequencedFakeChatCompletionClient(
        results: <SarvamChatResult>[
          const SarvamChatResult(
            content:
                'I\'ll create a comprehensive document about my capabilities and available tools for you.',
            model: 'sarvam-105b',
            completionTokens: 18,
          ),
          const SarvamChatResult(
            content: '',
            model: 'sarvam-105b',
            toolCalls: <SarvamToolCall>[
              SarvamToolCall(
                id: 'forced_doc',
                name: 'generate_docx',
                arguments: <String, dynamic>{
                  'title': 'Nero Capabilities and Tools',
                  'markdown_content':
                      '# Nero Capabilities and Tools\n\n## What I can do\n\n- Answer questions\n- Generate documents\n\n## Available tools\n\n- Web search\n- Page reading\n- Article extraction\n- DOCX generation',
                },
              ),
            ],
          ),
        ],
      );
      final docGenerationService = FakeDocGenerationService();
      final controller = ChatSessionController(
        client: client,
        docGenerationService: docGenerationService,
        auditLogStore: FakeAuditLogStore(),
        agentTaskStore: FakeAgentTaskStore(),
        toolSelector: FakeToolSelector(
          selectedTools: const <String>['generate_docx'],
        ),
        workingMemoryStore: FakeWorkingMemoryStore(),
        semanticFactStore: FakeSemanticFactStore(),
      );
      const settings = NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-105b',
      );

      await controller.sendPrompt(
        'generate a doc with 2-3 pages on what you can do, and what tools you have access to.',
        settings,
      );
      await waitForMessageCompletion(controller);

      expect(docGenerationService.requests, hasLength(1));
      expect(
        controller.messages.last.content,
        'I created the document and attached it above.',
      );
      expect(controller.messages.last.generatedArtifacts, hasLength(1));
    },
  );

  test(
    'document requests recover when the initial assistant response is empty',
    () async {
      final client = SequencedFakeChatCompletionClient(
        results: <SarvamChatResult>[
          const SarvamChatResult(
            content: '',
            model: 'sarvam-105b',
            completionTokens: 0,
          ),
          const SarvamChatResult(
            content: '',
            model: 'sarvam-105b',
            toolCalls: <SarvamToolCall>[
              SarvamToolCall(
                id: 'forced_doc_after_empty',
                name: 'generate_docx',
                arguments: <String, dynamic>{
                  'title': 'Nero Capabilities',
                  'markdown_content':
                      '# Nero Capabilities\n\nNero can answer questions and generate files.',
                },
              ),
            ],
          ),
        ],
      );
      final docGenerationService = FakeDocGenerationService();
      final controller = ChatSessionController(
        client: client,
        docGenerationService: docGenerationService,
        auditLogStore: FakeAuditLogStore(),
        agentTaskStore: FakeAgentTaskStore(),
        toolSelector: FakeToolSelector(
          selectedTools: const <String>['generate_docx'],
        ),
        workingMemoryStore: FakeWorkingMemoryStore(),
        semanticFactStore: FakeSemanticFactStore(),
      );
      const settings = NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-105b',
      );

      await controller.sendPrompt(
        'generate a docx with 1 page of your capabilities',
        settings,
      );
      await waitForMessageCompletion(controller);

      expect(docGenerationService.requests, hasLength(1));
      expect(
        controller.messages.last.content,
        'I created the document and attached it above.',
      );
      expect(controller.messages.last.generatedArtifacts, hasLength(1));
      expect(controller.status, 'Done');
    },
  );

  test(
    'artifact fallback records runtime debug counters for repair attempts',
    () async {
      final database = db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final runStore = RuntimeRunStore(database: database);
      final coordinator = RunCoordinator(
        orchestrator: AgentOrchestrator(
          toolSelector: FakeToolSelector(
            selectedTools: const <String>['generate_docx'],
          ),
          contextEngine: ContextEngine(),
          promptVariantSelector: const PromptVariantSelector(),
          toolDispatcher: ToolDispatcher(),
          responseGuard: const ResponseGuard(),
        ),
        runtimeLedgerService: RuntimeLedgerService(store: runStore),
        runIdFactory: () => 'run_artifact_repair_debug',
      );
      final client = SequencedFakeChatCompletionClient(
        results: <SarvamChatResult>[
          const SarvamChatResult(
            content:
                'I will create a comprehensive document about my capabilities and tools.',
            model: 'sarvam-105b',
            completionTokens: 16,
          ),
          const SarvamChatResult(
            content: '',
            model: 'sarvam-105b',
            toolCalls: <SarvamToolCall>[
              SarvamToolCall(
                id: 'forced_doc',
                name: 'generate_docx',
                arguments: <String, dynamic>{
                  'title': 'Nero Capabilities',
                  'markdown_content':
                      '# Nero Capabilities\n\n- Answer questions\n- Generate files',
                },
              ),
            ],
          ),
        ],
      );
      final controller = ChatSessionController(
        client: client,
        docGenerationService: FakeDocGenerationService(),
        auditLogStore: FakeAuditLogStore(),
        agentTaskStore: FakeAgentTaskStore(),
        toolSelector: FakeToolSelector(
          selectedTools: const <String>['generate_docx'],
        ),
        workingMemoryStore: FakeWorkingMemoryStore(),
        semanticFactStore: FakeSemanticFactStore(),
        runCoordinator: coordinator,
      );
      const settings = NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-105b',
      );

      await controller.sendPrompt(
        'generate a doc with 2-3 pages on what you can do',
        settings,
      );
      await waitForMessageCompletion(controller);

      final persistedRun = await runStore.getRun('run_artifact_repair_debug');
      expect(persistedRun, isNotNull);
      final debugCounters = Map<String, Object?>.from(
        (persistedRun!.metadata['debug_counters'] as Map?) ??
            const <String, Object?>{},
      );
      final debugMetadata = Map<String, Object?>.from(
        (persistedRun.metadata['debug_metadata'] as Map?) ??
            const <String, Object?>{},
      );
      expect(debugCounters['artifact_repair_attempt_count'], 1);
      expect(debugCounters['artifact_repair_success_count'], 1);
      expect(debugMetadata['artifact_repair_last'], isA<Map>());
      expect(
        (debugMetadata['artifact_repair_last'] as Map)['output_tool'],
        'generate_docx',
      );
      expect(
        (debugMetadata['artifact_repair_last'] as Map)['success'],
        isTrue,
      );
    },
  );

  test(
    'document requests recover by generating docx from markdown content embedded in code-like output',
    () async {
      final client = SequencedFakeChatCompletionClient(
        results: <SarvamChatResult>[
          const SarvamChatResult(
            content:
                'I will prepare the document content for you.',
            model: 'sarvam-105b',
            completionTokens: 12,
          ),
          const SarvamChatResult(
            content: '''
```python
result = generate_docx(
  title="Capabilities",
  markdown_content="""# My Capabilities

## Core Features
- Answer questions
- Generate files
"""
)
```
''',
            model: 'sarvam-105b',
            completionTokens: 40,
          ),
        ],
      );
      final docGenerationService = FakeDocGenerationService();
      final controller = ChatSessionController(
        client: client,
        docGenerationService: docGenerationService,
        auditLogStore: FakeAuditLogStore(),
        agentTaskStore: FakeAgentTaskStore(),
        toolSelector: FakeToolSelector(
          selectedTools: const <String>['generate_docx'],
        ),
        workingMemoryStore: FakeWorkingMemoryStore(),
        semanticFactStore: FakeSemanticFactStore(),
      );
      const settings = NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-105b',
      );

      await controller.sendPrompt(
        'generate the doc about your capabilities',
        settings,
      );
      await waitForMessageCompletion(controller);

      expect(docGenerationService.requests, hasLength(1));
      expect(
        docGenerationService.requests.single.title,
        'My Capabilities',
      );
      expect(
        controller.messages.last.content,
        'I created the document and attached it above.',
      );
      expect(controller.messages.last.generatedArtifacts, hasLength(1));
    },
  );

  test('artifact capability questions do not force file generation', () async {
    final client = FakeChatCompletionClient(
      result: const SarvamChatResult(
        content: 'Yes. I can generate both DOCX and PDF files when you ask for content.',
        model: 'sarvam-105b',
        completionTokens: 14,
      ),
    );
    final controller = ChatSessionController(
      client: client,
      docGenerationService: FakeDocGenerationService(),
      localToolRuntimeService: FakeLocalToolRuntimeService(),
      auditLogStore: FakeAuditLogStore(),
      agentTaskStore: FakeAgentTaskStore(),
      toolSelector: FakeToolSelector(
        selectedTools: const <String>[
          'generate_docx',
          'generate_report_pdf',
        ],
      ),
      workingMemoryStore: FakeWorkingMemoryStore(),
      semanticFactStore: FakeSemanticFactStore(),
    );
    const settings = NeroSettings(
      azureApiKey: 'sk_test',
      selectedModelId: 'sarvam-105b',
    );

    await controller.sendPrompt('Can you generate doc? pdf?', settings);
    await waitForMessageCompletion(controller);

    expect(controller.messages.last.generatedArtifacts, isEmpty);
    expect(
      controller.messages.last.content,
      contains('generate both DOCX and PDF'),
    );
  });

  test(
    'pdf requests recover by generating a pdf artifact from markdown content embedded in code-like output',
    () async {
      final client = SequencedFakeChatCompletionClient(
        results: <SarvamChatResult>[
          const SarvamChatResult(
            content: 'I will prepare the PDF content for you.',
            model: 'sarvam-105b',
            completionTokens: 12,
          ),
          const SarvamChatResult(
            content: '''
```python
result = generate_report_pdf(
  title="Capabilities PDF",
  markdown_content="""# My Capabilities

## Core Features
- Answer questions
- Generate files
"""
)
```
''',
            model: 'sarvam-105b',
            completionTokens: 40,
          ),
        ],
      );
      final localToolRuntimeService = FakeLocalToolRuntimeService();
      final controller = ChatSessionController(
        client: client,
        localToolRuntimeService: localToolRuntimeService,
        auditLogStore: FakeAuditLogStore(),
        agentTaskStore: FakeAgentTaskStore(),
        toolSelector: FakeToolSelector(
          selectedTools: const <String>['generate_report_pdf'],
        ),
        workingMemoryStore: FakeWorkingMemoryStore(),
        semanticFactStore: FakeSemanticFactStore(),
      );
      const settings = NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-105b',
      );

      await controller.sendPrompt(
        'generate a pdf about your capabilities',
        settings,
      );
      await waitForMessageCompletion(controller);

      expect(localToolRuntimeService.requests, hasLength(1));
      expect(
        localToolRuntimeService.requests.single.toolType,
        ToolType.generateReportPdf,
      );
      expect(
        localToolRuntimeService.requests.single.parameters['title'],
        'My Capabilities',
      );
      expect(controller.messages.last.generatedArtifacts, hasLength(1));
      expect(controller.messages.last.generatedArtifacts.single.extension, 'pdf');
      expect(
        controller.messages.last.content,
        'I created the PDF and attached it above.',
      );
    },
  );

  test(
    'docx requests synthesize markdown locally when the model reasons about tool use but never emits a tool call',
    () async {
      final client = SequencedFakeChatCompletionClient(
        results: <SarvamChatResult>[
          const SarvamChatResult(
            content:
                'I will prepare a DOCX file about my capabilities and use cases.',
            model: 'sarvam-105b',
            completionTokens: 12,
          ),
          const SarvamChatResult(
            content: '',
            model: 'sarvam-105b',
            reasoningContent:
                'We need to create a DOCX file and call generate_docx with title and markdown_content.',
            completionTokens: 20,
          ),
          const SarvamChatResult(
            content:
                '# What I Can Do\n\n## Use Cases\n\n- Answer questions\n- Summarize information\n- Help with coding\n',
            model: 'sarvam-105b',
            completionTokens: 48,
          ),
        ],
      );
      final docGenerationService = FakeDocGenerationService();
      final controller = ChatSessionController(
        client: client,
        docGenerationService: docGenerationService,
        auditLogStore: FakeAuditLogStore(),
        agentTaskStore: FakeAgentTaskStore(),
        toolSelector: FakeToolSelector(
          selectedTools: const <String>['generate_docx'],
        ),
        workingMemoryStore: FakeWorkingMemoryStore(),
        semanticFactStore: FakeSemanticFactStore(),
      );
      const settings = NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-105b',
      );

      await controller.sendPrompt(
        'create a docx file with what you can do and your usecases in 1-2 pages.',
        settings,
      );
      await waitForMessageCompletion(controller);

      expect(docGenerationService.requests, hasLength(1));
      expect(
        docGenerationService.requests.single.title,
        'What I Can Do',
      );
      expect(controller.messages.last.generatedArtifacts, hasLength(1));
      expect(
        controller.messages.last.content,
        'I created the document and attached it above.',
      );
      expect(
        controller.messages.last.content.contains('did not emit a valid'),
        isFalse,
      );
    },
  );

  test(
    'docx requests recover when the model returns python-docx implementation code instead of an artifact',
    () async {
      final client = SequencedFakeChatCompletionClient(
        results: <SarvamChatResult>[
          const SarvamChatResult(
            content: '''
I'll create a comprehensive document about my capabilities and use cases.

```python
from docx import Document
from docx.shared import Pt

def create_capabilities_document():
    doc = Document()
    doc.add_heading("Nero Capabilities", 0)
```
''',
            model: 'sarvam-105b',
            completionTokens: 64,
          ),
          const SarvamChatResult(
            content:
                '# Nero Capabilities\n\n## What I Can Do\n\n- Generate documents\n- Summarize content\n- Help with coding\n',
            model: 'sarvam-105b',
            completionTokens: 40,
          ),
        ],
      );
      final docGenerationService = FakeDocGenerationService();
      final controller = ChatSessionController(
        client: client,
        docGenerationService: docGenerationService,
        auditLogStore: FakeAuditLogStore(),
        agentTaskStore: FakeAgentTaskStore(),
        toolSelector: FakeToolSelector(
          selectedTools: const <String>['generate_docx'],
        ),
        workingMemoryStore: FakeWorkingMemoryStore(),
        semanticFactStore: FakeSemanticFactStore(),
      );
      const settings = NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-105b',
      );

      await controller.sendPrompt(
        'I want a doc with details about what you can do and your capabilities, usecases.',
        settings,
      );
      await waitForMessageCompletion(controller);

      expect(docGenerationService.requests, hasLength(1));
      expect(controller.messages.last.generatedArtifacts, hasLength(1));
      expect(
        controller.messages.last.content,
        'I created the document and attached it above.',
      );
      expect(controller.messages.last.content.contains('```python'), isFalse);
      expect(controller.messages.last.content.contains('from docx import'), isFalse);
    },
  );

  test(
    'pdf capability questions answer directly instead of attempting artifact generation',
    () async {
      final client = FakeChatCompletionClient(
        result: const SarvamChatResult(
          content: 'Yes. I can create both DOCX and PDF files when you ask for actual content.',
          model: 'sarvam-105b',
          completionTokens: 14,
        ),
      );
      final controller = ChatSessionController(
        client: client,
        docGenerationService: FakeDocGenerationService(),
        localToolRuntimeService: FakeLocalToolRuntimeService(),
        auditLogStore: FakeAuditLogStore(),
        agentTaskStore: FakeAgentTaskStore(),
        toolSelector: FakeToolSelector(
          selectedTools: const <String>['generate_docx', 'generate_report_pdf'],
        ),
        workingMemoryStore: FakeWorkingMemoryStore(),
        semanticFactStore: FakeSemanticFactStore(),
      );
      const settings = NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-105b',
      );

      await controller.sendPrompt('can you create doc and pdf?', settings);
      await waitForMessageCompletion(controller);

      expect(controller.messages.last.generatedArtifacts, isEmpty);
      expect(
        controller.messages.last.content,
        contains('create both DOCX and PDF'),
      );
    },
  );

  test(
    'streamed duplicate doc tool events do not trip the repeat guard',
    () async {
      final client = FakeChatCompletionClient(
        result: const SarvamChatResult(
          content: 'unused fallback',
          model: 'sarvam-105b',
        ),
      );
      final streamingClient = SequencedFakeStreamingClient(
        rounds: <List<AgentStreamEvent>>[
          <AgentStreamEvent>[
            const ThinkingDeltaEvent('The user wants a DOCX'),
            const ThinkingDeltaEvent(
              'The user wants a DOCX document with GATE exam details.',
            ),
            const ToolCallFinalEvent(
              SarvamToolCall(
                id: 'tool_doc',
                name: 'generate_docx',
                arguments: <String, dynamic>{
                  'title': 'GATE CSE Guide',
                  'markdown_content': '# GATE CSE Guide\n\nSimple guide.',
                },
              ),
            ),
            const ToolCallFinalEvent(
              SarvamToolCall(
                id: 'tool_doc',
                name: 'generate_docx',
                arguments: <String, dynamic>{
                  'title': 'GATE CSE Guide',
                  'markdown_content': '# GATE CSE Guide\n\nSimple guide.',
                },
              ),
            ),
            const StreamFinishedEvent(
              finishReason: 'tool_calls',
              model: 'sarvam-105b',
            ),
          ],
          <AgentStreamEvent>[
            const ThinkingDeltaEvent('I have the document result.'),
            const ContentDeltaEvent(
              'I created the document and attached it above.',
            ),
            const UsageReportEvent(completionTokens: 12, totalTokens: 12),
            const StreamFinishedEvent(
              finishReason: 'stop',
              model: 'sarvam-105b',
            ),
          ],
        ],
      );
      final controller = ChatSessionController(
        client: client,
        streamingClient: streamingClient,
        docGenerationService: FakeDocGenerationService(),
        auditLogStore: FakeAuditLogStore(),
        agentTaskStore: FakeAgentTaskStore(),
        toolSelector: FakeToolSelector(
          selectedTools: const <String>['generate_docx'],
        ),
        workingMemoryStore: FakeWorkingMemoryStore(),
        semanticFactStore: FakeSemanticFactStore(),
      );
      const settings = NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-105b',
      );

      await controller.sendPrompt(
        'generate a docx with details of gate exam for CSE core student.',
        settings,
      );
      await waitForMessageCompletion(controller);

      expect(
        controller.messages.last.content,
        'I created the document and attached it above.',
      );
      expect(controller.messages.last.generatedArtifacts, hasLength(1));
      expect(
        controller.messages.last.content.contains('Cloud request failed'),
        isFalse,
      );
    },
  );

  test('tokenized reasoning deltas stay as one readable thought', () async {
    final client = FakeChatCompletionClient(
      result: const SarvamChatResult(
        content: 'unused fallback',
        model: 'sarvam-105b',
      ),
    );
    final streamingClient = FakeStreamingClient(
      events: <AgentStreamEvent>[
        const ThinkingDeltaEvent('The'),
        const ThinkingDeltaEvent(' user'),
        const ThinkingDeltaEvent(' wants'),
        const ThinkingDeltaEvent(' a'),
        const ThinkingDeltaEvent(' DOCX'),
        const ThinkingDeltaEvent(' document'),
        const ThinkingDeltaEvent(' with'),
        const ThinkingDeltaEvent(' details'),
        const ContentDeltaEvent(
          'I created the document and attached it above.',
        ),
        const StreamFinishedEvent(finishReason: 'stop', model: 'sarvam-105b'),
      ],
    );
    final controller = ChatSessionController(
      client: client,
      streamingClient: streamingClient,
      auditLogStore: FakeAuditLogStore(),
      agentTaskStore: FakeAgentTaskStore(),
      toolSelector: FakeToolSelector(),
      workingMemoryStore: FakeWorkingMemoryStore(),
      semanticFactStore: FakeSemanticFactStore(),
    );
    const settings = NeroSettings(
      azureApiKey: 'sk_test',
      selectedModelId: 'sarvam-105b',
    );

    unawaited(controller.sendPrompt('Generate a docx', settings));
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final streamingMessage = controller.messages.last;
    final thoughtActivity = streamingMessage.activities.firstWhere(
      (activity) => activity.type == ChatActivityType.thought,
    );
    expect(thoughtActivity.items.last.title, contains('DOCX document'));
    expect(thoughtActivity.items.last.title.contains('\nD\nO\nC'), isFalse);
    expect(thoughtActivity.items.last.title.contains('\nuser\nwants'), isFalse);

    await waitForMessageCompletion(controller);
  });

  test(
    'successful completion stores memory snapshot with completed status',
    () async {
      final workingMemoryStore = FakeWorkingMemoryStore();
      final client = FakeChatCompletionClient(
        result: const SarvamChatResult(
          content: 'Hello from Sarvam.',
          model: 'sarvam-30b',
          promptTokens: 10,
          completionTokens: 4,
          totalTokens: 14,
        ),
      );
      final controller = ChatSessionController(
        client: client,
        auditLogStore: FakeAuditLogStore(),
        agentTaskStore: FakeAgentTaskStore(),
        toolSelector: FakeToolSelector(),
        workingMemoryStore: workingMemoryStore,
        semanticFactStore: FakeSemanticFactStore(),
      );
      const settings = NeroSettings(
        azureApiKey: 'sk_test',
        selectedModelId: 'sarvam-30b',
      );

      await controller.sendPrompt('Say hello', settings);
      await waitForMessageCompletion(controller);

      expect(workingMemoryStore.snapshots, isNotEmpty);
      expect(workingMemoryStore.snapshots.last.metadata['status'], 'completed');
    },
  );
}

class FakeChatCompletionClient implements ChatCompletionClient {
  FakeChatCompletionClient({this.result, this.error});

  final SarvamChatResult? result;
  final Object? error;

  String? lastApiKey;
  String? lastModelId;
  List<ChatMessage> lastMessages = const <ChatMessage>[];

  @override
  Future<SarvamChatResult> completeChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  }) async {
    lastApiKey = apiKey;
    lastModelId = modelId;
    lastMessages = messages;
    if (error != null) {
      throw error!;
    }
    return result!;
  }

  @override
  void cancel() {}
}

class CountingChatCompletionClient implements ChatCompletionClient {
  CountingChatCompletionClient({required this.result});

  final SarvamChatResult result;
  int cancelCount = 0;

  @override
  Future<SarvamChatResult> completeChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  }) async {
    return result;
  }

  @override
  void cancel() {
    cancelCount += 1;
  }
}

class DeferredChatCompletionClient implements ChatCompletionClient {
  final Completer<SarvamChatResult> _completer = Completer<SarvamChatResult>();
  String? lastApiKey;
  String? lastModelId;
  List<ChatMessage> lastMessages = const <ChatMessage>[];
  bool cancelled = false;

  @override
  Future<SarvamChatResult> completeChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  }) {
    lastApiKey = apiKey;
    lastModelId = modelId;
    lastMessages = messages;
    return _completer.future;
  }

  void complete(SarvamChatResult result) {
    if (!_completer.isCompleted) {
      _completer.complete(result);
    }
  }

  @override
  void cancel() {
    cancelled = true;
  }
}

class FakeToolSelector extends ToolSelector {
  FakeToolSelector({this.selectedTools = const <String>[]})
    : super(
        client: FakeChatCompletionClient(
          result: const SarvamChatResult(content: '[]', model: 'sarvam-m'),
        ),
      );

  final List<String> selectedTools;

  @override
  Future<List<String>> selectTools({
    required String apiKey,
    required String prompt,
    required List<ChatMessage> recentMessages,
  }) async {
    return selectedTools;
  }
}

class FakeStreamingClient implements ChatStreamingClient {
  FakeStreamingClient({required this.events});

  final List<AgentStreamEvent> events;

  @override
  Stream<AgentStreamEvent> streamChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  }) async* {
    for (final event in events) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      yield event;
    }
  }

  @override
  void cancel() {}
}

class CountingStreamingClient implements ChatStreamingClient {
  int cancelCount = 0;

  @override
  Stream<AgentStreamEvent> streamChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  }) async* {}

  @override
  void cancel() {
    cancelCount += 1;
  }
}

class SequencedFakeStreamingClient implements ChatStreamingClient {
  SequencedFakeStreamingClient({required this.rounds});

  final List<List<AgentStreamEvent>> rounds;
  int _round = 0;

  @override
  Stream<AgentStreamEvent> streamChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  }) async* {
    final events = rounds[_round < rounds.length ? _round : rounds.length - 1];
    if (_round < rounds.length - 1) {
      _round += 1;
    }
    for (final event in events) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      yield event;
    }
  }

  @override
  void cancel() {}
}

class SequencedFakeChatCompletionClient implements ChatCompletionClient {
  SequencedFakeChatCompletionClient({required this.results});

  final List<SarvamChatResult> results;
  final List<List<ChatMessage>> recordedCalls = <List<ChatMessage>>[];
  final List<List<SarvamToolDefinition>> recordedToolDefinitions =
      <List<SarvamToolDefinition>>[];
  int _index = 0;

  @override
  Future<SarvamChatResult> completeChat({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    List<SarvamToolDefinition> tools = const <SarvamToolDefinition>[],
  }) async {
    recordedCalls.add(List<ChatMessage>.from(messages));
    recordedToolDefinitions.add(List<SarvamToolDefinition>.from(tools));
    final result = results[_index];
    if (_index < results.length - 1) {
      _index += 1;
    }
    return result;
  }

  @override
  void cancel() {}
}

class FakeDocGenerationService extends DocGenerationService {
  FakeDocGenerationService()
    : super(
        workspaceStore: FakeWorkspaceStore(),
        auditLogStore: FakeAuditLogStore(),
      );

  final List<DocRequest> requests = <DocRequest>[];

  @override
  Future<WorkspaceItem> generateDocx({
    required DocRequest request,
    String? conversationId,
    String? messageId,
  }) async {
    requests.add(request);
    return WorkspaceItem(
      id: 'artifact_doc',
      conversationId: conversationId ?? 'standalone',
      type: WorkspaceItemType.generatedArtifact,
      title: '${request.title}.docx',
      createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      localPath: 'C:/tmp/${request.title}.docx',
      extension: 'docx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      sizeBytes: 128,
    );
  }
}

class FakeLocalToolRuntimeService extends LocalToolRuntimeService {
  FakeLocalToolRuntimeService()
    : super(
        nativeBridgeService: FakeNativeBridgeService(),
        workspaceStore: FakeWorkspaceStore(),
        auditLogStore: FakeAuditLogStore(),
      );

  final List<runtime.ToolExecutionRequest> requests =
      <runtime.ToolExecutionRequest>[];

  @override
  Future<runtime.ToolExecutionResult> executeToolRequest({
    required runtime.ToolExecutionRequest request,
    void Function(runtime.RuntimeJobStatus status)? onStatusChange,
  }) async {
    requests.add(request);
    onStatusChange?.call(runtime.RuntimeJobStatus.running);
    onStatusChange?.call(runtime.RuntimeJobStatus.completed);
    return const runtime.ToolExecutionResult(
      jobId: 'job_pdf',
      status: runtime.RuntimeJobStatus.completed,
      artifacts: <runtime.GeneratedArtifactDescriptor>[
        runtime.GeneratedArtifactDescriptor(
          id: 'artifact_pdf',
          title: 'Capabilities PDF.pdf',
          kindLabel: 'PDF document',
          localPath: 'C:/tmp/Capabilities PDF.pdf',
          extension: 'pdf',
          mimeType: 'application/pdf',
          sizeBytes: 256,
        ),
      ],
    );
  }
}

class FailingDocGenerationService extends DocGenerationService {
  FailingDocGenerationService()
    : super(
        workspaceStore: FakeWorkspaceStore(),
        auditLogStore: FakeAuditLogStore(),
      );

  @override
  Future<WorkspaceItem> generateDocx({
    required DocRequest request,
    String? conversationId,
    String? messageId,
  }) async {
    throw StateError('disk full');
  }
}

class FakeWebToolService extends WebToolService {
  final List<String> searchedQueries = <String>[];

  @override
  Future<ToolExecutionResult> searchWeb({
    required String query,
    int limit = 5,
  }) async {
    searchedQueries.add(query);
    return const ToolExecutionResult(
      success: true,
      summary: 'Search completed.',
      formattedOutput: '### Search Results\n- Example result',
    );
  }
}

class FakeAgentTaskStore extends AgentTaskStore {
  @override
  Future<void> upsertTask(AgentTask task) async {}
}

class CapturingAgentTaskStore extends AgentTaskStore {
  AgentTask? lastTask;

  @override
  Future<void> upsertTask(AgentTask task) async {
    lastTask = task;
  }
}

class FakeWorkingMemoryStore extends WorkingMemoryStore {
  FakeWorkingMemoryStore() : super(database: null);

  final List<WorkingMemorySnapshot> snapshots = <WorkingMemorySnapshot>[];

  @override
  Future<void> upsertSnapshot(WorkingMemorySnapshot snapshot) async {
    snapshots.add(snapshot);
  }

  @override
  Future<WorkingMemorySnapshot?> latestSnapshotForTask(String taskId) async {
    return null;
  }
}

class FakeSemanticFactStore extends SemanticFactStore {
  FakeSemanticFactStore() : super(database: null);

  @override
  Future<void> upsertFact(SemanticFact fact) async {}

  @override
  Future<List<SemanticFact>> listFacts({
    required String scope,
    String? scopeId,
    int limit = 100,
  }) async {
    return const <SemanticFact>[];
  }
}

/// Waits until the controller has finished streaming its newest message.
///
/// Resolves as soon as the controller notifies a state change (via its
/// [ChangeNotifier] listener) rather than burning a fixed poll interval, so the
/// wait costs O(notifications) instead of O(elapsed / interval).
Future<void> waitForMessageCompletion(
  ChatSessionController controller, {
  Duration timeout = const Duration(seconds: 2),
}) {
  return until(
    () {
      final messages = controller.messages;
      return messages.isNotEmpty && !messages.last.isStreaming;
    },
    timeout: timeout,
    on: controller,
  );
}

/// Waits for [predicate] to become true.
///
/// When [on] is supplied the wait is driven by its notifications; a low-rate
/// timer acts as a safety net so a missed notification (or no [on] at all)
/// still resolves instead of hanging until [timeout].
Future<void> until(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 2),
  ChatSessionController? on,
}) async {
  if (predicate()) {
    return;
  }

  final completer = Completer<void>();
  void check() {
    if (!completer.isCompleted && predicate()) {
      completer.complete();
    }
  }

  on?.addListener(check);
  final safetyNet = Timer.periodic(
    const Duration(milliseconds: 10),
    (_) => check(),
  );
  try {
    await completer.future.timeout(timeout);
  } on TimeoutException {
    fail('Timed out waiting for condition.');
  } finally {
    safetyNet.cancel();
    on?.removeListener(check);
  }
}
