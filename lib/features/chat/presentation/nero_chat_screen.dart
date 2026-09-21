import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../app/app_error_reporter.dart';
import '../../../app/navigation.dart';
import '../../../app/run_replay_bus.dart';
import '../../../core/format/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/widgets.dart';
import '../../agent/domain/agent_task.dart';
import '../../runtime/domain/runtime_progress_snapshot.dart';
import '../../runtime/domain/runtime_run.dart';
import 'execution_plan_view_model.dart';
import '../../audit/application/audit_log_store.dart';
import '../../audit/domain/app_capability.dart';
import '../../audit/domain/audit_log_entry.dart';
import '../application/chat_history_controller.dart';
import '../../settings/presentation/nero_settings_screen.dart';
import '../../settings/reasoning_settings.dart';
import '../../settings/nero_model_catalog.dart';
import '../../settings/settings_controller.dart';
import '../../providers/azure_ai_config.dart';
import '../application/azure_responses_client.dart';
import '../application/chat_session_controller.dart';
import '../domain/chat_conversation.dart';
import '../domain/chat_message.dart';
import 'chat_rich_content.dart';
import 'reasoning/reasoning_block.dart';
import 'widgets/shell/chat_sidebar.dart';
import 'reasoning/thinking_strip.dart';
import 'widgets/agent_mode_selector.dart';
import 'widgets/approval_card.dart';
import 'widgets/composer/attachment_descriptors.dart';
import 'widgets/composer/composer.dart';
import 'widgets/composer/composer_attachment_entry.dart';
import '../../workspace/application/file_ingestion_service.dart';
import '../../workspace/application/workspace_store.dart';
import '../../workspace/application/attachment_context_extractor.dart';
import '../../workspace/application/document_export_service.dart';
import '../../workspace/presentation/workspace_browser_screen.dart';
import '../../workspace/domain/workspace_item.dart';
import '../../../platform/device/native_bridge_service.dart';
import '../../mcp/application/mcp_registry.dart';
import '../../mcp/application/mcp_tool_executor.dart';
import '../../mcp/domain/mcp_server_config.dart';
import '../../mcp/domain/mcp_tool_descriptor.dart';
import '../../sandbox/application/sandbox_controller.dart';
import '../../sandbox/application/sandbox_tool_executor.dart';

class NeroChatScreen extends StatefulWidget {
  const NeroChatScreen({
    super.key,
    this.destinations = const <NeroDestination>[],
    this.onOpenDestination,
    this.settingsController,
    this.historyController,
    this.workspaceStore,
    this.auditLogStore,
    this.nativeBridgeService,
    this.mcpRegistry,
    this.sandboxController,
  });

  /// Extra navigation entries rendered in the sidebar's Tools section.
  final List<NeroDestination> destinations;

  /// Invoked when a sidebar destination is tapped. The host shell owns routing.
  final Future<void> Function(NeroDestination destination)? onOpenDestination;

  /// App-lifetime services supplied by the shell. When null the screen builds
  /// and owns its own instances, which keeps the screen usable standalone in
  /// tests and previews.
  final SettingsController? settingsController;
  final ChatHistoryController? historyController;
  final WorkspaceStore? workspaceStore;
  final AuditLogStore? auditLogStore;
  final NativeBridgeService? nativeBridgeService;

  /// When supplied, every enabled MCP tool becomes callable by the model.
  final McpRegistry? mcpRegistry;

  /// When supplied, `sandbox_run_code` executes snippets on-device even while
  /// no sandbox screen is open (the shell hosts the WebView).
  final SandboxController? sandboxController;

  @override
  State<NeroChatScreen> createState() => _NeroChatScreenState();
}

