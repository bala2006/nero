import 'sarvam_api_client.dart';

class InlineToolCallCompatibilityParser {
  const InlineToolCallCompatibilityParser();

  static final RegExp _blockPattern = RegExp(
    r'<tool_call>\s*([a-zA-Z0-9_]+)\s*(?:</tool_call>)?([\s\S]*?)(?=<tool_call>|$)',
    dotAll: true,
  );
  static final RegExp _argumentPattern = RegExp(
    r'<arg_key>\s*([\s\S]*?)\s*</arg_key>\s*<arg_value>\s*([\s\S]*?)\s*</arg_value>',
    multiLine: true,
  );
  static final RegExp _xmlArtifactPattern = RegExp(
    r'</?(tool_call|arg_key|arg_value)>',
  );
  static final RegExp _excessLineBreakPattern = RegExp(r'\n{3,}');

  InlineToolExtractionResult extract(String content) {
    final trimmed = content.trim();
    if (!trimmed.contains('<tool_call>')) {
      return InlineToolExtractionResult(
        content: trimmed,
        toolCalls: const <SarvamToolCall>[],
      );
    }

    final toolCalls = <SarvamToolCall>[];
    final stripped = StringBuffer();
    var lastEnd = 0;

    for (final match in _blockPattern.allMatches(trimmed)) {
      final start = match.start;
      if (start > lastEnd) {
        stripped.write(trimmed.substring(lastEnd, start));
      }

      final name = match.group(1)?.trim() ?? '';
      final body = match.group(2) ?? '';
      lastEnd = match.end;
      if (name.isEmpty) {
        continue;
      }

      final arguments = <String, dynamic>{};
      for (final argMatch in _argumentPattern.allMatches(body)) {
        final key = argMatch.group(1)?.trim() ?? '';
        final value = argMatch.group(2)?.trim() ?? '';
        if (key.isEmpty) {
          continue;
        }
        arguments[key] = value;
      }

      toolCalls.add(
        SarvamToolCall(
          id: 'inline_${toolCalls.length}_$name',
          name: name,
          arguments: arguments,
        ),
      );
    }

    if (lastEnd < trimmed.length) {
      stripped.write(trimmed.substring(lastEnd));
    }

    return InlineToolExtractionResult(
      content: _normalizeResidualText(stripped.toString()),
      toolCalls: List<SarvamToolCall>.unmodifiable(toolCalls),
    );
  }

  String _normalizeResidualText(String content) {
    final withoutXmlArtifacts = content
        .replaceAll(_xmlArtifactPattern, ' ')
        .replaceAll(_excessLineBreakPattern, '\n\n');
    return withoutXmlArtifacts.trim();
  }
}
