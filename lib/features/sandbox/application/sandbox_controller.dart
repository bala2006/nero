import 'package:flutter/foundation.dart';

import '../../audit/application/audit_log_store.dart';
import '../../audit/domain/app_capability.dart';
import '../../audit/domain/audit_log_entry.dart';
import '../domain/sandbox_models.dart';
import 'sandbox_runner.dart';
import 'sandbox_store.dart';

/// Owns sandbox sessions, the permission policy and the run lifecycle.
class SandboxController extends ChangeNotifier {
  SandboxController({
    required SandboxRunner runner,
    SandboxStore? store,
    AuditLogStore? auditLogStore,
  }) : _runner = runner,
       _store = store ?? SandboxStore(),
       _auditLogStore = auditLogStore ?? AuditLogStore();

  final SandboxRunner _runner;
  final SandboxStore _store;
  final AuditLogStore _auditLogStore;

  /// The execution backend, exposed so the shell can host its WebView once for
  /// the whole app while this controller keeps ownership of runs.
  SandboxRunner get runner => _runner;

  List<SandboxSession> _sessions = const <SandboxSession>[];
  SandboxPolicy _policy = const SandboxPolicy();
  String? _activeSessionId;
  bool _loading = true;
  bool _running = false;
  SandboxRunOutcome? _lastOutcome;

  List<SandboxSession> get sessions =>
      List<SandboxSession>.unmodifiable(_sessions);

  SandboxPolicy get policy => _policy;

  String? get activeSessionId => _activeSessionId;

  bool get isLoading => _loading;

  bool get isRunning => _running;

  SandboxRunOutcome? get lastOutcome => _lastOutcome;

  SandboxSession? get activeSession {
    final id = _activeSessionId;
    if (id == null) {
      return null;
    }
    for (final session in _sessions) {
      if (session.id == id) {
        return session;
      }
    }
    return null;
  }

  /// Loads persisted sessions, seeding one so the screen is never empty.
  Future<void> load() async {
    _sessions = await _store.loadSessions();
    _policy = await _store.loadPolicy();
    if (_sessions.isEmpty) {
      _sessions = <SandboxSession>[
        SandboxSession.create(
          id: _generateId(),
          language: SandboxLanguage.javascript,
        ),
      ];
      await _store.saveSessions(_sessions);
    }
    _activeSessionId = _sessions.first.id;
    _loading = false;
    notifyListeners();
  }

  void selectSession(String sessionId) {
    if (_activeSessionId == sessionId) {
      return;
    }
    _activeSessionId = sessionId;
    _lastOutcome = null;
    notifyListeners();
  }

  Future<SandboxSession> createSession(SandboxLanguage language) async {
    final session = SandboxSession.create(
      id: _generateId(),
      language: language,
    );
    _sessions = <SandboxSession>[session, ..._sessions];
    _activeSessionId = session.id;
    _lastOutcome = null;
    await _store.saveSessions(_sessions);
    notifyListeners();
    return session;
  }

  Future<void> renameSession(String sessionId, String name) async {
    _replace(
      sessionId,
      (session) => session.copyWith(
        name: name.trim().isEmpty ? session.name : name.trim(),
        updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _store.saveSessions(_sessions);
    notifyListeners();
  }

  Future<void> updateSource(String sessionId, String source) async {
    _replace(
      sessionId,
      (session) => session.copyWith(
        source: source,
        updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    notifyListeners();
  }

  Future<void> setLanguage(
    String sessionId,
    SandboxLanguage language,
  ) async {
    _replace(
      sessionId,
      (session) => session.copyWith(
        language: language,
        updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _store.saveSessions(_sessions);
    notifyListeners();
  }

  Future<void> deleteSession(String sessionId) async {
    _sessions = _sessions
        .where((session) => session.id != sessionId)
        .toList(growable: false);
    if (_activeSessionId == sessionId) {
      _activeSessionId = _sessions.isEmpty ? null : _sessions.first.id;
    }
    _lastOutcome = null;
    await _store.saveSessions(_sessions);
    notifyListeners();
  }

  Future<void> togglePermission(SandboxPermission permission) async {
    final allowed = Set<SandboxPermission>.from(_policy.allowedPermissions);
    if (!allowed.remove(permission)) {
      allowed.add(permission);
    }
    _policy = _policy.copyWith(allowedPermissions: allowed);
    await _store.savePolicy(_policy);
    notifyListeners();
  }

  Future<void> setMaxRuntimeMs(int maxRuntimeMs) async {
    _policy = _policy.copyWith(maxRuntimeMs: maxRuntimeMs);
    await _store.savePolicy(_policy);
    notifyListeners();
  }

  /// Persists the current source, then runs it from the UI.
  Future<SandboxRunOutcome> run() async {
    final session = activeSession;
    if (session == null) {
      return SandboxRunOutcome.failure('No sandbox session is open.');
    }
    await _store.saveSessions(_sessions);
    return runSession(
      session,
      auditDetail:
          'Running ${session.language.label} "${session.name}" '
          '(${session.source.length} chars).',
      showInUi: true,
    );
  }

  /// Runs an arbitrary session. Used both by the screen (its own session) and
  /// by the agent's `sandbox_run_code` tool (a transient session), which is why
  /// audit detail, status reporting and UI mirroring are optional.
  Future<SandboxRunOutcome> runSession(
    SandboxSession session, {
    String? auditDetail,
    ValueChanged<String>? onStatus,
    bool showInUi = false,
  }) async {
    if (_running) {
      return SandboxRunOutcome.failure('A snippet is already running.');
    }
    _running = true;
    if (showInUi) {
      _lastOutcome = null;
    }
    onStatus?.call('Running ${session.language.label} in the sandbox…');
    notifyListeners();

    await _auditLogStore.record(
      capabilityKey: AppCapabilities.sandboxRun.key,
      title: AppCapabilities.sandboxRun.label,
      detail: auditDetail ??
          'Running ${session.language.label} "${session.name}".',
      status: AuditLogStatus.started,
    );

    SandboxRunOutcome outcome;
    try {
      outcome = await _runner.run(session: session, policy: _policy);
    } catch (error) {
      outcome = SandboxRunOutcome.failure('The sandbox crashed: $error');
    }

    _running = false;
    if (showInUi) {
      _lastOutcome = outcome;
    }
    await _auditLogStore.record(
      capabilityKey: AppCapabilities.sandboxRun.key,
      title: AppCapabilities.sandboxRun.label,
      detail: outcome.success
          ? 'Sandbox snippet completed in ${outcome.durationMs ?? 0}ms.'
          : 'Sandbox snippet failed: ${outcome.error ?? 'unknown error'}',
      status: outcome.success ? AuditLogStatus.success : AuditLogStatus.failed,
    );
    notifyListeners();
    return outcome;
  }

  void clearOutcome() {
    if (_lastOutcome == null) {
      return;
    }
    _lastOutcome = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _runner.dispose();
    super.dispose();
  }

  void _replace(
    String sessionId,
    SandboxSession Function(SandboxSession session) transform,
  ) {
    _sessions = _sessions
        .map(
          (session) => session.id == sessionId ? transform(session) : session,
        )
        .toList(growable: false);
  }

  String _generateId() =>
      'sbx_${DateTime.now().microsecondsSinceEpoch.toString()}';
}
