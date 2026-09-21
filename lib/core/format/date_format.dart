/// Date and relative-time formatting helpers.
library;

const List<String> _shortMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `12 Sep`.
String formatShortDate(int? epochMs) {
  if (epochMs == null || epochMs <= 0) {
    return '';
  }
  final date = DateTime.fromMillisecondsSinceEpoch(epochMs);
  return '${date.day} ${_shortMonths[date.month - 1]}';
}

/// `12 Sep 2026, 14:03`.
String formatDateTime(int? epochMs) {
  if (epochMs == null || epochMs <= 0) {
    return '';
  }
  final date = DateTime.fromMillisecondsSinceEpoch(epochMs);
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${_shortMonths[date.month - 1]} ${date.year}, $hour:$minute';
}

/// `just now`, `4m ago`, `3h ago`, `2d ago`, or a short date beyond a week.
String formatRelativeTime(int? epochMs) {
  if (epochMs == null || epochMs <= 0) {
    return '';
  }
  final difference = DateTime.now().millisecondsSinceEpoch - epochMs;
  if (difference < 45000) {
    return 'just now';
  }
  final minutes = difference ~/ 60000;
  if (minutes < 60) {
    return '${minutes}m ago';
  }
  final hours = minutes ~/ 60;
  if (hours < 24) {
    return '${hours}h ago';
  }
  final days = hours ~/ 24;
  if (days < 7) {
    return '${days}d ago';
  }
  return formatShortDate(epochMs);
}
