import '../../audit/application/audit_log_store.dart';
import '../../audit/domain/app_capability.dart';
import '../../audit/domain/audit_log_entry.dart';
import '../../chat/application/sarvam_api_client.dart';
import '../../chat/application/tool_executor_registry.dart';
import '../../chat/application/web_tools.dart';
import '../../chat/domain/chat_message.dart';
import '../domain/sandbox_models.dart';
import 'sandbox_controller.dart';

/// Runs the `sandbox_run_code` tool: the agent's way to execute code on-device.
///
/// Every call is user-approved through the approval gate before it reaches this
/// executor (risk classifier maps `sandbox_*` to write), and each run is
/// recorded in the audit log with the snippet's length rather than its source,
/// so logs stay small and never leak snippet contents.
class SandboxToolExecutor implements ExternalToolExecutor {
  SandboxToolExecutor({
    required SandboxController controller,
    AuditLogStore? auditLogStore,
  }) : _controller = controller,
       _auditLogStore = auditLogStore ?? AuditLogStore();

  static const String toolName = 'sandbox_run_code';

  static const int maxSourceCharacters = 60000;

  final SandboxController _controller;
  final AuditLogStore _auditLogStore;

  @override
  bool handles(String toolName) => toolName == SandboxToolExecutor.toolName;

  @override
  Future<ToolExecutionResult> execute(
    SarvamToolCall toolCall,
    ToolExecutionContext context,
  ) async {
    final arguments = toolCall.arguments;
    final source = arguments['source']?.toString() ?? '';
    final languageName = arguments['language']?.toString();
    final reason = arguments['reason']?.toString();

    if (source.trim().isEmpty) {
      return _failure('The "source" argument is empty; nothing to run.');
    }
    if (source.length > maxSourceCharacters) {
      return _failure(
        'The snippet is ${source.length} characters; the sandbox accepts at '
        'most $maxSourceCharacters.',
      );
    }

    final language = switch (languageName) {
      'html' || 'page' => SandboxLanguage.html,
      _ => SandboxLanguage.javascript,
    };

    context.onThought(
      'Running ${language.label} in the on-device sandbox…',
    );
    await _auditLogStore.record(
      capabilityKey: AppCapabilities.sandboxRun.key,
      title: AppCapabilities.sandboxRun.label,
      detail:
          'Agent ran ${language.label} code (${source.length} chars)'
          '${reason == null || reason.isEmpty ? '' : ' — $reason'}.',
      status: AuditLogStatus.started,
      conversationId: context.conversationId,
    );

    // Run against a transient session so agent snippets never overwrite a
    // scratchpad the user was editing in the Sandbox screen.
    final session = SandboxSession(
      id: 'agent_${DateTime.now().microsecondsSinceEpoch}',
      name: 'Agent run',
      language: language,
      source: source,
      createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );

    final outcome = await _controller.runSession(
      session,
      onStatus: (status) {
        if (status.trim().isNotEmpty) {
          context.onThought(status);
        }
      },
    );

    await _auditLogStore.record(
      capabilityKey: AppCapabilities.sandboxRun.key,
      title: AppCapabilities.sandboxRun.label,
      detail: outcome.success
          ? 'Agent sandbox snippet finished in ${outcome.durationMs ?? 0}ms.'
          : 'Agent sandbox snippet failed: ${outcome.error ?? 'unknown error'}',
      status: outcome.success ? AuditLogStatus.success : AuditLogStatus.failed,
      conversationId: context.conversationId,
    );

    context.onActivity(
      ChatActivity(
        type: ChatActivityType.thought,
        title: outcome.success
            ? 'Ran ${language.label} on-device'
            : 'Sandbox run failed',
        subtitle: outcome.durationMs == null
            ? null
            : 'finished in ${outcome.durationMs}ms',
        items: <ChatActivityItem>[
          if (reason != null && reason.trim().isNotEmpty)
            ChatActivityItem(title: reason.trim()),
        ],
        isComplete: true,
      ),
    );

    if (!outcome.success) {
      return ToolExecutionResult(
        success: false,
        summary: outcome.error ?? 'The snippet failed.',
        formattedOutput: _renderOutput(outcome),
        items: const <ToolExecutionItem>[],
      );
    }

    return ToolExecutionResult(
      success: true,
      summary:
          'Ran ${language.label} on-device in ${outcome.durationMs ?? 0}ms.',
      formattedOutput: _renderOutput(outcome),
      items: <ToolExecutionItem>[
        for (final log in outcome.logs.take(20))
          ToolExecutionItem(
            title: log.message,
            subtitle: log.level,
          ),
      ],
    );
  }

  String _renderOutput(SandboxRunOutcome outcome) {
    final buffer = StringBuffer();
    final error = outcome.error;
    if (error != null && error.trim().isNotEmpty) {
      buffer
        ..write('Error: ')
        ..writeln(error.trim());
    }
    if (outcome.output.trim().isNotEmpty) {
      buffer
        ..writeln('Result:')
        ..writeln(outcome.output.trim());
    }
    if (outcome.logs.isNotEmpty) {
      buffer.writeln('Console output:');
      for (final log in outcome.logs) {
        buffer.writeln('[${log.level}] ${log.message}');
      }
    }
    final text = buffer.toString().trim();
    if (text.isEmpty) {
      return 'The snippet ran successfully and produced no output.';
    }
    if (text.length > 24000) {
      return '${text.substring(0, 24000)}\n…[output truncated by Nero]';
    }
    return text;
  }

  ToolExecutionResult _failure(String message) {
    return ToolExecutionResult(
      success: false,
      summary: message,
      formattedOutput: message,
    );
  }
}
