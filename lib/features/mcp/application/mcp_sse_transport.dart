import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/mcp_protocol.dart';
import '../domain/mcp_server_config.dart';
import 'mcp_sse_parser.dart';
import 'mcp_transport.dart';

/// Legacy MCP "HTTP + SSE" transport, used by servers built before the
/// Streamable HTTP revision.
///
/// The client opens a long-lived GET stream and waits for the server's
/// `endpoint` event, which names the URL that JSON-RPC requests must be POSTed
/// to. Responses come back on the GET stream, matched by request id.
class McpSseTransport implements McpTransport {
  McpSseTransport({
    required this.config,
    HttpClient? httpClient,
    Duration? timeout,
  }) : _httpClient = httpClient,
       _timeout = timeout ?? Duration(milliseconds: config.timeoutMs);

  final McpServerConfig config;
  final Duration _timeout;

  HttpClient? _httpClient;
  StreamSubscription<String>? _streamSubscription;
  final Map<int, Completer<McpMessage>> _pending =
      <int, Completer<McpMessage>>{};
  final StreamController<McpMessage> _serverMessages =
      StreamController<McpMessage>.broadcast();
  Completer<Uri>? _ready;
  Uri? _postUri;
  String? _lastEventId;
  bool _closed = false;

  /// Server-initiated messages (notifications and requests).
  Stream<McpMessage> get serverMessages => _serverMessages.stream;

  @override
  Future<McpTransportResponse> send(
    McpRequest request, {
    String? sessionId,
  }) async {
    final completer = Completer<McpMessage>();
    _pending[request.id] = completer;
    try {
      await _post(request.toJson());
      final message = await completer.future.timeout(_timeout);
      return McpTransportResponse(
        messages: <McpMessage>[message],
        sessionId: sessionId,
      );
    } on TimeoutException {
      _pending.remove(request.id);
      throw McpTransportException(
        'MCP request "${request.method}" timed out after '
        '${_timeout.inSeconds}s.',
      );
    } finally {
      _pending.remove(request.id);
    }
  }

  @override
  Future<void> notify(
    McpNotification notification, {
    String? sessionId,
  }) async {
    await _post(notification.toJson());
  }

  @override
  Future<void> close() async {
    _closed = true;
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          const McpTransportException('MCP transport closed.'),
        );
      }
    }
    _pending.clear();
    await _serverMessages.close();
    _httpClient?.close(force: true);
    _httpClient = null;
  }

  Future<void> _post(Map<String, dynamic> payload) async {
    final target = await _ensureConnected();
    final client = _httpClient ??= HttpClient();
    try {
      final request = await client.postUrl(target).timeout(_timeout);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      _applyAuth(request);
      if (_lastEventId != null) {
        request.headers.set('last-event-id', _lastEventId!);
      }
      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close().timeout(_timeout);
      await response.drain<void>().catchError((_) {});
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw McpTransportException(
          'MCP POST failed (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
    } on McpTransportException {
      rethrow;
    } on TimeoutException {
      throw const McpTransportException('MCP POST timed out.');
    } on SocketException catch (error) {
      throw McpTransportException('MCP connection failed: ${error.message}');
    }
  }

  Future<Uri> _ensureConnected() {
    final ready = _ready;
    if (ready != null) {
      return ready.future;
    }
    final completer = Completer<Uri>();
    _ready = completer;
    unawaited(_openStream(completer));
    return completer.future.timeout(
      _timeout,
      onTimeout: () {
        throw McpTransportException(
          'MCP server did not send an endpoint event within '
          '${_timeout.inSeconds}s.',
        );
      },
    );
  }

  Future<void> _openStream(Completer<Uri> ready) async {
    final endpoint = Uri.tryParse(config.url.trim());
    if (endpoint == null || !endpoint.hasScheme) {
      if (!ready.isCompleted) {
        ready.completeError(
          McpTransportException('Invalid MCP server URL: "${config.url}".'),
        );
      }
      return;
    }

    final client = _httpClient ??= HttpClient();
    client.connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(endpoint).timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      request.headers.set('cache-control', 'no-cache');
      _applyAuth(request);
      final response = await request.close().timeout(_timeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw McpTransportException(
          'MCP server rejected the credentials (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw McpTransportException(
          'MCP SSE handshake failed (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }

      final parser = SseParser();
      _streamSubscription = response
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              final frame = parser.addLine(line);
              if (frame == null) {
                return;
              }
              _handleFrame(frame, endpoint, ready);
            },
            onError: (Object error) {
              if (!ready.isCompleted) {
                ready.completeError(
                  McpTransportException('MCP SSE stream error: $error'),
                );
              }
            },
            onDone: () {
              if (!ready.isCompleted && !_closed) {
                ready.completeError(
                  const McpTransportException(
                    'MCP SSE stream closed before an endpoint was provided.',
                  ),
                );
              }
            },
            cancelOnError: false,
          );
    } catch (error) {
      if (!ready.isCompleted) {
        ready.completeError(
          error is McpTransportException
              ? error
              : McpTransportException('MCP SSE handshake failed: $error'),
        );
      }
    }
  }

  void _handleFrame(SseEvent frame, Uri baseUri, Completer<Uri> ready) {
    if (frame.id != null && frame.id!.isNotEmpty) {
      _lastEventId = frame.id;
    }
    switch (frame.event) {
      case 'endpoint':
        final resolved = baseUri.resolve(frame.data.trim());
        _postUri = resolved;
        if (!ready.isCompleted) {
          ready.complete(resolved);
        }
        return;
      case 'message':
      case null:
      case '':
        break;
      default:
        // Unknown event types are ignored for forward compatibility.
        return;
    }

    final decoded = _tryDecode(frame.data);
    if (decoded == null) {
      return;
    }
    final id = decoded.id;
    if (id != null) {
      final completer = _pending.remove(id);
      if (completer != null && !completer.isCompleted) {
        completer.complete(decoded);
        return;
      }
    }
    if (!_serverMessages.isClosed) {
      _serverMessages.add(decoded);
    }
  }

  McpMessage? _tryDecode(String data) {
    final trimmed = data.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return McpMessage.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return null;
  }

  void _applyAuth(HttpClientRequest request) {
    final token = config.authToken.trim();
    if (token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    config.headers.forEach((name, value) {
      if (name.trim().isEmpty) {
        return;
      }
      try {
        request.headers.set(name, value);
      } catch (_) {}
    });
  }

  /// The POST endpoint discovered during the SSE handshake, when connected.
  Uri? get discoveredEndpoint => _postUri;
}
