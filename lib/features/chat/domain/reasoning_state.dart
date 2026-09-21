/// Reasoning (extended thinking) state attached to an assistant message.
///
/// Replaces the old `thinkingSteps` string list, which conflated the model's
/// reasoning text with UI "steps" and could not represent streaming, segment
/// boundaries, duration or token usage.
library;

enum ReasoningStatus {
  /// Nothing has been requested yet.
  idle,

  /// Reasoning deltas are still arriving.
  streaming,

  /// Reasoning finished; the answer is being or has been produced.
  complete,

  /// The request failed while reasoning.
  failed,
}

ReasoningStatus reasoningStatusFromJson(String? value) {
  return switch (value) {
    'streaming' => ReasoningStatus.streaming,
    'complete' => ReasoningStatus.complete,
    'failed' => ReasoningStatus.failed,
    _ => ReasoningStatus.idle,
  };
}

String reasoningStatusToJson(ReasoningStatus status) {
  return switch (status) {
    ReasoningStatus.idle => 'idle',
    ReasoningStatus.streaming => 'streaming',
    ReasoningStatus.complete => 'complete',
    ReasoningStatus.failed => 'failed',
  };
}

/// One contiguous run of reasoning text.
///
/// The Responses API emits `reasoning_summary_part.added` boundaries, which map
/// naturally onto segments; each segment gets its own duration so the UI can
/// show "Thought for 3s" per part when a model returns several.
class ReasoningSegment {
  const ReasoningSegment({
    required this.text,
    this.startedAtEpochMs,
    this.durationMs,
  });

  final String text;
  final int? startedAtEpochMs;
  final int? durationMs;

  bool get isEmpty => text.trim().isEmpty;

  ReasoningSegment copyWith({
    String? text,
    int? startedAtEpochMs,
    int? durationMs,
  }) {
    return ReasoningSegment(
      text: text ?? this.text,
      startedAtEpochMs: startedAtEpochMs ?? this.startedAtEpochMs,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'text': text,
    'startedAtEpochMs': startedAtEpochMs,
    'durationMs': durationMs,
  };

  factory ReasoningSegment.fromJson(Map<String, dynamic> json) {
    return ReasoningSegment(
      text: json['text']?.toString() ?? '',
      startedAtEpochMs: (json['startedAtEpochMs'] as num?)?.toInt(),
      durationMs: (json['durationMs'] as num?)?.toInt(),
    );
  }
}

class ReasoningState {
  const ReasoningState({
    this.status = ReasoningStatus.idle,
    this.segments = const <ReasoningSegment>[],
    this.durationMs,
    this.reasoningTokens,
    this.phaseLabel,
    this.error,
  });

  final ReasoningStatus status;
  final List<ReasoningSegment> segments;

  /// Total wall-clock time spent reasoning, excluding time paused on tools.
  final int? durationMs;

  /// Estimated reasoning tokens (reasoning text is not always counted by the
  /// provider's usage block, so this is derived from character length).
  final int? reasoningTokens;

  /// Coarse phase derived from the runtime progress snapshot
  /// (`Planning`, `Searching`, `Writing`…).
  final String? phaseLabel;

  final String? error;

  bool get hasContent => segments.any((segment) => !segment.isEmpty);

  bool get isStreaming => status == ReasoningStatus.streaming;

  /// Full reasoning text, segments joined by a blank line.
  String get text {
    final buffer = StringBuffer();
    for (final segment in segments) {
      final trimmed = segment.text.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (buffer.isNotEmpty) {
        buffer.write('\n\n');
      }
      buffer.write(trimmed);
    }
    return buffer.toString();
  }

  int get segmentCount =>
      segments.where((segment) => segment.text.trim().isNotEmpty).length;

  ReasoningState copyWith({
    ReasoningStatus? status,
    List<ReasoningSegment>? segments,
    int? durationMs,
    int? reasoningTokens,
    String? phaseLabel,
    String? error,
    bool clearDurationMs = false,
    bool clearPhaseLabel = false,
    bool clearError = false,
  }) {
    return ReasoningState(
      status: status ?? this.status,
      segments: segments ?? this.segments,
      durationMs: clearDurationMs ? null : durationMs ?? this.durationMs,
      reasoningTokens: reasoningTokens ?? this.reasoningTokens,
      phaseLabel: clearPhaseLabel ? null : phaseLabel ?? this.phaseLabel,
      error: clearError ? null : error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'status': reasoningStatusToJson(status),
    'segments': segments.map((segment) => segment.toJson()).toList(
      growable: false,
    ),
    'durationMs': durationMs,
    'reasoningTokens': reasoningTokens,
    'phaseLabel': phaseLabel,
    'error': error,
  };

  factory ReasoningState.fromJson(Map<String, dynamic> json) {
    final rawSegments = json['segments'];
    return ReasoningState(
      status: reasoningStatusFromJson(json['status']?.toString()),
      segments: rawSegments is List
          ? rawSegments
                .whereType<Map>()
                .map(
                  (item) =>
                      ReasoningSegment.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const <ReasoningSegment>[],
      durationMs: (json['durationMs'] as num?)?.toInt(),
      reasoningTokens: (json['reasoningTokens'] as num?)?.toInt(),
      phaseLabel: json['phaseLabel']?.toString(),
      error: json['error']?.toString(),
    );
  }

  /// Backward-compatible bridge for history written before reasoning state
  /// existed: the old `thinkingSteps` list becomes one segment per step.
  static ReasoningState fromLegacyThinkingSteps(
    List<String> steps, {
    int? durationMs,
  }) {
    final segments = steps
        .map((step) => step.trim())
        .where((step) => step.isNotEmpty)
        .map((step) => ReasoningSegment(text: step))
        .toList(growable: false);
    if (segments.isEmpty) {
      return const ReasoningState();
    }
    return ReasoningState(
      status: ReasoningStatus.complete,
      segments: segments,
      durationMs: durationMs,
    );
  }
}
