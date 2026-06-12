import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/auto_continuation_policy.dart';
import 'package:nero/features/chat/application/sarvam_api_client.dart';

void main() {
  const policy = AutoContinuationPolicy();

  test('continues when finish reason is length', () {
    final shouldContinue = policy.shouldAutoContinue(
      prompt: 'explain this',
      result: const SarvamChatResult(
        content: 'Partial answer',
        model: 'sarvam-105b',
        finishReason: 'length',
      ),
      accumulatedResponse: 'Partial answer',
      roundsUsed: 0,
      containsMermaid: (_) => false,
    );

    expect(shouldContinue, isTrue);
  });

  test('continues when answer looks truncated', () {
    final shouldContinue = policy.shouldAutoContinue(
      prompt: 'give me a list of examples',
      result: const SarvamChatResult(
        content: '1. First example\n2. Second example and',
        model: 'sarvam-105b',
      ),
      accumulatedResponse: '1. First example\n2. Second example and',
      roundsUsed: 0,
      containsMermaid: (_) => false,
    );

    expect(shouldContinue, isTrue);
  });

  test('continues when diagram prompt lacks mermaid output', () {
    final shouldContinue = policy.shouldAutoContinue(
      prompt: 'show architecture diagram',
      result: const SarvamChatResult(
        content: 'Architecture overview follows.',
        model: 'sarvam-105b',
      ),
      accumulatedResponse: 'Architecture overview follows.',
      roundsUsed: 0,
      containsMermaid: (_) => false,
    );

    expect(shouldContinue, isTrue);
  });

  test('does not continue after max rounds or when tool calls were used', () {
    expect(
      policy.shouldAutoContinue(
        prompt: 'continue',
        result: const SarvamChatResult(
          content: 'Done.',
          model: 'sarvam-105b',
          toolCalls: <SarvamToolCall>[
            SarvamToolCall(id: '1', name: 'search_web', arguments: <String, dynamic>{}),
          ],
        ),
        accumulatedResponse: 'Done.',
        roundsUsed: 0,
        containsMermaid: (_) => false,
      ),
      isFalse,
    );

    expect(
      policy.shouldAutoContinue(
        prompt: 'continue',
        result: const SarvamChatResult(
          content: 'Done.',
          model: 'sarvam-105b',
        ),
        accumulatedResponse: 'Done.',
        roundsUsed: 3,
        containsMermaid: (_) => false,
      ),
      isFalse,
    );
  });
}
