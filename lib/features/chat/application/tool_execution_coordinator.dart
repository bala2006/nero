import 'dart:async';

import '../../audit/application/audit_log_store.dart';
import '../../audit/domain/app_capability.dart';
import '../../audit/domain/audit_log_entry.dart';
import '../../tools/domain/tool_types.dart';
import '../domain/chat_message.dart';
import 'document_artifact_tool_executor.dart';
import 'native_output_tool_bridge.dart';
import 'sarvam_api_client.dart';
import 'tool_executor_registry.dart';
import 'web_tools.dart';

typedef ToolExecutionThoughtCallback = void Function(String thought);
typedef ToolExecutionActivityCallback = void Function(ChatActivity activity);
typedef ToolExecutionArtifactCallback =
    void Function(GeneratedArtifactReference artifact);
typedef ToolExecutionFailureCallback = void Function(Object error);
typedef ToolExecutionStringProvider = String? Function();
typedef ToolExecutionConversationProvider = String Function();

class ToolExecutionCoordinator {
  const ToolExecutionCoordinator({
    required WebToolService webToolService,
    required AuditLogStore auditLogStore,
    required DocumentArtifactToolExecutor documentArtifactToolExecutor,
    required NativeOutputToolBridge nativeOutputToolBridge,
    ToolExecutorRegistry? externalExecutorRegistry,
  }) : _webToolService = webToolService,
       _auditLogStore = auditLogStore,
       _documentArtifactToolExecutor = documentArtifactToolExecutor,
       _nativeOutputToolBridge = nativeOutputToolBridge,
       _externalExecutorRegistry = externalExecutorRegistry;

  final WebToolService _webToolService;
  final AuditLogStore _auditLogStore;
  final DocumentArtifactToolExecutor _documentArtifactToolExecutor;
  final NativeOutputToolBridge _nativeOutputToolBridge;

  /// Consulted first so MCP and sandbox tools (which are not in the built-in
  /// switch below) can be executed without changing this class again.
  final ToolExecutorRegistry? _externalExecutorRegistry;

  Future<ToolExecutionResult> execute(
    SarvamToolCall toolCall, {
    required ToolExecutionConversationProvider conversationId,
    required ToolExecutionStringProvider activeRequestPrompt,
    required ToolExecutionStringProvider latestUserPrompt,
    required ToolExecutionStringProvider activeAssistantId,
    required ToolExecutionThoughtCallback onThought,
    required ToolExecutionActivityCallback onActivity,
    required ToolExecutionArtifactCallback onArtifact,
    ToolExecutionFailureCallback? onDocxFailure,
  }) async {
    final external = _externalExecutorRegistry?.resolve(toolCall.name);
    if (external != null) {
      return external.execute(
        toolCall,
        ToolExecutionContext(
          conversationId: conversationId(),
          activeRequestPrompt: activeRequestPrompt(),
          latestUserPrompt: latestUserPrompt(),
          assistantMessageId: activeAssistantId(),
          onThought: onThought,
          onActivity: onActivity,
          onArtifact: onArtifact,
        ),
      );
    }
    switch (toolCall.name) {
      case 'search_web':
        return _executeSearchWeb(
          toolCall,
          conversationId: conversationId(),
          onThought: onThought,
          onActivity: onActivity,
        );
      case 'read_url':
        return _executeReadUrl(
          toolCall,
          conversationId: conversationId(),
          onThought: onThought,
          onActivity: onActivity,
        );
      case 'extract_article':
        return _executeExtractArticle(
          toolCall,
          conversationId: conversationId(),
          onThought: onThought,
          onActivity: onActivity,
        );
      case 'generate_docx':
        onThought('Creating a document');
        return _documentArtifactToolExecutor.execute(
          toolCall: toolCall,
          conversationId: conversationId(),
          messageId: activeAssistantId(),
          activeRequestPrompt: activeRequestPrompt(),
          latestUserPrompt: latestUserPrompt(),
          onArtifact: onArtifact,
          onActivity: onActivity,
          onDocxFailure: onDocxFailure,
        );
      case 'generate_report_pdf':
        onThought('Creating a PDF');
        return _documentArtifactToolExecutor.execute(
          toolCall: toolCall,
          conversationId: conversationId(),
          messageId: activeAssistantId(),
          activeRequestPrompt: activeRequestPrompt(),
          latestUserPrompt: latestUserPrompt(),
          onArtifact: onArtifact,
          onActivity: onActivity,
        );
      case 'generate_xlsx':
        onThought('Creating a spreadsheet');
        return _executeSpreadsheetTool(
          toolCall,
          conversationId: conversationId(),
          messageId: activeAssistantId(),
          onArtifact: onArtifact,
          onActivity: onActivity,
        );
      case 'create_text_file':
        onThought('Creating a file');
        return _executeCreateTextFileTool(
          toolCall,
          conversationId: conversationId(),
          messageId: activeAssistantId(),
          onArtifact: onArtifact,
          onActivity: onActivity,
        );
      case 'edit_text_file':
        onThought('Editing a file');
        return _executeEditTextFileTool(
          toolCall,
          conversationId: conversationId(),
          messageId: activeAssistantId(),
          onArtifact: onArtifact,
          onActivity: onActivity,
        );
      case 'write_project_files':
        onThought('Creating project files');
        return _executeWriteProjectFilesTool(
          toolCall,
          conversationId: conversationId(),
          messageId: activeAssistantId(),
          onArtifact: onArtifact,
          onActivity: onActivity,
        );
      case 'package_zip':
        onThought('Packaging files into ZIP');
        return _executePackageZipTool(
          toolCall,
          conversationId: conversationId(),
          messageId: activeAssistantId(),
          onArtifact: onArtifact,
          onActivity: onActivity,
        );
      default:
        return ToolExecutionResult(
          success: false,
          summary: 'Unsupported tool ${toolCall.name}.',
          formattedOutput:
              'Tool ${toolCall.name} is not available in this build.',
        );
    }
  }

