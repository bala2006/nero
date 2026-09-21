/// Lifecycle of one MCP server connection.
enum McpConnectionStatus {
  disconnected,
  connecting,
  connected,
  needsAuth,
  error,
}

extension McpConnectionStatusX on McpConnectionStatus {
  String get label => switch (this) {
    McpConnectionStatus.disconnected => 'Not connected',
    McpConnectionStatus.connecting => 'Connecting…',
    McpConnectionStatus.connected => 'Connected',
    McpConnectionStatus.needsAuth => 'Needs auth',
    McpConnectionStatus.error => 'Error',
  };

  bool get isConnected => this == McpConnectionStatus.connected;

  bool get isBusy => this == McpConnectionStatus.connecting;
}

class McpConnectionState {
  const McpConnectionState({
    this.status = McpConnectionStatus.disconnected,
    this.serverName,
    this.protocolVersion,
    this.toolCount = 0,
    this.error,
    this.updatedAtEpochMs,
  });

  final McpConnectionStatus status;

  /// `serverInfo.name` reported during initialize.
  final String? serverName;

  /// Negotiated `protocolVersion`.
  final String? protocolVersion;

  final int toolCount;
  final String? error;
  final int? updatedAtEpochMs;

  static const McpConnectionState idle = McpConnectionState();

  bool get isConnected => status.isConnected;

  McpConnectionState copyWith({
    McpConnectionStatus? status,
    String? serverName,
    String? protocolVersion,
    int? toolCount,
    String? error,
    int? updatedAtEpochMs,
    bool clearError = false,
  }) {
    return McpConnectionState(
      status: status ?? this.status,
      serverName: serverName ?? this.serverName,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      toolCount: toolCount ?? this.toolCount,
      error: clearError ? null : error ?? this.error,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
    );
  }
}
