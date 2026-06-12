import '../domain/agent_task.dart';

class AgentToolOutcome {
  const AgentToolOutcome({
    required this.toolName,
    required this.success,
    this.detail,
  });

  final String toolName;
  final bool success;
  final String? detail;
}

class AgentPlanStepInput {
  const AgentPlanStepInput({
    required this.id,
    required this.kind,
    required this.title,
    this.detail,
  });

  final String id;
  final String kind;
  final String title;
  final String? detail;
}

class AgentTaskPlanner {
  const AgentTaskPlanner();

  AgentTask createTask({
    required String conversationId,
    required String prompt,
    List<String> selectedTools = const <String>[],
    List<AgentPlanStepInput> apiSteps = const <AgentPlanStepInput>[],
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final normalizedPrompt = prompt.trim();
    return AgentTask(
      id: 'task_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversationId,
      prompt: normalizedPrompt,
      status: AgentTaskStatus.queued,
      createdAtEpochMs: now,
      updatedAtEpochMs: now,
      steps: _buildPlan(
        prompt: normalizedPrompt,
        selectedTools: selectedTools,
        apiSteps: apiSteps,
      ),
    );
  }

  AgentTask replanForSelectedTools({
    required AgentTask task,
    required List<String> selectedTools,
    List<AgentPlanStepInput> apiSteps = const <AgentPlanStepInput>[],
  }) {
    return _rebuildTask(
      task: task,
      prompt: task.prompt,
      selectedTools: selectedTools,
      apiSteps: apiSteps,
    );
  }

  AgentTask replanForToolOutcomes({
    required AgentTask task,
    required List<String> selectedTools,
    required List<AgentToolOutcome> outcomes,
    List<AgentPlanStepInput> apiSteps = const <AgentPlanStepInput>[],
  }) {
    final docGenerationFailed = outcomes.any(
      (outcome) => _isOutputTool(outcome.toolName) && !outcome.success,
    );
    return _rebuildTask(
      task: task,
      prompt: task.prompt,
      selectedTools: selectedTools,
      docGenerationFailed: docGenerationFailed,
      apiSteps: apiSteps,
    );
  }

  AgentTask _rebuildTask({
    required AgentTask task,
    required String prompt,
    required List<String> selectedTools,
    bool docGenerationFailed = false,
    List<AgentPlanStepInput> apiSteps = const <AgentPlanStepInput>[],
  }) {
    final plannedSteps = _buildPlan(
      prompt: prompt,
      selectedTools: selectedTools,
      docGenerationFailed: docGenerationFailed,
      apiSteps: apiSteps,
    );
    final existingById = <String, AgentStep>{
      for (final step in task.steps) step.id: step,
    };
    final mergedSteps = plannedSteps
        .map((planned) => _mergeStep(planned, existingById[planned.id]))
        .toList(growable: false);
    return task.copyWith(
      updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      steps: mergedSteps,
    );
  }

  AgentStep _mergeStep(AgentStep planned, AgentStep? existing) {
    if (existing == null) {
      return planned;
    }
    return existing.copyWith(
      id: planned.id,
      title: planned.title,
      detail: existing.status == AgentStepStatus.pending
          ? planned.detail
          : existing.detail ?? planned.detail,
    );
  }

  List<AgentStep> _buildPlan({
    required String prompt,
    required List<String> selectedTools,
    bool docGenerationFailed = false,
    List<AgentPlanStepInput> apiSteps = const <AgentPlanStepInput>[],
  }) {
    if (apiSteps.isNotEmpty) {
      return List<AgentStep>.unmodifiable(
        apiSteps
            .map(
              (step) => AgentStep(
                id: step.id,
                kind: step.kind,
                title: step.title,
                status: AgentStepStatus.pending,
                detail: step.detail,
              ),
            )
            .toList(growable: false),
      );
    }
    final loweredPrompt = prompt.toLowerCase();
    final route = _routePrompt(
      prompt: loweredPrompt,
      selectedTools: selectedTools,
      docGenerationFailed: docGenerationFailed,
    );
    return List<AgentStep>.unmodifiable(
      route.steps
          .map(
            (step) => AgentStep(
              id: step.id,
              kind: step.kind,
              title: step.title,
              status: AgentStepStatus.pending,
              detail: step.detail,
            ),
          )
          .toList(growable: false),
    );
  }

  _PlannerRoute _routePrompt({
    required String prompt,
    required List<String> selectedTools,
    required bool docGenerationFailed,
  }) {
    final selected = selectedTools.toSet();
    final usesWebTools = selected.any(_isWebTool);
    final usesDocumentTool = selected.any(_isOutputTool);
    final needsDiagram = _needsDiagram(prompt);
    final needsCode = _needsCode(prompt);
    final needsResearch = _needsResearch(prompt);
    final needsDocument = _needsDocument(prompt);

    if (selected.length > 1) {
      return _PlannerRoute.hybrid(
        usesWebTools: usesWebTools,
        usesDocumentTool: usesDocumentTool,
        needsDiagram: needsDiagram,
        docGenerationFailed: docGenerationFailed,
      );
    }
    if (usesDocumentTool) {
      return _PlannerRoute.documentJob(
        needsDiagram: needsDiagram,
        docGenerationFailed: docGenerationFailed,
      );
    }
    if (usesWebTools) {
      return _PlannerRoute.researchQuery(needsDiagram: needsDiagram);
    }
    if (needsDocument) {
      return _PlannerRoute.documentJob(
        needsDiagram: needsDiagram,
        docGenerationFailed: docGenerationFailed,
      );
    }
    if (needsResearch) {
      return _PlannerRoute.researchQuery(needsDiagram: needsDiagram);
    }
    if (_needsFileCreation(prompt)) {
      return _PlannerRoute.fileCreation(
        needsDiagram: needsDiagram,
        needsZip: _needsZipPackage(prompt),
      );
    }
    if (needsCode) {
      return _PlannerRoute.codeGen(needsDiagram: needsDiagram);
    }
    return _PlannerRoute.simpleQuery(needsDiagram: needsDiagram);
  }

  bool _isWebTool(String toolName) {
    return toolName == 'search_web' ||
        toolName == 'read_url' ||
        toolName == 'extract_article';
  }

  bool _isOutputTool(String toolName) {
    return toolName == 'generate_docx' ||
        toolName == 'generate_xlsx' ||
        toolName == 'generate_report_pdf';
  }

  bool _needsCode(String prompt) {
    const keywords = <String>[
      'code',
      'function',
      'flutter',
      'dart',
      'python',
      'typescript',
      'javascript',
      'sql',
      'algorithm',
      'refactor',
      'implement',
      'bug',
      'debug',
    ];
    return keywords.any(prompt.contains);
  }

  bool _needsResearch(String prompt) {
    const keywords = <String>[
      'latest',
      'today',
      'current',
      'news',
      'recent',
      'search',
      'look up',
      'browse',
      'find online',
      'web',
      'website',
      'url',
      'link',
      'docs',
      'documentation',
    ];
    return keywords.any(prompt.contains);
  }

  bool _needsDocument(String prompt) {
    return (prompt.contains('docx') ||
            prompt.contains('pdf') ||
            prompt.contains('xlsx') ||
            prompt.contains('excel') ||
            prompt.contains('spreadsheet') ||
            prompt.contains('word') ||
            prompt.contains('document') ||
            prompt.contains('report') ||
            prompt.contains('memo') ||
            prompt.contains('letter')) &&
        (prompt.contains('create') ||
            prompt.contains('generate') ||
            prompt.contains('make') ||
            prompt.contains('prepare') ||
            prompt.contains('write'));
  }

  bool _needsDiagram(String prompt) {
    return prompt.contains('diagram') ||
        prompt.contains('mermaid') ||
        prompt.contains('flowchart') ||
        prompt.contains('visual');
  }

  bool _needsFileCreation(String prompt) {
    final asksToCreate =
        prompt.contains('create') ||
        prompt.contains('generate') ||
        prompt.contains('make') ||
        prompt.contains('write') ||
        prompt.contains('build');
    final namesFiles =
        prompt.contains('file') ||
        prompt.contains('.txt') ||
        prompt.contains('.md') ||
        prompt.contains('readme') ||
        prompt.contains('project') ||
        prompt.contains('workspace') ||
        prompt.contains('folder') ||
        prompt.contains('directory');
    return asksToCreate && namesFiles;
  }

  bool _needsZipPackage(String prompt) {
    return prompt.contains('zip') ||
        prompt.contains('archive') ||
        prompt.contains('bundle') ||
        prompt.contains('package') ||
        prompt.contains('download');
  }
}

class _PlannerRoute {
  const _PlannerRoute(this.steps);

