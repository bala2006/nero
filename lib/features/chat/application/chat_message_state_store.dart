import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../domain/chat_message.dart';

class ChatMessageStateStore {
  final List<ChatMessage> _messages = <ChatMessage>[];
  final LinkedHashMap<String, ChatMessage> _messagesById =
      LinkedHashMap<String, ChatMessage>();
  final Map<String, int> _messageIndexById = <String, int>{};
  final Map<String, ValueNotifier<ChatMessage>> _messageNotifiers =
      <String, ValueNotifier<ChatMessage>>{};
  final Map<String, int> _messageTokenEstimates = <String, int>{};
  final ValueNotifier<int> _messageListVersion = ValueNotifier<int>(0);

  late final UnmodifiableListView<ChatMessage> _messagesView =
      UnmodifiableListView<ChatMessage>(_messages);
  List<String> _messageIdList = const <String>[];

  int _conversationTokenEstimate = 0;
  /// The trimmed content of the most recent user-role message, maintained in
  /// O(1) as messages are appended or replaced.  Avoids the reverse linear
  /// scan that was previously performed in the controller.
  String? _latestUserContent;

  List<ChatMessage> get messages => _messagesView;
  ValueListenable<int> get messageListVersionListenable => _messageListVersion;
  int get conversationTokenEstimate => _conversationTokenEstimate;
  /// The content of the most recently appended / replaced user message,
  /// or `null` if no user message exists yet.
  String? get latestUserContent => _latestUserContent;

  /// Cached, unmodifiable list of message ids.
  ///
  /// Rebuilt only when the list structure changes (append / replace-all),
  /// never on streaming content updates — the transcript `ListView` listens
  /// to [messageIds] and must not rebuild every bound bubble on each delta.
  List<String> get messageIds => _messageIdList;

  void _rebuildMessageIdList() {
    _messageIdList = List<String>.unmodifiable(
      _messages.map<String>((message) => message.id),
    );
    _messageListVersion.value += 1;
  }

  ValueListenable<ChatMessage>? messageListenable(String messageId) {
    return _messageNotifiers[messageId];
  }

  ChatMessage? messageById(String messageId) {
    return _messagesById[messageId];
  }

  int indexOfMessageId(String messageId) {
    return _messageIndexById[messageId] ?? -1;
  }

  void appendMessages(
    Iterable<ChatMessage> messages, {
    required int Function(ChatMessage message) estimateTokens,
  }) {
    var didChange = false;
    for (final message in messages) {
      _messages.add(message);
      _messagesById[message.id] = message;
      _messageIndexById[message.id] = _messages.length - 1;
      final estimate = estimateTokens(message);
      _messageTokenEstimates[message.id] = estimate;
      _conversationTokenEstimate += estimate;
      _messageNotifiers[message.id] = ValueNotifier<ChatMessage>(message);
      // Track the latest non-empty user message content in O(1).
      if (message.role == ChatRole.user && message.content.trim().isNotEmpty) {
        _latestUserContent = message.content.trim();
      }
      didChange = true;
    }
    if (didChange) {
      _rebuildMessageIdList();
    }
  }

  void replaceAllMessages(
    List<ChatMessage> messages, {
    required int Function(ChatMessage message) estimateTokens,
  }) {
    for (final notifier in _messageNotifiers.values) {
      notifier.dispose();
    }
    _messageNotifiers.clear();
    _messagesById.clear();
    _messageIndexById.clear();
    _messageTokenEstimates.clear();
    _conversationTokenEstimate = 0;
    _latestUserContent = null;
    _messages
      ..clear()
      ..addAll(messages);
    for (final message in messages) {
      _messagesById[message.id] = message;
      _messageIndexById[message.id] = _messageIndexById.length;
      final estimate = estimateTokens(message);
      _messageTokenEstimates[message.id] = estimate;
      _conversationTokenEstimate += estimate;
      _messageNotifiers[message.id] = ValueNotifier<ChatMessage>(message);
      if (message.role == ChatRole.user && message.content.trim().isNotEmpty) {
        _latestUserContent = message.content.trim();
      }
    }
    _rebuildMessageIdList();
  }

