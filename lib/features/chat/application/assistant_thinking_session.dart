import '../domain/chat_message.dart';

class AssistantThinkingSession {
  String? _currentThought;
  final List<String> _completedThoughts = <String>[];
  final List<ChatActivity> _activities = <ChatActivity>[];

  String? get currentThought => _currentThought;
  List<String> get completedThoughts =>
      List<String>.unmodifiable(_completedThoughts);
  List<ChatActivity> get activities => List<ChatActivity>.unmodifiable(_activities);

  void clear() {
    _currentThought = null;
    _completedThoughts.clear();
    _activities.clear();
  }

  bool updateCurrentThought(String? nextThought, {bool completeCurrent = false}) {
    final existing = normalizeThoughtText(_currentThought);
    if (completeCurrent && existing != null && existing.isNotEmpty) {
      if (_completedThoughts.isEmpty || _completedThoughts.last != existing) {
        _completedThoughts.add(existing);
      }
      _currentThought = null;
      return true;
    }

    final normalized = normalizeThoughtText(nextThought);
    if (normalized == null || normalized.isEmpty) {
      return false;
    }
    final isIncrementalUpdate =
        existing != null &&
        existing.isNotEmpty &&
        (normalized.startsWith(existing) || existing.startsWith(normalized));
    final isPlaceholder =
        existing == 'Planning response' ||
        existing == 'Thinking...' ||
        existing == 'Running tools';
    if (!isIncrementalUpdate &&
        !isPlaceholder &&
        existing != null &&
        existing.isNotEmpty &&
        existing != normalized) {
      if (_completedThoughts.isEmpty || _completedThoughts.last != existing) {
        _completedThoughts.add(existing);
      }
    }
    _currentThought = normalized;
    return true;
  }

  void recordToolActivity(ChatActivity activity) {
    _activities.add(activity);
  }

  List<String> visibleThinkingSteps({bool includeCurrent = true}) {
    final steps = <String>[..._completedThoughts];
    final current = normalizeThoughtText(_currentThought);
    if (includeCurrent && current != null && current.isNotEmpty) {
      if (steps.isEmpty || steps.last != current) {
        steps.add(current);
      }
    }
    return List<String>.unmodifiable(steps);
  }

  List<ChatActivity> visibleActivities({
    required bool isStreaming,
    required String thoughtTitle,
  }) {
    return List<ChatActivity>.unmodifiable(<ChatActivity>[
      ChatActivity(
        type: ChatActivityType.thought,
        title: thoughtTitle,
        subtitle: null,
        items: [
          for (final step in visibleThinkingSteps(includeCurrent: isStreaming))
            ChatActivityItem(title: step),
        ],
        isComplete: !isStreaming,
      ),
      ..._activities,
    ]);
  }

  String? normalizeThoughtText(String? value) {
    final normalized = value
        ?.replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
