import 'package:flutter/foundation.dart';

import '../../workspace/application/workspace_store.dart';
import '../../memory/domain/artifact_reference.dart';
import '../../memory/application/memory_store.dart';
import '../../memory/application/semantic_fact_store.dart';
import '../../memory/application/working_memory_store.dart';
import '../../memory/domain/memory_entry.dart';
import '../../memory/domain/semantic_fact.dart';
import '../../memory/domain/working_memory_snapshot.dart';
import '../domain/chat_message.dart';

class ContextEngineResult {
  const ContextEngineResult({
    required this.messages,
    required this.workingMemory,
    required this.episodicMemories,
    required this.semanticFacts,
    required this.artifactReferences,
  });

  final List<ChatMessage> messages;
  final WorkingMemorySnapshot? workingMemory;
  final List<MemoryEntry> episodicMemories;
  final List<SemanticFact> semanticFacts;
  final List<ArtifactReference> artifactReferences;
}

class ContextEngine {
  ContextEngine({
    MemoryStore? memoryStore,
    SemanticFactStore? semanticFactStore,
    WorkingMemoryStore? workingMemoryStore,
    WorkspaceStore? workspaceStore,
    int historyMessageLimit = 12,
  }) : _memoryStore = memoryStore ?? MemoryStore(),
       _semanticFactStore = semanticFactStore ?? SemanticFactStore(),
       _workingMemoryStore = workingMemoryStore ?? WorkingMemoryStore(),
       _workspaceStore = workspaceStore ?? WorkspaceStore(),
       _historyMessageLimit = historyMessageLimit;

  final MemoryStore _memoryStore;
  final SemanticFactStore _semanticFactStore;
  final WorkingMemoryStore _workingMemoryStore;
  final WorkspaceStore _workspaceStore;
  final int _historyMessageLimit;

  Future<ContextEngineResult> assemble({
    required String conversationId,
    required String? taskId,
    required List<ChatMessage> history,
    required String systemPrompt,
    required String outputToolsPrompt,
    String? taskHint,
  }) async {
    try {
      final trimmedHistory = history
          .where((message) => !message.isStreaming)
          .toList(growable: false);
      final recent = _scoreAndSelectHistory(trimmedHistory);
      final workingMemory = taskId == null
          ? null
          : await _workingMemoryStore.latestSnapshotForTask(taskId);
      final episodicMemories = await _memoryStore.listEntries(
        kind: MemoryEntryKind.episodic,
        conversationId: conversationId,
        limit: 3,
      );
      final semanticFacts = await _semanticFactStore.listFacts(
        scope: 'conversation',
        scopeId: conversationId,
        limit: 5,
      );
      final artifactReferences = (await _workspaceStore.listRecent(
        conversationId: conversationId,
        limit: 3,
      ))
          .where((item) => item.type.name.contains('Artifact'))
          .map(
            (item) => ArtifactReference(
              artifactId: item.id,
              title: item.title,
              kind: item.type.name,
              localPath: item.localPath,
              sourceUri: item.sourceUri,
            ),
          )
          .toList(growable: false);
      return ContextEngineResult(
        messages: <ChatMessage>[
          ChatMessage(
            id: 'system_variant',
            role: ChatRole.system,
            content: systemPrompt,
          ),
          ChatMessage(
            id: 'output_tools',
            role: ChatRole.system,
            content: outputToolsPrompt,
          ),
          if (taskHint != null && taskHint.trim().isNotEmpty)
            ChatMessage(
              id: 'task_hint',
              role: ChatRole.system,
              content: taskHint.trim(),
            ),
          ..._memoryMessages(
            workingMemory: workingMemory,
            episodicMemories: episodicMemories,
            semanticFacts: semanticFacts,
            artifactReferences: artifactReferences,
          ),
          ...recent,
        ],
        workingMemory: workingMemory,
        episodicMemories: episodicMemories,
        semanticFacts: semanticFacts,
        artifactReferences: artifactReferences,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[ContextEngine] Context assembly degraded: $error\n$stackTrace',
      );
      final start = history.length > _historyMessageLimit
          ? history.length - _historyMessageLimit
          : 0;
      final trimmedHistory = history.sublist(start);
      return ContextEngineResult(
        messages: <ChatMessage>[
          ChatMessage(
            id: 'system_variant',
            role: ChatRole.system,
            content: systemPrompt,
          ),
          ChatMessage(
            id: 'output_tools',
            role: ChatRole.system,
            content: outputToolsPrompt,
          ),
          if (taskHint != null && taskHint.trim().isNotEmpty)
            ChatMessage(
              id: 'task_hint',
              role: ChatRole.system,
              content: taskHint.trim(),
            ),
          ...trimmedHistory,
        ],
        workingMemory: null,
        episodicMemories: const <MemoryEntry>[],
        semanticFacts: const <SemanticFact>[],
        artifactReferences: const <ArtifactReference>[],
      );
    }
  }