class _NeroChatScreenState extends State<NeroChatScreen>
    with WidgetsBindingObserver {
  static const int _maxAttachmentsPerPrompt = 5;

  late final ChatSessionController _controller;
  late final AzureResponsesClient _azureClient;
  late final ChatHistoryController _historyController;
  late final SettingsController _settingsController;
  late final WorkspaceStore _workspaceStore;
  late final AuditLogStore _auditLogStore;
  late final DocumentExportService _documentExportService;
  late final NativeBridgeService _nativeBridgeService;
  late final FileIngestionService _fileIngestionService;
  final AttachmentContextExtractor _attachmentContextExtractor =
      const AttachmentContextExtractor();
  final NeroModelCatalog _modelCatalog = const NeroModelCatalog();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;
  String? _activeConversationId;
  Timer? _persistDebounce;
  bool _ownsSettingsController = false;
  bool _ownsHistoryController = false;
  bool _lastGeneratingState = false;
  bool _isImportingFiles = false;
  McpToolExecutor? _mcpToolExecutor;
  SandboxToolExecutor? _sandboxToolExecutor;
  Set<String> _exportingMessageIds = const <String>{};
  int _consumedReplayId = -1;
  InlineBanner? _replayedPromptBanner;
  List<ComposerAttachmentEntry> _pendingAttachments =
      const <ComposerAttachmentEntry>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsSettingsController = widget.settingsController == null;
    _ownsHistoryController = widget.historyController == null;
    _settingsController = widget.settingsController ?? SettingsController();
    // Always subscribe: the shared controller from the shell is also observed
    // by other screens, and this screen still needs to react to model changes.
    _settingsController.addListener(_handleSettingsChanged);
    // Azure AI is the only provider. The endpoint and key come from
    // AzureAiConfig; the URL is read live so a settings refresh applies without
    // restarting the chat session.
    final azureClient = AzureResponsesClient(
      baseUrlProvider: () => _settingsController.state.azureBaseUrl,
      reasoningEffort: AzureAiConfig.reasoningEffort,
      maxOutputTokens: AzureAiConfig.maxOutputTokens,
    );
    _azureClient = azureClient;
    _controller = ChatSessionController(
      client: azureClient,
      streamingClient: azureClient,
    )..addListener(_handleControllerChanged);    _historyController = widget.historyController ?? ChatHistoryController();
    _workspaceStore = widget.workspaceStore ?? WorkspaceStore();
    _auditLogStore = widget.auditLogStore ?? AuditLogStore();
    _nativeBridgeService =
        widget.nativeBridgeService ?? NativeBridgeService();
    _fileIngestionService = FileIngestionService(
      nativeBridgeService: _nativeBridgeService,
    );
    _documentExportService = DocumentExportService(
      workspaceStore: _workspaceStore,
      auditLogStore: _auditLogStore,
      nativeBridgeService: _nativeBridgeService,
    );
    final mcpRegistry = widget.mcpRegistry;
    if (mcpRegistry != null) {
      final executor = McpToolExecutor(
        registry: mcpRegistry,
        auditLogStore: _auditLogStore,
      );
      _mcpToolExecutor = executor;
      // `mcp__*` names are not in the built-in tool switch, so the executor is
      // registered into the dispatch chain the coordinator consults first.
      _controller.registerToolExecutor(executor);
      // Per-tool approval choices beat the global policy, and a server marked
      // auto-approve only skips the prompt for tools that did not override it.
      _controller.externalApprovalOverrideResolver = (toolName) {
        final tool = mcpRegistry.toolByQualifiedName(toolName);
        if (tool == null) {
          return null;
        }
        return switch (tool.approvalMode) {
          McpToolApprovalMode.alwaysAsk => true,
          McpToolApprovalMode.never => false,
          McpToolApprovalMode.inherit =>
            mcpRegistry.serverById(tool.serverId)?.autoApprove == true
                ? false
                : null,
        };
      };
    }
    final sandboxController = widget.sandboxController;
    if (sandboxController != null) {
      _sandboxToolExecutor = SandboxToolExecutor(
        controller: sandboxController,
        auditLogStore: _auditLogStore,
      );
      _controller.registerToolExecutor(_sandboxToolExecutor!);
    }
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final executor = _mcpToolExecutor;
    if (executor != null) {
      _controller.unregisterToolExecutor(executor);
    }
    final sandboxExecutor = _sandboxToolExecutor;
    if (sandboxExecutor != null) {
      _controller.unregisterToolExecutor(sandboxExecutor);
    }
    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();
    if (_ownsHistoryController) {
      _historyController.dispose();
    }
    _settingsController.removeListener(_handleSettingsChanged);
    if (_ownsSettingsController) {
      _settingsController.dispose();
    }
    _persistDebounce?.cancel();
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_consumeSharedContent());
    }
  }

  /// Picks up a prompt handed back by the Runs screen's "Run again" and puts
  /// it in the composer with a one-shot banner. Keyed by emission id so a
  /// rebuild never re-fills (or clobbers) the text the user has edited since.
  void _consumeReplayedPrompt() {
    final pending = RunReplayBus.instance.pending;
    if (pending == null || pending.id == _consumedReplayId) {
      return;
    }
    _consumedReplayId = pending.id;
    _inputController.text = pending.prompt;
    _inputController.selection = TextSelection.collapsed(
      offset: pending.prompt.length,
    );
    _inputFocusNode.requestFocus();
    _replayedPromptBanner = InlineBanner(
      message:
          'Loaded a previous prompt from Runs. Edit it or send it as-is.',
      tone: InlineBannerTone.info,
      icon: Icons.replay_rounded,
      actionLabel: 'Dismiss',
      onAction: () {
        setState(() => _replayedPromptBanner = null);
      },
    );
    setState(() {});
  }

  void _handleControllerChanged() {
    if (!mounted) return;

    final messageCountChanged =
        _controller.messages.length != _lastMessageCount;
    if (messageCountChanged) {
      final shouldAutoScroll = _isNearBottom();
      _lastMessageCount = _controller.messages.length;
      if (shouldAutoScroll) {
        _scrollToBottom(animated: true);
      }
    }

    final generationEnded = _lastGeneratingState && !_controller.isGenerating;
    _lastGeneratingState = _controller.isGenerating;
    if (messageCountChanged || generationEnded) {
      _scheduleConversationPersist();
    }
  }

  void _handleSettingsChanged() {
    final settings = _settingsController.state;
    final model = _modelCatalog.byId(settings.selectedModelId);
    // Reasoning effort and summary verbosity are read straight from settings so
    // a change in the settings screen applies to the very next request.
    final advanced = _settingsController.advanced;
    final reasoning = advanced.reasoning;
    _azureClient
      ..reasoningEffort = reasoning.effort.name
      ..reasoningSummary = reasoning.verbosity.name;
    // Autonomy, budgets and the approval policy feed the gate directly.
    _controller.configureAgentSettings(advanced);
    _controller.configureForSettings(settings, model.name);
  }

  void _scrollToBottom({required bool animated}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      final target = position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) {
      return true;
    }
    final position = _scrollController.position;
    return (position.maxScrollExtent - position.pixels).abs() < 144;
  }

  Future<void> _bootstrap() async {
    try {
      await _settingsController.load();
      await _historyController.load();
      _handleSettingsChanged();
      final activeConversation = _historyController.activeConversation;
      _activeConversationId = activeConversation?.id;
      _controller.setConversationContext(_activeConversationId);
      if (activeConversation != null) {
        _controller.replaceMessages(activeConversation.messages);
        _lastMessageCount = activeConversation.messages.length;
      }
      await _consumeSharedContent();
    } catch (error, stackTrace) {
      AppErrorReporter.instance.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to start the app.',
      );
    }
  }

  Future<void> _send() async {
    try {
      final prompt = _inputController.text.trim();
      if (prompt.isEmpty || _controller.isGenerating) {
        return;
      }
      final attachments = _dedupeComposerEntries(_pendingAttachments)
          .where((entry) => !entry.isLoading)
          .map((entry) => entry.item)
          .map(_workspaceItemToChatAttachment)
          .toList(growable: false);
      _inputController.clear();
      setState(() => _pendingAttachments = const <ComposerAttachmentEntry>[]);
      await _controller.sendPrompt(
        prompt,
        _settingsController.state,
        attachments: attachments,
      );
    } catch (error, stackTrace) {
      AppErrorReporter.instance.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to send the prompt.',
      );
    }
  }

  Future<void> _stop() async {
    try {
      await _controller.cancel();
    } catch (error, stackTrace) {
      AppErrorReporter.instance.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to stop generation.',
      );
    }
  }

  Future<void> _resendUserMessage(ChatMessage message) async {
    if (message.role != ChatRole.user || _controller.isGenerating) {
      return;
    }
    try {
      await _controller.sendPrompt(
        message.content,
        _settingsController.state,
        attachments: List<ChatAttachment>.unmodifiable(message.attachments),
      );
      _scrollToBottom(animated: true);
    } catch (error, stackTrace) {
      AppErrorReporter.instance.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to resend the prompt.',
      );
    }
  }

  void _editUserMessage(ChatMessage message) {
    if (message.role != ChatRole.user) {
      return;
    }
    _inputController.value = TextEditingValue(
      text: message.content,
      selection: TextSelection.collapsed(offset: message.content.length),
    );
    setState(() {
      _pendingAttachments = _composerEntriesFromAttachments(
        message.attachments,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _inputFocusNode.requestFocus();
      _scrollToBottom(animated: true);
    });
  }

  Future<void> _copyUserMessage(ChatMessage message) async {
    if (message.role != ChatRole.user || message.content.trim().isEmpty) {
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: message.content));
    } catch (error, stackTrace) {
      AppErrorReporter.instance.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to copy the prompt.',
      );
    }
  }

  Future<void> _openSettings() async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NeroSettingsScreen(controller: _settingsController),
        ),
      );
    } catch (error, stackTrace) {
      AppErrorReporter.instance.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to open settings.',
      );
    }
  }

  Future<void> _openDestination(NeroDestination destination) async {
    // The workspace screen needs live chat state, so it is handled here rather
    // than by the shell's named-route handler.
    if (destination.route == AppRoutes.workspace) {
      await _openWorkspace();
      return;
    }
    final handler = widget.onOpenDestination;
    if (handler == null) {
      return;
    }
    try {
      await handler(destination);
      // A pushed screen (Runs) may have queued a prompt for the composer.
      if (mounted) {
        _consumeReplayedPrompt();
      }
    } catch (error, stackTrace) {
      AppErrorReporter.instance.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to open ${destination.label}.',
      );
    }
  }

  Future<void> _openWorkspace() async {
    final activeConversation = _historyController.activeConversation;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkspaceBrowserScreen(
          conversationId: _activeConversationId ?? 'standalone',
          conversationTitle:
              activeConversation?.title ?? 'Current conversation',
          messages: List<ChatMessage>.unmodifiable(_controller.messages),
          activeTask: _controller.activeTask,
          runtimeProgressSnapshot: _controller.runtimeProgressSnapshot,
        ),
      ),
    );
  }

  Future<void> _consumeSharedContent() async {
    try {
      final payload = await _nativeBridgeService.consumeSharedContent();
      if (payload == null) {
        return;
      }
      await _applySharedContentPayload(payload);
    } catch (error, stackTrace) {
      AppErrorReporter.instance.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to read shared content.',
      );
    }
  }

  Future<void> _applySharedContentPayload(SharedContentPayload payload) async {
    final conversationId = _activeConversationId ?? 'standalone';
    if (payload.text != null && payload.text!.trim().isNotEmpty) {
      final existing = _inputController.text.trim();
      final incoming = payload.text!.trim();
      _inputController.text = existing.isEmpty
          ? incoming
          : '$existing\n\n$incoming';
      _inputController.selection = TextSelection.collapsed(
        offset: _inputController.text.length,
      );
    }
    if (payload.items.isNotEmpty) {
      final items = _fileIngestionService.workspaceItemsFromNativeItems(
        payload.items,
        conversationId: conversationId,
        source: 'share_in',
      );
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.workspaceShareIn.key,
        title: AppCapabilities.workspaceShareIn.label,
        detail: 'Received ${items.length} shared item(s) from another app.',
        status: AuditLogStatus.started,
        conversationId: conversationId,
      );
      await _ingestWorkspaceItems(
        items,
        conversationId: conversationId,
        capability: AppCapabilities.workspaceShareIn,
        successDetail:
            'Imported ${items.length} shared item(s) into the workspace.',
      );
    }
    if ((payload.text?.trim().isNotEmpty ?? false) ||
        payload.items.isNotEmpty) {
      _inputFocusNode.requestFocus();
    }
  }

  Future<void> _exportAssistantMessage(ChatMessage message) async {
    if (message.role != ChatRole.assistant ||
        message.isStreaming ||
        _exportingMessageIds.contains(message.id)) {
      return;
    }
    final format = await _showExportFormatSheet();
    if (format == null || !mounted) {
      return;
    }
    setState(() {
      _exportingMessageIds = <String>{..._exportingMessageIds, message.id};
    });
    try {
      final result = await _documentExportService.exportAssistantMessage(
        message: message,
        conversationId: _activeConversationId ?? 'standalone',
        format: format,
      );
      if (result != null) {
        _attachGeneratedArtifactToMessage(
          messageId: message.id,
          item: result.workspaceItem,
        );
      }
    } catch (error, stackTrace) {
      AppErrorReporter.instance.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to export the response.',
      );
    } finally {
      if (mounted) {
        setState(() {
          final next = Set<String>.from(_exportingMessageIds)
            ..remove(message.id);
          _exportingMessageIds = Set<String>.unmodifiable(next);
        });
      }
    }
  }

  Future<void> _shareAssistantMessage(ChatMessage message) async {
    if (message.role != ChatRole.assistant ||
        message.isStreaming ||
        _exportingMessageIds.contains(message.id)) {
      return;
    }
    final format = await _showExportFormatSheet(title: 'Share response as');
    if (format == null || !mounted) {
      return;
    }
    setState(() {
      _exportingMessageIds = <String>{..._exportingMessageIds, message.id};
    });
    try {
      final result = await _documentExportService.shareAssistantMessage(
        message: message,
        conversationId: _activeConversationId ?? 'standalone',
        format: format,
      );
      if (result != null) {
        _attachGeneratedArtifactToMessage(
          messageId: message.id,
          item: result.workspaceItem,
        );
      }
    } catch (error, stackTrace) {
      AppErrorReporter.instance.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to share the response.',
      );
    } finally {
      if (mounted) {
        setState(() {
          final next = Set<String>.from(_exportingMessageIds)
            ..remove(message.id);
          _exportingMessageIds = Set<String>.unmodifiable(next);
        });
      }
    }
  }

  Future<ExportDocumentFormat?> _showExportFormatSheet({
    String title = 'Save response as',
  }) {
    return showModalBottomSheet<ExportDocumentFormat>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                for (final format in ExportDocumentFormat.values) ...[
                  _ExportFormatTile(
                    format: format,
                    onTap: () => Navigator.of(context).pop(format),
                  ),
                  if (format != ExportDocumentFormat.values.last)
                    const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _attachGeneratedArtifactToMessage({
    required String messageId,
    required WorkspaceItem item,
  }) {
    final metadata = _decodeWorkspaceMetadata(item.metadataJson);
    _controller.attachGeneratedArtifact(
      messageId,
      GeneratedArtifactReference(
        id: item.id,
        title: item.title,
        kindLabel: _attachmentTypeLabel(item),
        extension: item.extension,
        mimeType: item.mimeType,
        localPath: item.localPath,
        sourceUri: item.sourceUri,
        sizeBytes: item.sizeBytes,
        previewMarkdown: metadata['previewMarkdown']?.toString(),
      ),
    );
    _scheduleConversationPersist();
  }

  Map<String, Object?> _decodeWorkspaceMetadata(String? metadataJson) {
    if (metadataJson == null || metadataJson.trim().isEmpty) {
      return const <String, Object?>{};
    }
    try {
      final decoded = jsonDecode(metadataJson);
      if (decoded is Map) {
        return Map<String, Object?>.from(decoded);
      }
    } catch (_) {}
    return const <String, Object?>{};
  }

  Future<void> _openGeneratedArtifactPreview(
    ChatMessage message,
    GeneratedArtifactReference artifact,
  ) async {
    if (_isPreviewableDocumentArtifact(artifact) &&
        artifact.previewMarkdown != null &&
        artifact.previewMarkdown!.trim().isNotEmpty) {
      await _showDocumentPreviewOverlay(
        title: artifact.title,
        kindLabel: artifact.kindLabel,
        markdownContent: artifact.previewMarkdown!,
      );
      return;
    }
    await _downloadGeneratedArtifact(message, artifact);
  }

  Future<void> _shareGeneratedArtifact(
    GeneratedArtifactReference artifact,
  ) async {
    try {
      await _nativeBridgeService.shareFiles(
        filePaths: artifact.localPath == null
            ? const <String>[]
            : <String>[artifact.localPath!],
        sourceUris: artifact.sourceUri == null
            ? const <String>[]
            : <String>[artifact.sourceUri!],
        subject: artifact.title,
        mimeType: artifact.mimeType,
      );
    } catch (error, stackTrace) {
      AppErrorReporter.instance.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to share the generated file.',
      );
    }
  }

  Future<void> _downloadGeneratedArtifact(
    ChatMessage message,
    GeneratedArtifactReference artifact,
  ) async {
    try {
      final result = await _documentExportService.exportExistingWorkspaceItem(
        item: WorkspaceItem(
          id: artifact.id,
          conversationId: _activeConversationId ?? 'standalone',
          type: WorkspaceItemType.generatedArtifact,
          title: artifact.title,
          createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
          updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
          sourceUri: artifact.sourceUri,
          localPath: artifact.localPath,
          mimeType: artifact.mimeType,
          extension: artifact.extension,
          sizeBytes: artifact.sizeBytes,
          metadataJson: jsonEncode(<String, Object?>{
            if (artifact.previewMarkdown != null)
              'previewMarkdown': artifact.previewMarkdown,
          }),
        ),
        conversationId: _activeConversationId ?? 'standalone',
      );
      if (result != null) {
        _attachGeneratedArtifactToMessage(
          messageId: message.id,
          item: result.workspaceItem,
        );
      }
    } catch (error, stackTrace) {
      AppErrorReporter.instance.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to download the generated file.',
      );
    }
  }

  Future<void> _downloadInlineDocxArtifact(
    ChatMessage message, {
    required String title,
    required String markdownContent,
  }) async {
    try {
      final artifact = await _controller.generateInlineDocxArtifact(
        messageId: message.id,
        title: title,
        markdownContent: markdownContent,
      );
      if (artifact != null) {
        await _downloadGeneratedArtifact(message, artifact);
      }
    } catch (error, stackTrace) {
      AppErrorReporter.instance.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to generate the document artifact.',
      );
    }
  }

  bool _isPreviewableDocumentArtifact(GeneratedArtifactReference artifact) {
    final extension = artifact.extension?.toLowerCase();
    return extension == 'doc' || extension == 'docx';
  }

  Future<void> _showDocumentPreviewOverlay({
    required String title,
    required String kindLabel,
    required String markdownContent,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
          child: _DocumentPreviewDialog(
            title: title,
            kindLabel: kindLabel,
            markdownContent: markdownContent,
            onClose: () => Navigator.of(dialogContext).pop(),
            onFullscreen: () {
              Navigator.of(dialogContext).pop();
              unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _FullscreenDocumentPreviewScreen(
                      title: title,
                      kindLabel: kindLabel,
                      markdownContent: markdownContent,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _importFiles() async {
    final action = await _showAttachmentSourceSheet();
    if (action == null) {
      return;
    }
    switch (action) {
      case _AttachmentImportAction.files:
        await _importFilesFromDisk();
      case _AttachmentImportAction.photos:
        await _importPhotos();
      case _AttachmentImportAction.camera:
        await _capturePhoto();
    }
  }

  Future<void> _importFilesFromDisk() async {
    if (_isImportingFiles) {
      return;
    }
    setState(() => _isImportingFiles = true);
    try {
      final conversationId = _activeConversationId ?? 'standalone';
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.workspaceImportFile.key,
        title: AppCapabilities.workspaceImportFile.label,
        detail: 'Opening the system document picker.',
        status: AuditLogStatus.started,
        conversationId: conversationId,
      );
      final result = await _fileIngestionService.pickFiles(
        conversationId: conversationId,
      );
      if (result.cancelled || result.items.isEmpty) {
        await _auditLogStore.record(
          capabilityKey: AppCapabilities.workspaceImportFile.key,
          title: AppCapabilities.workspaceImportFile.label,
          detail: 'User cancelled file import.',
          status: AuditLogStatus.success,
          conversationId: conversationId,
        );
        return;
      }
      await _ingestWorkspaceItems(
        result.items,
        conversationId: conversationId,
        capability: AppCapabilities.workspaceImportFile,
        successDetail:
            'Imported ${result.items.length} file(s) into the workspace.',
      );
    } catch (error, stackTrace) {
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.workspaceImportFile.key,
        title: AppCapabilities.workspaceImportFile.label,
        detail: error.toString(),
        status: AuditLogStatus.failed,
        conversationId: _activeConversationId ?? 'standalone',
      );
      AppErrorReporter.instance.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to import files.',
      );
    } finally {
      if (mounted) {
        setState(() => _isImportingFiles = false);
      }
    }
  }

  Future<void> _importPhotos() async {
    if (_isImportingFiles) {
      return;
    }
    setState(() => _isImportingFiles = true);
    final conversationId = _activeConversationId ?? 'standalone';
    try {
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.workspaceImportPhoto.key,
        title: AppCapabilities.workspaceImportPhoto.label,
        detail: 'Opening the system photo picker.',
        status: AuditLogStatus.started,
        conversationId: conversationId,
      );
      final result = await _fileIngestionService.pickImages(
        conversationId: conversationId,
      );
      if (result.cancelled || result.items.isEmpty) {
        await _auditLogStore.record(
          capabilityKey: AppCapabilities.workspaceImportPhoto.key,
          title: AppCapabilities.workspaceImportPhoto.label,
          detail: 'User cancelled photo import.',
          status: AuditLogStatus.success,
          conversationId: conversationId,
        );
        return;
      }
      await _ingestWorkspaceItems(
        result.items,
        conversationId: conversationId,
        capability: AppCapabilities.workspaceImportPhoto,
        successDetail:
            'Imported ${result.items.length} photo(s) into the workspace.',
      );
    } catch (error, stackTrace) {
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.workspaceImportPhoto.key,
        title: AppCapabilities.workspaceImportPhoto.label,
        detail: error.toString(),
        status: AuditLogStatus.failed,
        conversationId: conversationId,
      );
      AppErrorReporter.instance.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to import photos.',
      );
    } finally {
      if (mounted) {
        setState(() => _isImportingFiles = false);
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_isImportingFiles) {
      return;
    }
    setState(() => _isImportingFiles = true);
    final conversationId = _activeConversationId ?? 'standalone';
    try {
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.workspaceCapturePhoto.key,
        title: AppCapabilities.workspaceCapturePhoto.label,
        detail: 'Opening the camera capture flow.',
        status: AuditLogStatus.started,
        conversationId: conversationId,
      );
      final result = await _fileIngestionService.captureImage(
        conversationId: conversationId,
      );
      if (result.cancelled || result.items.isEmpty) {
        await _auditLogStore.record(
          capabilityKey: AppCapabilities.workspaceCapturePhoto.key,
          title: AppCapabilities.workspaceCapturePhoto.label,
          detail: 'User cancelled camera capture.',
          status: AuditLogStatus.success,
          conversationId: conversationId,
        );
        return;
      }
      await _ingestWorkspaceItems(
        result.items,
        conversationId: conversationId,
        capability: AppCapabilities.workspaceCapturePhoto,
        successDetail:
            'Added ${result.items.length} captured photo(s) to the workspace.',
      );
    } catch (error, stackTrace) {
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.workspaceCapturePhoto.key,
        title: AppCapabilities.workspaceCapturePhoto.label,
        detail: error.toString(),
        status: AuditLogStatus.failed,
        conversationId: conversationId,
      );
      AppErrorReporter.instance.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to capture a photo.',
      );
    } finally {
      if (mounted) {
        setState(() => _isImportingFiles = false);
      }
    }
  }

  Future<void> _ingestWorkspaceItems(
    List<WorkspaceItem> incomingItems, {
    required String conversationId,
    required AppCapability capability,
    required String successDetail,
  }) async {
    final uniqueIncomingItems = _dedupeWorkspaceItems(
      incomingItems,
      existingEntries: _pendingAttachments,
    );
    final remainingSlots =
        _maxAttachmentsPerPrompt -
        _dedupeComposerEntries(_pendingAttachments).length;
    if (remainingSlots <= 0) {
      return;
    }
    final acceptedItems = uniqueIncomingItems
        .take(remainingSlots)
        .toList(growable: false);
    if (acceptedItems.isEmpty) {
      return;
    }
    final loadingEntries = acceptedItems
        .map((item) => ComposerAttachmentEntry(item: item, isLoading: true))
        .toList(growable: false);
    if (mounted) {
      setState(() {
        _pendingAttachments = _dedupeComposerEntries(<ComposerAttachmentEntry>[
          ..._pendingAttachments,
          ...loadingEntries,
        ]);
      });
    }
    try {
      final enrichedItems = await Future.wait(
        acceptedItems.map(_attachmentContextExtractor.enrichItem),
      );
      await _workspaceStore.insertItems(enrichedItems);
      await _auditLogStore.record(
        capabilityKey: capability.key,
        title: capability.label,
        detail: successDetail,
        status: AuditLogStatus.success,
        conversationId: conversationId,
      );
      if (!mounted) {
        return;
      }
      final enrichedById = {for (final item in enrichedItems) item.id: item};
      setState(() {
        _pendingAttachments = _dedupeComposerEntries(
          _pendingAttachments.map((entry) {
            final enriched = enrichedById[entry.item.id];
            return enriched != null
                ? entry.copyWith(item: enriched, isLoading: false)
                : entry;
          }),
        );
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _pendingAttachments = _pendingAttachments
              .where((entry) => !entry.isLoading)
              .toList(growable: false);
        });
      }
      rethrow;
    }
  }

  Future<_AttachmentImportAction?> _showAttachmentSourceSheet() {
    return showModalBottomSheet<_AttachmentImportAction>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Add to workspace',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _AttachmentSourceTile(
                  icon: Icons.folder_open_rounded,
                  title: 'Files',
                  subtitle: 'PDF, docs, spreadsheets, and more',
                  onTap: () =>
                      Navigator.of(context).pop(_AttachmentImportAction.files),
                ),
                const SizedBox(height: 8),
                _AttachmentSourceTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Photos',
                  subtitle: 'Pick screenshots and images from your device',
                  onTap: () =>
                      Navigator.of(context).pop(_AttachmentImportAction.photos),
                ),
                const SizedBox(height: 8),
                _AttachmentSourceTile(
                  icon: Icons.photo_camera_outlined,
                  title: 'Camera',
                  subtitle: 'Capture a new image and add it directly',
                  onTap: () =>
                      Navigator.of(context).pop(_AttachmentImportAction.camera),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _scheduleConversationPersist() {
    final conversationId = _activeConversationId;
    if (conversationId == null) {
      return;
    }
    final messages = List<ChatMessage>.unmodifiable(_controller.messages);
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 220), () {
      unawaited(
        _historyController.upsertConversationMessages(conversationId, messages),
      );
    });
  }

  /// Bottom strip of the drawer: one-line MCP status (connected servers and
  /// exposed tools, since that is the thing most likely to be silently off)
  /// plus the settings entry.
  Widget _buildSidebarFooter() {
    final registry = widget.mcpRegistry;
    final servers = registry?.servers ?? const <McpServerConfig>[];
    final connected = servers
        .where(
          (server) =>
              server.enabled &&
              registry?.connectionFor(server.id).isConnected == true,
        )
        .length;
    final tools = registry?.enabledTools.length ?? 0;
    final statusText = servers.isEmpty
        ? 'No MCP servers'
        : '$connected/${servers.length} servers · $tools tool${tools == 1 ? '' : 's'} on';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.hub_outlined,
                size: 13,
                color: tools > 0 ? AppColors.tealBright : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10.6,
                    color: tools > 0
                        ? AppColors.textSecondary
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _SidebarFooterSettingsEntry(onOpenSettings: _openSettings),
        ],
      ),
    );
  }

  Future<void> _createNewChat() async {
    _persistDebounce?.cancel();
    if (_controller.isGenerating) {
      await _controller.cancel();
    }
    final conversation = await _historyController.createConversation();
    _activeConversationId = conversation.id;
    _controller.setConversationContext(_activeConversationId);
    _controller.replaceMessages(const <ChatMessage>[]);
    _inputController.clear();
    setState(() => _pendingAttachments = const <ComposerAttachmentEntry>[]);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openConversation(ChatConversation conversation) async {
    _persistDebounce?.cancel();
    if (_controller.isGenerating) {
      await _controller.cancel();
    }
    _activeConversationId = conversation.id;
    await _historyController.setActiveConversation(conversation.id);
    _controller.setConversationContext(_activeConversationId);
    _controller.replaceMessages(conversation.messages);
    _inputController.clear();
    setState(() => _pendingAttachments = const <ComposerAttachmentEntry>[]);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Resets the transcript after the active conversation was deleted from the
  /// sidebar. The history controller has already created/re-pointed a fresh
  /// conversation; here the on-screen state follows.
  Future<void> _startFreshConversationState() async {
    _activeConversationId = _historyController.activeConversationId;
    _controller.setConversationContext(_activeConversationId);
    _controller.replaceMessages(
      _historyController.activeConversation?.messages ??
          const <ChatMessage>[],
    );
    _inputController.clear();
    if (mounted) {
      setState(() => _pendingAttachments = const <ComposerAttachmentEntry>[]);
    }
  }

  void _removePendingAttachment(String itemId) {
    setState(() {
      _pendingAttachments = _pendingAttachments
          .where((entry) => entry.item.id != itemId)
          .toList(growable: false);
    });
  }

  ChatAttachment _workspaceItemToChatAttachment(WorkspaceItem item) {
    return ChatAttachment(
      id: item.id,
      title: item.title,
      kindLabel: _attachmentTypeLabel(item),
      extension: item.extension,
      contextText: _attachmentContextExtractor.extractCachedContext(item),
    );
  }

  String _attachmentTypeLabel(WorkspaceItem item) =>
      attachmentTypeLabelForExtension(item.extension);

  List<ComposerAttachmentEntry> _dedupeComposerEntries(
    Iterable<ComposerAttachmentEntry> entries,
  ) {
    final seen = <String>{};
    final result = <ComposerAttachmentEntry>[];
    for (final entry in entries) {
      final signature = _workspaceItemSignature(entry.item);
      if (!seen.add(signature)) {
        continue;
      }
      result.add(entry);
    }
    return List<ComposerAttachmentEntry>.unmodifiable(result);
  }

  List<ComposerAttachmentEntry> _composerEntriesFromAttachments(
    List<ChatAttachment> attachments,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _dedupeComposerEntries(
      attachments.map(
        (attachment) => ComposerAttachmentEntry(
          item: WorkspaceItem(
            id: attachment.id,
            conversationId: _activeConversationId ?? 'standalone',
            type: WorkspaceItemType.importedFile,
            title: attachment.title,
            createdAtEpochMs: now,
            updatedAtEpochMs: now,
            extension: attachment.extension,
            metadataJson:
                attachment.contextText == null ||
                    attachment.contextText!.trim().isEmpty
                ? null
                : jsonEncode(<String, Object?>{
                    'extractedText': attachment.contextText!.trim(),
                  }),
          ),
          isLoading: false,
        ),
      ),
    );
  }

  List<WorkspaceItem> _dedupeWorkspaceItems(
    Iterable<WorkspaceItem> items, {
    Iterable<ComposerAttachmentEntry> existingEntries =
        const <ComposerAttachmentEntry>[],
  }) {
    final seen = <String>{
      for (final entry in existingEntries) _workspaceItemSignature(entry.item),
    };
    final result = <WorkspaceItem>[];
    for (final item in items) {
      final signature = _workspaceItemSignature(item);
      if (!seen.add(signature)) {
        continue;
      }
      result.add(item);
    }
    return List<WorkspaceItem>.unmodifiable(result);
  }

  String _workspaceItemSignature(WorkspaceItem item) {
    final source = item.sourceUri?.trim();
    if (source != null && source.isNotEmpty) {
      return 'source:$source';
    }
    final path = item.localPath?.trim();
    if (path != null && path.isNotEmpty) {
      return 'path:$path';
    }
    return [
      item.title.trim().toLowerCase(),
      item.extension?.trim().toLowerCase() ?? '',
      item.sizeBytes?.toString() ?? '',
    ].join('|');
  }

  /// Reasoning display preferences, read live so a settings change applies to
  /// already-rendered messages without a reload.
  ReasoningPreferences get _reasoningPreferences =>
      _settingsController.advanced.reasoning;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom;
    final keyboardInset = mediaQuery.viewInsets.bottom;

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      drawer: ChatSidebar(
        historyController: _historyController,
        activeConversationId: _activeConversationId,
        onNewChat: _createNewChat,
        onSelectConversation: _openConversation,
        onDeleteConversation: (conversation) async {
          await _historyController.deleteConversation(conversation.id);
          if (conversation.id == _activeConversationId) {
            await _startFreshConversationState();
          }
        },
        destinations: widget.destinations,
        onOpenDestination: _openDestination,
        footer: _buildSidebarFooter(),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: NeroBackdrop()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge(<Listenable>[
                    _controller,
                    _settingsController,
                  ]),
                  builder: (context, _) {
                    final settings = _settingsController.state;
                    final selectedModel = _modelCatalog.byId(
                      settings.selectedModelId,
                    );
                    return _TopBar(
                      modelName: selectedModel.name,
                      contextTokens: _controller.currentContextTokens,
                      modelContextTokens: selectedModel.contextWindowTokens,
                      onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                      onWorkspaceTap: _openWorkspace,
                      onSettingsTap: _openSettings,
                    );
                  },
                ),
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _controller.messageListVersionListenable,
                    builder: (context, _, __) {
                      final messageIds = _controller.messageIds;
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        itemCount: messageIds.length,
                        itemBuilder: (context, index) => _MessageBubbleBinding(
                          key: ValueKey(messageIds[index]),
                          controller: _controller,
                          messageId: messageIds[index],
                          onHistoryTap: _resendUserMessage,
                          onEditTap: _editUserMessage,
                          onCopyTap: _copyUserMessage,
                          onExportTap: _exportAssistantMessage,
                          onShareTap: _shareAssistantMessage,
                          onArtifactPrimaryTap: _openGeneratedArtifactPreview,
                          onArtifactShareTap: _shareGeneratedArtifact,
                          onInlineArtifactDownload: _downloadInlineDocxArtifact,
                          isExporting: _exportingMessageIds.contains(
                            messageIds[index],
                          ),
                          reasoningDisplayMode: _reasoningPreferences.displayMode,
                          keepReasoningExpanded:
                              _reasoningPreferences.keepExpandedOnComplete,
                        ),
                      );
                    },
                  ),
                ),
                AnimatedPadding(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.fromLTRB(
                    12,
                    0,
                    12,
                    keyboardInset > 0 ? keyboardInset + 8 : 12 + bottomInset,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          final controllerError = _controller.blockingReason;
                          final activeTask = _controller.activeTask;
                          final runtimeProgressSnapshot =
                              _controller.runtimeProgressSnapshot;
                          final shouldShowTaskDock =
                              (runtimeProgressSnapshot?.phases.isNotEmpty ??
                                  false) ||
                              (activeTask != null &&
                                  (activeTask.status == AgentTaskStatus.running ||
                                      activeTask.status ==
                                          AgentTaskStatus.failed ||
                                      activeTask.status ==
                                          AgentTaskStatus.waitingUser));
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (controllerError != null &&
                                  controllerError.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    0,
                                    14,
                                    10,
                                  ),
                                  child: InlineBanner(
                                    message: controllerError,
                                    actionLabel:
                                        controllerError.contains(
                                          'Sarvam API key',
                                        )
                                        ? 'Open settings'
                                        : null,
                                    onAction:
                                        controllerError.contains(
                                          'API key',
                                        )
                                        ? _openSettings
                                        : null,
                                  ),
                                ),
                              if (_replayedPromptBanner != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    0,
                                    14,
                                    10,
                                  ),
                                  child: _replayedPromptBanner!,
                                ),
                              if (shouldShowTaskDock)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  child: _ExecutionPlanPanel(
                                    task: activeTask,
                                    runtimeProgressSnapshot:
                                        runtimeProgressSnapshot,
                                    isActive: _controller.isGenerating,
                                    attachedToComposer: true,
                                  ),
                                ),
                              Composer(
                                controller: _inputController,
                                focusNode: _inputFocusNode,
                                isGenerating: _controller.isGenerating,
                                isInputEnabled: !_controller.isGenerating,
                                canSubmit: !_controller.isGenerating,
                                isImportingFiles: _isImportingFiles,
                                pendingAttachments: _pendingAttachments,
                                footerLabel: 'Nero',
                                hintText: 'Ask Nero anything…',
                                onImportFiles: _importFiles,
                                onRemoveAttachment: _removePendingAttachment,
                                onSend: _send,
                                onStop: _stop,
                                attachedPlanVisible: shouldShowTaskDock,
                                statusStrip: _controller.isGenerating
                                    ? ThinkingStrip(
                                        reasoning:
                                            _controller.activeReasoning,
                                        isGenerating: true,
                                        statusText: _controller.status,
                                        onStop: _stop,
                                      )
                                    : null,
                                modeSelector: AgentModeSelector(
                                  mode: _controller.agentMode,
                                  isOverridden:
                                      _controller.hasAgentModeOverride,
                                  isEnabled: !_controller.isGenerating,
                                  onChanged: _controller.setAgentMode,
                                ),
                                afterInputSlots: <Widget>[
                                  if (_controller.pendingApproval != null)
                                    ApprovalCard(
                                      approval: _controller.pendingApproval!,
                                      onApprove: () {
                                        _controller.approvePendingToolCall();
                                        _scrollToBottom(animated: true);
                                      },
                                      onReject:
                                          _controller.rejectPendingToolCall,
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.modelName,
    required this.contextTokens,
    required this.modelContextTokens,
    required this.onMenuTap,
    required this.onWorkspaceTap,
    required this.onSettingsTap,
  });

  final String modelName;
  final int contextTokens;
  final int modelContextTokens;
  final VoidCallback onMenuTap;
  final VoidCallback onWorkspaceTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          HeaderIconButton(
            icon: Icons.menu_rounded,
            semanticLabel: 'Chats',
            onTap: onMenuTap,
          ),
          const SizedBox(width: 10),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_rounded,
                    size: 16,
                    color: AppColors.tealBright,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        modelName,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${formatCompactTokens(contextTokens)} / ${formatCompactTokens(modelContextTokens)}',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          HeaderIconButton(
            icon: Icons.folder_open_rounded,
            semanticLabel: 'Workspace',
            onTap: onWorkspaceTap,
          ),
          const SizedBox(width: 10),
          HeaderIconButton(
            icon: Icons.tune_rounded,
            semanticLabel: 'Settings',
            onTap: onSettingsTap,
          ),
        ],
      ),
    );
  }

}

