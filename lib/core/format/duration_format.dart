/// Duration and elapsed-time formatting helpers.
///
/// Consolidates the private `_formatReasoningLabel` and the ad-hoc second
/// formatting scattered through the chat presentation layer.
library;

/// `820ms`, `1.4s`, `12s`, `1m 05s`, `1h 04m`.
String formatDurationMs(int? durationMs) {
  if (durationMs == null || durationMs <= 0) {
    return '';
  }
  if (durationMs < 1000) {
    return '${durationMs}ms';
  }
  final seconds = durationMs / 1000;
  if (seconds < 60) {
    return seconds >= 10
        ? '${seconds.toStringAsFixed(0)}s'
        : '${seconds.toStringAsFixed(1)}s';
  }
  final totalSeconds = seconds.floor();
  final minutes = totalSeconds ~/ 60;
  final remainingSeconds = totalSeconds % 60;
  if (minutes < 60) {
    return '${minutes}m ${remainingSeconds.toString().padLeft(2, '0')}s';
  }
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return '${hours}h ${remainingMinutes.toString().padLeft(2, '0')}m';
}

/// Short form used inside compact headers: `0.4s`, `3s`, `12s`, `1m 5s`.
String formatDurationShort(int? durationMs) {
  if (durationMs == null || durationMs <= 0) {
    return '';
  }
  final seconds = durationMs / 1000;
  if (seconds < 10) {
    return '${seconds.toStringAsFixed(1)}s';
  }
  if (seconds < 60) {
    return '${seconds.toStringAsFixed(0)}s';
  }
  final totalSeconds = seconds.floor();
  return '${totalSeconds ~/ 60}m ${totalSeconds % 60}s';
}

/// Elapsed time between [from] and now (or [to] when supplied).
int elapsedMsSince(int fromEpochMs, {int? toEpochMs}) {
  final end = toEpochMs ?? DateTime.now().millisecondsSinceEpoch;
  final elapsed = end - fromEpochMs;
  return elapsed <= 0 ? 0 : elapsed;
}
