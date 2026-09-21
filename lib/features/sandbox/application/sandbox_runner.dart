import '../domain/sandbox_models.dart';

/// Executes a sandbox session.
///
/// Kept as an interface so the backend stays swappable: the WebView runner is
/// the only implementation today, and a Dart-subset interpreter can be added
/// later without touching the controller or the screens.
abstract class SandboxRunner {
  Future<SandboxRunOutcome> run({
    required SandboxSession session,
    required SandboxPolicy policy,
  });

  void dispose();
}
