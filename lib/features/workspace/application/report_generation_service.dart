import '../../agent/domain/agent_task.dart';
import '../../chat/domain/chat_message.dart';
import '../../runtime/application/agent_task_runtime_progress_adapter.dart';
import '../../runtime/domain/runtime_progress_snapshot.dart';
import 'document_export_service.dart';

class GeneratedReport {
  const GeneratedReport({
    required this.title,
    required this.markdown,
    required this.plainText,
  });

  final String title;
  final String markdown;
  final String plainText;
}

class ReportGenerationService {
  ReportGenerationService({
    DocumentExportService? documentExportService,
  }) : _documentExportService = documentExportService ?? DocumentExportService();

  final DocumentExportService _documentExportService;
  final AgentTaskRuntimeProgressAdapter _taskRuntimeProgressAdapter =
      const AgentTaskRuntimeProgressAdapter();

  GeneratedReport buildConversationReport({
    required String conversationTitle,
    required List<ChatMessage> messages,
    AgentTask? activeTask,
    RuntimeProgressSnapshot? runtimeProgressSnapshot,
  }) {
    final normalizedTitle = _normalizeTitle(conversationTitle);
    final markdown = StringBuffer()
      ..writeln('# $normalizedTitle')
      ..writeln()
      ..writeln(
        '_Generated ${DateTime.now().toLocal().toString().replaceFirst('.000', '')}_',
      )
      ..writeln();

    final effectiveRuntimeProgress =
        runtimeProgressSnapshot ?? _taskRuntimeProgressAdapter.adapt(activeTask);
    if (effectiveRuntimeProgress != null &&
        effectiveRuntimeProgress.phases.isNotEmpty) {
      markdown
        ..writeln('## Runtime Progress')
        ..writeln()
        ..writeln('- Run ID: ${effectiveRuntimeProgress.runId}')
        ..writeln('- Status: ${effectiveRuntimeProgress.runStatus.name}')
        ..writeln('- Phases: ${effectiveRuntimeProgress.phases.length}')
        ..writeln();
      markdown.writeln('### Runtime Phases');
      markdown.writeln();
      for (final phase in effectiveRuntimeProgress.phases) {
        final detail = phase.error ?? phase.activeDetail;
        markdown.writeln(
          '- [${phase.status.name}] ${phase.title}${detail == null ? '' : ' - $detail'}',
        );
      }
      markdown.writeln();
    } else if (activeTask != null) {
      markdown
        ..writeln('## Active Task')
        ..writeln()
        ..writeln('- Prompt: ${activeTask.prompt.trim()}')
        ..writeln('- Status: ${activeTask.status.name}')
        ..writeln('- Steps: ${activeTask.steps.length}')
        ..writeln();
      if (activeTask.steps.isNotEmpty) {
        markdown.writeln('### Task Steps');
        markdown.writeln();
        for (final step in activeTask.steps) {
          markdown.writeln(
            '- [${step.status.name}] ${step.title}${step.detail == null ? '' : ' - ${step.detail}'}',
          );
        }
        markdown.writeln();
      }
    }

    markdown
      ..writeln('## Conversation')
      ..writeln();

    for (final message in messages.where((message) => message.role != ChatRole.system)) {
      final roleLabel = switch (message.role) {
        ChatRole.user => 'User',
        ChatRole.assistant => 'Assistant',
        ChatRole.system => 'System',
      };
      markdown
        ..writeln('### $roleLabel')
        ..writeln();

      if (message.attachments.isNotEmpty) {
        markdown.writeln(
          '_Attachments: ${message.attachments.map((item) => item.title).join(', ')}_',
        );
        markdown.writeln();
      }

      final body = message.role == ChatRole.assistant
          ? _documentExportService.toMarkdown(message.content)
          : message.content.trim();
      markdown.writeln(body.isEmpty ? '_No content_' : body);
      markdown.writeln();
    }

    final markdownText = markdown.toString().trim();
    return GeneratedReport(
      title: normalizedTitle,
      markdown: markdownText,
      plainText: _documentExportService.toPlainText(markdownText),
    );
  }

  String _normalizeTitle(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return 'Nero conversation report';
    }
    return normalized;
  }
}
