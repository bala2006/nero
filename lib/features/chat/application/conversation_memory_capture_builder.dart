import '../../agent/domain/agent_task.dart';
import '../../memory/domain/semantic_fact.dart';
import '../../memory/domain/working_memory_snapshot.dart';

class ConversationMemoryCapture {
  const ConversationMemoryCapture({
    required this.snapshot,
    required this.fact,
  });

  final WorkingMemorySnapshot snapshot;
  final SemanticFact fact;
}

class ConversationMemoryCaptureBuilder {
  const ConversationMemoryCaptureBuilder();

  ConversationMemoryCapture build({
    required AgentTask task,
    required String conversationId,
    required String prompt,
    required String finalResponse,
    required String? currentThought,
    required int visibleActivityCount,
    required int messageCount,
    required int nowEpochMs,
  }) {
    final summary = summarize(prompt, finalResponse);
    final assumptions = <String>[
      if (currentThought != null && currentThought.trim().isNotEmpty)
        currentThought.trim(),
      if (visibleActivityCount > 0)
        'Used $visibleActivityCount visible activity entries.',
    ];
    return ConversationMemoryCapture(
      snapshot: WorkingMemorySnapshot(
        id: 'working_${task.id}',
        conversationId: conversationId,
        taskId: task.id,
        summary: summary,
        assumptions: assumptions,
        focusFilePaths: const <String>[],
        metadata: <String, Object?>{
          'status': task.status.name,
          'messageCount': messageCount,
        },
        createdAtEpochMs: nowEpochMs,
        updatedAtEpochMs: nowEpochMs,
      ),
      fact: SemanticFact(
        id: 'fact_latest_response_${task.id}',
        scope: 'conversation',
        scopeId: conversationId,
        key: 'latest_response',
        value: <String, Object?>{
          'prompt': prompt,
          'summary': summary,
        },
        confidence: 0.72,
        createdAtEpochMs: nowEpochMs,
        updatedAtEpochMs: nowEpochMs,
      ),
    );
  }

  String summarize(String prompt, String response) {
    final normalizedPrompt = prompt.replaceAll(RegExp(r'\s+'), ' ').trim();
    final normalizedResponse = response.replaceAll(RegExp(r'\s+'), ' ').trim();
    final clippedResponse = normalizedResponse.length > 240
        ? '${normalizedResponse.substring(0, 240)}...'
        : normalizedResponse;
    return 'Prompt: $normalizedPrompt | Response: $clippedResponse';
  }
}
