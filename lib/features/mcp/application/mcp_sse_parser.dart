/// One server-sent event frame.
class SseEvent {
  const SseEvent({this.event, required this.data, this.id});

  final String? event;
  final String data;
  final String? id;
}

/// Incremental parser for the `text/event-stream` framing.
///
/// Handles multi-line `data:` fields, comments (`:` prefix), and events split
/// across chunk boundaries, which happens constantly on a mobile connection.
class SseParser {
  SseParser();

  final StringBuffer _data = StringBuffer();
  String? _eventName;
  String? _lastId;
  bool _sawData = false;

  /// Feeds one line (without its terminator). Returns a frame when the line
  /// terminates an event, otherwise null.
  SseEvent? addLine(String rawLine) {
    // Strip a trailing CR so CRLF streams parse identically to LF streams.
    final line = rawLine.endsWith('\r')
        ? rawLine.substring(0, rawLine.length - 1)
        : rawLine;

    if (line.isEmpty) {
      if (!_sawData) {
        _eventName = null;
        return null;
      }
      final frame = SseEvent(
        event: _eventName,
        data: _data.toString(),
        id: _lastId,
      );
      _data.clear();
      _eventName = null;
      _sawData = false;
      return frame;
    }

    if (line.startsWith(':')) {
      // Comment / keep-alive.
      return null;
    }

    final separator = line.indexOf(':');
    final field = separator == -1 ? line : line.substring(0, separator);
    var value = separator == -1 ? '' : line.substring(separator + 1);
    if (value.startsWith(' ')) {
      value = value.substring(1);
    }

    switch (field) {
      case 'data':
        if (_sawData) {
          _data.write('\n');
        }
        _data.write(value);
        _sawData = true;
      case 'event':
        _eventName = value;
      case 'id':
        _lastId = value;
      case 'retry':
        // Backoff hints are not used; the client owns its own retry policy.
        break;
    }
    return null;
  }

  /// Flushes a final event when the stream ends without a trailing blank line.
  SseEvent? flush() {
    if (!_sawData) {
      return null;
    }
    final frame = SseEvent(event: _eventName, data: _data.toString(), id: _lastId);
    _data.clear();
    _eventName = null;
    _sawData = false;
    return frame;
  }

  void reset() {
    _data.clear();
    _eventName = null;
    _sawData = false;
  }
}
