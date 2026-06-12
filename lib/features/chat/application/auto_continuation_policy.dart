import 'sarvam_api_client.dart';

class AutoContinuationPolicy {
  const AutoContinuationPolicy({this.maxRounds = 3});

  final int maxRounds;

  bool shouldAutoContinue({
    required String prompt,
    required SarvamChatResult result,
    required String accumulatedResponse,
    required int roundsUsed,
    required bool Function(String content) containsMermaid,
    bool expectsArtifact = false,
    bool artifactProduced = false,
  }) {
    if (result.toolCalls.isNotEmpty) {
      return false;
    }

    // Force continuation if an artifact was expected but not produced
    // (no tool call made and no markdown recovered yet).
    if (expectsArtifact && !artifactProduced && roundsUsed < maxRounds) {
      return true;
    }

    if (roundsUsed >= maxRounds) {
      return false;
    }
    final finishReason = result.finishReason?.trim().toLowerCase();
    if (finishReason == 'length' || finishReason == 'max_tokens') {
      return true;
    }
    final completionTokens = result.completionTokens;
    if (completionTokens != null && completionTokens >= 1900) {
      return true;
    }
    if (accumulatedResponse.trim().isEmpty) {
      return false;
    }
    if (_looksTruncated(accumulatedResponse)) {
      return true;
    }
    if (_looksAbruptForPrompt(
      prompt: prompt,
      accumulatedResponse: accumulatedResponse,
      containsMermaid: containsMermaid,
    )) {
      return true;
    }
    return false;
  }

  bool _looksTruncated(String content) {
    final trimmed = content.trimRight();
    if (trimmed.isEmpty) {
      return false;
    }
    if (_hasUnclosedCodeFence(trimmed)) {
      return true;
    }
    const incompleteEndings = <String>[
      '```',
      ':',
      ',',
      ';',
      '(',
      '[',
      '{',
      '-',
      'and',
      'or',
      'with',
      'where',
      'Visual Diagram:',
      'Code Solution:',
      'Problem Statement:',
    ];
    for (final ending in incompleteEndings) {
      if (trimmed.endsWith(ending)) {
        return true;
      }
    }
    final lastChar = trimmed.substring(trimmed.length - 1);
    const strongStops = <String>{'.', '!', '?', '`', ')', ']', '}'};
    return !strongStops.contains(lastChar);
  }

  bool _hasUnclosedCodeFence(String content) {
    return RegExp(r'```').allMatches(content).length.isOdd;
  }

  bool _looksAbruptForPrompt({
    required String prompt,
    required String accumulatedResponse,
    required bool Function(String content) containsMermaid,
  }) {
    final loweredPrompt = prompt.toLowerCase();
    final trimmed = accumulatedResponse.trimRight();
    if (trimmed.isEmpty) {
      return false;
    }

    final asksForDiagram =
        loweredPrompt.contains('diagram') ||
        loweredPrompt.contains('mermaid') ||
        loweredPrompt.contains('flowchart') ||
        loweredPrompt.contains('visual');
    if (asksForDiagram && !containsMermaid(trimmed)) {
      return true;
    }

    final asksForStructuredList =
        loweredPrompt.contains('top') ||
        loweredPrompt.contains('list') ||
        loweredPrompt.contains('questions') ||
        loweredPrompt.contains('problems') ||
        loweredPrompt.contains('examples');
    final endsAtFence = trimmed.endsWith('```');
    if (asksForStructuredList && endsAtFence) {
      return true;
    }

    return false;
  }
}
