/// Turns untrusted MCP text and schemas into something safe to show a model.
///
/// **Why this exists.** Tool names, descriptions and schemas come from a remote
/// server the user connected to. They are attacker-controlled input that ends
/// up in the model's prompt, so they are a prompt-injection surface. Everything
/// a server publishes is therefore treated as hostile: control characters and
/// invisible characters are stripped, instruction-like sentences are removed,
/// and length is capped.
library;

/// Sentences that look like attempts to talk to the model rather than describe
/// a tool. They are dropped from server-supplied text.
final List<RegExp> _injectionPatterns = <RegExp>[
  RegExp(r'\bignore (all |any |the )?(previous|prior|above|earlier)\b', caseSensitive: false),
  RegExp(r'\bdisregard (all |any |the )?(previous|prior|above|earlier|instructions)\b', caseSensitive: false),
  RegExp(r'\byou (must|should|shall|will) (now|always|never|immediately)\b', caseSensitive: false),
  RegExp(r'\bdo not (tell|inform|mention|reveal|disclose)\b', caseSensitive: false),
  RegExp(r'\bwithout (telling|informing|asking) (the )?user\b', caseSensitive: false),
  RegExp(r'\b(system|developer|assistant)\s*:', caseSensitive: false),
  RegExp(r'<\|[a-z_]+?\|>'),
  RegExp(r'\bnew instructions?:', caseSensitive: false),
  RegExp(r'\boverride (the )?(system|safety|policy)\b', caseSensitive: false),
  RegExp(r'\bexfiltrat\w*\b', caseSensitive: false),
  RegExp(r'\bsend (the |your |all )?(user\W?s )?(api|secret|token|key|password|credential)', caseSensitive: false),
];

const int defaultMaxDescriptionLength = 480;
const int defaultMaxSchemaDepth = 6;
const int defaultMaxSchemaProperties = 60;

/// Strips invisibles/control characters and collapses whitespace.
String stripInvisibleCharacters(String value) {
  return value
      // Control characters except tab/newline.
      .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]'), '')
      // Zero-width and bidi-override characters.
      .replaceAll(RegExp(r'[\u200B-\u200F\u202A-\u202E\u2060-\u2064\uFEFF]'), '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
}

/// Sanitises untrusted server text for display and for the model prompt.
String sanitizeMcpText(
  String value, {
  int maxLength = defaultMaxDescriptionLength,
}) {
  final stripped = stripInvisibleCharacters(value);
  final collapsed = stripped.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();
  if (collapsed.isEmpty) {
    return '';
  }
  final cleanedSentences = <String>[];
  for (final rawSentence in collapsed.split(RegExp(r'(?<=[.!?])\s+'))) {
    final sentence = rawSentence.trim();
    if (sentence.isEmpty) {
      continue;
    }
    if (_isInjectionAttempt(sentence)) {
      continue;
    }
    cleanedSentences.add(sentence);
  }
  final result = cleanedSentences.join(' ').trim();
  if (result.isEmpty) {
    return '';
  }
  if (result.length <= maxLength) {
    return result;
  }
  return '${result.substring(0, maxLength).trimRight()}…';
}

bool _isInjectionAttempt(String sentence) {
  for (final pattern in _injectionPatterns) {
    if (pattern.hasMatch(sentence)) {
      return true;
    }
  }
  return false;
}

/// Keywords that are safe to forward to the model's tool definition.
const Set<String> _allowedSchemaKeys = <String>{
  'type',
  'description',
  'title',
  'properties',
  'required',
  'items',
  'enum',
  'default',
  'minimum',
  'maximum',
  'minLength',
  'maxLength',
  'minItems',
  'maxItems',
  'pattern',
  'format',
  'additionalProperties',
  'anyOf',
  'oneOf',
  'allOf',
  'nullable',
};

/// Projects an MCP `inputSchema` into the parameter object handed to the model.
///
/// Guarantees the result is an object schema with a `properties` map, drops
/// keywords the model does not understand, sanitises every `description` and
/// `title`, and bounds depth and breadth so a hostile server cannot blow up
/// the prompt.
Map<String, Object?> projectMcpInputSchema(
  Map<String, Object?> schema, {
  int maxDepth = defaultMaxSchemaDepth,
  int maxProperties = defaultMaxSchemaProperties,
}) {
  final projected = _project(
    schema,
    depth: 0,
    maxDepth: maxDepth,
    propertyBudget: _Budget(maxProperties),
  );
  final map = projected is Map<String, Object?>
      ? projected
      : <String, Object?>{};
  if (map['type']?.toString() != 'object') {
    return <String, Object?>{
      'type': 'object',
      'properties': const <String, Object?>{},
      'required': const <String>[],
      'additionalProperties': true,
    };
  }
  map.putIfAbsent('properties', () => const <String, Object?>{});
  map.putIfAbsent('required', () => const <String>[]);
  return map;
}

class _Budget {
  _Budget(this.remaining);

  int remaining;

  bool consume() {
    if (remaining <= 0) {
      return false;
    }
    remaining -= 1;
    return true;
  }
}

Object? _project(
  Object? value, {
  required int depth,
  required int maxDepth,
  required _Budget propertyBudget,
}) {
  if (value is List) {
    if (depth >= maxDepth) {
      return const <Object?>[];
    }
    return value
        .take(32)
        .map(
          (item) => _project(
            item,
            depth: depth + 1,
            maxDepth: maxDepth,
            propertyBudget: propertyBudget,
          ),
        )
        .toList(growable: false);
  }
  if (value is! Map) {
    return value;
  }
  if (depth >= maxDepth) {
    return const <String, Object?>{};
  }

  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key.toString();
    if (!_allowedSchemaKeys.contains(key)) {
      continue;
    }
    final entryValue = entry.value;
    switch (key) {
      case 'description':
      case 'title':
        final sanitized = sanitizeMcpText(
          entryValue?.toString() ?? '',
          maxLength: key == 'title' ? 90 : defaultMaxDescriptionLength,
        );
        if (sanitized.isNotEmpty) {
          result[key] = sanitized;
        }
      case 'properties':
        if (entryValue is! Map) {
          break;
        }
        final properties = <String, Object?>{};
        for (final property in entryValue.entries) {
          if (!propertyBudget.consume()) {
            break;
          }
          final propertyName = property.key.toString();
          if (propertyName.trim().isEmpty) {
            continue;
          }
          properties[propertyName] = _project(
            property.value,
            depth: depth + 1,
            maxDepth: maxDepth,
            propertyBudget: propertyBudget,
          );
        }
        result['properties'] = properties;
      case 'required':
        if (entryValue is! List) {
          break;
        }
        final required = entryValue
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .take(64)
            .toList(growable: false);
        result['required'] = required;
      case 'enum':
        if (entryValue is! List) {
          break;
        }
        result['enum'] = entryValue
            .take(64)
            .map(
              (item) => item is String
                  ? stripInvisibleCharacters(item).trim()
                  : item,
            )
            .toList(growable: false);
      default:
        result[key] = _project(
          entryValue,
          depth: depth + 1,
          maxDepth: maxDepth,
          propertyBudget: propertyBudget,
        );
    }
  }
  return result;
}