class _MessageBubbleBinding extends StatelessWidget {
  const _MessageBubbleBinding({
    super.key,
    required this.controller,
    required this.messageId,
    required this.onHistoryTap,
    required this.onEditTap,
    required this.onCopyTap,
    required this.onExportTap,
    required this.onShareTap,
    required this.onArtifactPrimaryTap,
    required this.onArtifactShareTap,
    required this.onInlineArtifactDownload,
    required this.isExporting,
    required this.reasoningDisplayMode,
    required this.keepReasoningExpanded,
  });

  final ChatSessionController controller;
  final String messageId;
  final ReasoningDisplayMode reasoningDisplayMode;
  final bool keepReasoningExpanded;
  final Future<void> Function(ChatMessage message) onHistoryTap;
  final void Function(ChatMessage message) onEditTap;
  final Future<void> Function(ChatMessage message) onCopyTap;
  final Future<void> Function(ChatMessage message) onExportTap;
  final Future<void> Function(ChatMessage message) onShareTap;
  final Future<void> Function(
    ChatMessage message,
    GeneratedArtifactReference artifact,
  )
  onArtifactPrimaryTap;
  final void Function(GeneratedArtifactReference artifact) onArtifactShareTap;
  final Future<void> Function(
    ChatMessage message, {
    required String title,
    required String markdownContent,
  })
  onInlineArtifactDownload;
  final bool isExporting;

