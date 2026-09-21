import 'dart:convert';

import '../../audit/application/audit_log_store.dart';
import '../../audit/domain/app_capability.dart';
import '../../audit/domain/audit_log_entry.dart';
import '../../chat/application/sarvam_api_client.dart';
import '../../chat/application/tool_executor_registry.dart';
import '../../chat/application/web_tools.dart';
import '../../chat/domain/chat_message.dart';
import '../domain/mcp_protocol.dart';
import '../domain/mcp_tool_descriptor.dart';
import 'mcp_artifact_writer.dart';
import 'mcp_client.dart';
import 'mcp_registry.dart';
import 'mcp_schema_projector.dart';

/// Executes `mcp__*` tool calls.
///
/// The executor is deliberately conservative about two things:
///
/// * **Server text is untrusted.** Tool output is fed back to the model, so it
///   is passed through [sanitizeMcpText] and length-capped before it becomes
///   part of the conversation.
/// * **Binary content never reaches the prompt.** Base64 payloads are written
///   to the workspace and replaced by an artifact reference.
class McpToolExecutor implements ExternalToolExecutor {
  McpToolExecutor({
    required McpRegistry registry,
    AuditLogStore? auditLogStore,
    McpArtifactWriter? artifactWriter,
    this.maxOutputCharacters = 24000,
    this.maxArgumentCharacters = 60000,
  }) : _registry = registry,
       _auditLogStore = auditLogStore ?? AuditLogStore(),
       _artifactWriter = artifactWriter ?? McpArtifactWriter();

  static const String toolPrefix = 'mcp__';

  /// A tool result carries two different shapes of item: the chat timeline
  /// wants [ChatActivityItem]s, while the model wants [ToolExecutionItem]s.
  static List<ChatActivityItem> _asActivityItems(
    List<ToolExecutionItem> items,
  ) {
    return items
        .map(
          (item) => ChatActivityItem(
            title: item.title,
            subtitle: item.subtitle,
            trailing: item.trailing,
            url: item.url,
          ),
        )
        .toList(growable: false);
  }

  final McpRegistry _registry;
  final AuditLogStore _auditLogStore;
  final McpArtifactWriter _artifactWriter;

  /// Cap on the tool output handed back to the model.
  final int maxOutputCharacters;

  /// Cap on the serialized arguments, so a runaway model cannot push a
  /// multi-megabyte payload at a remote server.
  final int maxArgumentCharacters;

  @override
  bool handles(String toolName) => toolName.startsWith(toolPrefix);

