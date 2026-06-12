import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

import 'sarvam_api_client.dart';
import 'web_tools.dart';

class ToolDispatchResult {
  const ToolDispatchResult({
    required this.call,
    required this.result,
    required this.compactSummary,
  });

  final SarvamToolCall call;
  final ToolExecutionResult result;
  final String compactSummary;
}

typedef ToolExecutor =
    Future<ToolExecutionResult> Function(SarvamToolCall toolCall);

class ToolDispatcher {
  ToolDispatcher();

  final Map<String, _CachedToolResult> _cache = <String, _CachedToolResult>{};

  Future<List<ToolDispatchResult>> dispatch(
    List<SarvamToolCall> toolCalls, {
    required ToolExecutor executor,
  }) async {
    final futures = toolCalls.map((toolCall) async {
      final key = _cacheKey(toolCall);
      final cached = _cache[key];
      if (cached != null && !cached.isExpired) {
        return ToolDispatchResult(
          call: toolCall,
          result: cached.result,
          compactSummary: await _compactSummary(toolCall, cached.result),
        );
      }

      final result = await executor(toolCall);
      _cache[key] = _CachedToolResult(
        result: result,
        expiresAt: DateTime.now().add(_ttlFor(toolCall.name)),
      );
      return ToolDispatchResult(
        call: toolCall,
        result: result,
        compactSummary: await _compactSummary(toolCall, result),
      );
    });

    return Future.wait(futures);
  }

  Duration _ttlFor(String toolName) {
    return switch (toolName) {
      'search_web' => const Duration(minutes: 5),
      'read_url' => const Duration(minutes: 10),
      'extract_article' => const Duration(minutes: 10),
      'generate_docx' => const Duration(minutes: 1),
      _ => const Duration(minutes: 2),
    };
  }

  String _cacheKey(SarvamToolCall toolCall) {
    final normalized = Map<String, dynamic>.from(toolCall.arguments);
    final keys = normalized.keys.toList()..sort();
    final raw =
        '${toolCall.name}:${jsonEncode({for (final key in keys) key: normalized[key]})}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  Future<String> _compactSummary(
    SarvamToolCall toolCall,
    ToolExecutionResult result,
  ) {
    final payload = <String, Object?>{
      'toolName': toolCall.name,
      'success': result.success,
      'summary': result.summary,
      'formattedOutput': result.formattedOutput,
      'items': result.items
          .take(3)
          .map(
            (item) => <String, Object?>{
              'title': item.title,
              'subtitle': item.subtitle,
            },
          )
          .toList(growable: false),
    };
    return Isolate.run(() => _compactSummaryInIsolate(payload));
  }
}

String _compactSummaryInIsolate(Map<String, Object?> payload) {
  final toolName = payload['toolName']?.toString() ?? 'tool';
  final success = payload['success'] == true;
  final summary = payload['summary']?.toString() ?? '';
  final formattedOutput = payload['formattedOutput']?.toString() ?? '';
  final items = payload['items'] as List<Object?>? ?? const <Object?>[];
  final buffer = StringBuffer()
    ..writeln('Tool `$toolName` summary:')
    ..writeln(summary);
  if ((toolName == 'generate_docx' ||
      toolName == 'generate_xlsx' ||
      toolName == 'generate_report_pdf' ||
      toolName == 'create_text_file' ||
      toolName == 'edit_text_file' ||
      toolName == 'write_project_files' ||
      toolName == 'package_zip') &&
      !success &&
      formattedOutput.trim().isNotEmpty) {
    final fallback = formattedOutput
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    final expanded = fallback.length > 2000
        ? '${fallback.substring(0, 2000)}...'
        : fallback;
    buffer.writeln(expanded);
    return buffer.toString().trim();
  }
  if (items.isNotEmpty) {
    for (final rawItem in items) {
      final item = rawItem is Map
          ? Map<String, Object?>.from(rawItem)
          : const <String, Object?>{};
      buffer.writeln(
        '- ${item['title'] ?? ''}${item['subtitle'] == null ? '' : ': ${item['subtitle']}'}',
      );
    }
  } else if (formattedOutput.trim().isNotEmpty) {
    final sanitized = formattedOutput
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    final compact = sanitized.length > 280
        ? '${sanitized.substring(0, 280)}...'
        : sanitized;
    buffer.writeln(compact);
  }
  return buffer.toString().trim();
}

class _CachedToolResult {
  const _CachedToolResult({
    required this.result,
    required this.expiresAt,
  });

  final ToolExecutionResult result;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
