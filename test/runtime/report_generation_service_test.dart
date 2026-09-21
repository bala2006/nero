import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/agent/domain/agent_task.dart';
import 'package:nero/features/chat/domain/chat_message.dart';
import 'package:nero/features/runtime/domain/runtime_progress_snapshot.dart';
import 'package:nero/features/runtime/domain/runtime_run.dart';
import 'package:nero/features/runtime/domain/runtime_run_node.dart';
import 'package:nero/features/workspace/application/document_export_service.dart';
import 'package:nero/features/workspace/application/report_generation_service.dart';

void main() {
  test(
    'buildConversationReport normalizes assistant blocks and synthesizes runtime progress from task data',
    () {
      final service = ReportGenerationService(
        documentExportService: DocumentExportService(),
      );

      final report = service.buildConversationReport(
        conversationTitle: '   ',
        messages: const <ChatMessage>[
          ChatMessage(
            id: 'system_1',
            role: ChatRole.system,
            content: 'Ignore this',
          ),
          ChatMessage(
            id: 'user_1',
            role: ChatRole.user,
            content: 'Build me an app',
            attachments: <ChatAttachment>[
              ChatAttachment(
                id: 'file_1',
                title: 'requirements.md',
                kindLabel: 'Markdown document',
              ),
            ],
          ),
          ChatMessage(
            id: 'assistant_1',
            role: ChatRole.assistant,
            content: '''
[[NERO_BLOCK:CODE lang=dart]]
void main() {}
[[/NERO_BLOCK]]
''',
          ),
        ],
        activeTask: const AgentTask(
          id: 'task_1',
          conversationId: 'conversation_1',
          prompt: 'Build me an app',
          status: AgentTaskStatus.running,
          createdAtEpochMs: 1,
          updatedAtEpochMs: 2,
          steps: <AgentStep>[
            AgentStep(
              id: 'step_1',
              kind: AgentStepKinds.planTask,
              title: 'Plan project',
              status: AgentStepStatus.completed,
              detail: 'Chose Flutter',
            ),
          ],
        ),
      );

      expect(report.title, 'Nero conversation report');
      expect(report.markdown, contains('## Runtime Progress'));
      expect(report.markdown, contains('- Run ID: task:task_1'));
      expect(
        report.markdown,
        contains('- [completed] Plan project - Chose Flutter'),
      );
      expect(report.markdown, contains('_Attachments: requirements.md_'));
      expect(report.markdown, contains('```dart'));
      expect(report.markdown, isNot(contains('Ignore this')));
      expect(report.plainText, contains('void main() {}'));
    },
  );

  test(
    'buildConversationReport prefers runtime progress over task step fallback',
    () {
      final service = ReportGenerationService(
        documentExportService: DocumentExportService(),
      );

      final report = service.buildConversationReport(
        conversationTitle: 'Capabilities report',
        messages: const <ChatMessage>[
          ChatMessage(
            id: 'user_1',
            role: ChatRole.user,
            content: 'Create a docx report',
          ),
        ],
        activeTask: const AgentTask(
          id: 'task_1',
          conversationId: 'conversation_1',
          prompt: 'Create a docx report',
          status: AgentTaskStatus.running,
          createdAtEpochMs: 1,
          updatedAtEpochMs: 2,
          steps: <AgentStep>[
            AgentStep(
              id: 'step_1',
              kind: AgentStepKinds.planTask,
              title: 'Legacy plan task',
              status: AgentStepStatus.running,
            ),
          ],
        ),
        runtimeProgressSnapshot: const RuntimeProgressSnapshot(
          runId: 'run_1',
          runStatus: RuntimeRunStatus.runningTools,
          phases: <RuntimePhaseSnapshot>[
            RuntimePhaseSnapshot(
              phaseKey: 'tool_batch',
              title: 'Execute tools',
              status: RuntimeRunNodeStatus.running,
              activeDetail: 'Generating the requested document.',
            ),
          ],
        ),
      );

      expect(report.markdown, contains('## Runtime Progress'));
      expect(report.markdown, contains('- Run ID: run_1'));
      expect(
        report.markdown,
        contains('- [running] Execute tools - Generating the requested document.'),
      );
      expect(report.markdown, isNot(contains('## Active Task')));
      expect(report.markdown, isNot(contains('Legacy plan task')));
    },
  );
}
