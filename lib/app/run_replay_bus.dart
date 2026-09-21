import 'package:flutter/foundation.dart';

/// Hands a previously executed prompt back to the chat composer.
///
/// Used by the Runs screen's "Run again": the run's original prompt is emitted
/// here, the navigator pops back to the chat, and the screen fills the composer
/// and shows a one-shot banner. A bus instead of a constructor argument because
/// the chat screen is the home shell — there is no route above it to push with
/// arguments.
class RunReplayBus extends ChangeNotifier {
  RunReplayBus._();

  static final RunReplayBus instance = RunReplayBus._();

  String? _pendingPrompt;
  int _emissionCounter = 0;

  /// The prompt waiting to be placed into the composer, with an id so the
  /// chat screen can tell a fresh emission from one it already consumed.
  ({int id, String prompt})? get pending {
    final prompt = _pendingPrompt;
    if (prompt == null) {
      return null;
    }
    return (id: _emissionCounter, prompt: prompt);
  }

  void emit(String prompt) {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _pendingPrompt = trimmed;
    _emissionCounter += 1;
    notifyListeners();
  }

  /// Marks the current emission as handled.
  void consume() {
    if (_pendingPrompt == null) {
      return;
    }
    _pendingPrompt = null;
    notifyListeners();
  }
}