  Future<ToolExecutionResult> _executeSearchWeb(
    SarvamToolCall toolCall, {
    required String conversationId,
    required ToolExecutionThoughtCallback onThought,
    required ToolExecutionActivityCallback onActivity,
  }) async {
    unawaited(
      _auditLogStore.record(
        capabilityKey: AppCapabilities.webSearch.key,
        title: AppCapabilities.webSearch.label,
        detail: toolCall.arguments['query']?.toString(),
        status: AuditLogStatus.started,
        conversationId: conversationId,
      ),
    );
    onThought('Searching the web');
    final searchResult = await _webToolService.searchWeb(
      query: toolCall.arguments['query']?.toString() ?? '',
      limit: _coerceInt(toolCall.arguments['limit']) ?? 5,
    );
    unawaited(
      _auditLogStore.record(
        capabilityKey: AppCapabilities.webSearch.key,
        title: AppCapabilities.webSearch.label,
        detail: searchResult.summary,
        status: searchResult.success
            ? AuditLogStatus.success
            : AuditLogStatus.failed,
        conversationId: conversationId,
      ),
    );
    onActivity(
      ChatActivity(
        type: ChatActivityType.webSearch,
        title: 'Searched the web',
        subtitle: searchResult.query,
        items: [
          for (final item in searchResult.items)
            ChatActivityItem(
              title: item.title,
              subtitle: item.subtitle,
              trailing: item.trailing,
              url: item.url,
            ),
        ],
        isComplete: true,
      ),
    );
    return searchResult;
  }

  Future<ToolExecutionResult> _executeReadUrl(
    SarvamToolCall toolCall, {
    required String conversationId,
    required ToolExecutionThoughtCallback onThought,
    required ToolExecutionActivityCallback onActivity,
  }) async {
    unawaited(
      _auditLogStore.record(
        capabilityKey: AppCapabilities.webReadUrl.key,
        title: AppCapabilities.webReadUrl.label,
        detail: toolCall.arguments['url']?.toString(),
        status: AuditLogStatus.started,
        conversationId: conversationId,
      ),
    );
    onThought('Reading a web page');
    final readResult = await _webToolService.readUrl(
      toolCall.arguments['url']?.toString() ?? '',
    );
    unawaited(
      _auditLogStore.record(
        capabilityKey: AppCapabilities.webReadUrl.key,
        title: AppCapabilities.webReadUrl.label,
        detail: readResult.summary,
        status: readResult.success
            ? AuditLogStatus.success
            : AuditLogStatus.failed,
        conversationId: conversationId,
      ),
    );
    onActivity(
      ChatActivity(
        type: ChatActivityType.pageRead,
        title: 'Read page',
        subtitle: readResult.url,
        items: [
          for (final item in readResult.items)
            ChatActivityItem(
              title: item.title,
              subtitle: item.subtitle,
              trailing: item.trailing,
              url: item.url,
            ),
        ],
        isComplete: true,
      ),
    );
    return readResult;
  }