  final List<_PlannedStep> steps;

  factory _PlannerRoute.simpleQuery({required bool needsDiagram}) {
    return _PlannerRoute(<_PlannedStep>[
      const _PlannedStep(
        kind: AgentStepKinds.interpretPrompt,
        id: 'interpret_prompt',
        title: 'Understand request',
        detail: 'Extract the user goal, output shape, and key constraints.',
      ),
      const _PlannedStep(
        kind: AgentStepKinds.prepareResponse,
        id: 'draft_response',
        title: 'Draft response',
        detail: 'Prepare the answer directly from the conversation context.',
      ),
      const _PlannedStep(
        kind: AgentStepKinds.streamResponse,
        id: 'stream_response',
        title: 'Deliver answer',
        detail: 'Stream or finalize the response in chat and persist task state.',
      ),
      if (needsDiagram)
        const _PlannedStep(
          kind: AgentStepKinds.renderDiagram,
          id: 'render_diagram',
          title: 'Render Mermaid diagram',
          detail: 'Validate and render Mermaid output separately from drafting.',
        ),
    ]);
  }

  factory _PlannerRoute.codeGen({required bool needsDiagram}) {
    return _PlannerRoute(<_PlannedStep>[
      const _PlannedStep(
        kind: AgentStepKinds.interpretPrompt,
        id: 'interpret_prompt',
        title: 'Understand coding task',
        detail: 'Extract the coding goal, constraints, and expected output.',
      ),
      const _PlannedStep(
        kind: AgentStepKinds.planTask,
        id: 'plan_task',
        title: 'Plan implementation',
        detail: 'Create the smallest reliable code-first step sequence.',
      ),
      const _PlannedStep(
        kind: AgentStepKinds.prepareResponse,
        id: 'prepare_response',
        title: 'Draft code solution',
        detail: 'Prepare a code-first response with concise explanation.',
      ),
      const _PlannedStep(
        kind: AgentStepKinds.streamResponse,
        id: 'stream_response',
        title: 'Deliver answer',
        detail: 'Stream or finalize the response in chat and persist task state.',
      ),
      if (needsDiagram)
        const _PlannedStep(
          kind: AgentStepKinds.renderDiagram,
          id: 'render_diagram',
          title: 'Render Mermaid diagram',
          detail: 'Validate and render Mermaid output separately from drafting.',
        ),
    ]);
  }

