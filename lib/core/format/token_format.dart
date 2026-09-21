/// Token-count and byte-size formatting helpers.
library;

/// `980`, `1.2k`, `42.5k`, `1.1M`.
String formatCompactTokens(int value) {
  if (value < 1000) {
    return value.toString();
  }
  if (value < 1000000) {
    final compact = value / 1000;
    return '${compact < 100 ? compact.toStringAsFixed(1) : compact.toStringAsFixed(0)}k';
  }
  final compact = value / 1000000;
  return '${compact.toStringAsFixed(1)}M';
}

/// Approximate tokens for a character count (one token ~= 4 characters).
int estimatedTokensFromCharacters(int charLength) {
  if (charLength <= 0) {
    return 0;
  }
  return (charLength / 4).ceil();
}

/// `412 B`, `18.4 KB`, `3.1 MB`.
String formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) {
    return '';
  }
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// `1.4 tok/s`.
String formatTokensPerSecond(double? value) {
  if (value == null || value <= 0) {
    return '';
  }
  return '${value.toStringAsFixed(1)} tok/s';
}
