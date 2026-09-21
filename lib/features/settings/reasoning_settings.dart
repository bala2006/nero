/// User preferences controlling how reasoning is requested and displayed.
library;

/// How much of the model's reasoning the chat transcript shows.
enum ReasoningDisplayMode {
  /// Reasoning blocks are expanded while streaming and stay expanded.
  always,

  /// Reasoning streams expanded, then collapses to a summary line.
  collapsed,

  /// Reasoning is captured and persisted but never rendered.
  hidden,
}

/// `reasoning.summary` value sent to the provider.
///
/// The Responses API only emits `response.reasoning_summary_text.delta` events
/// when a summary level is requested, so this must not be omitted.
enum ReasoningSummaryVerbosity {
  /// Let the provider pick the summary length.
  auto,

  /// Shortest useful summary.
  concise,

  /// Most detailed summary the model produces.
  detailed,

  /// Do not request reasoning summaries at all.
  none,
}

extension ReasoningDisplayModeX on ReasoningDisplayMode {
  String get name => switch (this) {
    ReasoningDisplayMode.always => 'always',
    ReasoningDisplayMode.collapsed => 'collapsed',
    ReasoningDisplayMode.hidden => 'hidden',
  };

  String get label => switch (this) {
    ReasoningDisplayMode.always => 'Always expanded',
    ReasoningDisplayMode.collapsed => 'Collapse when done',
    ReasoningDisplayMode.hidden => 'Hidden',
  };

  static ReasoningDisplayMode fromName(String? value) {
    return switch (value) {
      'always' => ReasoningDisplayMode.always,
      'hidden' => ReasoningDisplayMode.hidden,
      _ => ReasoningDisplayMode.collapsed,
    };
  }
}

extension ReasoningSummaryVerbosityX on ReasoningSummaryVerbosity {
  String get name => switch (this) {
    ReasoningSummaryVerbosity.auto => 'auto',
    ReasoningSummaryVerbosity.concise => 'concise',
    ReasoningSummaryVerbosity.detailed => 'detailed',
    ReasoningSummaryVerbosity.none => 'none',
  };

  String get label => switch (this) {
    ReasoningSummaryVerbosity.auto => 'Auto',
    ReasoningSummaryVerbosity.concise => 'Concise',
    ReasoningSummaryVerbosity.detailed => 'Detailed',
    ReasoningSummaryVerbosity.none => 'Off (fastest)',
  };

  static ReasoningSummaryVerbosity fromName(String? value) {
    return switch (value) {
      'concise' => ReasoningSummaryVerbosity.concise,
      'detailed' => ReasoningSummaryVerbosity.detailed,
      'none' => ReasoningSummaryVerbosity.none,
      _ => ReasoningSummaryVerbosity.auto,
    };
  }
}

/// Reasoning effort levels the Responses API accepts.
enum ReasoningEffort { minimal, low, medium, high }

extension ReasoningEffortX on ReasoningEffort {
  String get name => switch (this) {
    ReasoningEffort.minimal => 'minimal',
    ReasoningEffort.low => 'low',
    ReasoningEffort.medium => 'medium',
    ReasoningEffort.high => 'high',
  };

  String get label => switch (this) {
    ReasoningEffort.minimal => 'Minimal',
    ReasoningEffort.low => 'Low',
    ReasoningEffort.medium => 'Medium',
    ReasoningEffort.high => 'High',
  };

  String get description => switch (this) {
    ReasoningEffort.minimal => 'Fastest; least deliberation.',
    ReasoningEffort.low => 'Light deliberation for simple prompts.',
    ReasoningEffort.medium => 'Provider default balance.',
    ReasoningEffort.high => 'Deepest deliberation on complex tasks.',
  };

  static ReasoningEffort fromName(String? value) {
    return switch (value) {
      'minimal' => ReasoningEffort.minimal,
      'low' => ReasoningEffort.low,
      'medium' => ReasoningEffort.medium,
      _ => ReasoningEffort.high,
    };
  }
}

class ReasoningPreferences {
  const ReasoningPreferences({
    this.displayMode = ReasoningDisplayMode.collapsed,
    this.verbosity = ReasoningSummaryVerbosity.auto,
    this.effort = ReasoningEffort.high,
    this.keepExpandedOnComplete = false,
  });

  final ReasoningDisplayMode displayMode;
  final ReasoningSummaryVerbosity verbosity;
  final ReasoningEffort effort;

  /// When true the block stays open after reasoning finishes.
  final bool keepExpandedOnComplete;

  bool get isVisible => displayMode != ReasoningDisplayMode.hidden;

  bool get requestsSummary => verbosity != ReasoningSummaryVerbosity.none;

  ReasoningPreferences copyWith({
    ReasoningDisplayMode? displayMode,
    ReasoningSummaryVerbosity? verbosity,
    ReasoningEffort? effort,
    bool? keepExpandedOnComplete,
  }) {
    return ReasoningPreferences(
      displayMode: displayMode ?? this.displayMode,
      verbosity: verbosity ?? this.verbosity,
      effort: effort ?? this.effort,
      keepExpandedOnComplete:
          keepExpandedOnComplete ?? this.keepExpandedOnComplete,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'displayMode': displayMode.name,
    'verbosity': verbosity.name,
    'effort': effort.name,
    'keepExpandedOnComplete': keepExpandedOnComplete,
  };

  factory ReasoningPreferences.fromJson(Map<String, dynamic> json) {
    return ReasoningPreferences(
      displayMode: ReasoningDisplayModeX.fromName(
        json['displayMode']?.toString(),
      ),
      verbosity: ReasoningSummaryVerbosityX.fromName(
        json['verbosity']?.toString(),
      ),
      effort: ReasoningEffortX.fromName(json['effort']?.toString()),
      keepExpandedOnComplete: json['keepExpandedOnComplete'] == true,
    );
  }
}