  factory _PlannerRoute.researchQuery({required bool needsDiagram}) {
    return _PlannerRoute(<_PlannedStep>[
      const _PlannedStep(
        kind: AgentStepKinds.interpretPrompt,
        id: 'interpret_prompt',
        title: 'Understand research request',
        detail: 'Extract the research goal, constraints, and output format.',
      ),
      const _PlannedStep(
        kind: AgentStepKinds.planTask,
        id: 'plan_task',
        title: 'Plan research',
        detail: 'Decide which external context is needed before answering.',
      ),
      const _PlannedStep(
        kind: AgentStepKinds.toolResearch,
        id: 'tool_research',
        title: 'Collect external context',
        detail: 'Use the selected web tools to gather current external evidence.',
      ),
      const _PlannedStep(
        kind: AgentStepKinds.synthesizeResponse,
        id: 'synthesize_response',
        title: 'Synthesize findings',
        detail: 'Convert tool results into a grounded answer with clear takeaways.',
      ),
      const _PlannedStep(
        kind: AgentStepKinds.streamResponse,
        id: 'stream_response',
        title: 'Deliver answer',
        detail: 'Stream or finalize the response in chat and persist task state.',
      ),
      if (needsDiagram)
        const _PlannedStep(
          kind: AgentStepKinds.renderDiagram,
          id: 'render_diagram',
          title: 'Render Mermaid diagram',
          detail: 'Validate and render Mermaid output separately from drafting.',
        ),
    ]);
  }

  factory _PlannerRoute.documentJob({
    required bool needsDiagram,
    required bool docGenerationFailed,
  }) {
    return _PlannerRoute(<_PlannedStep>[
      const _PlannedStep(
        kind: AgentStepKinds.interpretPrompt,
        id: 'interpret_prompt',
        title: 'Understand document request',
        detail: 'Extract the document goal, format, and expected deliverable.',
      ),
      const _PlannedStep(
        kind: AgentStepKinds.planTask,
        id: 'plan_task',
        title: 'Plan document generation',
        detail: 'Prepare the document-generation path and output contract.',
      ),
      _PlannedStep(
        kind: AgentStepKinds.generateDocument,
        id: 'generate_document',
        title: 'Create document artifact',
        detail: docGenerationFailed
            ? 'Document generation failed. Stop artifact generation and surface the error clearly.'
            : 'Create the requested document artifact from structured markdown.',
      ),
      if (docGenerationFailed)
        const _PlannedStep(
          kind: AgentStepKinds.prepareResponse,
          id: 'prepare_response',
          title: 'Prepare error response',
          detail: 'Report artifact failure clearly instead of degrading into an in-chat fallback.',
        ),
      const _PlannedStep(
        kind: AgentStepKinds.streamResponse,
        id: 'stream_response',
        title: 'Deliver answer',
        detail: 'Stream or finalize the response in chat and persist task state.',
      ),
      if (needsDiagram)
        const _PlannedStep(
          kind: AgentStepKinds.renderDiagram,
          id: 'render_diagram',
          title: 'Render Mermaid diagram',
          detail: 'Validate and render Mermaid output separately from drafting.',
        ),
    ]);
  }

