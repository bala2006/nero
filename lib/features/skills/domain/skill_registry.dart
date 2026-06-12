import 'skill_models.dart';

class SkillRegistry {
  SkillRegistry._();

  static const SkillDescriptor researchReportSkill = SkillDescriptor(
    skillId: 'research_report_skill',
    version: 1,
    displayName: 'Research Report',
    purpose: 'Gather evidence, rank sources, and synthesize a research report.',
    visibility: SkillVisibility.preferred,
    requestKinds: <SkillRequestKind>{SkillRequestKind.research},
    inputContract: SkillContract(
      title: 'Research report input',
      description: 'Structured inputs for a research report skill run.',
      fields: <SkillFieldDefinition>[
        SkillFieldDefinition(
          name: 'topic',
          kind: SkillValueKind.string,
          description: 'The topic to research.',
          required: true,
          allowEmpty: false,
        ),
        SkillFieldDefinition(
          name: 'depth',
          kind: SkillValueKind.string,
          description: 'Depth of research to perform.',
          required: false,
          allowEmpty: false,
          examples: <Object?>['brief', 'standard', 'deep'],
        ),
        SkillFieldDefinition(
          name: 'audience',
          kind: SkillValueKind.string,
          description: 'Target audience for the report.',
          required: false,
          allowEmpty: false,
        ),
        SkillFieldDefinition(
          name: 'citation_style',
          kind: SkillValueKind.string,
          description: 'Preferred citation style.',
          required: false,
          allowEmpty: false,
        ),
      ],
    ),
    outputContract: SkillContract(
      title: 'Research report output',
      description: 'Normalized output produced by the research workflow.',
      fields: <SkillFieldDefinition>[
        SkillFieldDefinition(
          name: 'summary',
          kind: SkillValueKind.string,
          description: 'Concise summary of the findings.',
          required: true,
        ),
        SkillFieldDefinition(
          name: 'evidence',
          kind: SkillValueKind.array,
          description: 'Evidence items collected during the run.',
          required: true,
        ),
        SkillFieldDefinition(
          name: 'findings',
          kind: SkillValueKind.array,
          description: 'Key findings extracted from evidence.',
          required: true,
        ),
        SkillFieldDefinition(
          name: 'recommendation',
          kind: SkillValueKind.string,
          description: 'Actionable recommendation or answer.',
          required: false,
        ),
        SkillFieldDefinition(
          name: 'artifact_path',
          kind: SkillValueKind.string,
          description: 'Optional exported artifact path.',
          required: false,
        ),
      ],
    ),
    policy: SkillPolicy(
      sideEffectPolicy: SkillSideEffectPolicy.readOnly,
      singleUse: false,
      requiresVerifier: true,
      requiresEvidence: true,
      approvalRequired: false,
      allowParallelExecution: true,
      maxRetries: 2,
      timeoutMilliseconds: 120000,
    ),
    qualityGate: SkillQualityGate(
      requiredChecks: <String>[
        'source_coverage',
        'dedupe_sources',
        'claim_traceability',
        'verifier_review',
      ],
      strictOutputValidation: true,
    ),
    subgraph: SkillSubgraph(
      entryStepId: 'research_report_skill.classify_request',
      terminalStepId: 'research_report_skill.emit_response',
      steps: <SkillStepDescriptor>[
        SkillStepDescriptor(
          id: 'research_report_skill.classify_request',
          title: 'Classify request',
          description: 'Normalize the question and determine the research shape.',
          kind: SkillStepKind.classify,
          inputKeys: <String>['topic', 'depth', 'audience', 'citation_style'],
          outputKeys: <String>['classification', 'research_scope'],
        ),
        SkillStepDescriptor(
          id: 'research_report_skill.gather_evidence',
          title: 'Gather evidence',
          description: 'Collect and normalize evidence from available sources.',
          kind: SkillStepKind.gatherEvidence,
          capabilityKeys: <String>[
            'web.search',
            'web.read_url',
            'web.extract_article',
          ],
          inputKeys: <String>['topic', 'research_scope'],
          outputKeys: <String>['evidence', 'source_index'],
        ),
        SkillStepDescriptor(
          id: 'research_report_skill.rank_evidence',
          title: 'Rank evidence',
          description: 'Score and dedupe evidence before synthesis.',
          kind: SkillStepKind.rankEvidence,
          inputKeys: <String>['evidence'],
          outputKeys: <String>['ranked_evidence'],
        ),
        SkillStepDescriptor(
          id: 'research_report_skill.synthesize_report',
          title: 'Synthesize report',
          description: 'Turn evidence into a concise, cited report draft.',
          kind: SkillStepKind.synthesize,
          inputKeys: <String>['ranked_evidence', 'topic'],
          outputKeys: <String>[
            'summary',
            'findings',
            'recommendation',
            'draft_markdown',
          ],
        ),
        SkillStepDescriptor(
          id: 'research_report_skill.verify_report',
          title: 'Verify report',
          description: 'Check completeness, contradictions, and unsupported claims.',
          kind: SkillStepKind.validate,
          inputKeys: <String>['summary', 'findings'],
          outputKeys: <String>['verification_status'],
        ),
        SkillStepDescriptor(
          id: 'research_report_skill.emit_response',
          title: 'Emit response',
          description: 'Finalize the research response payload.',
          kind: SkillStepKind.emitResponse,
          inputKeys: <String>['summary', 'findings', 'verification_status'],
          outputKeys: <String>['summary', 'evidence', 'findings', 'recommendation'],
        ),
      ],
    ),
    requiredCapabilityKeys: <String>[
      'web.search',
      'web.read_url',
      'web.extract_article',
    ],
    tags: <String>['research', 'evidence', 'report'],
  );

