import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../domain/sandbox_models.dart';
import 'sandbox_runner.dart';

/// Runs snippets inside a WebView.
///
/// **How it works.** Each run builds a self-contained HTML document holding the
/// user's source plus a small shim that replaces `console.*`, captures thrown
/// errors, and posts a single JSON payload back over a JavaScript channel. The
/// Dart side waits for that payload with a hard timeout.
///
/// **Why a WebView and not an isolate.** Arbitrary source cannot be evaluated in
/// a Dart isolate without shipping an interpreter package, and the platform
/// WebView is already present, already sandboxed from Dart memory, and already
/// capable of running both JS and HTML. The trade-off is that a WebView has no
/// true headless mode: [controller] must stay mounted in the widget tree for the
/// page to execute, which is why the sandbox screen keeps a 1×1 host.
class WebViewSandboxRunner implements SandboxRunner {
  WebViewSandboxRunner({this.channelName = 'NeroSandbox'}) {
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        channelName,
        onMessageReceived: (JavaScriptMessage message) =>
            _handleMessage(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            // A load failure with no pending run is the page being torn down;
            // with a pending run it must surface, otherwise the UI hangs.
            if (error.isForMainFrame ?? true) {
              _complete(<String, Object?>{
                'ok': false,
                'error': 'The sandbox page failed to load: ${error.description}',
              });
            }
          },
        ),
      );
  }

  final String channelName;
  final WebViewController _controller = WebViewController();

  Completer<Map<String, Object?>>? _pending;
  final List<SandboxLogEntry> _logs = <SandboxLogEntry>[];

  /// The view that must be mounted for snippets to execute.
  WebViewController get controller => _controller;

  bool get isRunning => _pending != null;

  /// Hosts the runner's WebView at 1×1. Kept off-screen rather than in an
  /// `Offstage`, because an unrendered WebView is not guaranteed to execute.
  Widget buildHost({Key? key, double size = 1}) {
    return Positioned(
      key: key,
      left: -1000,
      top: 0,
      width: size,
      height: size,
      child: WebViewWidget(controller: _controller),
    );
  }

  @override
  Future<SandboxRunOutcome> run({
    required SandboxSession session,
    required SandboxPolicy policy,
  }) async {
    if (_pending != null) {
      return SandboxRunOutcome.failure(
        'Another snippet is still running. Wait for it to finish.',
      );
    }
    final stopwatch = Stopwatch()..start();
    _logs.clear();
    final completer = Completer<Map<String, Object?>>();
    _pending = completer;

    try {
      await _controller.loadHtmlString(
        _buildDocument(session: session, policy: policy),
      );
    } catch (error) {
      _pending = null;
      return SandboxRunOutcome.failure('Could not start the sandbox: $error');
    }

    try {
      final payload = await completer.future.timeout(
        Duration(milliseconds: policy.maxRuntimeMs + 4000),
        onTimeout: () => <String, Object?>{
          'ok': false,
          'error':
              'Timed out after ${policy.maxRuntimeMs}ms. The snippet was '
              'abandoned.',
        },
      );
      stopwatch.stop();
      return _interpret(
        payload: payload,
        policy: policy,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (error) {
      stopwatch.stop();
      return SandboxRunOutcome(
        success: false,
        error: 'The sandbox failed to run this snippet: $error',
        logs: List<SandboxLogEntry>.unmodifiable(_logs),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } finally {
      _pending = null;
    }
  }

  @override
  void dispose() {
    _pending = null;
    _logs.clear();
    try {
      _controller.loadHtmlString('<html><body></body></html>');
    } catch (_) {}
  }

  // ---- internals ----------------------------------------------------------

  void _handleMessage(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      _complete(<String, Object?>{'ok': false, 'error': 'Unreadable result.'});
      return;
    }
    if (decoded is! Map) {
      _complete(<String, Object?>{'ok': false, 'error': 'Unreadable result.'});
      return;
    }
    final payload = Map<String, Object?>.from(decoded);
    final rawLogs = payload['logs'];
    if (rawLogs is List) {
      for (final entry in rawLogs) {
        if (entry is! Map) {
          continue;
        }
        _logs.add(
          SandboxLogEntry(
            level: entry['level']?.toString() ?? 'log',
            message: entry['message']?.toString() ?? '',
            atEpochMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
    }
    _complete(payload);
  }

  void _complete(Map<String, Object?> payload) {
    final pending = _pending;
    if (pending == null || pending.isCompleted) {
      return;
    }
    pending.complete(payload);
  }

  SandboxRunOutcome _interpret({
    required Map<String, Object?> payload,
    required SandboxPolicy policy,
    required int durationMs,
  }) {
    final output = payload['output']?.toString() ?? '';
    final truncated = output.length > policy.maxOutputCharacters;
    final bounded = truncated
        ? '${output.substring(0, policy.maxOutputCharacters)}\n…[output truncated]'
        : output;
    final error = payload['error']?.toString();
    final ok = payload['ok'] == true;
    return SandboxRunOutcome(
      success: ok,
      output: bounded,
      error: (error == null || error.isEmpty) ? null : error,
      logs: List<SandboxLogEntry>.unmodifiable(_logs),
      durationMs: durationMs,
      outputTruncated: truncated,
    );
  }

  /// Builds the document for one run.
  ///
  /// The user's source is embedded as a JSON string literal, so quotes and
  /// newlines cannot break out of the literal. `</` is additionally escaped so
  /// the source can never terminate the enclosing `<script>` tag early.
  String _buildDocument({
    required SandboxSession session,
    required SandboxPolicy policy,
  }) {
    final source = _escapeForScript(session.source);
    final allowNetwork = policy.allows(SandboxPermission.network);
    final allowStorage = policy.allows(SandboxPermission.persistentStorage);
    final allowClipboard = policy.allows(SandboxPermission.clipboard);
    final channel = jsonEncode(channelName);
    final flags = jsonEncode(<String, bool>{
      'network': allowNetwork,
      'storage': allowStorage,
      'clipboard': allowClipboard,
    });
    final runtimeMs = policy.maxRuntimeMs;

    final shim = '''
<script>
(function () {
  var FLAGS = $flags;
  var CHANNEL = $channel;
  var logs = [];

  function stringify(value, depth) {
    depth = depth || 0;
    if (value === null) return 'null';
    if (value === undefined) return 'undefined';
    var type = typeof value;
    if (type === 'string') return depth === 0 ? value : JSON.stringify(value);
    if (type === 'number' || type === 'boolean') return String(value);
    if (type === 'function') return '[function ' + (value.name || 'anonymous') + ']';
    if (depth > 3) return '…';
    if (Array.isArray(value)) {
      return '[' + value.map(function (item) { return stringify(item, depth + 1); }).join(', ') + ']';
    }
    if (value instanceof Error) return value.name + ': ' + value.message;
    try {
      return JSON.stringify(value, function (key, item) {
        if (typeof item === 'function') return '[function]';
        if (typeof item === 'bigint') return String(item);
        return item;
      });
    } catch (error) {
      return String(value);
    }
  }

  function record(level, args) {
    var parts = [];
    for (var index = 0; index < args.length; index += 1) {
      parts.push(stringify(args[index], 0));
    }
    logs.push({ level: level, message: parts.join(' ') });
  }

  var realConsole = window.console || {};
  window.console = {
    log: function () { record('log', arguments); },
    info: function () { record('info', arguments); },
    warn: function () { record('warn', arguments); },
    error: function () { record('error', arguments); },
    debug: function () { record('debug', arguments); },
    table: function (value) { record('log', [value]); },
    trace: function () { record('trace', arguments); },
    dir: function (value) { record('log', [value]); },
    group: function () {},
    groupEnd: function () {},
    time: function () {},
    timeEnd: function () {},
    assert: function (condition, message) {
      if (!condition) { record('error', ['Assertion failed: ' + stringify(message, 0)]); }
    }
  };

  // Deny-by-default shims. These are defence in depth, not a hard boundary.
  if (!FLAGS.network && typeof window.fetch === 'function') {
    window.fetch = function () {
      return Promise.reject(new TypeError('Network access is blocked in the sandbox.'));
    };
    var blockedXhr = function () { throw new Error('Network access is blocked in the sandbox.'); };
    window.XMLHttpRequest = blockedXhr;
    window.WebSocket = blockedXhr;
    window.EventSource = blockedXhr;
  }
  if (!FLAGS.storage) {
    var blockedStorage = {
      getItem: function () { return null; },
      setItem: function () { throw new Error('Storage is blocked in the sandbox.'); },
      removeItem: function () {},
      clear: function () {},
      key: function () { return null; },
      get length() { return 0; }
    };
    try { Object.defineProperty(window, 'localStorage', { value: blockedStorage, configurable: false }); } catch (e) {}
    try { Object.defineProperty(window, 'sessionStorage', { value: blockedStorage, configurable: false }); } catch (e) {}
    try { Object.defineProperty(window, 'indexedDB', { value: undefined, configurable: false }); } catch (e) {}
  }
  if (!FLAGS.clipboard && window.navigator) {
    try {
      Object.defineProperty(window.navigator, 'clipboard', { value: undefined, configurable: true });
    } catch (e) {}
  }

  window.addEventListener('error', function (event) {
    record('uncaught', [event.message || 'Script error']);
  });
  window.addEventListener('unhandledrejection', function (event) {
    record('uncaught', ['Unhandled promise rejection: ' + stringify(event.reason, 0)]);
  });

  window.__neroPost = function (payload) {
    payload.logs = logs;
    try {
      window['$channelName'].postMessage(JSON.stringify(payload));
    } catch (error) {
      // Channel gone (page tearing down): nothing useful left to do.
    }
  };
})();
</script>
''';

    final runner = session.language == SandboxLanguage.javascript
        ? _javascriptRunner(source: source, runtimeMs: runtimeMs)
        : _htmlRunner(source: source, runtimeMs: runtimeMs);

    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
$shim
</head>
<body>
$runner
</body>
</html>
''';
  }

  String _javascriptRunner({required String source, required int runtimeMs}) {
    return '''
<script>
(function () {
  var timer = null;
  function finish(payload) {
    if (timer !== null) { clearTimeout(timer); }
    window.__neroPost(payload);
  }
  timer = setTimeout(function () {
    finish({ ok: false, error: 'Timed out after ${runtimeMs}ms.' });
  }, $runtimeMs);
  try {
    var result = new Function('"use strict";\\n' + $source)();
    if (result && typeof result.then === 'function') {
      result.then(function (resolved) {
        finish({ ok: true, output: __neroFormat(resolved) });
      }, function (error) {
        finish({ ok: false, error: __neroFormat(error) });
      });
    } else {
      finish({ ok: true, output: __neroFormat(result) });
    }
  } catch (error) {
    finish({ ok: false, error: (error && error.stack) ? String(error.stack) : String(error) });
  }
})();
function __neroFormat(value) {
  if (value === undefined) return '';
  if (value === null) return 'null';
  if (typeof value === 'string') return value;
  try { return JSON.stringify(value, null, 2); } catch (error) { return String(value); }
}
</script>
''';
  }

  String _htmlRunner({required String source, required int runtimeMs}) {
    return '''
$source
<script>
(function () {
  var timer = setTimeout(function () {
    window.__neroPost({ ok: false, error: 'Timed out after ${runtimeMs}ms.' });
  }, $runtimeMs);
  function report() {
    clearTimeout(timer);
    window.__neroPost({ ok: true, output: '' });
  }
  if (document.readyState === 'complete') {
    report();
  } else {
    window.addEventListener('load', report);
  }
})();
</script>
''';
  }

  String _escapeForScript(String value) {
    return jsonEncode(value).replaceAll('</', r'<\/');
  }
}
