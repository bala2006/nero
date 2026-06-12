/// Utilities for merging incremental reasoning / thinking deltas from the
/// streaming LLM into a coherent single buffer, and for computing token-rate
/// telemetry from request timing.
///
/// All methods are pure (no side effects).  Extracted from
/// [ChatSessionController] during the Phase 5 cleanliness pass.
class ReasoningDeltaMerger {
  const ReasoningDeltaMerger();

  // -------------------------------------------------------------------------
  // Reasoning delta merge
  // -------------------------------------------------------------------------

  /// Merges [delta] into [buffer].  The method deduplicates repeated content,
  /// handles suffix/prefix overlap, and decides whether the delta looks like
  /// an incremental reasoning token or a standalone sentence.
  void mergeDelta(StringBuffer buffer, String delta) {
    final raw = delta.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (raw.trim().isEmpty) {
      return;
    }
    final current = buffer.toString();
    final currentTrimmed = current.trim();
    final nextTrimmed = raw.trim();

    if (current.isEmpty) {
      buffer.write(raw.trimLeft());
      return;
    }

    // Exact duplicate or already a suffix of current
    if (nextTrimmed == currentTrimmed ||
        currentTrimmed.endsWith(nextTrimmed)) {
      return;
    }

    // Delta is a full replacement / extension of the current buffer
    if (raw.startsWith(current) || nextTrimmed.startsWith(currentTrimmed)) {
      buffer
        ..clear()
        ..write(raw.trimLeft());
      return;
    }

    // Partial overlap at suffix/prefix boundary
    final overlap = _suffixPrefixOverlap(currentTrimmed, nextTrimmed);
    if (overlap > 0) {
      buffer.write(nextTrimmed.substring(overlap));
      return;
    }

    // Short reasoning token — append with whitespace guard
    if (_looksLikeReasoningToken(raw)) {
      if (!_endsWithWhitespaceOrNewline(current) &&
          !_startsWithPunctuation(nextTrimmed)) {
        buffer.write(' ');
      }
      buffer.write(raw.trim());
      return;
    }

    // Treat as a new sentence / paragraph
    buffer
      ..write(current.endsWith('\n') ? '' : '\n')
      ..write(nextTrimmed);
  }

  // -------------------------------------------------------------------------
  // Token-rate telemetry
  // -------------------------------------------------------------------------

  /// Estimates a live tokens-per-second rate from the number of characters
  /// currently revealed and the total elapsed time since [requestStartedAt].
  double? liveTokensPerSecond({
    required int revealedLength,
    required DateTime? requestStartedAt,
  }) {
    if (requestStartedAt == null || revealedLength <= 0) return null;
    final elapsedMs =
        DateTime.now().difference(requestStartedAt).inMilliseconds;
    if (elapsedMs <= 0) return null;
    final estimated = _estimatedTokensFromCharacters(revealedLength);
    if (estimated <= 0) return null;
    return estimated / (elapsedMs / 1000);
  }

  /// Computes the final average tokens-per-second once [generatedTokens]
  /// and [requestStartedAt] are both known.
  double? averageTokensPerSecond({
    required int? generatedTokens,
    required DateTime? requestStartedAt,
  }) {
    if (requestStartedAt == null ||
        generatedTokens == null ||
        generatedTokens <= 0) {
      return null;
    }
    final elapsedMs =
        DateTime.now().difference(requestStartedAt).inMilliseconds;
    if (elapsedMs <= 0) return null;
    return generatedTokens / (elapsedMs / 1000);
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  int _suffixPrefixOverlap(String current, String next) {
    final maxLength =
        current.length < next.length ? current.length : next.length;
    for (var length = maxLength; length > 0; length -= 1) {
      if (current.substring(current.length - length) ==
          next.substring(0, length)) {
        return length;
      }
    }
    return 0;
  }

  bool _looksLikeReasoningToken(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length <= 4) return true;
    if (!trimmed.contains(' ') &&
        !trimmed.contains('\n') &&
        !_endsWithSentencePunctuation(trimmed)) {
      return true;
    }
    return false;
  }

  bool _endsWithWhitespaceOrNewline(String value) =>
      value.isNotEmpty && RegExp(r'\s$').hasMatch(value);

  bool _startsWithPunctuation(String value) =>
      value.isNotEmpty && RegExp(r'^[,.;:!?)]').hasMatch(value);

  bool _endsWithSentencePunctuation(String value) =>
      value.isNotEmpty && RegExp(r'[.!?:]$').hasMatch(value);

  /// Rough token count from character length: one token ≈ 4 characters.
  double _estimatedTokensFromCharacters(int charLength) {
    return (charLength / 4).clamp(0.0, double.maxFinite);
  }
}
