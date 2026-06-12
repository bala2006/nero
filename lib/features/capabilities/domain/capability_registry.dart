enum CapabilityKind { tool, skill, workflow, resource, agentCell }

enum CapabilityCategory { read, build, effect, skill, resource }

enum CapabilitySideEffectPolicy {
  none,
  readOnly,
  localArtifactWrite,
  localStateWrite,
  networkWrite,
}

enum CapabilityReliabilityClass { low, medium, high }

enum CapabilityModelExposure { hidden, visible, preferred }

class CapabilityToolDescriptor {
  const CapabilityToolDescriptor({
    required this.name,
    required this.description,
    required this.parameters,
    this.examples = const <String>[],
  });

  final String name;
  final String description;
  final Map<String, Object?> parameters;
  final List<String> examples;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'name': name,
      'description': description,
      'parameters': parameters,
      if (examples.isNotEmpty) 'examples': List<String>.unmodifiable(examples),
    };
  }
}

class CapabilityDefinition {
  const CapabilityDefinition({
    required this.key,
    required this.version,
    required this.displayName,
    required this.description,
    required this.kind,
    required this.category,
    required this.sideEffectPolicy,
    required this.singleUse,
    required this.reliabilityClass,
    required this.modelExposure,
    this.toolDescriptor,
    this.tags = const <String>[],
  });

  final String key;
  final int version;
  final String displayName;
  final String description;
  final CapabilityKind kind;
  final CapabilityCategory category;
  final CapabilitySideEffectPolicy sideEffectPolicy;
  final bool singleUse;
  final CapabilityReliabilityClass reliabilityClass;
  final CapabilityModelExposure modelExposure;
  final CapabilityToolDescriptor? toolDescriptor;
  final List<String> tags;

  bool get exposedToModel => modelExposure != CapabilityModelExposure.hidden;

  bool get isTool => kind == CapabilityKind.tool;

  String? get toolName => toolDescriptor?.name;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'key': key,
      'version': version,
      'displayName': displayName,
      'description': description,
      'kind': kind.name,
      'category': category.name,
      'sideEffectPolicy': sideEffectPolicy.name,
      'singleUse': singleUse,
      'reliabilityClass': reliabilityClass.name,
      'modelExposure': modelExposure.name,
      'tool': toolDescriptor?.toMap(),
      'tags': List<String>.unmodifiable(tags),
    };
  }
}

class CapabilityRegistry {
  CapabilityRegistry._();

