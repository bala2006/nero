import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../agent/domain/agent_task.dart';
import '../../chat/domain/chat_message.dart';
import '../../runtime/domain/runtime_progress_snapshot.dart';
import '../application/document_export_service.dart';
import '../application/report_generation_service.dart';
import '../application/workspace_controller.dart';
import '../domain/workspace_item.dart';

enum _WorkspaceFilter {
  all('All'),
  imported('Imports'),
  generated('Artifacts');

  const _WorkspaceFilter(this.label);

  final String label;
}

class WorkspaceBrowserScreen extends StatefulWidget {
  const WorkspaceBrowserScreen({
    super.key,
    required this.conversationId,
    required this.conversationTitle,
    required this.messages,
    this.activeTask,
    this.runtimeProgressSnapshot,
  });

  final String conversationId;
  final String conversationTitle;
  final List<ChatMessage> messages;
  final AgentTask? activeTask;
  final RuntimeProgressSnapshot? runtimeProgressSnapshot;

  @override
  State<WorkspaceBrowserScreen> createState() => _WorkspaceBrowserScreenState();
}

class _WorkspaceBrowserScreenState extends State<WorkspaceBrowserScreen> {
  late final WorkspaceController _controller;
  late final DocumentExportService _documentExportService;
  late final ReportGenerationService _reportGenerationService;
  _WorkspaceFilter _filter = _WorkspaceFilter.all;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _controller = WorkspaceController()..load();
    _documentExportService = DocumentExportService();
    _reportGenerationService = ReportGenerationService(
      documentExportService: _documentExportService,
    );
  }

  Future<void> _shareReport() async {
    final report = _reportGenerationService.buildConversationReport(
      conversationTitle: widget.conversationTitle,
      messages: widget.messages,
      activeTask: widget.activeTask,
      runtimeProgressSnapshot: widget.runtimeProgressSnapshot,
    );
    final format = await _pickFormat(title: 'Share report');
    if (format == null) {
      return;
    }
    await _runBusy(
      () => _documentExportService.shareDocument(
        title: report.title,
        conversationId: widget.conversationId,
        format: format,
        markdownContent: report.markdown,
        plainTextContent: report.plainText,
        metadata: const <String, Object?>{
          'reportKind': 'conversation',
        },
      ),
    );
    await _controller.load();
  }

  Future<void> _saveReport() async {
    final report = _reportGenerationService.buildConversationReport(
      conversationTitle: widget.conversationTitle,
      messages: widget.messages,
      activeTask: widget.activeTask,
      runtimeProgressSnapshot: widget.runtimeProgressSnapshot,
    );
    final format = await _pickFormat(title: 'Save report');
    if (format == null) {
      return;
    }
    await _runBusy(
      () => _documentExportService.exportDocument(
        title: report.title,
        conversationId: widget.conversationId,
        format: format,
        markdownContent: report.markdown,
        plainTextContent: report.plainText,
        metadata: const <String, Object?>{
          'reportKind': 'conversation',
        },
      ),
    );
    await _controller.load();
  }

  Future<void> _deleteItem(WorkspaceItem item) async {
    await _runBusy(() => _controller.deleteItem(item));
  }

  Future<void> _shareItem(WorkspaceItem item) async {
    await _runBusy(() => _controller.shareItem(item));
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_isBusy) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<ExportDocumentFormat?> _pickFormat({
    required String title,
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
                  _FormatTile(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _WorkspaceBackdrop()),
          SafeArea(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final items = _filteredItems(_controller.items);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  children: [
                    Row(
                      children: [
                        _HeaderIconButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Workspace',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Files, artifacts, and reports for this session.',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 11.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isBusy)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: AppColors.orange,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: 'Conversation Report',
                      subtitle:
                          'Create a clean report from the current conversation, task steps, and generated outputs.',
                      child: Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.save_alt_rounded,
                              label: 'Save',
                              onTap: _saveReport,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.ios_share_rounded,
                              label: 'Share',
                              onTap: _shareReport,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: 'Workspace Items',
                      subtitle:
                          'Imported files, captured media, and saved artifacts stay available here.',
                      child: Column(
                        children: [
                          Row(
                            children: [
                              for (final filter in _WorkspaceFilter.values) ...[
                                _FilterChip(
                                  label: filter.label,
                                  selected: _filter == filter,
                                  onTap: () => setState(() => _filter = filter),
                                ),
                                if (filter != _WorkspaceFilter.values.last)
                                  const SizedBox(width: 8),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_controller.isLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.orange,
                              ),
                            )
                          else if (_controller.error != null)
                            Text(
                              _controller.error!,
                              style: AppTextStyles.bodySecondary.copyWith(
                                color: AppColors.amber,
                                fontSize: 12,
                              ),
                            )
                          else if (items.isEmpty)
                            Text(
                              'No workspace items yet.',
                              style: AppTextStyles.bodySecondary.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12.2,
                              ),
                            )
                          else
                            for (var index = 0; index < items.length; index++) ...[
                              _WorkspaceItemTile(
                                item: items[index],
                                onDeleteTap: () => _deleteItem(items[index]),
                                onShareTap: items[index].localPath == null
                                    ? null
                                    : () => _shareItem(items[index]),
                              ),
                              if (index != items.length - 1)
                                const SizedBox(height: 10),
                            ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<WorkspaceItem> _filteredItems(List<WorkspaceItem> items) {
    return switch (_filter) {
      _WorkspaceFilter.all => items,
      _WorkspaceFilter.imported => items
          .where((item) => item.type == WorkspaceItemType.importedFile)
          .toList(growable: false),
      _WorkspaceFilter.generated => items
          .where((item) => item.type == WorkspaceItemType.generatedArtifact)
          .toList(growable: false),
    };
  }
}

class _WorkspaceBackdrop extends StatelessWidget {
  const _WorkspaceBackdrop();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: AppColors.backgroundBackdrop);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textPrimary,
              fontSize: 14.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.bodySecondary.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11.9,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceOverlay,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.orange : AppColors.surfaceOverlay,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: selected
                    ? AppColors.textOnDarkStrong
                    : AppColors.textSecondary,
                fontSize: 11.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceItemTile extends StatelessWidget {
  const _WorkspaceItemTile({
    required this.item,
    required this.onDeleteTap,
    this.onShareTap,
  });

  final WorkspaceItem item;
  final VoidCallback onDeleteTap;
  final VoidCallback? onShareTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOverlay,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _workspaceItemAccent(item).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _workspaceItemIcon(item),
              size: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.type == WorkspaceItemType.generatedArtifact ? 'Artifact' : 'Imported'}${item.extension == null ? '' : ' • .${item.extension}'}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11.2,
                  ),
                ),
              ],
            ),
          ),
          if (onShareTap != null)
            IconButton(
              onPressed: onShareTap,
              icon: const Icon(
                Icons.ios_share_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
            ),
          IconButton(
            onPressed: onDeleteTap,
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

Color _workspaceItemAccent(WorkspaceItem item) {
  final extension = item.extension?.toLowerCase();
  return switch (extension) {
    'pdf' => AppColors.red,
    'doc' || 'docx' => const Color(0xFF1E88FF),
    'xls' || 'xlsx' || 'csv' => AppColors.amber,
    'ppt' || 'pptx' => const Color(0xFF8E8E8E),
    _ => item.type == WorkspaceItemType.generatedArtifact
        ? AppColors.orange
        : AppColors.tealBright,
  };
}

IconData _workspaceItemIcon(WorkspaceItem item) {
  final extension = item.extension?.toLowerCase();
  return switch (extension) {
    'pdf' => Icons.picture_as_pdf_rounded,
    'doc' || 'docx' => Icons.description_rounded,
    'xls' || 'xlsx' || 'csv' => Icons.table_chart_rounded,
    'ppt' || 'pptx' => Icons.slideshow_rounded,
    'txt' || 'md' || 'json' => Icons.description_rounded,
    _ => item.type == WorkspaceItemType.generatedArtifact
        ? Icons.auto_awesome_rounded
        : Icons.folder_open_rounded,
  };
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceGlass,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Icon(
            icon,
            size: 19,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.format,
    required this.onTap,
  });

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
