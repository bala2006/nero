import '../../tools/application/local_tool_runtime_service.dart';
import '../../tools/domain/tool_runtime_models.dart' as runtime;
import '../../tools/domain/tool_types.dart';
import '../../docs/application/artifact_result_adapter.dart';
import '../domain/chat_message.dart';
import 'web_tools.dart';

typedef ArtifactApplyCallback =
    void Function(GeneratedArtifactReference artifact);
typedef ActivityRecordCallback = void Function(ChatActivity activity);

class NativeOutputToolBridge {
  const NativeOutputToolBridge({
    required LocalToolRuntimeService localToolRuntimeService,
    ArtifactResultAdapter? artifactResultAdapter,
  }) : _localToolRuntimeService = localToolRuntimeService,
       _artifactResultAdapter = artifactResultAdapter ?? const ArtifactResultAdapter();

  final LocalToolRuntimeService _localToolRuntimeService;
  final ArtifactResultAdapter _artifactResultAdapter;

  Future<ToolExecutionResult> execute({
    required ToolType toolType,
    required String title,
    required Map<String, dynamic> parameters,
    required String conversationId,
    required String? messageId,
    required String successSummary,
    required String failurePrefix,
    String activityTitle = 'Created file',
    ArtifactApplyCallback? onArtifact,
    ActivityRecordCallback? onActivity,
  }) async {
    final runtimeResult = await _localToolRuntimeService.executeToolRequest(
      request: runtime.ToolExecutionRequest(
        jobId: '${toolType.name}_${DateTime.now().microsecondsSinceEpoch}',
        toolType: toolType,
        parameters: parameters,
        conversationId: conversationId,
        messageId: messageId,
      ),
    );

    final outcome = _artifactResultAdapter.outcomeForNativeRuntimeResult(
      runtimeResult: runtimeResult,
      successSummary: successSummary,
      failurePrefix: failurePrefix,
      activityTitle: activityTitle,
    );
    for (final artifact in outcome.artifacts) {
      onArtifact?.call(artifact);
    }
    final activity = outcome.activity;
    if (activity != null) {
      onActivity?.call(activity);
    }
    return outcome.toolResult;
  }
}
