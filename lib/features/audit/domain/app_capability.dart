enum CapabilitySensitivity {
  low,
  medium,
  high,
}

class AppCapability {
  const AppCapability({
    required this.key,
    required this.label,
    required this.description,
    required this.sensitivity,
    this.requiresApproval = false,
  });

  final String key;
  final String label;
  final String description;
  final CapabilitySensitivity sensitivity;
  final bool requiresApproval;
}

class AppCapabilities {
  static const chatPrompt = AppCapability(
    key: 'chat.prompt.send',
    label: 'Send prompt',
    description: 'Start a new model response from the user prompt.',
    sensitivity: CapabilitySensitivity.low,
  );

  static const webSearch = AppCapability(
    key: 'web.search',
    label: 'Search the web',
    description: 'Search external web results using DuckDuckGo HTML search.',
    sensitivity: CapabilitySensitivity.medium,
  );

  static const webReadUrl = AppCapability(
    key: 'web.read_url',
    label: 'Read web page',
    description: 'Fetch and summarize a specific web page URL.',
    sensitivity: CapabilitySensitivity.medium,
  );

  static const webExtractArticle = AppCapability(
    key: 'web.extract_article',
    label: 'Extract article',
    description: 'Fetch and extract article-focused content from a URL.',
    sensitivity: CapabilitySensitivity.medium,
  );

  static const diagramRender = AppCapability(
    key: 'diagram.render',
    label: 'Render diagram',
    description: 'Validate and render Mermaid diagram output.',
    sensitivity: CapabilitySensitivity.low,
  );

  static const workspaceImportFile = AppCapability(
    key: 'workspace.file.import',
    label: 'Import file',
    description: 'Import a user-selected file into the local workspace.',
    sensitivity: CapabilitySensitivity.medium,
  );

  static const workspaceImportPhoto = AppCapability(
    key: 'workspace.photo.import',
    label: 'Import photo',
    description: 'Import user-selected photos into the local workspace.',
    sensitivity: CapabilitySensitivity.medium,
  );

  static const workspaceCapturePhoto = AppCapability(
    key: 'workspace.photo.capture',
    label: 'Capture photo',
    description: 'Capture a new photo and add it to the local workspace.',
    sensitivity: CapabilitySensitivity.medium,
  );

  static const workspaceExportFile = AppCapability(
    key: 'workspace.file.export',
    label: 'Export file',
    description: 'Save a generated document to a user-selected destination.',
    sensitivity: CapabilitySensitivity.medium,
  );

  static const workspaceDeleteItem = AppCapability(
    key: 'workspace.item.delete',
    label: 'Delete workspace item',
    description: 'Remove a stored workspace item from the local workspace.',
    sensitivity: CapabilitySensitivity.medium,
  );

  static const workspaceBrowse = AppCapability(
    key: 'workspace.browser.open',
    label: 'Open workspace',
    description: 'Browse imported files, saved artifacts, and reports.',
    sensitivity: CapabilitySensitivity.low,
  );

  static const workspaceShareIn = AppCapability(
    key: 'workspace.share.receive',
    label: 'Receive shared content',
    description: 'Import text, files, or images shared into Nero from other apps.',
    sensitivity: CapabilitySensitivity.medium,
  );

  static const workspaceShareOut = AppCapability(
    key: 'workspace.share.send',
    label: 'Share content',
    description: 'Share workspace files, reports, or assistant output to other apps.',
    sensitivity: CapabilitySensitivity.medium,
  );

  static const reportGenerate = AppCapability(
    key: 'report.generate',
    label: 'Generate report',
    description: 'Generate a structured conversation report from Nero outputs.',
    sensitivity: CapabilitySensitivity.low,
  );

  static const settingsApiKey = AppCapability(
    key: 'settings.api_key.update',
    label: 'Update API key',
    description: 'Store or change the Sarvam API key on device.',
    sensitivity: CapabilitySensitivity.high,
  );

