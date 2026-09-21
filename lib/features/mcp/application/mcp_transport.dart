import '../domain/mcp_protocol.dart';

/// Thrown when a transport cannot complete a request.
class McpTransportException implements Exception {
  const McpTransportException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

/// Result of one transport round-trip.
class McpTransportResponse {
  const McpTransportResponse({
    this.messages = const <McpMessage>[],
    this.sessionId,
  });

  /// Every JSON-RPC message received in this round-trip.
  final List<McpMessage> messages;

  /// `Mcp-Session-Id` advertised by the server, when present.
  final String? sessionId;

  bool get isEmpty => messages.isEmpty;

  /// The response matching [requestId], if the server answered inline.
  McpMessage? responseFor(int requestId) {
    for (final message in messages) {
      if (message.id == requestId) {
        return message;
      }
    }
    return null;
  }
}

/// How Nero reaches an MCP server.
abstract class McpTransport {
  /// Sends one request and resolves with the messages received.
  Future<McpTransportResponse> send(
    McpRequest request, {
    String? sessionId,
  });

  /// Sends a notification (no response expected).
  Future<void> notify(McpNotification notification, {String? sessionId});

  /// Releases sockets and background streams.
  Future<void> close();
}
