import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/agent/domain/agent_task.dart';
import 'package:nero/features/docs/application/artifact_request_policy.dart';

void main() {
  const policy = ArtifactRequestPolicy();

  test('preferredOutputToolForPrompt infers docx when selection is empty', () {
    final tool = policy.preferredOutputToolForPrompt(
      'create a docx about capabilities',
      const <String>[],
    );

    expect(tool, 'generate_docx');
  });

  test('preferredOutputToolForPrompt respects selected tools', () {
    final tool = policy.preferredOutputToolForPrompt(
      'create a pdf about capabilities',
      const <String>['search_web', 'generate_report_pdf'],
    );

    expect(tool, 'generate_report_pdf');
  });

  test('capability questions are skipped instead of treated as artifact requests', () {
    expect(
      policy.shouldSkipArtifactCompletion('Can you generate doc and pdf?'),
      isTrue,
    );
    expect(
      policy.preferredOutputToolForPrompt(
        'Can you generate doc and pdf?',
        const <String>[],
      ),
      isNull,
    );
  });

  test('strictFailureIfNeeded returns standardized failure resolution', () {
    final resolution = policy.strictFailureIfNeeded(
      prompt: 'create a docx about capabilities',
      selectedTools: const <String>['generate_docx'],
      hasGeneratedArtifacts: false,
    );

    expect(resolution, isNotNull);
    expect(resolution!.stepError, 'Artifact generation ended without a valid file.');
    expect(
      resolution.userResponse,
      'I could not complete the requested file artifact because no valid file was produced.',
    );
  });

  test('documentGenerationAlreadyAttempted tracks finished document steps', () {
    expect(
      policy.documentGenerationAlreadyAttempted(
        const AgentTask(
          id: 'task_1',
          conversationId: 'conversation_1',
          prompt: 'Create a docx',
          status: AgentTaskStatus.running,
          createdAtEpochMs: 1,
          updatedAtEpochMs: 2,
          steps: <AgentStep>[
            AgentStep(
              id: 'step_1',
              kind: AgentStepKinds.generateDocument,
              title: 'Generate document',
              status: AgentStepStatus.failed,
            ),
          ],
        ),
      ),
      isTrue,
    );
    expect(
      policy.documentGenerationAlreadyAttempted(
        const AgentTask(
          id: 'task_2',
          conversationId: 'conversation_1',
          prompt: 'Create a docx',
          status: AgentTaskStatus.running,
          createdAtEpochMs: 1,
          updatedAtEpochMs: 2,
          steps: <AgentStep>[
            AgentStep(
              id: 'step_1',
              kind: AgentStepKinds.generateDocument,
              title: 'Generate document',
              status: AgentStepStatus.running,
            ),
          ],
        ),
      ),
      isFalse,
    );
  });
}