  Future<ToolExecutionResult> _executeExtractArticle(
    SarvamToolCall toolCall, {
    required String conversationId,
    required ToolExecutionThoughtCallback onThought,
    required ToolExecutionActivityCallback onActivity,
  }) async {
    unawaited(
      _auditLogStore.record(
        capabilityKey: AppCapabilities.webExtractArticle.key,
        title: AppCapabilities.webExtractArticle.label,
        detail: toolCall.arguments['url']?.toString(),
        status: AuditLogStatus.started,
        conversationId: conversationId,
      ),
    );
    onThought('Extracting article content');
    final articleResult = await _webToolService.extractArticle(
      toolCall.arguments['url']?.toString() ?? '',
    );
    unawaited(
      _auditLogStore.record(
        capabilityKey: AppCapabilities.webExtractArticle.key,
        title: AppCapabilities.webExtractArticle.label,
        detail: articleResult.summary,
        status: articleResult.success
            ? AuditLogStatus.success
            : AuditLogStatus.failed,
        conversationId: conversationId,
      ),
    );
    onActivity(
      ChatActivity(
        type: ChatActivityType.articleExtract,
        title: 'Extracted article',
        subtitle: articleResult.url,
        items: [
          for (final item in articleResult.items)
            ChatActivityItem(
              title: item.title,
              subtitle: item.subtitle,
              trailing: item.trailing,
              url: item.url,
            ),
        ],
        isComplete: true,
      ),
    );
    return articleResult;
  }

  Future<ToolExecutionResult> _executeSpreadsheetTool(
    SarvamToolCall toolCall, {
    required String conversationId,
    required String? messageId,
    required ToolExecutionArtifactCallback onArtifact,
    required ToolExecutionActivityCallback onActivity,
  }) async {
    final title = _coerceToolString(toolCall.arguments['title']).isEmpty
        ? 'Nero Workbook'
        : _coerceToolString(toolCall.arguments['title']);
    final sheets = _coerceSpreadsheetSheets(toolCall.arguments['sheets']);
    if (sheets.isEmpty) {
      return const ToolExecutionResult(
        success: false,
        summary: 'XLSX generation failed.',
        formattedOutput:
            'The generate_xlsx tool requires a non-empty sheets array.',
      );
    }
    return _executeNativeOutputTool(
      toolType: ToolType.generateXlsx,
      title: title,
      parameters: <String, dynamic>{
        'title': title,
        'workbook': <String, dynamic>{'title': title, 'sheets': sheets},
      },
      conversationId: conversationId,
      messageId: messageId,
      successSummary: 'Created XLSX spreadsheet',
      failurePrefix: 'Spreadsheet generation failed',
      onArtifact: onArtifact,
      onActivity: onActivity,
    );
  }

  Future<ToolExecutionResult> _executeCreateTextFileTool(
    SarvamToolCall toolCall, {
    required String conversationId,
    required String? messageId,
    required ToolExecutionArtifactCallback onArtifact,
    required ToolExecutionActivityCallback onActivity,
  }) async {
    final fileName = _coerceToolString(toolCall.arguments['file_name']);
    final content = _coerceToolString(toolCall.arguments['content']);
    if (fileName.isEmpty || content.isEmpty) {
      return const ToolExecutionResult(
        success: false,
        summary: 'File creation failed.',
        formattedOutput:
            'The create_text_file tool requires non-empty file_name and content.',
      );
    }
    return _executeNativeOutputTool(
      toolType: ToolType.createTextFile,
      title: fileName,
      parameters: <String, dynamic>{'file_name': fileName, 'content': content},
      conversationId: conversationId,
      messageId: messageId,
      successSummary: 'Created file',
      failurePrefix: 'File creation failed',
      onArtifact: onArtifact,
      onActivity: onActivity,
    );
  }

  Future<ToolExecutionResult> _executeEditTextFileTool(
    SarvamToolCall toolCall, {
    required String conversationId,
    required String? messageId,
    required ToolExecutionArtifactCallback onArtifact,
    required ToolExecutionActivityCallback onActivity,
  }) async {
    final fileName = _coerceToolString(toolCall.arguments['file_name']);
    final content = _coerceToolString(toolCall.arguments['content']);
    if (fileName.isEmpty || content.isEmpty) {
      return const ToolExecutionResult(
        success: false,
        summary: 'File edit failed.',
        formattedOutput:
            'The edit_text_file tool requires non-empty file_name and content.',
      );
    }
    return _executeNativeOutputTool(
      toolType: ToolType.editTextFile,
      title: fileName,
      parameters: <String, dynamic>{'file_name': fileName, 'content': content},
      conversationId: conversationId,
      messageId: messageId,
      successSummary: 'Edited file',
      failurePrefix: 'File edit failed',
      onArtifact: onArtifact,
      onActivity: onActivity,
    );
  }

