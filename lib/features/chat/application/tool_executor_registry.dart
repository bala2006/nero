import '../domain/chat_message.dart';
import 'sarvam_api_client.dart';
import 'web_tools.dart';

/// Ambient context handed to an external tool executor.
class ToolExecutionContext {
  const ToolExecutionContext({
    required this.conversationId,
    required this.onThought,
    required this.onActivity,
    required this.onArtifact,
    this.activeRequestPrompt,
    this.latestUserPrompt,
    this.assistantMessageId,
  });

  final String conversationId;

  /// Status label surfaced while the tool runs (becomes the phase caption).
  final void Function(String thought) onThought;

  /// Inline activity recorded on the assistant message.
  final void Function(ChatActivity activity) onActivity;

  /// Registers a generated artifact against the assistant message.
  final void Function(GeneratedArtifactReference artifact) onArtifact;

  final String? activeRequestPrompt;
  final String? latestUserPrompt;
  final String? assistantMessageId;
}

/// A tool executor for names the built-in coordinator does not own, such as
/// `mcp__*` and `sandbox_*`.
abstract class ExternalToolExecutor {
  /// Whether this executor can run [toolName].
  bool handles(String toolName);

  /// Runs the call. Implementations must not throw for ordinary tool failures;
  /// return a failed [ToolExecutionResult] instead so the model can recover.
  Future<ToolExecutionResult> execute(
    SarvamToolCall toolCall,
    ToolExecutionContext context,
  );
}

/// Ordered dispatch chain consulted before the built-in tool switch.
class ToolExecutorRegistry {
  ToolExecutorRegistry();

  final List<ExternalToolExecutor> _executors = <ExternalToolExecutor>[];

  List<ExternalToolExecutor> get executors =>
      List<ExternalToolExecutor>.unmodifiable(_executors);

  void register(ExternalToolExecutor executor) {
    _executors.add(executor);
  }

  void unregister(ExternalToolExecutor executor) {
    _executors.remove(executor);
  }

  /// First executor that claims [toolName], or null when it is built-in.
  ExternalToolExecutor? resolve(String toolName) {
    for (final executor in _executors) {
      if (executor.handles(toolName)) {
        return executor;
      }
    }
    return null;
  }
}
