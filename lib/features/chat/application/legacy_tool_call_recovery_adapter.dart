import 'inline_tool_call_compatibility_parser.dart';
import 'legacy_tool_call_recovery_policy.dart';
import 'sarvam_api_client.dart';

class LegacyToolCallRecoveryStats {
  const LegacyToolCallRecoveryStats({
    this.compatibilityMarkupDetected = false,
    this.strippedCompatibilityMarkup = false,
    this.recoveredToolCallCount = 0,
  });

  final bool compatibilityMarkupDetected;
  final bool strippedCompatibilityMarkup;
  final int recoveredToolCallCount;

  bool get usedCompatibilityRecovery =>
      compatibilityMarkupDetected &&
      (strippedCompatibilityMarkup || recoveredToolCallCount > 0);
}

class LegacyToolCallRecoveryOutcome {
  const LegacyToolCallRecoveryOutcome({
    required this.result,
    required this.stats,
  });

  final SarvamChatResult result;
  final LegacyToolCallRecoveryStats stats;
}

class LegacyToolCallRecoveryAdapter {
  const LegacyToolCallRecoveryAdapter({
    InlineToolCallCompatibilityParser parser =
        const InlineToolCallCompatibilityParser(),
    LegacyToolCallRecoveryPolicy policy =
        const LegacyToolCallRecoveryPolicy(),
  }) : _parser = parser,
       _policy = policy;

  final InlineToolCallCompatibilityParser _parser;
  final LegacyToolCallRecoveryPolicy _policy;

  SarvamChatResult recoverResult({
    required SarvamChatResult result,
    required String content,
    required Set<String> allowedToolNames,
    required Map<String, Set<String>> requiredToolArguments,
  }) {
    return recoverWithStats(
      result: result,
      content: content,
      allowedToolNames: allowedToolNames,
      requiredToolArguments: requiredToolArguments,
    ).result;
  }

  LegacyToolCallRecoveryOutcome recoverWithStats({
    required SarvamChatResult result,
    required String content,
    required Set<String> allowedToolNames,
    required Map<String, Set<String>> requiredToolArguments,
  }) {
    if (result.toolCalls.isNotEmpty || content.trim().isEmpty) {
      return LegacyToolCallRecoveryOutcome(
        result: result,
        stats: const LegacyToolCallRecoveryStats(),
      );
    }

    final extraction = _parser.extract(content);
    if (extraction.toolCalls.isEmpty) {
      return LegacyToolCallRecoveryOutcome(
        result: result,
        stats: const LegacyToolCallRecoveryStats(),
      );
    }

    final recoveredToolCalls = extraction.toolCalls
        .where((call) => allowedToolNames.contains(call.name))
        .where(
          (call) => _hasRequiredToolArguments(
            call,
            requiredToolArguments[call.name],
          ),
        )
        .toList(growable: false);
    final allowPromotion = _policy.shouldPromoteRecoveredToolCalls(
      strippedContent: extraction.content,
      hasRecoveredToolCalls: recoveredToolCalls.isNotEmpty,
    );
    if (recoveredToolCalls.isEmpty) {
      return LegacyToolCallRecoveryOutcome(
        result: result.copyWith(content: extraction.content),
        stats: const LegacyToolCallRecoveryStats(
          compatibilityMarkupDetected: true,
          strippedCompatibilityMarkup: true,
        ),
      );
    }
    if (!allowPromotion) {
      return LegacyToolCallRecoveryOutcome(
        result: result.copyWith(content: extraction.content),
        stats: const LegacyToolCallRecoveryStats(
          compatibilityMarkupDetected: true,
          strippedCompatibilityMarkup: true,
        ),
      );
    }

    return LegacyToolCallRecoveryOutcome(
      result: result.copyWith(
        content: extraction.content,
        toolCalls: recoveredToolCalls,
        finishReason: 'tool_calls',
      ),
      stats: LegacyToolCallRecoveryStats(
        compatibilityMarkupDetected: true,
        strippedCompatibilityMarkup: true,
        recoveredToolCallCount: recoveredToolCalls.length,
      ),
    );
  }

  bool _hasRequiredToolArguments(
    SarvamToolCall call,
    Set<String>? requiredArguments,
  ) {
    if (requiredArguments == null || requiredArguments.isEmpty) {
      return true;
    }
    return requiredArguments.every((argument) {
      final value = call.arguments[argument];
      return value != null && value.toString().trim().isNotEmpty;
    });
  }
}
