import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/sarvam_api_client.dart';
import 'package:nero/features/chat/application/tool_selector.dart';
import 'package:nero/features/chat/domain/chat_message.dart';

void main() {
  test('explicit empty selector output remains authoritative', () async {
    final selector = ToolSelector(
      client: _FakeSelectorClient(
        result: const SarvamChatResult(content: '[]', model: 'sarvam-m'),
      ),
    );

    final selected = await selector.selectTools(
      apiKey: 'sk_test',
      prompt: 'hello',
      recentMessages: const <ChatMessage>[],
    );

    expect(selected, isEmpty);
  });

  test('malformed selector output does not fall back to every tool', () async {
    final selector = ToolSelector(
      client: _FakeSelectorClient(
        result: const SarvamChatResult(content: 'not-json', model: 'sarvam-m'),
      ),
    );

    final selected = await selector.selectTools(
      apiKey: 'sk_test',
      prompt: 'hi',
      recentMessages: const <ChatMessage>[],
    );

    expect(selected, isEmpty);
  });

  test('selector debug metadata captures parse fallback telemetry', () async {
    final selector = ToolSelector(
      client: _FakeSelectorClient(
        result: const SarvamChatResult(content: 'not-json', model: 'sarvam-m'),
      ),
    );

    final decision = await selector.selectDecision(
      apiKey: 'sk_test',
      prompt: 'hi',
      recentMessages: const <ChatMessage>[],
    );

    expect(decision.strategy, 'model_plus_classifier');
    expect(
      decision.strategyDetails['selector_response_kind'],
      'parse_error_fallback',
    );
    expect(decision.strategyDetails['heuristic_added_tools'], isA<List>());
  });

  test('doc requests still include generate_docx when selector model returns empty', () async {
    final selector = ToolSelector(
      client: _FakeSelectorClient(
        result: const SarvamChatResult(content: '[]', model: 'sarvam-m'),
      ),
    );

    final selected = await selector.selectTools(
      apiKey: 'sk_test',
      prompt: 'generate the doc about your capabilities',
      recentMessages: const <ChatMessage>[],
    );

    expect(selected, contains('generate_docx'));
  });

  test('docx requests preserve mandatory output tool even with unrelated selector output', () async {
    final selector = ToolSelector(
      client: _FakeSelectorClient(
        result: const SarvamChatResult(
          content: '["search_web"]',
          model: 'sarvam-m',
        ),
      ),
    );

    final selected = await selector.selectTools(
      apiKey: 'sk_test',
      prompt: 'create a docx with one page about your capabilities',
      recentMessages: const <ChatMessage>[],
    );

    expect(selected, contains('generate_docx'));
  });

  test('docx requests record mandatory tool additions in telemetry', () async {
    final selector = ToolSelector(
      client: _FakeSelectorClient(
        result: const SarvamChatResult(
          content: '["search_web"]',
          model: 'sarvam-m',
        ),
      ),
    );

    final decision = await selector.selectDecision(
      apiKey: 'sk_test',
      prompt: 'create a docx with one page about your capabilities',
      recentMessages: const <ChatMessage>[],
    );

    expect(
      (decision.strategyDetails['mandatory_added_tools'] as List),
      contains('generate_docx'),
    );
  });

  test('artifact capability questions do not force output tools', () async {
    final selector = ToolSelector(
      client: _FakeSelectorClient(
        result: const SarvamChatResult(
          content: '["generate_docx", "generate_report_pdf"]',
          model: 'sarvam-m',
        ),
      ),
    );

    final selected = await selector.selectTools(
      apiKey: 'sk_test',
      prompt: 'Can you generate doc? pdf?',
      recentMessages: const <ChatMessage>[],
    );

    expect(selected, isEmpty);
  });

  test('artifact capability questions record suppressed output tools in telemetry', () async {
    final selector = ToolSelector(
      client: _FakeSelectorClient(
        result: const SarvamChatResult(
          content: '["generate_docx", "generate_report_pdf"]',
          model: 'sarvam-m',
        ),
      ),
    );

    final decision = await selector.selectDecision(
      apiKey: 'sk_test',
      prompt: 'Can you generate doc? pdf?',
      recentMessages: const <ChatMessage>[],
    );

    expect(decision.strategy, 'classification_only');
    expect(
      (decision.strategyDetails['suppressed_tools'] as List),
      contains('generate_docx'),
    );
  });

  test('exact doc and pdf capability prompt does not force output tools', () async {
    final selector = ToolSelector(
      client: _FakeSelectorClient(
        result: const SarvamChatResult(
          content: '["generate_report_pdf"]',
          model: 'sarvam-m',
        ),
      ),
    );

    final selected = await selector.selectTools(
      apiKey: 'sk_test',
      prompt: 'can you create doc and pdf?',
      recentMessages: const <ChatMessage>[],
    );

    expect(selected, isEmpty);
  });

  test('i want a doc request still selects generate_docx', () async {
    final selector = ToolSelector(
      client: _FakeSelectorClient(
        result: const SarvamChatResult(content: '[]', model: 'sarvam-m'),
      ),
    );

    final selected = await selector.selectTools(
      apiKey: 'sk_test',
      prompt: 'I want a doc with details about your capabilities.',
      recentMessages: const <ChatMessage>[],
    );

    expect(selected, contains('generate_docx'));
  });

  test('short concrete doc question is artifact generation, not capability only', () async {
    final selector = ToolSelector(
      client: _FakeSelectorClient(
        result: const SarvamChatResult(content: '[]', model: 'sarvam-m'),
      ),
    );

    final decision = await selector.selectDecision(
      apiKey: 'sk_test',
      prompt: 'Can you create a doc about Flutter performance?',
      recentMessages: const <ChatMessage>[],
    );

    expect(decision.requestKind.name, 'artifactGeneration');
    expect(decision.artifactKind.name, 'docx');
    expect(decision.expectsArtifact, isTrue);
    expect(decision.requiresSideEffect, isTrue);
    expect(decision.finalAnswerMode.name, 'runtimeAssembled');
    expect(decision.fallbackPolicy.name, 'artifactStrictError');
    expect(decision.selectedTools, contains('generate_docx'));
  });

  test('research comparison prompts classify as research and select web tools', () async {
    final selector = ToolSelector(
      client: _FakeSelectorClient(
        result: const SarvamChatResult(content: '[]', model: 'sarvam-m'),
      ),
    );

    final decision = await selector.selectDecision(
      apiKey: 'sk_test',
      prompt: 'research and find out the difference between claude and open ai',
      recentMessages: const <ChatMessage>[],
    );

    expect(decision.classification.requestKind.name, 'researchAnswer');
    expect(decision.classification.requiresExternalContext, isTrue);
    expect(decision.requiresExternalContext, isTrue);
    expect(decision.requiresSideEffect, isFalse);
    expect(decision.expectsArtifact, isFalse);
    expect(decision.confidence, greaterThan(0));
    expect(decision.toDebugMetadata()['strategy'], 'model_plus_classifier');
    expect(decision.toDebugMetadata()['fallback_policy'], 'repairToolPlan');
    expect(decision.selectedTools, contains('search_web'));
  });

  test('hybrid research document request exposes typed decision metadata', () async {
    final selector = ToolSelector(
      client: _FakeSelectorClient(
        result: const SarvamChatResult(content: '[]', model: 'sarvam-m'),
      ),
    );

    final decision = await selector.selectDecision(
      apiKey: 'sk_test',
      prompt: 'Research current Flutter testing guidance and create a docx report',
      recentMessages: const <ChatMessage>[],
    );

    expect(decision.requestKind.name, 'hybrid');
    expect(decision.artifactKind.name, 'docx');
    expect(decision.requiresExternalContext, isTrue);
    expect(decision.requiresSideEffect, isTrue);
    expect(decision.expectsArtifact, isTrue);
    expect(decision.finalAnswerMode.name, 'hybrid');
    expect(decision.selectedTools, containsAll(<String>['search_web', 'generate_docx']));
    expect(decision.toDebugMetadata()['request_kind'], 'hybrid');
  });
}

class _FakeSelectorClient implements ChatCompletionClient {
  _FakeSelectorClient({required this.result});

  final SarvamChatResult result;

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
  void cancel() {}
}