  void replaceMessageAt(
    int index,
    ChatMessage message, {
    required int Function(ChatMessage message) estimateTokens,
  }) {
    final previous = _messages[index];
    _messages[index] = message;
    _messagesById.remove(previous.id);
    _messageIndexById.remove(previous.id);
    _messagesById[message.id] = message;
    _messageIndexById[message.id] = index;
    final previousEstimate = _messageTokenEstimates.remove(previous.id) ?? 0;
    final nextEstimate = estimateTokens(message);
    _messageTokenEstimates[message.id] = nextEstimate;
    _conversationTokenEstimate += nextEstimate - previousEstimate;
    // Keep user-content pointer up to date on edits/resends.
    if (message.role == ChatRole.user && message.content.trim().isNotEmpty) {
      _latestUserContent = message.content.trim();
    }
    final notifier = _messageNotifiers.remove(previous.id);
    if (notifier == null) {
      _messageNotifiers[message.id] = ValueNotifier<ChatMessage>(message);
      _rebuildMessageIdList();
      return;
    }
    if (previous.id != message.id) {
      notifier.dispose();
      _messageNotifiers[message.id] = ValueNotifier<ChatMessage>(message);
      _rebuildMessageIdList();
      return;
    }
    // Same message id: an in-place content update (streaming delta, activity
    // tick). Push the value through the per-message notifier silently — the
    // transcript list itself does not need to rebuild, only the bubble bound
    // to this notifier does. The id list is only re-anchored when the list
    // structure changes.
    notifier.value = message;
    if (_messageIdList.isEmpty || identical(_messageIdList, _messages)) {
      _rebuildMessageIdList();
    }
  }

  /// Synchronises an in-place update for an existing message id without
  /// notifying the transcript list.
  ///
  /// Streaming deltas call this instead of [replaceMessageAt]: the per-message
  /// [ValueNotifier] fires (so only the bound bubble rebuilds) while the
  /// list-level version — and therefore the transcript `ListView` — stays
  /// untouched. Structural changes (add / remove / re-order) must still go
  /// through [appendMessages] / [replaceAllMessages].
  ///
  /// Returns `true` when the message existed and was synced.
  bool syncMessage(ChatMessage message) {
    final index = _messageIndexById[message.id];
    if (index == null) {
      return false;
    }
    final previous = _messages[index];
    if (previous.id != message.id) {
      // Index map out of date for this slot — fall back to the structural
      // path so the maps are rebuilt correctly.
      replaceMessageAt(
        index,
        message,
        estimateTokens: (candidate) =>
            _messageTokenEstimates[candidate.id] ??
            _estimateViaContent(candidate),
      );
      return true;
    }
    _messages[index] = message;
    _messagesById[message.id] = message;
    final previousEstimate = _messageTokenEstimates[message.id] ?? 0;
    final nextEstimate = _estimateViaContent(message);
    if (nextEstimate != previousEstimate) {
      _messageTokenEstimates[message.id] = nextEstimate;
      _conversationTokenEstimate += nextEstimate - previousEstimate;
    }
    if (message.role == ChatRole.user &&
        message.content.trim().isNotEmpty) {
      _latestUserContent = message.content.trim();
    }
    final notifier = _messageNotifiers[message.id];
    if (notifier != null) {
      notifier.value = message;
    }
    return true;
  }

  int _estimateViaContent(ChatMessage message) {
    return message.content.length ~/ 4 + 8;
  }

  int estimatedTokensForMessage(
    ChatMessage message, {
    required int Function(ChatMessage message) estimateTokens,
  }) {
    return _messageTokenEstimates[message.id] ?? estimateTokens(message);
  }

  void dispose() {
    for (final notifier in _messageNotifiers.values) {
      notifier.dispose();
    }
    _messageNotifiers.clear();
    _messagesById.clear();
    _messageIndexById.clear();
    _messageTokenEstimates.clear();
    _messages.clear();
    _latestUserContent = null;
    _messageListVersion.dispose();
    _conversationTokenEstimate = 0;
  }
}