  static const settingsModel = AppCapability(
    key: 'settings.model.select',
    label: 'Select model',
    description: 'Change the active Sarvam model.',
    sensitivity: CapabilitySensitivity.low,
  );

  static const settingsReset = AppCapability(
    key: 'settings.reset',
    label: 'Reset settings',
    description: 'Reset cloud settings to defaults.',
    sensitivity: CapabilitySensitivity.medium,
  );

  static const toolExecution = AppCapability(
    key: 'tool.execution',
    label: 'Execute local tool',
    description: 'Execute an allowlisted local tool for document generation, project packaging, or artifact handling.',
    sensitivity: CapabilitySensitivity.medium,
  );

  static const settingsReasoning = AppCapability(
    key: 'settings.reasoning.update',
    label: 'Update reasoning settings',
    description: 'Change how reasoning is requested from the model and shown in chat.',
    sensitivity: CapabilitySensitivity.low,
  );

  static const settingsAgentMode = AppCapability(
    key: 'settings.agent_mode.update',
    label: 'Update agent mode',
    description: 'Change how autonomous the agent runs by default.',
    sensitivity: CapabilitySensitivity.low,
  );

  static const settingsApprovalPolicy = AppCapability(
    key: 'settings.approval_policy.update',
    label: 'Update approval policy',
    description:
        'Change when the agent must ask for approval before running a tool.',
    sensitivity: CapabilitySensitivity.high,
    requiresApproval: true,
  );

  static const agentApproval = AppCapability(
    key: 'agent.approval.decide',
    label: 'Approve agent action',
    description:
        'Approve, edit or reject a tool call the agent is waiting on.',
    sensitivity: CapabilitySensitivity.high,
  );

  static const mcpServerConnect = AppCapability(
    key: 'mcp.server.connect',
    label: 'Connect MCP server',
    description:
        'Connect to a remote Model Context Protocol server and discover its tools.',
    sensitivity: CapabilitySensitivity.high,
    requiresApproval: true,
  );

  static const mcpToolCall = AppCapability(
    key: 'mcp.tool.call',
    label: 'Call MCP tool',
    description: 'Invoke a tool exposed by a connected MCP server.',
    sensitivity: CapabilitySensitivity.high,
  );

  static const sandboxRun = AppCapability(
    key: 'sandbox.run',
    label: 'Run sandboxed code',
    description:
        'Execute user or model authored code inside the on-device sandbox.',
    sensitivity: CapabilitySensitivity.high,
  );

  static const sandboxFileWrite = AppCapability(
    key: 'sandbox.file.write',
    label: 'Write sandbox file',
    description: 'Create or modify a file inside a sandbox session.',
    sensitivity: CapabilitySensitivity.medium,
  );

  static const memoryForget = AppCapability(
    key: 'memory.forget',
    label: 'Forget memory',
    description: 'Delete a stored memory entry or semantic fact.',
    sensitivity: CapabilitySensitivity.high,
    requiresApproval: true,
  );

  static const List<AppCapability> all = <AppCapability>[
    chatPrompt,
    webSearch,
    webReadUrl,
    webExtractArticle,
    diagramRender,
    workspaceImportFile,
    workspaceImportPhoto,
    workspaceCapturePhoto,
    workspaceExportFile,
    workspaceDeleteItem,
    workspaceBrowse,
    workspaceShareIn,
    workspaceShareOut,
    reportGenerate,
    settingsApiKey,
    settingsModel,
    settingsReset,
    settingsReasoning,
    settingsAgentMode,
    settingsApprovalPolicy,
    agentApproval,
    mcpServerConnect,
    mcpToolCall,
    sandboxRun,
    sandboxFileWrite,
    memoryForget,
  ];

  static AppCapability? byKey(String key) {
    for (final capability in all) {
      if (capability.key == key) {
        return capability;
      }
    }
    return null;
  }
}