  @override
  Widget build(BuildContext context) {
    final messageListenable = controller.messageListenable(messageId);
    final fallbackMessage = controller.messageById(messageId);
    if (messageListenable == null || fallbackMessage == null) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<ChatMessage>(
      valueListenable: messageListenable,
      builder: (context, message, _) {
        return _MessageBubble(
          message: message,
          reasoningDisplayMode: reasoningDisplayMode,
          keepReasoningExpanded: keepReasoningExpanded,
          onHistoryTap: () => onHistoryTap(message),
          onEditTap: () => onEditTap(message),
          onCopyTap: () => onCopyTap(message),
          onExportTap: () => onExportTap(message),
          onShareTap: () => onShareTap(message),
          onArtifactPrimaryTap: (artifact) =>
              onArtifactPrimaryTap(message, artifact),
          onArtifactShareTap: onArtifactShareTap,
          onInlineArtifactDownload:
              ({required title, required markdownContent}) {
                return onInlineArtifactDownload(
                  message,
                  title: title,
                  markdownContent: markdownContent,
                );
              },
          isExporting: isExporting,
          onDiagramRenderResult: (success, error) {
            controller.reportDiagramRenderResult(
              messageId: message.id,
              success: success,
              error: error,
            );
          },
        );
      },
    );
  }
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.message,
    required this.onHistoryTap,
    required this.onEditTap,
    required this.onCopyTap,
    required this.onExportTap,
    required this.onShareTap,
    required this.onArtifactPrimaryTap,
    required this.onArtifactShareTap,
    required this.onInlineArtifactDownload,
    required this.isExporting,
    required this.onDiagramRenderResult,
    required this.reasoningDisplayMode,
    required this.keepReasoningExpanded,
  });

  final ChatMessage message;
  final ReasoningDisplayMode reasoningDisplayMode;
  final bool keepReasoningExpanded;
  final VoidCallback onHistoryTap;
  final VoidCallback onEditTap;
  final VoidCallback onCopyTap;
  final VoidCallback onExportTap;
  final VoidCallback onShareTap;
  final void Function(GeneratedArtifactReference artifact) onArtifactPrimaryTap;
  final void Function(GeneratedArtifactReference artifact) onArtifactShareTap;
  final Future<void> Function({
    required String title,
    required String markdownContent,
  })
  onInlineArtifactDownload;
  final bool isExporting;
  final void Function(bool success, String? error) onDiagramRenderResult;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  late Widget? _cachedContentWidget;
  late String _contentCacheKey;

  @override
  void initState() {
    super.initState();
    _contentCacheKey = '';
    _cachedContentWidget = null;
    _refreshCachedContent(force: true);
  }

  @override
  void didUpdateWidget(covariant _MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshCachedContent();
  }

  void _refreshCachedContent({bool force = false}) {
    final message = widget.message;
    final nextKey =
        '${message.id}|${message.isStreaming}|${message.content.hashCode}|${message.content.length}';
    if (!force && nextKey == _contentCacheKey) {
      return;
    }
    _contentCacheKey = nextKey;
    _cachedContentWidget = message.content.isEmpty
        ? null
        : RepaintBoundary(
            child: ChatRichContent(
              data: message.content,
              enableRichRendering: true,
              streamingMode: message.isStreaming,
              onDiagramRenderResult: widget.onDiagramRenderResult,
              onDownloadArtifact: (title, markdownContent) =>
                  widget.onInlineArtifactDownload(
                    title: title,
                    markdownContent: markdownContent,
                  ),
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isUser = message.role == ChatRole.user;
    final activityGroups = _groupActivities(message.activities);

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 8, 0, 8),
          child: FractionallySizedBox(
            widthFactor: 0.78,
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (message.attachments.isNotEmpty)
                  _UserMessageAttachmentList(attachments: message.attachments),
                Container(
                  padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceChatBubbleUser,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    message.content,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textOnDarkStrong,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.42,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                _UserMessageMetaRow(
                  message: message,
                  onHistoryTap: widget.onHistoryTap,
                  onEditTap: widget.onEditTap,
                  onCopyTap: widget.onCopyTap,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.reasoning != null)
              ReasoningBlock(
                reasoning: message.reasoning!,
                isStreaming: message.isStreaming,
                displayMode: widget.reasoningDisplayMode,
                keepExpandedOnComplete: widget.keepReasoningExpanded,
              ),
            for (final group in activityGroups)
              _ActivityCard(
                key: ValueKey(
                  '${message.id}:${group.activity.type.name}:${group.activity.title}:${group.activity.items.length}:${group.activity.isComplete}:${group.embeddedInlineActivities.length}:${message.isStreaming}',
                ),
                activity: group.activity,
                embeddedInlineActivities: group.embeddedInlineActivities,
                isStreaming: message.isStreaming,
                thinkingDurationMs: message.thinkingDurationMs,
                thinkingStartedAtEpochMs: message.thinkingStartedAtEpochMs,
              ),
            if (_cachedContentWidget != null) _cachedContentWidget!,
            if (message.generatedArtifacts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _GeneratedArtifactList(
                  artifacts: message.generatedArtifacts,
                  onPrimaryTap: widget.onArtifactPrimaryTap,
                  onShareTap: widget.onArtifactShareTap,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (message.isStreaming)
                        const MiniChip(
                          text: 'Running',
                          icon: Icons.cloud_sync_rounded,
                          accent: AppColors.tealBright,
                        ),
                      if (message.isStreaming &&
                          message.tokensPerSecond != null)
                        MiniChip(
                          text:
                              '${message.tokensPerSecond!.toStringAsFixed(1)} tok/s',
                          icon: Icons.speed_rounded,
                        ),
                      if (!message.isStreaming &&
                          message.averageTokensPerSecond != null)
                        MiniChip(
                          text:
                              'Avg ${message.averageTokensPerSecond!.toStringAsFixed(1)} tok/s',
                          icon: Icons.av_timer_rounded,
                          accent: AppColors.amber,
                        ),
                    ],
                  ),
                  if (!message.isStreaming && message.content.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 2),
                      child: _AssistantMessageMetaRow(
                        isExporting: widget.isExporting,
                        onExportTap: widget.onExportTap,
                        onShareTap: widget.onShareTap,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_ActivityDisplayGroup> _groupActivities(List<ChatActivity> activities) {
    final groups = <_ActivityDisplayGroup>[];
    for (var i = 0; i < activities.length; i++) {
      final activity = activities[i];
      if (activity.type == ChatActivityType.agentPlan) {
        continue;
      }
      if (activity.type == ChatActivityType.thought) {
        final embeddedInlineActivities = <ChatActivity>[];
        var cursor = i + 1;
        while (cursor < activities.length &&
            _isInlineToolActivity(activities[cursor].type)) {
          embeddedInlineActivities.add(activities[cursor]);
          cursor += 1;
        }
        groups.add(
          _ActivityDisplayGroup(
            activity: activity,
            embeddedInlineActivities: embeddedInlineActivities,
          ),
        );
        i = cursor - 1;
        continue;
      }
      if (_isInlineToolActivity(activity.type)) {
        continue;
      }
      groups.add(_ActivityDisplayGroup(activity: activity));
    }
    return groups;
  }

  bool _isInlineToolActivity(ChatActivityType type) {
    return type == ChatActivityType.webSearch ||
        type == ChatActivityType.pageRead ||
        type == ChatActivityType.articleExtract;
  }
}

class _UserMessageMetaRow extends StatelessWidget {
  const _UserMessageMetaRow({
    required this.message,
    required this.onHistoryTap,
    required this.onEditTap,
    required this.onCopyTap,
  });

  final ChatMessage message;
  final VoidCallback onHistoryTap;
  final VoidCallback onEditTap;
  final VoidCallback onCopyTap;

  @override
  Widget build(BuildContext context) {
    final label = formatShortDate(message.sentAtEpochMs);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 14),
          _UserMessageMetaIcon(
            icon: Icons.history_rounded,
            onTap: onHistoryTap,
          ),
          const SizedBox(width: 12),
          _UserMessageMetaIcon(icon: Icons.edit_outlined, onTap: onEditTap),
          const SizedBox(width: 12),
          _UserMessageMetaIcon(
            icon: Icons.content_copy_rounded,
            onTap: onCopyTap,
          ),
        ],
      ),
    );
  }

}