  static const SkillDescriptor documentGenerationSkill = SkillDescriptor(
    skillId: 'document_generation_skill',
    version: 1,
    displayName: 'Document Generation',
    purpose:
        'Build a document artifact from structured content and persist it locally.',
    visibility: SkillVisibility.preferred,
    requestKinds: <SkillRequestKind>{SkillRequestKind.document},
    inputContract: SkillContract(
      title: 'Document generation input',
      description: 'Structured inputs for generating a document artifact.',
      fields: <SkillFieldDefinition>[
        SkillFieldDefinition(
          name: 'title',
          kind: SkillValueKind.string,
          description: 'Document title.',
          required: true,
        ),
        SkillFieldDefinition(
          name: 'format',
          kind: SkillValueKind.string,
          description: 'Target artifact format.',
          required: true,
          examples: <Object?>['docx', 'pdf'],
        ),
        SkillFieldDefinition(
          name: 'markdown_content',
          kind: SkillValueKind.string,
          description: 'Primary document body in markdown.',
          required: true,
        ),
        SkillFieldDefinition(
          name: 'audience',
          kind: SkillValueKind.string,
          description: 'Target audience for the document.',
          required: false,
        ),
      ],
    ),
    outputContract: SkillContract(
      title: 'Document generation output',
      description: 'Normalized artifact result for document generation.',
      fields: <SkillFieldDefinition>[
        SkillFieldDefinition(
          name: 'summary',
          kind: SkillValueKind.string,
          description: 'User-facing success summary.',
          required: true,
        ),
        SkillFieldDefinition(
          name: 'artifact_path',
          kind: SkillValueKind.string,
          description: 'Local path to the generated artifact.',
          required: true,
        ),
        SkillFieldDefinition(
          name: 'artifact_name',
          kind: SkillValueKind.string,
          description: 'Artifact filename.',
          required: false,
        ),
        SkillFieldDefinition(
          name: 'format',
          kind: SkillValueKind.string,
          description: 'Generated document format.',
          required: true,
        ),
      ],
    ),
    policy: SkillPolicy(
      sideEffectPolicy: SkillSideEffectPolicy.localArtifactWrite,
      singleUse: true,
      requiresVerifier: true,
      requiresEvidence: false,
      approvalRequired: false,
      allowParallelExecution: false,
      maxRetries: 1,
      timeoutMilliseconds: 120000,
    ),
    qualityGate: SkillQualityGate(
      requiredChecks: <String>[
        'structure_validation',
        'artifact_persisted',
        'verifier_review',
      ],
      strictOutputValidation: true,
    ),
    subgraph: SkillSubgraph(
      entryStepId: 'document_generation_skill.determine_format',
      terminalStepId: 'document_generation_skill.compose_response',
      steps: <SkillStepDescriptor>[
        SkillStepDescriptor(
          id: 'document_generation_skill.determine_format',
          title: 'Determine format',
          description: 'Pick the target document format and output binding.',
          kind: SkillStepKind.classify,
          inputKeys: <String>['title', 'format', 'markdown_content'],
          outputKeys: <String>['format_binding', 'format'],
        ),
        SkillStepDescriptor(
          id: 'document_generation_skill.build_content_model',
          title: 'Build content model',
          description: 'Normalize the markdown into a document content model.',
          kind: SkillStepKind.format,
          inputKeys: <String>['title', 'markdown_content'],
          outputKeys: <String>['content_model'],
        ),
        SkillStepDescriptor(
          id: 'document_generation_skill.validate_structure',
          title: 'Validate structure',
          description: 'Check headings, sections, and artifact constraints.',
          kind: SkillStepKind.validate,
          inputKeys: <String>['content_model'],
          outputKeys: <String>['structure_validation'],
        ),
        SkillStepDescriptor(
          id: 'document_generation_skill.render_artifact',
          title: 'Render artifact',
          description: 'Render the selected document artifact locally.',
          kind: SkillStepKind.renderArtifact,
          capabilityKeys: <String>[
            'output.generate_docx',
            'output.generate_report_pdf',
          ],
          inputKeys: <String>['content_model', 'format'],
          outputKeys: <String>['artifact_path', 'artifact_name'],
        ),
        SkillStepDescriptor(
          id: 'document_generation_skill.persist_artifact',
          title: 'Persist artifact',
          description: 'Capture the generated file for downstream consumers.',
          kind: SkillStepKind.persistArtifact,
          inputKeys: <String>['artifact_path'],
          outputKeys: <String>['artifact_reference'],
        ),
        SkillStepDescriptor(
          id: 'document_generation_skill.compose_response',
          title: 'Compose response',
          description: 'Finalize the artifact response envelope.',
          kind: SkillStepKind.emitResponse,
          inputKeys: <String>['artifact_path', 'format'],
          outputKeys: <String>['summary', 'artifact_path', 'artifact_name', 'format'],
        ),
      ],
    ),
    requiredCapabilityKeys: <String>[],
    tags: <String>['document', 'artifact', 'local'],
  );