  List<ChatMessage> _scoreAndSelectHistory(List<ChatMessage> history) {
    if (history.length <= _historyMessageLimit) {
      return history;
    }
    final scored = history.asMap().entries.map((entry) {
      final index = entry.key;
      final message = entry.value;
      final recencyScore = (index + 1) / history.length;
      final lengthScore = message.content.length > 240 ? 0.15 : 0.0;
      final attachmentScore = message.attachments.isNotEmpty ? 0.2 : 0.0;
      final score = recencyScore + lengthScore + attachmentScore;
      return _ScoredMessage(message: message, score: score);
    }).toList(growable: false)
      ..sort((a, b) => b.score.compareTo(a.score));
    final selected = scored
        .take(_historyMessageLimit)
        .map((entry) => entry.message)
        .toList(growable: false);
    final selectedIds = selected.map((message) => message.id).toSet();
    return history
        .where((message) => selectedIds.contains(message.id))
        .toList(growable: false);
  }

  List<ChatMessage> _memoryMessages({
    required WorkingMemorySnapshot? workingMemory,
    required List<MemoryEntry> episodicMemories,
    required List<SemanticFact> semanticFacts,
    required List<ArtifactReference> artifactReferences,
  }) {
    final messages = <ChatMessage>[];
    if (workingMemory != null) {
      messages.add(
        ChatMessage(
          id: 'working_memory',
          role: ChatRole.system,
          content:
              'Working memory snapshot:\nSummary: ${workingMemory.summary}\n'
              'Assumptions: ${workingMemory.assumptions.join('; ')}\n'
              'Focus files: ${workingMemory.focusFilePaths.join(', ')}',
        ),
      );
    }
    if (semanticFacts.isNotEmpty) {
      messages.add(
        ChatMessage(
          id: 'semantic_facts',
          role: ChatRole.system,
          content: 'Relevant facts:\n${semanticFacts.map(_formatFact).join('\n')}',
        ),
      );
    }
    if (episodicMemories.isNotEmpty) {
      messages.add(
        ChatMessage(
          id: 'episodic_memory',
          role: ChatRole.system,
          content:
              'Recent related episodes:\n${episodicMemories.map(_formatMemory).join('\n')}',
        ),
      );
    }
    if (artifactReferences.isNotEmpty) {
      messages.add(
        ChatMessage(
          id: 'artifact_references',
          role: ChatRole.system,
          content:
              'Recent artifacts in this conversation:\n${artifactReferences.map(_formatArtifact).join('\n')}',
        ),
      );
    }
    return messages;
  }

  String _formatFact(SemanticFact fact) {
    final value = fact.value.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(', ');
    return '- ${fact.key}: $value';
  }

  String _formatMemory(MemoryEntry entry) {
    return '- ${entry.summary ?? entry.title}';
  }

  String _formatArtifact(ArtifactReference artifact) {
    return '- ${artifact.title} (${artifact.kind})';
  }
}

class _ScoredMessage {
  const _ScoredMessage({
    required this.message,
    required this.score,
  });

  final ChatMessage message;
  final double score;
}