class _UserMessageMetaIcon extends StatelessWidget {
  const _UserMessageMetaIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(icon, size: 16, color: AppColors.textMuted),
      ),
    );
  }
}

class _AssistantMessageMetaRow extends StatelessWidget {
  const _AssistantMessageMetaRow({
    required this.isExporting,
    required this.onExportTap,
    required this.onShareTap,
  });

  final bool isExporting;
  final VoidCallback onExportTap;
  final VoidCallback onShareTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: isExporting ? null : onExportTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: AppColors.textMuted,
                    ),
                  )
                : const Icon(
                    Icons.save_alt_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: isExporting ? null : onShareTap,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(
              Icons.ios_share_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Save / Share',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ExportFormatTile extends StatelessWidget {
  const _ExportFormatTile({required this.format, required this.onTap});

  final ExportDocumentFormat format;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceGlass,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(
            children: [
              Icon(
                switch (format) {
                  ExportDocumentFormat.markdown => Icons.description_rounded,
                  ExportDocumentFormat.text => Icons.notes_rounded,
                  ExportDocumentFormat.pdf => Icons.picture_as_pdf_rounded,
                  ExportDocumentFormat.zip => Icons.folder_zip_rounded,
                },
                size: 18,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  format.label,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '.${format.extension}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AttachmentImportAction { files, photos, camera }

class _AttachmentSourceTile extends StatelessWidget {
  const _AttachmentSourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceGlass,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityDisplayGroup {
  const _ActivityDisplayGroup({
    required this.activity,
    this.embeddedInlineActivities = const <ChatActivity>[],
  });

  final ChatActivity activity;
  final List<ChatActivity> embeddedInlineActivities;
}

class _ActivityCard extends StatefulWidget {
  const _ActivityCard({
    super.key,
    required this.activity,
    required this.isStreaming,
    this.thinkingDurationMs,
    this.thinkingStartedAtEpochMs,
    this.embeddedInlineActivities = const <ChatActivity>[],
  });

  final ChatActivity activity;
  final bool isStreaming;
  final int? thinkingDurationMs;
  final int? thinkingStartedAtEpochMs;
  final List<ChatActivity> embeddedInlineActivities;

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  static const double _defaultThoughtTimelineHeight = 94;
  static const double _maxThoughtTimelineHeight = 220;

  late bool _expanded;
  Timer? _collapseTimer;
  bool _collapseScheduled = false;
  late final ScrollController _itemsScrollController;

  @override
  void initState() {
    super.initState();
    _expanded = _shouldStayExpanded(widget.activity.type) || widget.isStreaming;
    _itemsScrollController = ScrollController();
    _scheduleCollapseIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _ActivityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldReopen =
        widget.isStreaming &&
        (widget.activity.items.length != oldWidget.activity.items.length ||
            widget.activity.isComplete != oldWidget.activity.isComplete ||
            widget.activity.title != oldWidget.activity.title);
    if (shouldReopen && !_expanded) {
      setState(() => _expanded = true);
    } else if (!widget.isStreaming &&
        _expanded &&
        !_shouldStayExpanded(widget.activity.type)) {
      setState(() => _expanded = false);
    }
    _scheduleCollapseIfNeeded();
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _itemsScrollController.dispose();
    super.dispose();
  }

  void _scheduleCollapseIfNeeded() {
    _collapseTimer?.cancel();
    if (_shouldStayExpanded(widget.activity.type)) {
      return;
    }
    if (widget.isStreaming && widget.activity.isComplete) {
      _collapseTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) {
          return;
        }
        setState(() => _expanded = false);
      });
      return;
    }
    if (!widget.isStreaming && _expanded && !_collapseScheduled) {
      _collapseScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _collapseScheduled = false;
        if (mounted) {
          setState(() => _expanded = false);
        }
      });
    }
  }

  List<Widget> _buildThoughtTimelineChildren(Color accent) {
    final children = <Widget>[];
    final remainingInlineActivities = List<ChatActivity>.of(
      widget.embeddedInlineActivities,
    );
    for (var index = 0; index < widget.activity.items.length; index++) {
      final item = widget.activity.items[index];
      final matchedInlineActivity = _takeMatchingInlineActivityForStep(
        stepTitle: item.title,
        remainingActivities: remainingInlineActivities,
      );
      final shouldReplaceThoughtStep = matchedInlineActivity != null;

      if (!shouldReplaceThoughtStep) {
        final isLastItem =
            index == widget.activity.items.length - 1 &&
            remainingInlineActivities.isEmpty;
        children.add(
          Padding(
            padding: EdgeInsets.only(bottom: isLastItem ? 0 : 7),
            child: _ActivityItemRow(
              item: item,
              accent: accent,
              type: widget.activity.type,
              isLoading:
                  !widget.activity.isComplete &&
                  index == widget.activity.items.length - 1,
              isLast: isLastItem,
              compact: true,
            ),
          ),
        );
      }

      if (matchedInlineActivity != null) {
        final isLastEmbedded =
            index == widget.activity.items.length - 1 &&
            remainingInlineActivities.isEmpty;
        children.add(
          Padding(
            padding: EdgeInsets.only(bottom: isLastEmbedded ? 0 : 7),
            child: _EmbeddedInlineToolSection(
              activity: matchedInlineActivity,
              isLast: isLastEmbedded,
            ),
          ),
        );
      }
    }

    while (remainingInlineActivities.isNotEmpty) {
      final activity = remainingInlineActivities.removeAt(0);
      final isLastEmbedded = remainingInlineActivities.isEmpty;
      children.add(
        Padding(
          padding: EdgeInsets.only(bottom: isLastEmbedded ? 0 : 7),
          child: _EmbeddedInlineToolSection(
            activity: activity,
            isLast: isLastEmbedded,
          ),
        ),
      );
    }

    return children;
  }

  ChatActivity? _takeMatchingInlineActivityForStep({
    required String stepTitle,
    required List<ChatActivity> remainingActivities,
  }) {
    for (var i = 0; i < remainingActivities.length; i++) {
      final activity = remainingActivities[i];
      if (_doesStepMatchInlineActivity(
        stepTitle: stepTitle,
        activity: activity,
      )) {
        return remainingActivities.removeAt(i);
      }
    }
    return null;
  }

  bool _doesStepMatchInlineActivity({
    required String stepTitle,
    required ChatActivity activity,
  }) {
    final normalizedStepTitle = stepTitle.toLowerCase();
    return switch (activity.type) {
      ChatActivityType.webSearch =>
        normalizedStepTitle.contains('searching the web') ||
            normalizedStepTitle.contains('search the web') ||
            normalizedStepTitle.contains('searched the web'),
      ChatActivityType.pageRead =>
        normalizedStepTitle.contains('reading a web page') ||
            normalizedStepTitle.contains('read page') ||
            normalizedStepTitle.contains('reading page'),
      ChatActivityType.articleExtract =>
        normalizedStepTitle.contains('extracting article content') ||
            normalizedStepTitle.contains('extract article') ||
            normalizedStepTitle.contains('extracted article'),
      _ => false,
    };
  }

  bool _shouldStayExpanded(ChatActivityType type) {
    return type == ChatActivityType.webSearch ||
        type == ChatActivityType.pageRead ||
        type == ChatActivityType.articleExtract;
  }

  double _thoughtTimelineViewportHeight(int itemCount) {
    if (itemCount <= 0) {
      return 72;
    }
    final estimatedHeight = 28.0 + (itemCount.clamp(1, 5) * 20.0);
    return estimatedHeight.clamp(
      _defaultThoughtTimelineHeight,
      _maxThoughtTimelineHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    const activityHeaderMinHeight = 46.0;
    final accent = switch (widget.activity.type) {
      ChatActivityType.thought => AppColors.tealBright,
      ChatActivityType.agentPlan => AppColors.orange,
      ChatActivityType.webSearch => AppColors.tealBright,
      ChatActivityType.pageRead => AppColors.amber,
      ChatActivityType.articleExtract => AppColors.amber,
    };
    final title = widget.activity.title;
    final subtitle = widget.activity.subtitle;
    final thoughtPreview =
        widget.activity.type == ChatActivityType.thought &&
            widget.activity.items.isNotEmpty
        ? widget.activity.items.last.title
        : null;
    final itemCount = widget.activity.items.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceOverlay,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(12),
                bottom: _expanded ? Radius.zero : const Radius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(
                  minHeight: activityHeaderMinHeight,
                ),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(12),
                    bottom: _expanded ? Radius.zero : const Radius.circular(12),
                  ),
                  color: AppColors.surfaceOverlayStrong.withValues(alpha: 0.84),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.055),
                      accent.withValues(alpha: 0.04),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.activity.type == ChatActivityType.thought)
                            _SmoothThinkingTimer(
                              baseDurationMs: widget.thinkingDurationMs,
                              thinkingStartedAtEpochMs:
                                  widget.thinkingStartedAtEpochMs,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            Text(
                              title,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (thoughtPreview != null &&
                              thoughtPreview.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                thoughtPreview,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 10.2,
                                  height: 1.15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (itemCount > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Text(
                          '$itemCount',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 15,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subtitle != null && subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        subtitle,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textOnDarkMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  if (widget.activity.type == ChatActivityType.thought ||
                      widget.activity.type == ChatActivityType.webSearch ||
                      widget.activity.type == ChatActivityType.pageRead ||
                      widget.activity.type == ChatActivityType.articleExtract)
                    Builder(
                      builder: (context) {
                        final timelineChildren =
                            widget.activity.type == ChatActivityType.thought &&
                                widget.embeddedInlineActivities.isNotEmpty
                            ? _buildThoughtTimelineChildren(accent)
                            : widget.activity.items
                                  .asMap()
                                  .entries
                                  .map(
                                    (entry) => Padding(
                                      padding: EdgeInsets.only(
                                        bottom:
                                            entry.key ==
                                                widget.activity.items.length - 1
                                            ? 0
                                            : 7,
                                      ),
                                      child: _ActivityItemRow(
                                        item: entry.value,
                                        accent: accent,
                                        type: widget.activity.type,
                                        isLoading:
                                            widget.activity.type ==
                                                ChatActivityType.thought &&
                                            !widget.activity.isComplete &&
                                            entry.key ==
                                                widget.activity.items.length -
                                                    1,
                                        isLast:
                                            entry.key ==
                                            widget.activity.items.length - 1,
                                        compact: true,
                                      ),
                                    ),
                                  )
                                  .toList(growable: false);
                        final shouldAppendDoneInTimeline =
                            !widget.isStreaming || widget.activity.isComplete;
                        final effectiveTimelineChildren = [
                          ...timelineChildren,
                          if (shouldAppendDoneInTimeline)
                            const _TimelineDoneRow(),
                        ];
                        final isThoughtTimeline =
                            widget.activity.type == ChatActivityType.thought;
                        final timelineViewportHeight = isThoughtTimeline
                            ? _thoughtTimelineViewportHeight(
                                effectiveTimelineChildren.length,
                              )
                            : _defaultThoughtTimelineHeight;

                        final timelineList = Scrollbar(
                          controller: _itemsScrollController,
                          thumbVisibility: effectiveTimelineChildren.length > 4,
                          thickness: 2,
                          radius: const Radius.circular(999),
                          child: ListView(
                            controller: _itemsScrollController,
                            primary: false,
                            padding: EdgeInsets.only(
                              right: 6,
                              bottom: isThoughtTimeline ? 14 : 0,
                            ),
                            shrinkWrap: !isThoughtTimeline,
                            children: effectiveTimelineChildren,
                          ),
                        );

                        if (!isThoughtTimeline) {
                          return ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: _defaultThoughtTimelineHeight,
                            ),
                            child: timelineList,
                          );
                        }

                        return SizedBox(
                          height: timelineViewportHeight,
                          child: timelineList,
                        );
                      },
                    )
                  else
                    for (final item in widget.activity.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ActivityItemRow(
                          item: item,
                          accent: accent,
                          type: widget.activity.type,
                          isLast: identical(item, widget.activity.items.last),
                        ),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SmoothThinkingTimer extends StatefulWidget {
  const _SmoothThinkingTimer({
    required this.baseDurationMs,
    required this.thinkingStartedAtEpochMs,
    required this.style,
  });

  final int? baseDurationMs;
  final int? thinkingStartedAtEpochMs;
  final TextStyle style;

  @override
  State<_SmoothThinkingTimer> createState() => _SmoothThinkingTimerState();
}

class _SmoothThinkingTimerState extends State<_SmoothThinkingTimer>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _SmoothThinkingTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thinkingStartedAtEpochMs != widget.thinkingStartedAtEpochMs) {
      _syncTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _syncTicker() {
    _ticker?.dispose();
    _ticker = null;
    if (widget.thinkingStartedAtEpochMs == null) {
      return;
    }
    _ticker = createTicker((_) {
      if (mounted) {
        setState(() {});
      }
    })..start();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatReasoningLabel(
        baseDurationMs: widget.baseDurationMs,
        thinkingStartedAtEpochMs: widget.thinkingStartedAtEpochMs,
      ),
      style: widget.style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

String _formatReasoningLabel({
  required int? baseDurationMs,
  required int? thinkingStartedAtEpochMs,
}) {
  var durationMs = baseDurationMs ?? 0;
  if (thinkingStartedAtEpochMs != null) {
    durationMs += DateTime.now()
        .difference(
          DateTime.fromMillisecondsSinceEpoch(thinkingStartedAtEpochMs),
        )
        .inMilliseconds;
  }
  if (durationMs <= 0) {
    return 'Reasoning';
  }
  final seconds = durationMs / 1000;
  if (seconds >= 10) {
    return 'Reasoning • ${seconds.toStringAsFixed(0)}s';
  }
  return 'Reasoning • ${seconds.toStringAsFixed(1)}s';
}

class _EmbeddedInlineToolSection extends StatefulWidget {
  const _EmbeddedInlineToolSection({
    required this.activity,
    required this.isLast,
  });

  final ChatActivity activity;
  final bool isLast;

  @override
  State<_EmbeddedInlineToolSection> createState() =>
      _EmbeddedInlineToolSectionState();
}

class _EmbeddedInlineToolSectionState
    extends State<_EmbeddedInlineToolSection> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.activity.subtitle?.trim();
    final resultCount = widget.activity.items.length;
    final hasResults = widget.activity.items.isNotEmpty;
    const rowHeight = 16.0;
    const rowGap = 8.0;
    const nonScrollingVerticalPadding = 12.0;
    const scrollingTopPadding = 6.0;
    const scrollingBottomPadding = 0.0;
    final requiresScrolling = resultCount > 3;
    final inlineContentHeight = requiresScrolling
        ? rowHeight * 3 +
              rowGap * 2 +
              scrollingTopPadding +
              scrollingBottomPadding
        : resultCount <= 0
        ? 0.0
        : rowHeight * resultCount +
              rowGap * (resultCount - 1) +
              nonScrollingVerticalPadding;
    final resultBoxHeight = requiresScrolling
        ? rowHeight * 3 +
              rowGap * 2 +
              scrollingTopPadding +
              scrollingBottomPadding
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.public_rounded,
                size: 12,
                color: AppColors.textMuted,
              ),
            ),
            if (!widget.isLast)
              Container(
                width: 1.25,
                height: hasResults
                    ? (14 + 7 + inlineContentHeight - 10).clamp(18.0, 120.0)
                    : 18,
                margin: const EdgeInsets.only(top: 3),
                color: AppColors.borderMedium,
              ),
          ],
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        query == null || query.isEmpty
                            ? 'Searching the web'
                            : query,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: const Color(0xFFCBC5BD),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$resultCount results',
                      style: AppTextStyles.caption.copyWith(
                        color: const Color(0xFFAAA39B),
                        fontSize: 10.2,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasResults) ...[
                const SizedBox(height: 7),
                (requiresScrolling
                    ? SizedBox(
                        height: resultBoxHeight,
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.fromLTRB(11, 6, 10, 0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF32302D),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0x1FFFFFFF),
                              width: 1,
                            ),
                          ),
                          child: Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true,
                            thickness: 2,
                            radius: const Radius.circular(999),
                            child: ListView.separated(
                              controller: _scrollController,
                              primary: false,
                              physics: const ClampingScrollPhysics(),
                              itemCount: widget.activity.items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) =>
                                  _inlineToolResultRow(
                                    widget.activity.items[index],
                                    index,
                                  ),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.fromLTRB(11, 6, 10, 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF32302D),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0x1FFFFFFF),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (
                              var index = 0;
                              index < widget.activity.items.length;
                              index++
                            ) ...[
                              _inlineToolResultRow(
                                widget.activity.items[index],
                                index,
                              ),
                              if (index != widget.activity.items.length - 1)
                                const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      )),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _inlineToolResultRow(ChatActivityItem item, int index) {
    return SizedBox(
      height: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _searchResultAccent(index),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.open_in_new_rounded,
              size: 6,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: const Color(0xFFF1EEE9),
                fontSize: 10.9,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _searchResultAccent(int index) {
    const accents = <Color>[
      Color(0xFF27C39F),
      Color(0xFFF08B38),
      Color(0xFFE64B78),
      Color(0xFF22C55E),
      Color(0xFF93A4FF),
    ];
    return accents[index % accents.length];
  }
}

class _TimelineDoneRow extends StatelessWidget {
  const _TimelineDoneRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 1),
      child: _ActivityItemRow(
        item: ChatActivityItem(title: 'Done', state: 'completed'),
        accent: AppColors.tealBright,
        type: ChatActivityType.thought,
        isLast: true,
        compact: true,
      ),
    );
  }
}

