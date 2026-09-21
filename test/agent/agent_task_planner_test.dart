import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/agent/application/agent_task_planner.dart';
import 'package:nero/features/agent/domain/agent_task.dart';

void main() {
  const planner = AgentTaskPlanner();

  test('simple query uses direct draft flow without planning step', () {
    final task = planner.createTask(
      conversationId: 'conv',
      prompt: 'What is recursion?',
    );

    expect(
      task.steps.map((step) => step.kind),
      <String>[
        AgentStepKinds.interpretPrompt,
        AgentStepKinds.prepareResponse,
        AgentStepKinds.streamResponse,
      ],
    );
  });

  test('research query injects research and synthesis steps', () {
    final task = planner.createTask(
      conversationId: 'conv',
      prompt: 'Find the latest Flutter CI guidance',
      selectedTools: const <String>['search_web'],
    );

    expect(
      task.steps.map((step) => step.kind),
      <String>[
        AgentStepKinds.interpretPrompt,
        AgentStepKinds.planTask,
        AgentStepKinds.toolResearch,
        AgentStepKinds.synthesizeResponse,
        AgentStepKinds.streamResponse,
      ],
    );
  });

  test('document failure replans into explicit error response', () {
    final initialTask = planner.createTask(
      conversationId: 'conv',
      prompt: 'Create a project proposal document',
      selectedTools: const <String>['generate_docx'],
    );
    final replanned = planner.replanForToolOutcomes(
      task: initialTask,
      selectedTools: const <String>['generate_docx'],
      outcomes: const <AgentToolOutcome>[
        AgentToolOutcome(toolName: 'generate_docx', success: false),
      ],
    );

    expect(
      replanned.steps.map((step) => step.kind),
      <String>[
        AgentStepKinds.interpretPrompt,
        AgentStepKinds.planTask,
        AgentStepKinds.generateDocument,
        AgentStepKinds.prepareResponse,
        AgentStepKinds.streamResponse,
      ],
    );
    expect(
      replanned.steps
          .firstWhere((step) => step.kind == AgentStepKinds.prepareResponse)
          .title,
      'Prepare error response',
    );
  });

  test('task progress snapshot exposes current and next steps canonically', () {
    const task = AgentTask(
      id: 'task_1',
      conversationId: 'conv',
      prompt: 'Research something',
      status: AgentTaskStatus.running,
      createdAtEpochMs: 1,
      updatedAtEpochMs: 2,
      steps: <AgentStep>[
        AgentStep(
          id: 'step_1',
          kind: AgentStepKinds.interpretPrompt,
          title: 'Interpret request',
          status: AgentStepStatus.completed,
        ),
        AgentStep(
          id: 'step_2',
          kind: AgentStepKinds.planTask,
          title: 'Plan research',
          status: AgentStepStatus.running,
          detail: 'Choosing sources.',
        ),
        AgentStep(
          id: 'step_3',
          kind: AgentStepKinds.toolResearch,
          title: 'Collect external context',
          status: AgentStepStatus.pending,
        ),
      ],
    );

    final progress = task.progressSnapshot;

    expect(progress.completedCount, 1);
    expect(progress.totalCount, 3);
    expect(progress.currentStep?.title, 'Plan research');
    expect(progress.nextStep?.title, 'Collect external context');
    expect(progress.primaryStep?.title, 'Plan research');
  });

  test('task progress snapshot surfaces blocked steps before pending ones', () {
    const task = AgentTask(
      id: 'task_2',
      conversationId: 'conv',
      prompt: 'Research something',
      status: AgentTaskStatus.failed,
      createdAtEpochMs: 1,
      updatedAtEpochMs: 2,
      steps: <AgentStep>[
        AgentStep(
          id: 'step_1',
          kind: AgentStepKinds.interpretPrompt,
          title: 'Interpret request',
          status: AgentStepStatus.completed,
        ),
        AgentStep(
          id: 'step_2',
          kind: AgentStepKinds.planTask,
          title: 'Plan research',
          status: AgentStepStatus.blocked,
          error: 'Response was empty.',
        ),
        AgentStep(
          id: 'step_3',
          kind: AgentStepKinds.toolResearch,
          title: 'Collect external context',
          status: AgentStepStatus.pending,
        ),
      ],
    );

    final progress = task.progressSnapshot;

    expect(progress.currentStep?.title, 'Plan research');
    expect(progress.primaryStep?.status, AgentStepStatus.blocked);
    expect(progress.nextStep?.title, 'Collect external context');
    expect(progress.hasBlockedSteps, isTrue);
  });
}
