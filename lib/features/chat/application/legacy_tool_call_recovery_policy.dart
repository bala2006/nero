class LegacyToolCallRecoveryPolicy {
  const LegacyToolCallRecoveryPolicy();

  bool shouldPromoteRecoveredToolCalls({
    required String strippedContent,
    required bool hasRecoveredToolCalls,
  }) {
    if (!hasRecoveredToolCalls) {
      return false;
    }
    final residual = strippedContent.trim();
    if (residual.isEmpty) {
      return true;
    }
    if (residual.length > 120 || residual.split(RegExp(r'\s+')).length > 12) {
      return false;
    }
    if (residual.contains('```') ||
        residual.contains('# ') ||
        residual.contains('class ') ||
        residual.contains('import ') ||
        residual.contains('def ') ||
        residual.contains('function ')) {
      return false;
    }
    return true;
  }
}