  Future<ToolExecutionResult> _executeWriteProjectFilesTool(
    SarvamToolCall toolCall, {
    required String conversationId,
    required String? messageId,
    required ToolExecutionArtifactCallback onArtifact,
    required ToolExecutionActivityCallback onActivity,
  }) async {
    final projectName = _coerceToolString(toolCall.arguments['project_name']);
    final rawFiles = toolCall.arguments['files'];
    if (projectName.isEmpty || rawFiles is! List || rawFiles.isEmpty) {
      return const ToolExecutionResult(
        success: false,
        summary: 'Project creation failed.',
        formattedOutput:
            'The write_project_files tool requires a non-empty project_name and files array.',
      );
    }
    final files = <Map<String, dynamic>>[];
    for (final rawFile in rawFiles) {
      if (rawFile is! Map) {
        continue;
      }
      final path = _coerceToolString(rawFile['path']);
      final content = _coerceToolString(rawFile['content']);
      if (path.isEmpty) {
        continue;
      }
      files.add(<String, dynamic>{'path': path, 'content': content});
    }
    if (files.isEmpty) {
      return const ToolExecutionResult(
        success: false,
        summary: 'Project creation failed.',
        formattedOutput: 'No valid files found in the files array.',
      );
    }
    return _executeNativeOutputTool(
      toolType: ToolType.writeProjectFiles,
      title: projectName,
      parameters: <String, dynamic>{
        'project_name': projectName,
        'files': files,
      },
      conversationId: conversationId,
      messageId: messageId,
      successSummary:
          'Created project "$projectName" with ${files.length} file(s)',
      failurePrefix: 'Project creation failed',
      onArtifact: onArtifact,
      onActivity: onActivity,
    );
  }

  Future<ToolExecutionResult> _executePackageZipTool(
    SarvamToolCall toolCall, {
    required String conversationId,
    required String? messageId,
    required ToolExecutionArtifactCallback onArtifact,
    required ToolExecutionActivityCallback onActivity,
  }) async {
    final archiveName = _coerceToolString(toolCall.arguments['archive_name']);
    if (archiveName.isEmpty) {
      return const ToolExecutionResult(
        success: false,
        summary: 'ZIP packaging failed.',
        formattedOutput:
            'The package_zip tool requires a non-empty archive_name.',
      );
    }
    return _executeNativeOutputTool(
      toolType: ToolType.packageZip,
      title: archiveName,
      parameters: <String, dynamic>{
        'archive_name': archiveName,
        'conversation_id': conversationId,
      },
      conversationId: conversationId,
      messageId: messageId,
      successSummary: 'Created ZIP archive',
      failurePrefix: 'ZIP packaging failed',
      onArtifact: onArtifact,
      onActivity: onActivity,
    );
  }

  Future<ToolExecutionResult> _executeNativeOutputTool({
    required ToolType toolType,
    required String title,
    required Map<String, dynamic> parameters,
    required String conversationId,
    required String? messageId,
    required String successSummary,
    required String failurePrefix,
    required ToolExecutionArtifactCallback onArtifact,
    required ToolExecutionActivityCallback onActivity,
  }) {
    return _nativeOutputToolBridge.execute(
      toolType: toolType,
      title: title,
      parameters: parameters,
      conversationId: conversationId,
      messageId: messageId,
      successSummary: successSummary,
      failurePrefix: failurePrefix,
      activityTitle: 'Created file',
      onArtifact: onArtifact,
      onActivity: onActivity,
    );
  }

  List<Map<String, dynamic>> _coerceSpreadsheetSheets(Object? rawSheets) {
    if (rawSheets is! List) {
      return const <Map<String, dynamic>>[];
    }
    final sheets = <Map<String, dynamic>>[];
    for (final rawSheet in rawSheets) {
      if (rawSheet is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(rawSheet);
      final name = _coerceToolString(map['name']);
      final rows = _coerceSpreadsheetRows(map['rows']);
      if (rows.isEmpty) {
        continue;
      }
      sheets.add(<String, dynamic>{
        'name': name.isEmpty ? 'Sheet${sheets.length + 1}' : name,
        'rows': rows,
      });
    }
    return List<Map<String, dynamic>>.unmodifiable(sheets);
  }

  List<List<Object?>> _coerceSpreadsheetRows(Object? rawRows) {
    if (rawRows is! List) {
      return const <List<Object?>>[];
    }
    final rows = <List<Object?>>[];
    for (final rawRow in rawRows) {
      if (rawRow is! List) {
        continue;
      }
      rows.add(List<Object?>.unmodifiable(rawRow.cast<Object?>()));
    }
    return List<List<Object?>>.unmodifiable(rows);
  }

  int? _coerceInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  String _coerceToolString(Object? value) {
    return value?.toString().trim() ?? '';
  }
}