  @override
  Future<ToolExecutionResult> execute(
    SarvamToolCall toolCall,
    ToolExecutionContext context,
  ) async {
    final descriptor = _registry.toolByQualifiedName(toolCall.name);
    if (descriptor == null) {
      return _failure(
        'No MCP tool named "${toolCall.name}" is currently available. '
        'It may have been disabled or its server disconnected.',
      );
    }
    final server = _registry.serverById(descriptor.serverId);
    if (server == null) {
      return _failure(
        'The MCP server for "${descriptor.name}" is no longer configured.',
      );
    }

    final arguments = _sanitizeArguments(toolCall.arguments);
    if (arguments == null) {
      return _failure(
        'The arguments for "${descriptor.name}" were too large to send.',
      );
    }

    context.onThought(
      'Calling ${descriptor.displayTitle} on ${server.displayName}…',
    );
    await _auditLogStore.record(
      capabilityKey: AppCapabilities.mcpToolCall.key,
      title: AppCapabilities.mcpToolCall.label,
      detail: 'Calling ${descriptor.qualifiedName} on ${server.displayName}.',
      status: AuditLogStatus.started,
      conversationId: context.conversationId,
    );

    final stopwatch = Stopwatch()..start();
    try {
      final client = await _registry.clientFor(server.id);
      final result = await client.callTool(
        name: descriptor.name,
        arguments: arguments,
      );
      stopwatch.stop();

      final outcome = await _interpret(
        result: result,
        descriptor: descriptor,
        serverDisplayName: server.displayName,
        context: context,
      );

      await _auditLogStore.record(
        capabilityKey: AppCapabilities.mcpToolCall.key,
        title: AppCapabilities.mcpToolCall.label,
        detail: result.isError
            ? '${descriptor.qualifiedName} reported an error: '
                  '${outcome.summary}'
            : '${descriptor.qualifiedName} completed: ${outcome.summary}',
        status: result.isError
            ? AuditLogStatus.failed
            : AuditLogStatus.success,
        conversationId: context.conversationId,
      );

      context.onActivity(
        ChatActivity(
          type: ChatActivityType.thought,
          title: result.isError
              ? '${descriptor.displayTitle} failed'
              : '${descriptor.displayTitle} finished',
          subtitle: '${server.displayName} · ${stopwatch.elapsedMilliseconds}ms',
          items: _asActivityItems(outcome.items),
          isComplete: true,
        ),
      );

      return outcome;
    } catch (error) {
      stopwatch.stop();
      final message = describeMcpFailure(error);
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.mcpToolCall.key,
        title: AppCapabilities.mcpToolCall.label,
        detail: '${descriptor.qualifiedName} could not run: $message',
        status: AuditLogStatus.failed,
        conversationId: context.conversationId,
      );
      return _failure(
        'Could not call "${descriptor.name}" on ${server.displayName}: $message',
      );
    }
  }

  /// Converts an MCP result into the shape the chat loop expects.
  Future<ToolExecutionResult> _interpret({
    required McpToolCallResult result,
    required McpToolDescriptor descriptor,
    required String serverDisplayName,
    required ToolExecutionContext context,
  }) async {
    final items = <ToolExecutionItem>[];
    final output = StringBuffer();
    final text = result.text;
    if (text.isNotEmpty) {
      output.write(_truncate(sanitizeMcpText(text, maxLength: maxOutputCharacters)));
    }

    for (final item in result.content) {
      switch (item.type) {
        case 'image':
          final reference = await _writeBinary(
            item: item,
            descriptor: descriptor,
            context: context,
            fallbackName: '${descriptor.name}.png',
          );
          if (reference != null) {
            items.add(
              ToolExecutionItem(
                title: reference.title,
                subtitle: '${reference.kindLabel} · ${_byteLabel(reference.sizeBytes)}',
                trailing: 'Image',
              ),
            );
            output
              ..write(output.isEmpty ? '' : '\n')
              ..write(
                '[image "${reference.title}" saved to the workspace as an '
                'artifact]',
              );
          }
        case 'resource' || 'resource_link':
          final item_ = item;
          final uri = item_.uri;
          if (item_.data != null && item_.data!.isNotEmpty) {
            final reference = await _writeBinary(
              item: item_,
              descriptor: descriptor,
              context: context,
              fallbackName: item_.name ?? descriptor.name,
            );
            if (reference != null) {
              items.add(
                ToolExecutionItem(
                  title: reference.title,
                  subtitle: reference.kindLabel,
                  trailing: 'Resource',
                ),
              );
              output
                ..write(output.isEmpty ? '' : '\n')
                ..write('[resource "${reference.title}" saved as an artifact]');
              break;
            }
          }
          if (uri != null && uri.isNotEmpty) {
            final reference = _artifactWriter.linkArtifact(
              serverId: descriptor.serverId,
              uri: uri,
              name: item_.name ?? item_.mimeType,
              mimeType: item_.mimeType,
            );
            context.onArtifact(reference);
            items.add(
              ToolExecutionItem(
                title: reference.title,
                subtitle: uri,
                url: uri,
                trailing: 'Link',
              ),
            );
            output
              ..write(output.isEmpty ? '' : '\n')
              ..write('[resource available at $uri]');
          }
      }
    }

    if (result.isError) {
      final summary = text.isEmpty
          ? '${descriptor.name} reported an error.'
          : _truncate(sanitizeMcpText(text, maxLength: 400), maxLength: 400);
      return ToolExecutionResult(
        success: false,
        summary: summary,
        formattedOutput: output.isEmpty
            ? 'The tool reported an error without any detail.'
            : output.toString(),
        items: items,
      );
    }

    return ToolExecutionResult(
      success: true,
      summary: '${descriptor.displayTitle} via $serverDisplayName',
      formattedOutput: output.isEmpty
          ? 'The tool completed successfully and returned no content.'
          : output.toString(),
      items: items,
    );
  }

  Future<GeneratedArtifactReference?> _writeBinary({
    required McpContentItem item,
    required McpToolDescriptor descriptor,
    required ToolExecutionContext context,
    required String fallbackName,
  }) async {
    final data = item.data;
    if (data == null || data.isEmpty) {
      return null;
    }
    final reference = await _artifactWriter.writeBase64(
      serverId: descriptor.serverId,
      toolName: descriptor.name,
      base64Data: data,
      mimeType: item.mimeType,
      suggestedName: item.name ?? fallbackName,
    );
    if (reference != null) {
      context.onArtifact(reference);
    }
    return reference;
  }

  /// Drops nulls and rejects an oversized payload.
  Map<String, dynamic>? _sanitizeArguments(Map<String, dynamic> arguments) {
    final cleaned = <String, dynamic>{};
    for (final entry in arguments.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      cleaned[entry.key] = value;
    }
    try {
      if (jsonEncode(cleaned).length > maxArgumentCharacters) {
        return null;
      }
    } catch (_) {
      // Non-encodable values are exactly the case we want to reject.
      return null;
    }
    return cleaned;
  }

  String _truncate(String value, {int? maxLength}) {
    final limit = maxLength ?? maxOutputCharacters;
    if (value.length <= limit) {
      return value;
    }
    return '${value.substring(0, limit)}\n…[output truncated by Nero]';
  }

  String _byteLabel(int? bytes) {
    if (bytes == null) {
      return 'unknown size';
    }
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  ToolExecutionResult _failure(String message) {
    return ToolExecutionResult(
      success: false,
      summary: message,
      formattedOutput: message,
    );
  }
}
