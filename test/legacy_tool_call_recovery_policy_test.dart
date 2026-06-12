import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/legacy_tool_call_recovery_policy.dart';

void main() {
  const policy = LegacyToolCallRecoveryPolicy();

  test('allows promotion for empty residual content', () {
    expect(
      policy.shouldPromoteRecoveredToolCalls(
        strippedContent: '',
        hasRecoveredToolCalls: true,
      ),
      isTrue,
    );
  });

  test('allows promotion for short migration-style lead-in text', () {
    expect(
      policy.shouldPromoteRecoveredToolCalls(
        strippedContent: 'I will create it.',
        hasRecoveredToolCalls: true,
      ),
      isTrue,
    );
  });

  test('blocks promotion for long mixed prose responses', () {
    expect(
      policy.shouldPromoteRecoveredToolCalls(
        strippedContent:
            'I will create the document after explaining the full plan, the sections, the capabilities, the use cases, and the exact structure in detail before I actually do the tool call.',
        hasRecoveredToolCalls: true,
      ),
      isFalse,
    );
  });
}