  static const SkillDescriptor modelComparisonSkill = SkillDescriptor(
    skillId: 'model_comparison_skill',
    version: 1,
    displayName: 'Model Comparison',
    purpose:
        'Compare multiple models against criteria and produce a recommendation.',
    visibility: SkillVisibility.visible,
    requestKinds: <SkillRequestKind>{SkillRequestKind.comparison},
    inputContract: SkillContract(
      title: 'Model comparison input',
      description: 'Structured inputs for comparing model candidates.',
      fields: <SkillFieldDefinition>[
        SkillFieldDefinition(
          name: 'models',
          kind: SkillValueKind.array,
          description: 'Models to compare.',
          required: true,
        ),
        SkillFieldDefinition(
          name: 'criteria',
          kind: SkillValueKind.array,
          description: 'Comparison criteria to apply.',
          required: false,
        ),
        SkillFieldDefinition(
          name: 'use_case',
          kind: SkillValueKind.string,
          description: 'The workload or use case being optimized.',
          required: true,
        ),
      ],
    ),
    outputContract: SkillContract(
      title: 'Model comparison output',
      description: 'Normalized output for a comparative recommendation.',
      fields: <SkillFieldDefinition>[
        SkillFieldDefinition(
          name: 'summary',
          kind: SkillValueKind.string,
          description: 'Short recommendation summary.',
          required: true,
        ),
        SkillFieldDefinition(
          name: 'comparison_table',
          kind: SkillValueKind.array,
          description: 'Structured comparison matrix.',
          required: true,
        ),
        SkillFieldDefinition(
          name: 'recommendation',
          kind: SkillValueKind.string,
          description: 'Recommended model and rationale.',
          required: true,
        ),
      ],
    ),
    policy: SkillPolicy(
      sideEffectPolicy: SkillSideEffectPolicy.readOnly,
      singleUse: false,
      requiresVerifier: true,
      requiresEvidence: true,
      approvalRequired: false,
      allowParallelExecution: true,
      maxRetries: 2,
      timeoutMilliseconds: 120000,
    ),
    qualityGate: SkillQualityGate(
      requiredChecks: <String>[
        'evidence_coverage',
        'criteria_alignment',
        'recommendation_present',
        'verifier_review',
      ],
      strictOutputValidation: true,
    ),
    subgraph: SkillSubgraph(
      entryStepId: 'model_comparison_skill.normalize_models',
      terminalStepId: 'model_comparison_skill.emit_response',
      steps: <SkillStepDescriptor>[
        SkillStepDescriptor(
          id: 'model_comparison_skill.normalize_models',
          title: 'Normalize models',
          description: 'Canonicalize model names and comparison inputs.',
          kind: SkillStepKind.classify,
          inputKeys: <String>['models', 'criteria', 'use_case'],
          outputKeys: <String>['normalized_models', 'comparison_scope'],
        ),
        SkillStepDescriptor(
          id: 'model_comparison_skill.gather_model_data',
          title: 'Gather model data',
          description: 'Collect evidence about each model.',
          kind: SkillStepKind.gatherEvidence,
          capabilityKeys: <String>[
            'web.search',
            'web.read_url',
            'web.extract_article',
          ],
          inputKeys: <String>['normalized_models', 'comparison_scope'],
          outputKeys: <String>['evidence', 'model_profiles'],
        ),
        SkillStepDescriptor(
          id: 'model_comparison_skill.compare_dimensions',
          title: 'Compare dimensions',
          description: 'Compare models across the requested criteria.',
          kind: SkillStepKind.compare,
          inputKeys: <String>['evidence', 'criteria'],
          outputKeys: <String>['comparison_table', 'tradeoffs'],
        ),
        SkillStepDescriptor(
          id: 'model_comparison_skill.rank_recommendation',
          title: 'Rank recommendation',
          description: 'Select the best-fit model for the use case.',
          kind: SkillStepKind.synthesize,
          inputKeys: <String>['comparison_table', 'use_case'],
          outputKeys: <String>['recommendation', 'summary'],
        ),
        SkillStepDescriptor(
          id: 'model_comparison_skill.verify_comparison',
          title: 'Verify comparison',
          description: 'Check the recommendation for consistency and gaps.',
          kind: SkillStepKind.validate,
          inputKeys: <String>['comparison_table', 'recommendation'],
          outputKeys: <String>['verification_status'],
        ),
        SkillStepDescriptor(
          id: 'model_comparison_skill.emit_response',
          title: 'Emit response',
          description: 'Finalize the comparison response.',
          kind: SkillStepKind.emitResponse,
          inputKeys: <String>['summary', 'comparison_table', 'recommendation'],
          outputKeys: <String>['summary', 'comparison_table', 'recommendation'],
        ),
      ],
    ),
    requiredCapabilityKeys: <String>[
      'web.search',
      'web.read_url',
      'web.extract_article',
    ],
    tags: <String>['comparison', 'research', 'recommendation'],
  );

  static const List<SkillDescriptor> all = <SkillDescriptor>[
    researchReportSkill,
    documentGenerationSkill,
    modelComparisonSkill,
  ];

  static const Map<String, SkillDescriptor> _index = <String, SkillDescriptor>{
    'research_report_skill': researchReportSkill,
    'document_generation_skill': documentGenerationSkill,
    'model_comparison_skill': modelComparisonSkill,
  };

  static SkillDescriptor? byId(String skillId) => _index[skillId];

  static List<SkillDescriptor> availableSkills([SkillContext? context]) {
    final resolvedContext = context ?? const SkillContext();
    return all
        .where((skill) => skill.isAvailableFor(resolvedContext))
        .toList(growable: false);
  }

  static List<SkillDescriptor> modelVisibleSkills([SkillContext? context]) {
    return availableSkills(context)
        .where((skill) => skill.exposedToModel)
        .toList(growable: false);
  }

  static List<String> skillIds() {
    return all.map((skill) => skill.skillId).toList(growable: false);
  }
}