class _ActivityItemRow extends StatefulWidget {
  const _ActivityItemRow({
    required this.item,
    required this.accent,
    required this.type,
    required this.isLast,
    this.isLoading = false,
    this.compact = false,
  });

  final ChatActivityItem item;
  final Color accent;
  final ChatActivityType type;
  final bool isLast;
  final bool isLoading;
  final bool compact;

  @override
  State<_ActivityItemRow> createState() => _ActivityItemRowState();
}

class _ActivityItemRowState extends State<_ActivityItemRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loadingController;

  bool get _isLoadingState {
    return widget.isLoading || widget.item.state == 'running';
  }

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _syncLoadingAnimation();
  }

  @override
  void didUpdateWidget(covariant _ActivityItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading != widget.isLoading ||
        oldWidget.item.state != widget.item.state) {
      _syncLoadingAnimation();
    }
  }

  void _syncLoadingAnimation() {
    if (_isLoadingState) {
      _loadingController.repeat();
    } else {
      _loadingController.stop();
      _loadingController.reset();
    }
  }

  @override
  void dispose() {
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type == ChatActivityType.thought ||
        widget.type == ChatActivityType.agentPlan) {
      return AnimatedBuilder(
        animation: _loadingController,
        builder: (context, _) {
          final scale = _isLoadingState
              ? 0.92 + (_loadingController.value * 0.16)
              : 1.0;
          final angle = _isLoadingState
              ? _loadingController.value * 6.28318
              : 0.0;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: widget.compact ? 1 : 2),
                      child: Transform.scale(
                        scale: scale,
                        child: Transform.rotate(
                          angle: angle,
                          child: Icon(
                            _iconForStructuredActivity(
                              widget.item.state,
                              widget.type,
                            ),
                            size: widget.compact ? 12 : 13,
                            color: _colorForStructuredActivity(
                              widget.item.state,
                              widget.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!widget.isLast)
                      Container(
                        width: widget.compact ? 1.25 : 1.5,
                        height: widget.compact ? 14 : 18,
                        margin: EdgeInsets.symmetric(
                          vertical: widget.compact ? 3 : 4,
                        ),
                        color: AppColors.borderMedium,
                      ),
                  ],
                ),
                SizedBox(width: widget.compact ? 7 : 8),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.item.title,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textOnDarkMuted,
                                fontSize: widget.compact ? 10.8 : 12,
                                height: widget.compact ? 1.2 : 1.35,
                                fontWeight:
                                    widget.type == ChatActivityType.agentPlan
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            if (widget.item.subtitle != null &&
                                widget.item.subtitle!.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: widget.compact ? 2 : 3,
                                ),
                                child: Text(
                                  widget.item.subtitle!,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textMuted,
                                    fontSize: widget.compact ? 9.6 : 10.5,
                                    height: widget.compact ? 1.18 : 1.35,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (widget.item.trailing != null &&
                          widget.item.trailing!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            widget.item.trailing!,
                            style: AppTextStyles.caption.copyWith(
                              color: _colorForStructuredActivity(
                                widget.item.state,
                                widget.accent,
                              ),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    if (widget.compact &&
        (widget.type == ChatActivityType.webSearch ||
            widget.type == ChatActivityType.pageRead ||
            widget.type == ChatActivityType.articleExtract)) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.public_rounded,
              size: 11.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              widget.item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                fontSize: 10.9,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.public_rounded,
            size: 13,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.title,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.item.subtitle != null &&
                          widget.item.subtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            widget.item.subtitle!,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.item.trailing != null &&
                    widget.item.trailing!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 1),
                    child: Text(
                      widget.item.trailing!,
                      style: AppTextStyles.caption.copyWith(
                        color: widget.accent,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _iconForStructuredActivity(String? state, ChatActivityType type) {
    return switch (state) {
      'running' => Icons.sync_rounded,
      'completed' => Icons.check_circle_rounded,
      'failed' => Icons.cancel_rounded,
      'blocked' => Icons.pause_circle_rounded,
      'cancelled' => Icons.remove_circle_rounded,
      _ =>
        type == ChatActivityType.thought
            ? Icons.psychology_alt_rounded
            : Icons.radio_button_unchecked_rounded,
    };
  }

  Color _colorForStructuredActivity(String? state, Color accent) {
    return switch (state) {
      'running' => accent,
      'completed' => AppColors.tealBright,
      'failed' => AppColors.red,
      'blocked' => AppColors.amber,
      'cancelled' => AppColors.textMuted,
      _ => AppColors.textMuted,
    };
  }
}

class _ExecutionPlanPanel extends StatefulWidget {
  const _ExecutionPlanPanel({
    this.task,
    this.runtimeProgressSnapshot,
    required this.isActive,
    this.attachedToComposer = false,
  });

  final AgentTask? task;
  final RuntimeProgressSnapshot? runtimeProgressSnapshot;
  final bool isActive;
  final bool attachedToComposer;

  @override
  State<_ExecutionPlanPanel> createState() => _ExecutionPlanPanelState();
}

class _ExecutionPlanPanelState extends State<_ExecutionPlanPanel>
    with TickerProviderStateMixin {
  bool _expanded = false;
  late final ScrollController _stepsScrollController;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isActive && !widget.attachedToComposer;
    _stepsScrollController = ScrollController();
  }

  @override
  void didUpdateWidget(covariant _ExecutionPlanPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_expanded && !widget.attachedToComposer) {
      setState(() => _expanded = true);
    } else if (!widget.isActive &&
        oldWidget.isActive &&
        _isTerminalPanelState(
          task: widget.task,
          runtimeProgressSnapshot: widget.runtimeProgressSnapshot,
        ) &&
        _expanded) {
      setState(() => _expanded = false);
    }
  }

  @override
  void dispose() {
    _stepsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = ExecutionPlanViewModel.fromTask(
      task: widget.task,
      runtimeProgressSnapshot: widget.runtimeProgressSnapshot,
    );
    final showSticky = widget.isActive;
    final background = showSticky
        ? AppColors.surfaceElevated
        : AppColors.surfaceComposer;
    final borderColor = showSticky
        ? AppColors.borderStrong
        : AppColors.borderComposer;

    return Container(
      margin: EdgeInsets.only(bottom: widget.attachedToComposer ? 0 : 0),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(widget.attachedToComposer ? 0 : 14),
          bottomRight: Radius.circular(widget.attachedToComposer ? 0 : 14),
        ),
        border: Border.all(color: borderColor),
        boxShadow: showSticky
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : const [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(
                _expanded ? 0 : (widget.attachedToComposer ? 0 : 14),
              ),
              bottomRight: Radius.circular(
                _expanded ? 0 : (widget.attachedToComposer ? 0 : 14),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(
                  _expanded ? 0 : (widget.attachedToComposer ? 0 : 14),
                ),
                bottomRight: Radius.circular(
                  _expanded ? 0 : (widget.attachedToComposer ? 0 : 14),
                ),
              ),
              child: Container(
                constraints: BoxConstraints(
                  minHeight: widget.attachedToComposer ? 72 : 52,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceOverlayStrong.withValues(alpha: 0.84),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.055),
                      AppColors.orange.withValues(alpha: 0.04),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: ExcludeSemantics(
                          child: Icon(
                            model.hasFailures
                                ? Icons.error_outline_rounded
                                : Icons.assignment_rounded,
                            size: 15,
                            color: model.hasFailures
                                ? AppColors.amber
                                : (showSticky
                                      ? AppColors.orange
                                      : AppColors.textMuted),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    model.title,
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textPrimary,
                                      fontSize: 12.2,
                                      fontWeight: FontWeight.w700,
                                      height: 1.1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _TaskStatusPill(
                                  label: model.statusLabel,
                                  color: model.statusColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${model.completedCount} of ${model.totalCount} ${model.usesRuntimePhases ? 'phases' : 'steps'} complete',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 10.8,
                                fontWeight: FontWeight.w500,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              model.summaryText,
                              style: AppTextStyles.caption.copyWith(
                                color: model.hasFailures
                                    ? AppColors.amber
                                    : AppColors.textMuted,
                                fontSize: 10.4,
                                fontWeight: FontWeight.w500,
                                height: 1.18,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 7),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 4,
                                value: model.completionRatio.clamp(0.0, 1.0),
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.06,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  model.hasFailures
                                      ? AppColors.amber
                                      : AppColors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          _expanded
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_right_rounded,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_expanded)
            Container(
              constraints: BoxConstraints(
                maxHeight: widget.attachedToComposer
                    ? (widget.isActive ? 156 : 128)
                    : (widget.isActive ? 188 : 144),
              ),
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 10),
              child: Scrollbar(
                controller: _stepsScrollController,
                thumbVisibility: model.entries.length > 3,
                thickness: 2,
                radius: const Radius.circular(999),
                child: ListView.separated(
                  controller: _stepsScrollController,
                  primary: false,
                  padding: const EdgeInsets.only(right: 8),
                  shrinkWrap: true,
                  itemCount: model.entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (context, index) {
                    final step = model.entries[index];
                    return _AnimatedExecutionStepRow(
                      key: ValueKey('${step.id}:${step.status.name}'),
                      step: step,
                      index: index,
                      statusLabel: ExecutionPlanViewModel.stepStatusLabel(
                        step.status,
                      ),
                      accent: ExecutionPlanViewModel.stepColor(step.status),
                      icon: ExecutionPlanViewModel.stepIcon(step.status),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

}

bool _isTerminalPanelState({
  required AgentTask? task,
  required RuntimeProgressSnapshot? runtimeProgressSnapshot,
}) {
  final runStatus = runtimeProgressSnapshot?.runStatus;
  if (runStatus == RuntimeRunStatus.completed ||
      runStatus == RuntimeRunStatus.failed ||
      runStatus == RuntimeRunStatus.cancelled) {
    return true;
  }
  final taskStatus = task?.status;
  return taskStatus == AgentTaskStatus.completed ||
      taskStatus == AgentTaskStatus.failed ||
      taskStatus == AgentTaskStatus.cancelled;
}

class _TaskStatusPill extends StatelessWidget {
  const _TaskStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontSize: 10.1,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _AnimatedExecutionStepRow extends StatefulWidget {
  const _AnimatedExecutionStepRow({
    super.key,
    required this.step,
    required this.index,
    required this.statusLabel,
    required this.accent,
    required this.icon,
  });

  final ExecutionPlanEntry step;
  final int index;
  final String statusLabel;
  final Color accent;
  final IconData icon;

  @override
  State<_AnimatedExecutionStepRow> createState() =>
      _AnimatedExecutionStepRowState();
}

class _AnimatedExecutionStepRowState extends State<_AnimatedExecutionStepRow>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _runningController;
  late final AnimationController _doneController;
  late AgentStepStatus _lastStatus;

  @override
  void initState() {
    super.initState();
    _lastStatus = widget.step.status;
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _runningController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _doneController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    Future<void>.delayed(Duration(milliseconds: 45 * widget.index), () {
      if (mounted) {
        _entryController.forward();
      }
    });

    if (widget.step.status == AgentStepStatus.running) {
      _runningController.repeat();
    }
    if (widget.step.status == AgentStepStatus.completed) {
      _doneController.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedExecutionStepRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.step.status != _lastStatus) {
      if (widget.step.status == AgentStepStatus.running) {
        _runningController.repeat();
      } else {
        _runningController.stop();
        _runningController.reset();
      }

      if (widget.step.status == AgentStepStatus.completed &&
          _lastStatus != AgentStepStatus.completed) {
        _doneController
          ..reset()
          ..forward();
      }
      _lastStatus = widget.step.status;
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _runningController.dispose();
    _doneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.step.detail;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _entryController,
        _runningController,
        _doneController,
      ]),
      builder: (context, child) {
        final entryValue = Curves.easeOutCubic.transform(
          _entryController.value,
        );
        final runningPulse = widget.step.status == AgentStepStatus.running
            ? 0.88 + (_runningController.value * 0.12)
            : 1.0;
        final doneFlash = widget.step.status == AgentStepStatus.completed
            ? (1 - (_doneController.value - 0.5).abs() * 2).clamp(0.0, 1.0)
            : 0.0;

        return Transform.translate(
          offset: Offset(0, (1 - entryValue) * 10),
          child: Opacity(
            opacity: entryValue.clamp(0.0, 1.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: widget.step.status == AgentStepStatus.running
                    ? AppColors.surfaceOverlay
                    : doneFlash > 0
                    ? AppColors.orange.withValues(
                        alpha: 0.06 + doneFlash * 0.08,
                      )
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Transform.scale(
                      scale: runningPulse,
                      child: Container(
                        width: 14,
                        height: 14,
                        alignment: Alignment.center,
                        child: widget.step.status == AgentStepStatus.running
                            ? Transform.rotate(
                                angle: _runningController.value * 6.28318,
                                child: Icon(
                                  widget.icon,
                                  size: 11.5,
                                  color: widget.accent,
                                ),
                              )
                            : Icon(
                                widget.icon,
                                size: 11.5,
                                color: widget.accent,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.index + 1}. ${widget.step.title}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 11.2,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                        ),
                        if (detail?.isNotEmpty ?? false)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              detail!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: widget.step.status ==
                                            AgentStepStatus.failed ||
                                        widget.step.status ==
                                            AgentStepStatus.blocked
                                    ? AppColors.amber
                                    : AppColors.textMuted,
                                fontSize: 9.75,
                                height: 1.2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 44,
                    child: Text(
                      widget.statusLabel,
                      textAlign: TextAlign.right,
                      style: AppTextStyles.caption.copyWith(
                        color: widget.accent,
                        fontSize: 9.9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UserMessageAttachmentList extends StatelessWidget {
  const _UserMessageAttachmentList({required this.attachments});

  final List<ChatAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: 58,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < attachments.length; index++) ...[
                SizedBox(
                  width: 236,
                  child: _UserMessageAttachmentCard(
                    attachment: attachments[index],
                  ),
                ),
                if (index != attachments.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UserMessageAttachmentCard extends StatelessWidget {
  const _UserMessageAttachmentCard({required this.attachment});

  final ChatAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF343331),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _attachmentAccentForExtension(
                attachment.extension,
              ).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _attachmentIconForExtension(attachment.extension),
              color: AppColors.textOnDarkStrong,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  attachment.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12.7,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  attachment.kindLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySecondary.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11.4,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _attachmentAccentForExtension(String? extension) {
  final normalized = extension?.toLowerCase();
  return switch (normalized) {
    'pdf' => AppColors.red,
    'doc' || 'docx' => const Color(0xFF1E88FF),
    'xls' || 'xlsx' || 'csv' => AppColors.amber,
    'ppt' || 'pptx' => const Color(0xFF8E8E8E),
    'txt' || 'md' || 'json' => const Color(0xFF8E8E8E),
    _ => const Color(0xFF8E8E8E),
  };
}

IconData _attachmentIconForExtension(String? extension) {
  final normalized = extension?.toLowerCase();
  return switch (normalized) {
    'pdf' => Icons.picture_as_pdf_rounded,
    'doc' || 'docx' => Icons.description_rounded,
    'xls' || 'xlsx' || 'csv' => Icons.table_chart_rounded,
    'ppt' || 'pptx' => Icons.slideshow_rounded,
    'txt' || 'md' || 'json' => Icons.description_rounded,
    _ => Icons.description_outlined,
  };
}

class _GeneratedArtifactList extends StatelessWidget {
  const _GeneratedArtifactList({
    required this.artifacts,
    required this.onPrimaryTap,
    required this.onShareTap,
  });

  final List<GeneratedArtifactReference> artifacts;
  final void Function(GeneratedArtifactReference artifact) onPrimaryTap;
  final void Function(GeneratedArtifactReference artifact) onShareTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 72,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < artifacts.length; index++) ...[
                SizedBox(
                  width: 244,
                  child: _GeneratedArtifactCard(
                    artifact: artifacts[index],
                    onPrimaryTap: () => onPrimaryTap(artifacts[index]),
                    onShareTap: () => onShareTap(artifacts[index]),
                  ),
                ),
                if (index != artifacts.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GeneratedArtifactCard extends StatelessWidget {
  const _GeneratedArtifactCard({
    required this.artifact,
    required this.onPrimaryTap,
    required this.onShareTap,
  });

  final GeneratedArtifactReference artifact;
  final VoidCallback onPrimaryTap;
  final VoidCallback onShareTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPrimaryTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x28FFFFFF)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _attachmentAccentForExtension(
                    artifact.extension,
                  ).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  _attachmentIconForExtension(artifact.extension),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      artifact.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 12.7,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          artifact.kindLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySecondary.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              _ArtifactActionButton(
                icon: Icons.download_rounded,
                tooltip: 'Download',
                onTap: onPrimaryTap,
              ),
              _ArtifactActionButton(
                icon: Icons.share_rounded,
                tooltip: 'Share',
                onTap: onShareTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtifactActionButton extends StatelessWidget {
  const _ArtifactActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.textSecondary, size: 17),
        ),
      ),
    );
  }
}

class _DocumentPreviewDialog extends StatelessWidget {
  const _DocumentPreviewDialog({
    required this.title,
    required this.kindLabel,
    required this.markdownContent,
    required this.onClose,
    required this.onFullscreen,
  });

  final String title;
  final String kindLabel;
  final String markdownContent;
  final VoidCallback onClose;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: 760,
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DocumentPreviewHeader(
              title: title,
              kindLabel: kindLabel,
              onClose: onClose,
              onFullscreen: onFullscreen,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: MarkdownBody(
                  data: markdownContent.trim(),
                  selectable: true,
                  shrinkWrap: true,
                  styleSheet: _documentPreviewMarkdownStyleSheet,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenDocumentPreviewScreen extends StatelessWidget {
  const _FullscreenDocumentPreviewScreen({
    required this.title,
    required this.kindLabel,
    required this.markdownContent,
  });

  final String title;
  final String kindLabel;
  final String markdownContent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: Colors.white),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.title.copyWith(color: Colors.white),
            ),
            Text(
              kindLabel,
              style: AppTextStyles.bodySecondary.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: MarkdownBody(
            data: markdownContent.trim(),
            selectable: true,
            shrinkWrap: true,
            styleSheet: _documentPreviewMarkdownStyleSheet,
          ),
        ),
      ),
    );
  }
}

class _DocumentPreviewHeader extends StatelessWidget {
  const _DocumentPreviewHeader({
    required this.title,
    required this.kindLabel,
    required this.onClose,
    required this.onFullscreen,
  });

  final String title;
  final String kindLabel;
  final VoidCallback onClose;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: const BoxDecoration(
        color: Color(0xFF242424),
        border: Border(bottom: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF1E88FF).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.description_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  kindLabel,
                  style: AppTextStyles.bodySecondary.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          _ArtifactActionButton(
            icon: Icons.open_in_full_rounded,
            tooltip: 'Full screen',
            onTap: onFullscreen,
          ),
          _ArtifactActionButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

final MarkdownStyleSheet _documentPreviewMarkdownStyleSheet =
    MarkdownStyleSheet(
      p: AppTextStyles.body.copyWith(
        color: AppColors.textPrimary,
        fontSize: 13.5,
        height: 1.5,
      ),
      h1: AppTextStyles.title.copyWith(
        color: AppColors.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
      h2: AppTextStyles.title.copyWith(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      h3: AppTextStyles.titleSmall.copyWith(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      listBullet: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
      strong: AppTextStyles.body.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      em: AppTextStyles.body.copyWith(
        color: AppColors.textPrimary,
        fontStyle: FontStyle.italic,
      ),
      code: AppTextStyles.codeMono(
        color: AppColors.textPrimary,
        fontSize: 12.5,
        backgroundColor: AppColors.surfaceOverlay,
      ),
      codeblockDecoration: BoxDecoration(
        color: AppColors.surfaceOverlay,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
      ),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.surfaceOverlay,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
      ),
      tableHead: AppTextStyles.body.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      tableBody: AppTextStyles.body.copyWith(
        color: AppColors.textPrimary,
      ),
      tableBorder: TableBorder.all(color: AppColors.borderSoft),
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderSoft),
        ),
      ),
    );


/// Settings row pinned to the bottom of the drawer.
class _SidebarFooterSettingsEntry extends StatelessWidget {
  const _SidebarFooterSettingsEntry({required this.onOpenSettings});

  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpenSettings,
      borderRadius: BorderRadius.circular(12),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: <Widget>[
            Icon(Icons.tune_rounded, size: 16, color: AppColors.textSecondary),
            SizedBox(width: 10),
            Text(
              'Settings',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.6,
                fontWeight: FontWeight.w500,
              ),
            ),
            Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