  static const CapabilityDefinition searchWeb = CapabilityDefinition(
    key: 'web.search',
    version: 1,
    displayName: 'Search the web',
    description: 'Search the internet for current or recent information.',
    kind: CapabilityKind.tool,
    category: CapabilityCategory.read,
    sideEffectPolicy: CapabilitySideEffectPolicy.readOnly,
    singleUse: false,
    reliabilityClass: CapabilityReliabilityClass.medium,
    modelExposure: CapabilityModelExposure.visible,
    toolDescriptor: CapabilityToolDescriptor(
      name: 'search_web',
      description:
          'Use for open-ended web research when the answer depends on current, recent, or external information. Do not use for prompts that can be answered from the conversation alone.',
      parameters: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'query': <String, Object?>{
            'type': 'string',
            'description': 'Search query to submit.',
            'minLength': 1,
          },
          'limit': <String, Object?>{
            'type': 'integer',
            'description': 'Maximum number of results to return.',
            'minimum': 1,
            'maximum': 10,
          },
        },
        'required': <String>['query'],
        'additionalProperties': false,
      },
      examples: <String>[
        'Latest AI news today',
        'Research Flutter performance best practices',
      ],
    ),
    tags: <String>['web', 'search', 'read'],
  );

  static const CapabilityDefinition readUrl = CapabilityDefinition(
    key: 'web.read_url',
    version: 1,
    displayName: 'Read web page',
    description: 'Fetch and summarize a specific web page URL.',
    kind: CapabilityKind.tool,
    category: CapabilityCategory.read,
    sideEffectPolicy: CapabilitySideEffectPolicy.readOnly,
    singleUse: false,
    reliabilityClass: CapabilityReliabilityClass.medium,
    modelExposure: CapabilityModelExposure.visible,
    toolDescriptor: CapabilityToolDescriptor(
      name: 'read_url',
      description:
          'Use when the user provides a specific URL and wants that page read, summarized, or inspected. Prefer this over search when the target page is already known.',
      parameters: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'url': <String, Object?>{
            'type': 'string',
            'description': 'The URL to fetch.',
            'minLength': 1,
          },
        },
        'required': <String>['url'],
        'additionalProperties': false,
      },
      examples: <String>[
        'Summarize https://flutter.dev',
        'Read this documentation page and explain the API',
      ],
    ),
    tags: <String>['web', 'fetch', 'read'],
  );

  static const CapabilityDefinition extractArticle = CapabilityDefinition(
    key: 'web.extract_article',
    version: 1,
    displayName: 'Extract article',
    description: 'Fetch and extract article-focused content from a URL.',
    kind: CapabilityKind.tool,
    category: CapabilityCategory.read,
    sideEffectPolicy: CapabilitySideEffectPolicy.readOnly,
    singleUse: false,
    reliabilityClass: CapabilityReliabilityClass.medium,
    modelExposure: CapabilityModelExposure.visible,
    toolDescriptor: CapabilityToolDescriptor(
      name: 'extract_article',
      description:
          'Use for article-style URLs when the main goal is to extract clean article body text from news, blog, or editorial pages.',
      parameters: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'url': <String, Object?>{
            'type': 'string',
            'description': 'The article URL to fetch and extract.',
            'minLength': 1,
          },
        },
        'required': <String>['url'],
        'additionalProperties': false,
      },
      examples: <String>[
        'Extract this Medium article',
        'Pull the text from this news article and summarize it',
      ],
    ),
    tags: <String>['web', 'article', 'read'],
  );

  static const CapabilityDefinition generateDocx = CapabilityDefinition(
    key: 'output.generate_docx',
    version: 1,
    displayName: 'Generate DOCX',
    description: 'Create a downloadable Word document file.',
    kind: CapabilityKind.tool,
    category: CapabilityCategory.build,
    sideEffectPolicy: CapabilitySideEffectPolicy.localArtifactWrite,
    singleUse: true,
    reliabilityClass: CapabilityReliabilityClass.high,
    modelExposure: CapabilityModelExposure.preferred,
    toolDescriptor: CapabilityToolDescriptor(
      name: 'generate_docx',
      description:
          'Use only when the user is asking you to create a downloadable Word document artifact. Provide a clean final title and final markdown content, not planning text, code, or tool instructions.',
      parameters: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'title': <String, Object?>{
            'type': 'string',
            'description': 'Document title.',
            'minLength': 1,
          },
          'markdown_content': <String, Object?>{
            'type': 'string',
            'description': 'Full document body in markdown.',
            'minLength': 1,
          },
        },
        'required': <String>['title', 'markdown_content'],
        'additionalProperties': false,
      },
      examples: <String>[
        'Create a DOCX proposal',
        'Generate a Word document report about Flutter testing',
      ],
    ),
    tags: <String>['output', 'document', 'docx'],
  );

  static const CapabilityDefinition generateXlsx = CapabilityDefinition(
    key: 'output.generate_xlsx',
    version: 1,
    displayName: 'Generate XLSX',
    description: 'Create a downloadable Excel spreadsheet file.',
    kind: CapabilityKind.tool,
    category: CapabilityCategory.build,
    sideEffectPolicy: CapabilitySideEffectPolicy.localArtifactWrite,
    singleUse: true,
    reliabilityClass: CapabilityReliabilityClass.high,
    modelExposure: CapabilityModelExposure.preferred,
    toolDescriptor: CapabilityToolDescriptor(
      name: 'generate_xlsx',
      description:
          'Use only when the user explicitly wants a spreadsheet or workbook artifact. Provide structured sheet data, not prose about how a spreadsheet could be created.',
      parameters: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'title': <String, Object?>{
            'type': 'string',
            'description': 'Workbook title.',
            'minLength': 1,
          },
          'sheets': <String, Object?>{
            'type': 'array',
            'description':
                'Array of sheet objects, each with a name and a 2D rows matrix.',
            'minItems': 1,
            'items': <String, Object?>{
              'type': 'object',
              'properties': <String, Object?>{
                'name': <String, Object?>{
                  'type': 'string',
                  'description': 'Sheet name.',
                  'minLength': 1,
                },
                'rows': <String, Object?>{
                  'type': 'array',
                  'description':
                      '2D rows matrix with strings, numbers, booleans, or formulas.',
                  'minItems': 1,
                },
              },
              'required': <String>['name', 'rows'],
              'additionalProperties': false,
            },
          },
        },
        'required': <String>['title', 'sheets'],
        'additionalProperties': false,
      },
      examples: <String>[
        'Create an expense tracker spreadsheet',
        'Generate an XLSX workbook with monthly sales sheets',
      ],
    ),
    tags: <String>['output', 'spreadsheet', 'xlsx'],
  );

  static const CapabilityDefinition generateReportPdf = CapabilityDefinition(
    key: 'output.generate_report_pdf',
    version: 1,
    displayName: 'Generate PDF',
    description: 'Create a downloadable PDF file.',
    kind: CapabilityKind.tool,
    category: CapabilityCategory.build,
    sideEffectPolicy: CapabilitySideEffectPolicy.localArtifactWrite,
    singleUse: true,
    reliabilityClass: CapabilityReliabilityClass.high,
    modelExposure: CapabilityModelExposure.preferred,
    toolDescriptor: CapabilityToolDescriptor(
      name: 'generate_report_pdf',
      description:
          'Use only when the user explicitly wants a downloadable PDF artifact. Provide final markdown content for the PDF and optional layout hints such as paper size or orientation.',
      parameters: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'title': <String, Object?>{
            'type': 'string',
            'description': 'PDF title.',
            'minLength': 1,
          },
          'markdown_content': <String, Object?>{
            'type': 'string',
            'description': 'Full PDF body in markdown.',
            'minLength': 1,
          },
          'paper_size': <String, Object?>{
            'type': 'string',
            'description': 'Paper size such as letter or a4.',
          },
          'orientation': <String, Object?>{
            'type': 'string',
            'description': 'portrait or landscape.',
          },
        },
        'required': <String>['title', 'markdown_content'],
        'additionalProperties': false,
      },
      examples: <String>[
        'Create a PDF summary report',
        'Generate a PDF brief with A4 landscape layout',
      ],
    ),
    tags: <String>['output', 'pdf', 'report'],
  );

  static const CapabilityDefinition createTextFile = CapabilityDefinition(
    key: 'output.create_text_file',
    version: 1,
    displayName: 'Create Text File',
    description: 'Create a plain text file (.txt, .md, .json, .py, etc.) in the workspace.',
    kind: CapabilityKind.tool,
    category: CapabilityCategory.build,
    sideEffectPolicy: CapabilitySideEffectPolicy.localArtifactWrite,
    singleUse: false,
    reliabilityClass: CapabilityReliabilityClass.high,
    modelExposure: CapabilityModelExposure.visible,
    toolDescriptor: CapabilityToolDescriptor(
      name: 'create_text_file',
      description:
          'Use when the user wants a single workspace file created. Prefer this for one file only; use write_project_files when multiple related files are needed.',
      parameters: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'file_name': <String, Object?>{
            'type': 'string',
            'description':
                'File name including extension, e.g. "README.md" or "main.py".',
            'minLength': 1,
          },
          'content': <String, Object?>{
            'type': 'string',
            'description': 'Full text content for the file.',
            'minLength': 1,
          },
        },
        'required': <String>['file_name', 'content'],
        'additionalProperties': false,
      },
      examples: <String>[
        'Create README.md',
        'Write main.py with the provided script',
      ],
    ),
    tags: <String>['output', 'file', 'text', 'create'],
  );

  static const CapabilityDefinition editTextFile = CapabilityDefinition(
    key: 'output.edit_text_file',
    version: 1,
    displayName: 'Edit Text File',
    description: 'Replace the content of an existing text file in the workspace.',
    kind: CapabilityKind.tool,
    category: CapabilityCategory.build,
    sideEffectPolicy: CapabilitySideEffectPolicy.localArtifactWrite,
    singleUse: false,
    reliabilityClass: CapabilityReliabilityClass.high,
    modelExposure: CapabilityModelExposure.visible,
    toolDescriptor: CapabilityToolDescriptor(
      name: 'edit_text_file',
      description:
          'Use when the user wants an existing workspace text file replaced with new full content. Do not use for brand new files.',
      parameters: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'file_name': <String, Object?>{
            'type': 'string',
            'description': 'Name of the file to edit (must already exist).',
            'minLength': 1,
          },
          'content': <String, Object?>{
            'type': 'string',
            'description': 'New full text content for the file.',
            'minLength': 1,
          },
        },
        'required': <String>['file_name', 'content'],
        'additionalProperties': false,
      },
      examples: <String>[
        'Update README.md with new installation steps',
        'Replace config.yaml with this new content',
      ],
    ),
    tags: <String>['output', 'file', 'text', 'edit'],
  );

  static const CapabilityDefinition writeProjectFiles = CapabilityDefinition(
    key: 'output.write_project_files',
    version: 1,
    displayName: 'Write Project Files',
    description:
        'Create multiple files at once as a project structure in the workspace.',
    kind: CapabilityKind.tool,
    category: CapabilityCategory.build,
    sideEffectPolicy: CapabilitySideEffectPolicy.localArtifactWrite,
    singleUse: false,
    reliabilityClass: CapabilityReliabilityClass.high,
    modelExposure: CapabilityModelExposure.visible,
    toolDescriptor: CapabilityToolDescriptor(
      name: 'write_project_files',
      description:
          'Use when the user wants a multi-file project or scaffold. Provide a project name and every file path with its full content in one structured call.',
      parameters: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'project_name': <String, Object?>{
            'type': 'string',
            'description': 'Name of the project.',
            'minLength': 1,
          },
          'files': <String, Object?>{
            'type': 'array',
            'description': 'Array of file objects, each with a path and content.',
            'minItems': 1,
            'items': <String, Object?>{
              'type': 'object',
              'properties': <String, Object?>{
                'path': <String, Object?>{
                  'type': 'string',
                  'description':
                      'Relative file path including directories, e.g. "src/main.py".',
                  'minLength': 1,
                },
                'content': <String, Object?>{
                  'type': 'string',
                  'description': 'Full text content for this file.',
                },
              },
              'required': <String>['path', 'content'],
              'additionalProperties': false,
            },
          },
        },
        'required': <String>['project_name', 'files'],
        'additionalProperties': false,
      },
      examples: <String>[
        'Create a Python CLI project with main.py and requirements.txt',
        'Scaffold a small HTML/CSS/JS app',
      ],
    ),
    tags: <String>['output', 'project', 'multi-file'],
  );

  static const CapabilityDefinition packageZip = CapabilityDefinition(
    key: 'output.package_zip',
    version: 1,
    displayName: 'Package as ZIP',
    description:
        'Bundle all workspace files from the current conversation into a downloadable ZIP archive.',
    kind: CapabilityKind.tool,
    category: CapabilityCategory.build,
    sideEffectPolicy: CapabilitySideEffectPolicy.localArtifactWrite,
    singleUse: true,
    reliabilityClass: CapabilityReliabilityClass.high,
    modelExposure: CapabilityModelExposure.visible,
    toolDescriptor: CapabilityToolDescriptor(
      name: 'package_zip',
      description:
          'Use after the needed workspace files already exist and the user wants them delivered as one downloadable ZIP archive.',
      parameters: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'archive_name': <String, Object?>{
            'type': 'string',
            'description': 'Name for the ZIP archive, e.g. "my_project".',
            'minLength': 1,
          },
        },
        'required': <String>['archive_name'],
        'additionalProperties': false,
      },
      examples: <String>[
        'Zip the generated project files',
        'Package the workspace output as my_project.zip',
      ],
    ),
    tags: <String>['output', 'zip', 'package', 'archive'],
  );

  static const List<CapabilityDefinition> all = <CapabilityDefinition>[
    searchWeb,
    readUrl,
    extractArticle,
    generateDocx,
    generateXlsx,
    generateReportPdf,
    createTextFile,
    editTextFile,
    writeProjectFiles,
    packageZip,
  ];

  static CapabilityDefinition? byKey(String key) {
    for (final capability in all) {
      if (capability.key == key) {
        return capability;
      }
    }
    return null;
  }

  static CapabilityDefinition? byToolName(String toolName) {
    for (final capability in all) {
      if (capability.toolName == toolName) {
        return capability;
      }
    }
    return null;
  }

  static List<CapabilityDefinition> visibleToModel() {
    return List<CapabilityDefinition>.unmodifiable(
      all.where((capability) => capability.exposedToModel),
    );
  }

  static List<CapabilityDefinition> preferredForModel() {
    return List<CapabilityDefinition>.unmodifiable(
      all.where(
        (capability) =>
            capability.modelExposure == CapabilityModelExposure.preferred,
      ),
    );
  }

  static List<String> modelToolNames() {
    return List<String>.unmodifiable(
      visibleToModel()
          .map((capability) => capability.toolName)
          .whereType<String>(),
    );
  }

  static List<CapabilityToolDescriptor> modelToolDescriptors() {
    return List<CapabilityToolDescriptor>.unmodifiable(
      visibleToModel()
          .map((capability) => capability.toolDescriptor)
          .whereType<CapabilityToolDescriptor>(),
    );
  }

  static List<Map<String, Object?>> modelToolPayloads() {
    return List<Map<String, Object?>>.unmodifiable(
      modelToolDescriptors().map((toolDescriptor) => toolDescriptor.toMap()),
    );
  }

  static List<CapabilityDefinition> singleUseCapabilities() {
    return List<CapabilityDefinition>.unmodifiable(
      all.where((capability) => capability.singleUse),
    );
  }

  static List<CapabilityDefinition> capabilitiesInCategory(
    CapabilityCategory category,
  ) {
    return List<CapabilityDefinition>.unmodifiable(
      all.where((capability) => capability.category == category),
    );
  }
}
