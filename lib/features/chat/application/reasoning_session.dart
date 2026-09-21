import '../../../core/format/token_format.dart';
import '../domain/reasoning_state.dart';
import 'reasoning_delta_merger.dart';

/// Accumulates streamed reasoning deltas into a [ReasoningState].
///
/// This replaces the old behaviour where every reasoning chunk was merged into
/// a single string and then surfaced as one "thought step". The session keeps
/// segment boundaries (from `reasoning_summary_part.added`), tracks wall-clock
/// duration while excluding time spent paused on tool calls, and estimates
/// reasoning tokens.
class ReasoningSession {
  ReasoningSession({this.merger = const ReasoningDeltaMerger()});

  final ReasoningDeltaMerger merger;

  ReasoningStatus _status = ReasoningStatus.idle;
  final List<ReasoningSegment> _segments = <ReasoningSegment>[];
  final StringBuffer _current = StringBuffer();
  int? _currentStartedAtEpochMs;
  int _accumulatedMs = 0;
  int? _activeSinceEpochMs;
  String? _phaseLabel;
  String? _error;
  int? _providerReasoningTokens;

  ReasoningStatus get status => _status;

  bool get hasContent =>
      _current.toString().trim().isNotEmpty ||
      _segments.any((segment) => segment.text.trim().isNotEmpty);

  /// Starts a new reasoning session for one assistant turn.
  void begin({int? startedAtEpochMs, String? phaseLabel}) {
    clear();
    _status = ReasoningStatus.streaming;
    _currentStartedAtEpochMs =
        startedAtEpochMs ?? DateTime.now().millisecondsSinceEpoch;
    _phaseLabel = phaseLabel;
    _activeSinceEpochMs = DateTime.now().millisecondsSinceEpoch;
  }

  /// Feeds one reasoning delta. Empty/whitespace deltas are ignored.
  void appendDelta(String delta) {
    if (delta.trim().isEmpty) {
      return;
    }
    if (_status == ReasoningStatus.idle) {
      begin();
    } else if (_status != ReasoningStatus.streaming) {
      // Late deltas after completion should not resurrect a finished block.
      return;
    }
    _resumeIfNeeded();
    merger.mergeDelta(_current, delta);
  }

  /// Closes the in-flight segment and starts a fresh one. Called when the
  /// provider signals `reasoning_summary_part.added`.
  void beginSegment() {
    if (_current.toString().trim().isEmpty) {
      _current.clear();
      return;
    }
    _flushCurrentSegment();
    _currentStartedAtEpochMs = DateTime.now().millisecondsSinceEpoch;
  }

  /// Updates the coarse phase label shown next to the thinking indicator.
  void setPhase(String? label) {
    final normalized = label?.trim();
    _phaseLabel = (normalized == null || normalized.isEmpty)
        ? null
        : normalized;
  }

  /// Records provider-reported reasoning tokens when the usage block has them.
  void setReasoningTokens(int? tokens) {
    if (tokens == null || tokens <= 0) {
      return;
    }
    _providerReasoningTokens = tokens;
  }

  /// Stops the duration clock (e.g. while a tool call runs).
  void pause() {
    final activeSince = _activeSinceEpochMs;
    if (activeSince == null) {
      return;
    }
    final elapsed = DateTime.now().millisecondsSinceEpoch - activeSince;
    if (elapsed > 0) {
      _accumulatedMs += elapsed;
    }
    _activeSinceEpochMs = null;
  }

  /// Restarts the duration clock.
  void resume() {
    _resumeIfNeeded();
  }

  /// Marks reasoning as finished and freezes the duration/segment list.
  void complete() {
    if (_status == ReasoningStatus.complete) {
      return;
    }
    pause();
    _flushCurrentSegment();
    if (_status != ReasoningStatus.failed) {
      _status = ReasoningStatus.complete;
    }
  }

  /// Marks reasoning as failed, preserving whatever was captured.
  void fail(String error) {
    pause();
    _flushCurrentSegment();
    _status = ReasoningStatus.failed;
    _error = error;
  }

  /// Immutable snapshot for rendering and persistence.
  ReasoningState snapshot() {
    final segments = <ReasoningSegment>[
      ..._segments,
      if (_current.toString().trim().isNotEmpty)
        ReasoningSegment(
          text: _current.toString(),
          startedAtEpochMs: _currentStartedAtEpochMs,
          durationMs: _currentSegmentDurationMs(),
        ),
    ];
    final durationMs = _liveDurationMs();
    return ReasoningState(
      status: _status,
      segments: List<ReasoningSegment>.unmodifiable(segments),
      durationMs: durationMs,
      reasoningTokens: _resolvedReasoningTokens(segments),
      phaseLabel: _phaseLabel,
      error: _error,
    );
  }

  void clear() {
    _status = ReasoningStatus.idle;
    _segments.clear();
    _current.clear();
    _currentStartedAtEpochMs = null;
    _accumulatedMs = 0;
    _activeSinceEpochMs = null;
    _phaseLabel = null;
    _error = null;
    _providerReasoningTokens = null;
  }

  void _resumeIfNeeded() {
    _activeSinceEpochMs ??= DateTime.now().millisecondsSinceEpoch;
  }

  void _flushCurrentSegment() {
    final text = _current.toString();
    if (text.trim().isNotEmpty) {
      _segments.add(
        ReasoningSegment(
          text: text,
          startedAtEpochMs: _currentStartedAtEpochMs,
          durationMs: _currentSegmentDurationMs(),
        ),
      );
    }
    _current.clear();
    _currentStartedAtEpochMs = null;
  }

  int? _liveDurationMs() {
    var total = _accumulatedMs;
    final activeSince = _activeSinceEpochMs;
    if (activeSince != null) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - activeSince;
      if (elapsed > 0) {
        total += elapsed;
      }
    }
    return total <= 0 ? null : total;
  }

  int? _currentSegmentDurationMs() {
    final startedAt = _currentStartedAtEpochMs;
    if (startedAt == null) {
      return null;
    }
    final elapsed = DateTime.now().millisecondsSinceEpoch - startedAt;
    return elapsed <= 0 ? null : elapsed;
  }

  int? _resolvedReasoningTokens(List<ReasoningSegment> segments) {
    final providerValue = _providerReasoningTokens;
    if (providerValue != null && providerValue > 0) {
      return providerValue;
    }
    final characterCount = segments.fold<int>(
      0,
      (total, segment) => total + segment.text.trim().length,
    );
    if (characterCount <= 0) {
      return null;
    }
    final estimated = estimatedTokensFromCharacters(characterCount);
    return estimated <= 0 ? null : estimated;
  }
}