  factory _PlannerRoute.hybrid({
    required bool usesWebTools,
    required bool usesDocumentTool,
    required bool needsDiagram,
    required bool docGenerationFailed,
  }) {
    return _PlannerRoute(<_PlannedStep>[
      const _PlannedStep(
        kind: AgentStepKinds.interpretPrompt,
        id: 'interpret_prompt',
        title: 'Understand multi-step request',
        detail: 'Extract the mixed research and delivery requirements.',
      ),
      const _PlannedStep(
        kind: AgentStepKinds.planTask,
        id: 'plan_task',
        title: 'Coordinate execution',
        detail: 'Coordinate the tool plan and fallback path before answering.',
      ),
      if (usesWebTools)
        const _PlannedStep(
          kind: AgentStepKinds.toolResearch,
          id: 'tool_research',
          title: 'Run research tools',
          detail: 'Execute the selected external tools in parallel and collect evidence.',
        ),
      if (usesDocumentTool)
        _PlannedStep(
          kind: AgentStepKinds.generateDocument,
          id: 'generate_document',
          title: 'Create document artifact',
          detail: docGenerationFailed
              ? 'Document artifact generation failed. Stop artifact creation and report the failure clearly.'
              : 'Create the requested document artifact alongside the research response.',
        ),
      const _PlannedStep(
        kind: AgentStepKinds.synthesizeResponse,
        id: 'synthesize_response',
        title: 'Compose final response',
        detail: 'Fuse the tool outputs into one coherent answer for the user.',
      ),
      const _PlannedStep(
        kind: AgentStepKinds.streamResponse,
        id: 'stream_response',
        title: 'Deliver answer',
        detail: 'Stream or finalize the response in chat and persist task state.',
      ),
      if (needsDiagram)
        const _PlannedStep(
          kind: AgentStepKinds.renderDiagram,
          id: 'render_diagram',
          title: 'Render Mermaid diagram',
          detail: 'Validate and render Mermaid output separately from drafting.',
        ),
    ]);
  }

  factory _PlannerRoute.fileCreation({
    required bool needsDiagram,
    required bool needsZip,
  }) {
    return _PlannerRoute(<_PlannedStep>[
      const _PlannedStep(
        kind: AgentStepKinds.interpretPrompt,
        id: 'interpret_prompt',
        title: 'Understand file request',
        detail: 'Extract the file creation goal, file types, and naming.',
      ),
      const _PlannedStep(
        kind: AgentStepKinds.planTask,
        id: 'plan_task',
        title: 'Plan file creation',
        detail: 'Plan the file structure and content generation sequence.',
      ),
      const _PlannedStep(
        kind: AgentStepKinds.createFiles,
        id: 'create_files',
        title: 'Create files',
        detail: 'Generate the requested files in the workspace.',
      ),
      if (needsZip)
        const _PlannedStep(
          kind: AgentStepKinds.packageProject,
          id: 'package_project',
          title: 'Package files',
          detail: 'Bundle all created files into a downloadable ZIP archive.',
        ),
      const _PlannedStep(
        kind: AgentStepKinds.streamResponse,
        id: 'stream_response',
        title: 'Deliver answer',
        detail: 'Stream or finalize the response in chat and persist task state.',
      ),
      if (needsDiagram)
        const _PlannedStep(
          kind: AgentStepKinds.renderDiagram,
          id: 'render_diagram',
          title: 'Render Mermaid diagram',
          detail: 'Validate and render Mermaid output separately from drafting.',
        ),
    ]);
  }
}

class _PlannedStep {
  const _PlannedStep({
    required this.kind,
    required this.id,
    required this.title,
    required this.detail,
  });

  final String kind;
  final String id;
  final String title;
  final String detail;
}
