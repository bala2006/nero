/// On-device sandbox domain models.
///
/// The sandbox runs code inside a WebView: a JavaScript engine that ships with
/// the platform, needs no extra dependency, and is isolated from Dart and from
/// the native bridge. Nothing here is a security boundary against a hostile
/// *app* — the WebView isolates the *page*, and the permission shims below are
/// defence in depth. Treat the sandbox as "safe to run untrusted snippets",
/// not "safe to run malware".
library;

enum SandboxLanguage { javascript, html }

extension SandboxLanguageX on SandboxLanguage {
  String get name => switch (this) {
    SandboxLanguage.javascript => 'javascript',
    SandboxLanguage.html => 'html',
  };

  String get label => switch (this) {
    SandboxLanguage.javascript => 'JavaScript',
    SandboxLanguage.html => 'HTML page',
  };

  String get description => switch (this) {
    SandboxLanguage.javascript =>
      'Run a script and read back everything it logged or returned.',
    SandboxLanguage.html =>
      'Render a full page. Its console output is captured too.',
  };

  /// Seed source so a new session is runnable immediately.
  String get starterSource => switch (this) {
    SandboxLanguage.javascript => '''
// Runs on-device. console.log output comes back here.
const numbers = [3, 1, 4, 1, 5, 9, 2, 6];
const sorted = [...numbers].sort((a, b) => a - b);
console.log('sorted:', sorted.join(', '));
console.log('sum:', numbers.reduce((total, n) => total + n, 0));
return { count: numbers.length, max: Math.max(...numbers) };
''',
    SandboxLanguage.html => '''
<h1>Hello from the sandbox</h1>
<p>Edit the HTML, then run it. Use <code>console.log</code> to send
values back to the output panel.</p>
<script>
  console.log('page loaded');
</script>
''',
  };

  static SandboxLanguage fromName(String? value) {
    return value == 'html' ? SandboxLanguage.html : SandboxLanguage.javascript;
  }
}

/// Capabilities a snippet may ask for. All are denied unless explicitly granted.
enum SandboxPermission { network, persistentStorage, clipboard, domInteraction }

extension SandboxPermissionX on SandboxPermission {
  String get name => switch (this) {
    SandboxPermission.network => 'network',
    SandboxPermission.persistentStorage => 'persistentStorage',
    SandboxPermission.clipboard => 'clipboard',
    SandboxPermission.domInteraction => 'domInteraction',
  };

  String get label => switch (this) {
    SandboxPermission.network => 'Network access',
    SandboxPermission.persistentStorage => 'Persistent storage',
    SandboxPermission.clipboard => 'Clipboard',
    SandboxPermission.domInteraction => 'Touch the host page',
  };

  String get description => switch (this) {
    SandboxPermission.network =>
      'Blocked by default. Allows fetch and XMLHttpRequest from the snippet.',
    SandboxPermission.persistentStorage =>
      'Blocked by default. Allows localStorage and sessionStorage.',
    SandboxPermission.clipboard =>
      'Blocked by default. Allows clipboard read and write.',
    SandboxPermission.domInteraction =>
      'Blocked by default. Allows the snippet to change the visible host page.',
  };

  static SandboxPermission fromName(String? value) {
    for (final permission in SandboxPermission.values) {
      if (permission.name == value) {
        return permission;
      }
    }
    return SandboxPermission.domInteraction;
  }
}

/// What a sandbox session is allowed to do.
class SandboxPolicy {
  const SandboxPolicy({
    this.allowedPermissions = const <SandboxPermission>{},
    this.maxRuntimeMs = 5000,
    this.maxOutputCharacters = 20000,
  });

  /// Deny by default: an empty set blocks everything.
  final Set<SandboxPermission> allowedPermissions;

  /// Hard wall-clock cap; the snippet is abandoned when it elapses.
  final int maxRuntimeMs;

  final int maxOutputCharacters;

  bool allows(SandboxPermission permission) =>
      allowedPermissions.contains(permission);

  SandboxPolicy copyWith({
    Set<SandboxPermission>? allowedPermissions,
    int? maxRuntimeMs,
    int? maxOutputCharacters,
  }) {
    return SandboxPolicy(
      allowedPermissions: allowedPermissions ?? this.allowedPermissions,
      maxRuntimeMs: maxRuntimeMs ?? this.maxRuntimeMs,
      maxOutputCharacters: maxOutputCharacters ?? this.maxOutputCharacters,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'allowedPermissions': allowedPermissions
        .map((permission) => permission.name)
        .toList(growable: false),
    'maxRuntimeMs': maxRuntimeMs,
    'maxOutputCharacters': maxOutputCharacters,
  };

  factory SandboxPolicy.fromJson(Map<String, dynamic> json) {
    final rawAllowed = json['allowedPermissions'];
    return SandboxPolicy(
      allowedPermissions: rawAllowed is List
          ? rawAllowed
                .map((item) => SandboxPermissionX.fromName(item.toString()))
                .toSet()
          : const <SandboxPermission>{},
      maxRuntimeMs: (json['maxRuntimeMs'] as num?)?.toInt() ?? 5000,
      maxOutputCharacters:
          (json['maxOutputCharacters'] as num?)?.toInt() ?? 20000,
    );
  }
}

/// One saved sandbox scratchpad.
class SandboxSession {
  const SandboxSession({
    required this.id,
    required this.name,
    required this.language,
    required this.source,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
  });

  final String id;
  final String name;
  final SandboxLanguage language;
  final String source;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;

  static SandboxSession create({
    required String id,
    required SandboxLanguage language,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return SandboxSession(
      id: id,
      name: language == SandboxLanguage.html ? 'New page' : 'New script',
      language: language,
      source: language.starterSource,
      createdAtEpochMs: now,
      updatedAtEpochMs: now,
    );
  }

  SandboxSession copyWith({
    String? id,
    String? name,
    SandboxLanguage? language,
    String? source,
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
  }) {
    return SandboxSession(
      id: id ?? this.id,
      name: name ?? this.name,
      language: language ?? this.language,
      source: source ?? this.source,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'language': language.name,
    'source': source,
    'createdAtEpochMs': createdAtEpochMs,
    'updatedAtEpochMs': updatedAtEpochMs,
  };

  factory SandboxSession.fromJson(Map<String, dynamic> json) {
    return SandboxSession(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Script',
      language: SandboxLanguageX.fromName(json['language']?.toString()),
      source: json['source']?.toString() ?? '',
      createdAtEpochMs: (json['createdAtEpochMs'] as num?)?.toInt() ?? 0,
      updatedAtEpochMs: (json['updatedAtEpochMs'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One captured console call.
class SandboxLogEntry {
  const SandboxLogEntry({
    required this.level,
    required this.message,
    required this.atEpochMs,
  });

  final String level;
  final String message;
  final int atEpochMs;

  bool get isError => level == 'error' || level == 'uncaught';
}

/// Result of one run.
class SandboxRunOutcome {
  const SandboxRunOutcome({
    required this.success,
    this.output = '',
    this.error,
    this.logs = const <SandboxLogEntry>[],
    this.durationMs,
    this.outputTruncated = false,
  });

  final bool success;
  final String output;
  final String? error;
  final List<SandboxLogEntry> logs;
  final int? durationMs;
  final bool outputTruncated;

  static SandboxRunOutcome failure(String message) =>
      SandboxRunOutcome(success: false, error: message);
}
