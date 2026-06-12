import '../../agent/domain/agent_task.dart';
import '../../docs/application/artifact_request_policy.dart';
import '../../settings/app_settings.dart';
import '../domain/chat_message.dart';
import 'sarvam_api_client.dart';

class ResponseRepairCoordinator {
  const ResponseRepairCoordinator({
    required ChatCompletionClient client,
    ArtifactRequestPolicy artifactRequestPolicy =
        const ArtifactRequestPolicy(),
  }) : _client = client,
       _artifactRequestPolicy = artifactRequestPolicy;

  final ChatCompletionClient _client;
  final ArtifactRequestPolicy _artifactRequestPolicy;

  Future<String?> repairEmptyDirectResponseIfNeeded({
    required String apiKey,
    required NeroSettings settings,
    required String prompt,
    required List<ChatMessage> requestMessages,
    required String currentResponse,
    required List<String> selectedTools,
  }) async {
    if (currentResponse.trim().isNotEmpty) {
      return null;
    }
    final outputTool = _artifactRequestPolicy.preferredOutputToolForPrompt(
      prompt,
      selectedTools,
    );
    if (outputTool != null) {
      return null;
    }
    final repairMessages = List<ChatMessage>.of(requestMessages, growable: true);
    repairMessages.add(
      ChatMessage(
        id: 'direct_response_repair_${repairMessages.length}',
        role: ChatRole.system,
        content:
            'The previous assistant response was empty. Answer the user directly now. Do not mention internal failures. Do not mention tools unless the user asked about them explicitly. If external context is incomplete, still provide the best concise answer possible from the available context.',
      ),
    );
    final result = await _client.completeChat(
      apiKey: apiKey,
      modelId: settings.selectedModelId,
      messages: repairMessages,
      tools: const <SarvamToolDefinition>[],
    );
    final repaired = result.content.trim();
    return repaired.isEmpty ? null : repaired;
  }

  bool shouldRecoverFromRepeatedToolLoop(Object error, AgentTask? task) {
    final message = error.toString();
    if (!message.contains('repeating the same tool calls')) {
      return false;
    }
    if (task == null) {
      return false;
    }
    final documentStep = task.steps
        .where((step) => step.kind == AgentStepKinds.generateDocument)
        .cast<AgentStep?>()
        .firstWhere((step) => step != null, orElse: () => null);
    return documentStep != null &&
        documentStep.status == AgentStepStatus.completed;
  }

  String repeatedToolLoopRecoveryMessage({required bool hasArtifact}) {
    if (hasArtifact) {
      return 'I created the file and attached it above.';
    }
    return 'File generation completed in degraded mode, so I could not finish the final synthesis step. The request was handled without creating a second tool pass.';
  }
}
