import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/docs/application/artifact_fallback_coordinator.dart';
import 'package:nero/features/chat/application/sarvam_api_client.dart';
import 'package:nero/features/chat/domain/chat_message.dart';

void main() {
  const coordinator = ArtifactFallbackCoordinator();

  test('returns existing artifact acknowledgement when artifact already exists', () async {
    final result = await coordinator.completePendingArtifact(
      prompt: 'create a doc about capabilities',
      outputTool: 'generate_docx',
      requestMessages: const <ChatMessage>[],
      currentResponse: '',
      availableTools: const <SarvamToolDefinition>[],
      documentGenerationAlreadyAttempted: false,
      alreadyHasArtifact: true,
      executeAssistantRound:
          ({
            required List<ChatMessage> requestMessages,
            required List<SarvamToolDefinition> tools,
            required StringBuffer responseBuffer,
          }) async => throw UnimplementedError(),
      findToolCall: (_, __) async => null,
      executeToolCall: (_) async => throw UnimplementedError(),
      recoverArtifactFromMarkdown: (_, __) async => null,
      forcedInstruction: 'call tool now',
    );

    expect(result?.finalResponse, 'I created the document and attached it above.');
  });

  test('returns strict error when tool call is missing', () async {
    final result = await coordinator.completePendingArtifact(
      prompt: 'create a doc about capabilities',
      outputTool: 'generate_docx',
      requestMessages: const <ChatMessage>[],
      currentResponse: '',
      availableTools: const <SarvamToolDefinition>[
        SarvamToolDefinition(
          name: 'generate_docx',
          description: 'Create a docx',
          parameters: <String, dynamic>{},
        ),
      ],
      documentGenerationAlreadyAttempted: false,
      alreadyHasArtifact: false,
      executeAssistantRound:
          ({
            required List<ChatMessage> requestMessages,
            required List<SarvamToolDefinition> tools,
            required StringBuffer responseBuffer,
          }) async => const SarvamChatResult(
            content: '# Capabilities\n\n- Search\n- Docs',
            toolCalls: <SarvamToolCall>[],
            promptTokens: 1,
            completionTokens: 1,
            totalTokens: 2,
            model: 'model',
            finishReason: 'stop',
          ),
      findToolCall: (_, __) async => null,
      executeToolCall:
          (_) async => const ToolExecutionOutcome(
            success: false,
            formattedOutput: '',
            generatedArtifactCount: 0,
          ),
      recoverArtifactFromMarkdown: (_, __) async => null,
      forcedInstruction: 'call tool now',
    );

    expect(
      result?.finalResponse,
      contains('could not complete the requested file artifact'),
    );
    expect(result?.stepDetail, contains('no valid tool call'));
    expect(result?.errorMessage, contains('could not be created'));
  });

  test('returns strict error when tool execution does not create an artifact', () async {
    final result = await coordinator.completePendingArtifact(
      prompt: 'create a pdf about capabilities',
      outputTool: 'generate_report_pdf',
      requestMessages: const <ChatMessage>[],
      currentResponse: 'We need to call generate_report_pdf with title and markdown_content.',
      availableTools: const <SarvamToolDefinition>[
        SarvamToolDefinition(
          name: 'generate_report_pdf',
          description: 'Create a pdf',
          parameters: <String, dynamic>{},
        ),
      ],
      documentGenerationAlreadyAttempted: false,
      alreadyHasArtifact: false,
      executeAssistantRound:
          ({
            required List<ChatMessage> requestMessages,
            required List<SarvamToolDefinition> tools,
            required StringBuffer responseBuffer,
          }) async => const SarvamChatResult(
            content: '',
            toolCalls: <SarvamToolCall>[
              SarvamToolCall(
                id: 'pdf_1',
                name: 'generate_report_pdf',
                arguments: <String, dynamic>{
                  'title': 'Capabilities',
                  'markdown_content': '# Capabilities',
                },
              ),
            ],
            promptTokens: 1,
            completionTokens: 1,
            totalTokens: 2,
            model: 'model',
            finishReason: 'stop',
          ),
      findToolCall: (result, _) async => result.toolCalls.single,
      executeToolCall:
          (_) async => const ToolExecutionOutcome(
            success: false,
            formattedOutput: 'PDF generation failed.',
            generatedArtifactCount: 0,
          ),
      recoverArtifactFromMarkdown: (_, __) async => null,
      forcedInstruction: 'call tool now',
    );

    expect(
      result?.finalResponse,
      contains('native file generation did not produce an artifact'),
    );
    expect(result?.stepDetail, 'PDF generation failed.');
    expect(result?.errorMessage, 'PDF generation failed.');
  });

  test('recovers by generating an artifact from validated markdown response', () async {
    final result = await coordinator.completePendingArtifact(
      prompt: 'create a doc about capabilities',
      outputTool: 'generate_docx',
      requestMessages: const <ChatMessage>[],
      currentResponse: '',
      availableTools: const <SarvamToolDefinition>[
        SarvamToolDefinition(
          name: 'generate_docx',
          description: 'Create a docx',
          parameters: <String, dynamic>{},
        ),
      ],
      documentGenerationAlreadyAttempted: false,
      alreadyHasArtifact: false,
      executeAssistantRound:
          ({
            required List<ChatMessage> requestMessages,
            required List<SarvamToolDefinition> tools,
            required StringBuffer responseBuffer,
          }) async => const SarvamChatResult(
            content: '# Capabilities\n\n- Search\n- Docs',
            toolCalls: <SarvamToolCall>[],
            promptTokens: 1,
            completionTokens: 1,
            totalTokens: 2,
            model: 'model',
            finishReason: 'stop',
          ),
      findToolCall: (_, __) async => null,
      executeToolCall: (_) async => throw UnimplementedError(),
      recoverArtifactFromMarkdown:
          (result, outputTool) async => const ToolExecutionOutcome(
            success: true,
            formattedOutput: 'Created file.',
            generatedArtifactCount: 1,
          ),
      forcedInstruction: 'call tool now',
    );

    expect(result?.finalResponse, 'I created the document and attached it above.');
    expect(
      result?.stepDetail,
      'File artifact generated successfully from validated markdown.',
    );
  });

  test('skips invalid current prose and falls through to forced tool execution', () async {
    var assistantRoundCalled = false;
    var markdownRecoveryCalled = false;
    final result = await coordinator.completePendingArtifact(
      prompt: 'create a doc about capabilities',
      outputTool: 'generate_docx',
      requestMessages: const <ChatMessage>[],
      currentResponse:
          'I will create a comprehensive document about my capabilities and tools.',
      availableTools: const <SarvamToolDefinition>[
        SarvamToolDefinition(
          name: 'generate_docx',
          description: 'Create a docx',
          parameters: <String, dynamic>{},
        ),
      ],
      documentGenerationAlreadyAttempted: false,
      alreadyHasArtifact: false,
      executeAssistantRound:
          ({
            required List<ChatMessage> requestMessages,
            required List<SarvamToolDefinition> tools,
            required StringBuffer responseBuffer,
          }) async {
            assistantRoundCalled = true;
            return const SarvamChatResult(
              content: '',
              toolCalls: <SarvamToolCall>[
                SarvamToolCall(
                  id: 'doc_1',
                  name: 'generate_docx',
                  arguments: <String, dynamic>{
                    'title': 'Capabilities',
                    'markdown_content': '# Capabilities\n\n- Search\n- Docs',
                  },
                ),
              ],
              model: 'model',
            );
          },
      findToolCall: (result, _) async => result.toolCalls.single,
      executeToolCall:
          (_) async => const ToolExecutionOutcome(
            success: true,
            formattedOutput: 'Created file.',
            generatedArtifactCount: 1,
          ),
      recoverArtifactFromMarkdown: (_, __) async {
        markdownRecoveryCalled = true;
        return const ToolExecutionOutcome(
          success: false,
          formattedOutput: 'should not be used for planning prose',
          generatedArtifactCount: 0,
        );
      },
      forcedInstruction: 'call tool now',
    );

    expect(assistantRoundCalled, isTrue);
    expect(markdownRecoveryCalled, isFalse);
    expect(result?.finalResponse, 'I created the document and attached it above.');
  });
}
