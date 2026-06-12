import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_highlighter/themes/atom-one-dark.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../workspace/application/diagram_artifact_store.dart';
import 'ai_thinking_animation.dart';
import 'webview_mermaid.dart';

class ChatRichContent extends StatelessWidget {
  const ChatRichContent({
    super.key,
    required this.data,
    this.enableRichRendering = true,
    this.streamingMode = false,
    this.onDiagramRenderResult,
    this.onDownloadArtifact,
  });

  final String data;
  final bool enableRichRendering;
  final bool streamingMode;
  final void Function(bool success, String? error)? onDiagramRenderResult;
  final Future<void> Function(String title, String markdownContent)?
  onDownloadArtifact;

  @override
  Widget build(BuildContext context) {
    if (data.trim() == 'Thinking...') {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: AIThinkingAnimation(),
      );
    }
    final segments = _MarkdownSegmentParser.parse(data);
    if (segments.isEmpty) {
      return _MarkdownTextBlock(data: data);
    }

    if (!enableRichRendering) {
      return _MarkdownTextBlock(data: data);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final segment in segments) ...[
          switch (segment.type) {
            _MarkdownSegmentType.markdown =>
              streamingMode
                  ? _StreamingMarkdownTextBlock(data: segment.content)
                  : _MarkdownTextBlock(data: segment.content),
            _MarkdownSegmentType.code => _CodeBlock(
              code: segment.content,
              language: segment.language,
              lightweight: streamingMode,
            ),
            _MarkdownSegmentType.diagram => _DiagramBlock(
              code: segment.content,
              onRenderResult: onDiagramRenderResult,
            ),
            _MarkdownSegmentType.table => _TableBlock(
              data: segment.content,
              lightweight: streamingMode,
            ),
            _MarkdownSegmentType.artifact => _ArtifactBlock(
              title: segment.title ?? 'Document',
              markdownContent: segment.content,
              onDownload: onDownloadArtifact == null
                  ? null
                  : () => onDownloadArtifact!(
                      segment.title ?? 'Document',
                      segment.content,
                    ),
            ),
          },
        ],
      ],
    );
  }
}

class _StreamingMarkdownTextBlock extends StatelessWidget {
  const _StreamingMarkdownTextBlock({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final trimmed = data.trim();
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MarkdownBody(
        data: trimmed,
        selectable: true,
        shrinkWrap: true,
        softLineBreak: true,
        styleSheet: _markdownStyleSheet,
      ),
    );
  }
}

class _MarkdownTextBlock extends StatelessWidget {
  const _MarkdownTextBlock({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final trimmed = data.trim();
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MarkdownBody(
        data: trimmed,
        selectable: true,
        shrinkWrap: true,
        softLineBreak: true,
        styleSheet: _markdownStyleSheet,
      ),
    );
  }
}

class _TableBlock extends StatefulWidget {
  const _TableBlock({required this.data, this.lightweight = false});

  final String data;
  final bool lightweight;

  @override
  State<_TableBlock> createState() => _TableBlockState();
}

class _TableBlockState extends State<_TableBlock> {
  static const double _tableViewportHeight = 248;
  static const double _tableMinViewportWidth = 720;
  static const double _expandedTableMinViewportWidth = 1040;

  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  bool _copied = false;

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.data.trim()));
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _copied = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ContainerHeader(
              icon: Icons.table_chart_rounded,
              iconColor: AppColors.amber,
              title: 'TABLE',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeaderIconAction(
                    icon: Icons.open_in_full_rounded,
                    label: 'Expand',
                    onTap: _openExpanded,
                  ),
                  const SizedBox(width: 4),
                  _HeaderCopyAction(copied: _copied, onTap: _copy),
                ],
              ),
            ),
            SizedBox(
              height: _tableViewportHeight,
              child: Scrollbar(
                controller: _verticalScrollController,
                thumbVisibility: false,
                thickness: 0,
                radius: const Radius.circular(999),
                child: SingleChildScrollView(
                  controller: _verticalScrollController,
                  primary: false,
                  padding: const EdgeInsets.all(12),
                  child: Scrollbar(
                    controller: _horizontalScrollController,
                    thumbVisibility: false,
                    scrollbarOrientation: ScrollbarOrientation.bottom,
                    notificationPredicate: (notification) =>
                        notification.metrics.axis == Axis.horizontal,
                    thickness: 0,
                    radius: const Radius.circular(999),
                    child: SingleChildScrollView(
                      controller: _horizontalScrollController,
                      primary: false,
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth:
                              _tableMinViewportWidth >
                                  MediaQuery.of(context).size.width - 56
                              ? _tableMinViewportWidth
                              : MediaQuery.of(context).size.width - 56,
                        ),
                        child: MarkdownBody(
                          data: widget.data.trim(),
                          selectable: true,
                          shrinkWrap: true,
                          styleSheet: _markdownStyleSheet,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExpanded() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFF1E1E1E),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E1E1E),
            title: Text(
              'Table',
              style: AppTextStyles.sans(color: Colors.white),
            ),
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth:
                      _expandedTableMinViewportWidth >
                          MediaQuery.of(context).size.width - 32
                      ? _expandedTableMinViewportWidth
                      : MediaQuery.of(context).size.width - 32,
                ),
                child: SingleChildScrollView(
                  child: MarkdownBody(
                    data: widget.data.trim(),
                    selectable: true,
                    shrinkWrap: true,
                    styleSheet: _markdownStyleSheet,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeBlock extends StatefulWidget {
  const _CodeBlock({
    required this.code,
    required this.language,
    this.lightweight = false,
  });

  final String code;
  final String? language;
  final bool lightweight;

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  static const double _codeViewportHeight = 248;

  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  bool _copied = false;

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _copied = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = (widget.language?.trim().isNotEmpty ?? false)
        ? widget.language!.trim()
        : 'text';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ContainerHeader(
              icon: _languageIcon(language),
              iconColor: AppColors.tealBright,
              title: language.toUpperCase(),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeaderIconAction(
                    icon: Icons.open_in_full_rounded,
                    label: 'Expand',
                    onTap: () => _openExpanded(language),
                  ),
                  const SizedBox(width: 4),
                  _HeaderCopyAction(copied: _copied, onTap: _copy),
                ],
              ),
            ),
            SizedBox(
              height: _codeViewportHeight,
              child: Scrollbar(
                controller: _verticalScrollController,
                thumbVisibility: false,
                thickness: 0,
                radius: const Radius.circular(999),
                child: SingleChildScrollView(
                  controller: _verticalScrollController,
                  primary: false,
                  padding: EdgeInsets.zero,
                  child: Scrollbar(
                    controller: _horizontalScrollController,
                    thumbVisibility: false,
                    scrollbarOrientation: ScrollbarOrientation.bottom,
                    notificationPredicate: (notification) =>
                        notification.metrics.axis == Axis.horizontal,
                    thickness: 0,
                    radius: const Radius.circular(999),
                    child: SingleChildScrollView(
                      controller: _horizontalScrollController,
                      primary: false,
                      scrollDirection: Axis.horizontal,
                      child: widget.lightweight
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: SelectableText(
                                widget.code.trimRight(),
                                style: AppTextStyles.codeMono(
                                  color: AppColors.textMarkdownBody,
                                  fontSize: 12.5,
                                  height: 1.55,
                                ),
                              ),
                            )
                          : HighlightView(
                              widget.code.trimRight(),
                              language: _highlightLanguage(language),
                              theme:
                                  Map<String, TextStyle>.from(atomOneDarkTheme)
                                    ..['root'] = AppTextStyles.codeMono(
                                      color: AppColors.textMarkdownBody,
                                      fontSize: 12.5,
                                      height: 1.55,
                                      backgroundColor: Colors.transparent,
                                    ),
                              padding: const EdgeInsets.all(12),
                              textStyle: AppTextStyles.codeMono(
                                color: AppColors.textMarkdownBody,
                                fontSize: 12.5,
                                height: 1.55,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExpanded(String language) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFF1E1E1E),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E1E1E),
            title: Text(
              language.toUpperCase(),
              style: AppTextStyles.editorMono(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width,
                ),
                child: SingleChildScrollView(
                  child: HighlightView(
                    widget.code.trimRight(),
                    language: _highlightLanguage(language),
                    theme: Map<String, TextStyle>.from(atomOneDarkTheme)
                      ..['root'] = AppTextStyles.codeMono(
                        color: AppColors.textMarkdownBody,
                        fontSize: 12.5,
                        height: 1.55,
                        backgroundColor: Colors.transparent,
                      ),
                    padding: const EdgeInsets.all(16),
                    textStyle: AppTextStyles.codeMono(
                      color: AppColors.textMarkdownBody,
                      fontSize: 12.5,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _languageIcon(String language) {
    switch (language.toLowerCase()) {
      case 'dart':
      case 'flutter':
        return Icons.flutter_dash_rounded;
      case 'json':
        return Icons.data_object_rounded;
      case 'yaml':
      case 'yml':
        return Icons.tune_rounded;
      case 'bash':
      case 'sh':
      case 'shell':
      case 'powershell':
        return Icons.terminal_rounded;
      default:
        return Icons.code_rounded;
    }
  }

  String _highlightLanguage(String language) {
    switch (language.toLowerCase()) {
      case 'sh':
      case 'shell':
        return 'bash';
      case 'yml':
        return 'yaml';
      case 'text':
        return 'plaintext';
      default:
        return language.toLowerCase();
    }
  }
}

class _DiagramBlock extends StatefulWidget {
  const _DiagramBlock({required this.code, this.onRenderResult});

  final String code;
  final void Function(bool success, String? error)? onRenderResult;

  @override
  State<_DiagramBlock> createState() => _DiagramBlockState();
}

class _DiagramBlockState extends State<_DiagramBlock> {
  static const double _diagramViewportHeight = 248;

  final DiagramArtifactStore _artifactStore = const DiagramArtifactStore();
  final ScrollController _sourceVerticalScrollController = ScrollController();
  final ScrollController _sourceHorizontalScrollController = ScrollController();
  bool _copied = false;
  bool _showSource = false;
  DiagramArtifactRecord? _artifact;
  String? _artifactLookupKey;

  @override
  void initState() {
    super.initState();
    _loadArtifact();
  }

  @override
  void didUpdateWidget(covariant _DiagramBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      _loadArtifact();
    }
  }

  @override
  void dispose() {
    _sourceVerticalScrollController.dispose();
    _sourceHorizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadArtifact() async {
    final normalizedCode = _normalizeDiagramCode(widget.code);
    _artifactLookupKey = normalizedCode;
    final artifact = await _artifactStore.load(normalizedCode);
    if (!mounted || _artifactLookupKey != normalizedCode) {
      return;
    }
    setState(() {
      _artifact = artifact;
    });
  }

  Future<void> _storePngArtifact(String pngDataUrl) async {
    final normalizedCode = _normalizeDiagramCode(widget.code);
    if (normalizedCode.isEmpty) {
      return;
    }
    final commaIndex = pngDataUrl.indexOf(',');
    final payload = commaIndex >= 0
        ? pngDataUrl.substring(commaIndex + 1)
        : pngDataUrl;
    final artifact = await _artifactStore.save(
      mermaidSource: normalizedCode,
      pngBytes: base64Decode(payload),
    );
    if (!mounted || _artifactLookupKey != normalizedCode) {
      return;
    }
    setState(() {
      _artifact = artifact;
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code.trim()));
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _copied = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedCode = _normalizeDiagramCode(widget.code);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ContainerHeader(
              icon: Icons.account_tree_rounded,
              iconColor: AppColors.tealBright,
              title: 'DIAGRAM',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() => _showSource = !_showSource);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 0,
                      ),
                      minimumSize: const Size(0, 20),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _showSource ? 'Preview' : 'Source',
                      style: AppTextStyles.caption.copyWith(fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _HeaderIconAction(
                    icon: Icons.open_in_full_rounded,
                    label: 'Expand',
                    onTap: _openExpanded,
                  ),
                  const SizedBox(width: 4),
                  _HeaderCopyAction(copied: _copied, onTap: _copy),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _showSource
                  ? SizedBox(
                      key: const ValueKey('diagram_source'),
                      height: _diagramViewportHeight,
                      child: Scrollbar(
                        controller: _sourceVerticalScrollController,
                        thumbVisibility: false,
                        thickness: 0,
                        radius: const Radius.circular(999),
                        child: SingleChildScrollView(
                          controller: _sourceVerticalScrollController,
                          primary: false,
                          padding: const EdgeInsets.all(12),
                          child: Scrollbar(
                            controller: _sourceHorizontalScrollController,
                            thumbVisibility: false,
                            scrollbarOrientation: ScrollbarOrientation.bottom,
                            notificationPredicate: (notification) =>
                                notification.metrics.axis == Axis.horizontal,
                            thickness: 0,
                            radius: const Radius.circular(999),
                            child: SingleChildScrollView(
                              controller: _sourceHorizontalScrollController,
                              primary: false,
                              scrollDirection: Axis.horizontal,
                              child: SelectableText(
                                widget.code.trimRight(),
                                style: AppTextStyles.codeMono(
                                  color: AppColors.textMarkdownBody,
                                  fontSize: 12.5,
                                  height: 1.55,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      key: const ValueKey('diagram_preview'),
                      height: _diagramViewportHeight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _artifact == null
                              ? _InlineDiagramPending(code: normalizedCode)
                              : _CachedDiagramImage(
                                  imagePath: _artifact!.imagePath,
                                ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExpanded() async {
    final normalizedCode = _normalizeDiagramCode(widget.code);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFF1E1E1E),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E1E1E),
            title: Text(
              'Diagram',
              style: AppTextStyles.sans(color: Colors.white),
            ),
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: _artifact == null
              ? WebViewMermaid(
                  code: normalizedCode,
                  height: MediaQuery.of(context).size.height,
                  onRenderResult: widget.onRenderResult,
                  onPngReady: _storePngArtifact,
                )
              : _CachedDiagramImage(imagePath: _artifact!.imagePath),
        ),
      ),
    );
  }

  String _normalizeDiagramCode(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return normalized;
    }
    final lines = normalized
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.trim() != '```' && line.trim() != '```mermaid')
        .toList(growable: false);
    final firstDiagramIndex = lines.indexWhere(
      (line) => _looksLikeMermaidStart(line.trimLeft()),
    );
    final relevantLines = firstDiagramIndex >= 0
        ? lines.sublist(firstDiagramIndex)
        : lines;
    return relevantLines.join('\n').trim();
  }

  bool _looksLikeMermaidStart(String line) {
    return RegExp(
      r'^(graph|flowchart|sequenceDiagram|classDiagram|stateDiagram(?:-v2)?|erDiagram|journey|gantt|pie|gitGraph|mindmap|timeline|zenuml|quadrantChart|requirementDiagram|C4Context|C4Container|C4Component|C4Dynamic|C4Deployment)\b',
      caseSensitive: false,
    ).hasMatch(line);
  }
}

class _CachedDiagramImage extends StatelessWidget {
  const _CachedDiagramImage({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E),
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Image.file(
            File(imagePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.tealBright,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineDiagramPending extends StatelessWidget {
  const _InlineDiagramPending({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final previewLines = code
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty)
        .take(6)
        .join('\n');
    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Expand once to render and cache this diagram.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMuted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          if (previewLines.isNotEmpty) ...[
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  previewLines,
                  style: AppTextStyles.codeMono(
                    color: AppColors.textOnDarkMuted,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContainerHeader extends StatelessWidget {
  const _ContainerHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      color: AppColors.surfaceOverlayStrong,
      child: Row(
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 6),
          Text(
            title,
            style: AppTextStyles.editorMono(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _HeaderCopyAction extends StatelessWidget {
  const _HeaderCopyAction({required this.copied, required this.onTap});

  final bool copied;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: copied
            ? AppColors.tealBright
            : AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        minimumSize: const Size(0, 20),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(copied ? Icons.check_rounded : Icons.copy_rounded, size: 12),
      label: Text(
        copied ? 'Copied' : 'Copy',
        style: AppTextStyles.caption.copyWith(fontSize: 10),
      ),
    );
  }
}

class _HeaderIconAction extends StatelessWidget {
  const _HeaderIconAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        minimumSize: const Size(0, 20),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 12),
      label: Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
    );
  }
}

enum _MarkdownSegmentType { markdown, code, diagram, table, artifact }

class _MarkdownSegment {
  const _MarkdownSegment({
    required this.type,
    required this.content,
    this.language,
    this.title,
  });

  final _MarkdownSegmentType type;
  final String content;
  final String? language;
  final String? title;
}

class _MarkdownSegmentParser {
  static const int _maxCachedInputs = 48;
  static final Map<String, List<_MarkdownSegment>> _cachedSegments =
      <String, List<_MarkdownSegment>>{};
  static final RegExp _tableDivider = RegExp(
    r'^\s*\|?(?:\s*:?-{3,}:?\s*\|)+(?:\s*:?-{3,}:?\s*)\|?\s*$',
  );
  static final RegExp _neroBlockStart = RegExp(
    r'^\s*\[\[NERO_BLOCK:(CODE|DIAGRAM|TABLE)(?:\s+lang=([A-Za-z0-9_+\-#.]+))?\]\]\s*$',
    caseSensitive: false,
  );
  static final RegExp _neroArtifactBlock = RegExp(
    r'^\s*\[\[NERO_BLOCK:DOCX(?<attrs>.*?)\]\]\s*$',
    caseSensitive: false,
  );
  static final RegExp _neroBlockEnd = RegExp(
    r'^\s*\[\[/NERO_BLOCK\]\]\s*$',
    caseSensitive: false,
  );

  static List<_MarkdownSegment> parse(String input) {
    final cached = _cachedSegments[input];
    if (cached != null) {
      return cached;
    }
    final lines = input.replaceAll('\r\n', '\n').split('\n');
    final segments = <_MarkdownSegment>[];
    final markdownBuffer = <String>[];
    var index = 0;

    void flushMarkdown() {
      final content = markdownBuffer.join('\n').trim();
      markdownBuffer.clear();
      if (content.isNotEmpty) {
        segments.add(
          _MarkdownSegment(
            type: _MarkdownSegmentType.markdown,
            content: content,
          ),
        );
      }
    }

    while (index < lines.length) {
      final line = lines[index];
      final nextLine = index + 1 < lines.length ? lines[index + 1] : null;
      final neroArtifactBlock = _neroArtifactBlock.firstMatch(line);
      if (neroArtifactBlock != null) {
        final attributes = _parseBlockAttributes(
          neroArtifactBlock.namedGroup('attrs') ?? '',
        );
        final markdownContent = attributes['markdown_content']?.trim();
        if (markdownContent != null && markdownContent.isNotEmpty) {
          flushMarkdown();
          segments.add(
            _MarkdownSegment(
              type: _MarkdownSegmentType.artifact,
              title: attributes['title']?.trim().isNotEmpty == true
                  ? attributes['title']!.trim()
                  : 'Document',
              content: markdownContent,
            ),
          );
          index += 1;
          continue;
        }
      }
      final neroBlockStart = _neroBlockStart.firstMatch(line);
      if (neroBlockStart != null) {
        flushMarkdown();
        final blockType = neroBlockStart.group(1)?.toUpperCase();
        final language = neroBlockStart.group(2)?.trim();
        index += 1;
        final blockLines = <String>[];
        while (index < lines.length && !_neroBlockEnd.hasMatch(lines[index])) {
          blockLines.add(lines[index]);
          index += 1;
        }
        if (index < lines.length) {
          index += 1;
        }
        final content = blockLines.join('\n').trimRight();
        if (content.isNotEmpty) {
          segments.add(
            _MarkdownSegment(
              type: switch (blockType) {
                'DIAGRAM' => _MarkdownSegmentType.diagram,
                'TABLE' => _MarkdownSegmentType.table,
                _ => _MarkdownSegmentType.code,
              },
              content: content,
              language: blockType == 'CODE'
                  ? (language?.isNotEmpty == true
                        ? language
                        : _detectCodeLanguage(content))
                  : (blockType == 'DIAGRAM'
                        ? (language?.isNotEmpty == true ? language : 'mermaid')
                        : null),
            ),
          );
        }
        continue;
      }

      if (line.trimLeft().startsWith('```')) {
        _dropTrailingStandaloneBlockLabel(markdownBuffer);
        flushMarkdown();
        final language = line.trim().substring(3).trim();
        index += 1;
        final codeLines = <String>[];
        while (index < lines.length &&
            !lines[index].trimLeft().startsWith('```')) {
          codeLines.add(lines[index]);
          index += 1;
        }
        if (index < lines.length) {
          index += 1;
        }
        segments.add(
          _MarkdownSegment(
            type: language.toLowerCase() == 'mermaid'
                ? _MarkdownSegmentType.diagram
                : _MarkdownSegmentType.code,
            content: codeLines.join('\n'),
            language: language,
          ),
        );
        continue;
      }

      if (_looksLikeStandaloneCodeIntro(line, nextLine) ||
          (_looksLikeStandaloneCodeStart(line) &&
              _trailingMarkdownLooksLikeCodeLabel(markdownBuffer))) {
        _dropTrailingStandaloneBlockLabel(markdownBuffer);
        flushMarkdown();
        final introLanguage = _languageHintFromLabel(line);
        if (_looksLikeStandaloneCodeIntro(line, nextLine)) {
          index += 1;
        }
        final codeLines = <String>[];
        while (index < lines.length) {
          final codeLine = lines[index];
          final trimmedCodeLine = codeLine.trimRight();
          if (trimmedCodeLine.isEmpty) {
            break;
          }
          if (_looksLikeAnotherSectionStart(trimmedCodeLine) &&
              !_looksLikeStandaloneCodeStart(codeLine)) {
            break;
          }
          codeLines.add(codeLine);
          index += 1;
        }
        final content = codeLines.join('\n').trimRight();
        if (content.isNotEmpty) {
          segments.add(
            _MarkdownSegment(
              type: _MarkdownSegmentType.code,
              content: content,
              language: introLanguage ?? _detectCodeLanguage(content),
            ),
          );
        }
        continue;
      }

      if (_looksLikeStandaloneDiagramIntro(line, nextLine)) {
        _dropTrailingStandaloneBlockLabel(markdownBuffer);
        flushMarkdown();
        index += 1;
        final diagramLines = <String>[];
        while (index < lines.length) {
          final diagramLine = lines[index];
          final trimmedDiagramLine = diagramLine.trim();
          if (trimmedDiagramLine.isEmpty) {
            diagramLines.add(diagramLine);
            index += 1;
            continue;
          }
          if (_looksLikeAnotherSectionStart(trimmedDiagramLine)) {
            break;
          }
          diagramLines.add(diagramLine);
          index += 1;
        }
        final content = diagramLines.join('\n').trim();
        if (content.isNotEmpty) {
          segments.add(
            _MarkdownSegment(
              type: _MarkdownSegmentType.diagram,
              content: content,
              language: 'mermaid',
            ),
          );
        }
        continue;
      }

      if (_looksLikeStandaloneDiagramStart(line)) {
        _dropTrailingStandaloneBlockLabel(markdownBuffer);
        flushMarkdown();
        final diagramLines = <String>[];
        while (index < lines.length) {
          final diagramLine = lines[index];
          final trimmedDiagramLine = diagramLine.trim();
          if (trimmedDiagramLine.isEmpty) {
            diagramLines.add(diagramLine);
            index += 1;
            continue;
          }
          if (_looksLikeAnotherSectionStart(trimmedDiagramLine) &&
              !_looksLikeStandaloneDiagramStart(diagramLine)) {
            break;
          }
          diagramLines.add(diagramLine);
          index += 1;
        }
        final content = diagramLines.join('\n').trim();
        if (content.isNotEmpty) {
          segments.add(
            _MarkdownSegment(
              type: _MarkdownSegmentType.diagram,
              content: content,
              language: 'mermaid',
            ),
          );
        }
        continue;
      }

      if (_looksLikeTableHeader(line, nextLine)) {
        flushMarkdown();
        final tableLines = <String>[line, nextLine!];
        index += 2;
        while (index < lines.length) {
          final tableLine = lines[index];
          if (tableLine.trim().isEmpty || !tableLine.contains('|')) {
            break;
          }
          tableLines.add(tableLine);
          index += 1;
        }
        segments.add(
          _MarkdownSegment(
            type: _MarkdownSegmentType.table,
            content: tableLines.join('\n'),
          ),
        );
        continue;
      }

      markdownBuffer.add(line);
      index += 1;
    }

    flushMarkdown();
    final parsed = List<_MarkdownSegment>.unmodifiable(segments);
    _cachedSegments[input] = parsed;
    if (_cachedSegments.length > _maxCachedInputs) {
      _cachedSegments.remove(_cachedSegments.keys.first);
    }
    return parsed;
  }

  static bool _looksLikeTableHeader(String line, String? nextLine) {
    if (nextLine == null) {
      return false;
    }
    return line.contains('|') && _tableDivider.hasMatch(nextLine);
  }

  static bool _looksLikeStandaloneDiagramIntro(String line, String? nextLine) {
    if (nextLine == null) {
      return false;
    }
    final normalized = line.trim().toLowerCase();
    if (!normalized.contains('mermaid') && !normalized.contains('diagram')) {
      return false;
    }
    return _looksLikeStandaloneDiagramStart(nextLine);
  }

  static bool _looksLikeStandaloneCodeIntro(String line, String? nextLine) {
    if (nextLine == null) {
      return false;
    }
    return _isStandaloneCodeLabel(line) &&
        _looksLikeStandaloneCodeStart(nextLine);
  }

  static bool _looksLikeStandaloneDiagramStart(String line) {
    return RegExp(
      r'^\s*(graph|flowchart|sequenceDiagram|classDiagram|stateDiagram(?:-v2)?|erDiagram|journey|gantt|pie|gitGraph|mindmap|timeline|zenuml|quadrantChart|requirementDiagram|C4Context|C4Container|C4Component|C4Dynamic|C4Deployment)\b',
      caseSensitive: false,
    ).hasMatch(line);
  }

  static bool _looksLikeStandaloneCodeStart(String line) {
    final trimmed = line.trimLeft();
    if (trimmed.isEmpty) {
      return false;
    }
    return RegExp(
          r'^(class |public |private |protected |interface |enum |fun |func |def |import |from |const |final |var |let |async |await |return |if\s*\(|for\s*\(|while\s*\(|switch\s*\(|try\s*\{|catch\s*\(|void |int |double |String |bool |List<|Map<|package |#include|using namespace|SELECT\b|INSERT\b|UPDATE\b|DELETE\b|WITH\b|CREATE\b)',
          caseSensitive: false,
        ).hasMatch(trimmed) ||
        trimmed.startsWith('{') ||
        trimmed.startsWith('}') ||
        trimmed.startsWith('//') ||
        trimmed.startsWith('/*') ||
        trimmed.contains('=>') ||
        trimmed.contains('();') ||
        trimmed.contains('{') ||
        RegExp(
          r'^[A-Za-z_][A-Za-z0-9_<>, ?]*\s+[A-Za-z_][A-Za-z0-9_]*\s*\(',
        ).hasMatch(trimmed);
  }

  static bool _isStandaloneCodeLabel(String line) {
    final normalized = line.trim().toLowerCase();
    return normalized == '**code**' ||
        normalized == 'code' ||
        normalized == 'code:' ||
        normalized == 'code solution:' ||
        normalized == 'java implementation' ||
        normalized == 'python implementation' ||
        normalized == 'dart implementation' ||
        normalized == 'c++ implementation' ||
        normalized == 'typescript implementation' ||
        normalized == 'javascript implementation';
  }

  static bool _trailingMarkdownLooksLikeCodeLabel(List<String> markdownBuffer) {
    for (var index = markdownBuffer.length - 1; index >= 0; index--) {
      final line = markdownBuffer[index].trim();
      if (line.isEmpty) {
        continue;
      }
      return _isStandaloneCodeLabel(line);
    }
    return false;
  }

  static void _dropTrailingStandaloneBlockLabel(List<String> markdownBuffer) {
    for (var index = markdownBuffer.length - 1; index >= 0; index--) {
      final line = markdownBuffer[index].trim();
      if (line.isEmpty) {
        markdownBuffer.removeAt(index);
        continue;
      }
      final normalized = line.toLowerCase();
      if (normalized == '**diagram**' ||
          normalized == '**visual diagram**' ||
          normalized == 'diagram' ||
          normalized == 'diagram:' ||
          normalized == 'visual diagram' ||
          normalized == 'visual diagram:' ||
          normalized == '**code**' ||
          normalized == 'code' ||
          normalized == 'code:' ||
          normalized == 'code solution:' ||
          normalized.endsWith('implementation')) {
        markdownBuffer.removeAt(index);
      }
      break;
    }
  }

  static String? _languageHintFromLabel(String line) {
    final normalized = line.trim().toLowerCase();
    if (normalized.contains('java')) {
      return 'java';
    }
    if (normalized.contains('python')) {
      return 'python';
    }
    if (normalized.contains('dart')) {
      return 'dart';
    }
    if (normalized.contains('c++')) {
      return 'cpp';
    }
    if (normalized.contains('typescript')) {
      return 'typescript';
    }
    if (normalized.contains('javascript')) {
      return 'javascript';
    }
    return null;
  }

  static Map<String, String> _parseBlockAttributes(String raw) {
    final attributes = <String, String>{};
    final attributePattern = RegExp(
      r'([A-Za-z_][A-Za-z0-9_]*)="((?:\\.|[^"\\])*)"',
    );
    for (final match in attributePattern.allMatches(raw)) {
      final key = match.group(1);
      final value = match.group(2);
      if (key == null || value == null) {
        continue;
      }
      attributes[key] = _unescapeQuotedAttribute(value);
    }
    return attributes;
  }

  static String _unescapeQuotedAttribute(String value) {
    return value
        .replaceAll(r'\"', '"')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\\', '\\');
  }

  static String _detectCodeLanguage(String content) {
    final normalized = content.toLowerCase();
    if (normalized.contains('public class ') ||
        normalized.contains('private final ') ||
        normalized.contains('system.out.println')) {
      return 'java';
    }
    if (normalized.contains('import dart:') ||
        normalized.contains('widget build(')) {
      return 'dart';
    }
    if (normalized.contains('#include') || normalized.contains('std::')) {
      return 'cpp';
    }
    if (normalized.contains('def ') || normalized.contains('print(')) {
      return 'python';
    }
    if (normalized.contains('function ') ||
        normalized.contains('const ') ||
        normalized.contains('let ')) {
      return 'javascript';
    }
    return 'text';
  }

  static bool _looksLikeAnotherSectionStart(String line) {
    return RegExp(
      r'^(#{1,6}\s|[-*]\s|\d+\.\s|[A-Z][A-Za-z ]+:|\*\*.+\*\*$|Problem statement|Approach|Explanation|Visual diagram|Diagram|Code solution|Code)',
      caseSensitive: false,
    ).hasMatch(line);
  }
}

class _ArtifactBlock extends StatefulWidget {
  const _ArtifactBlock({
    required this.title,
    required this.markdownContent,
    this.onDownload,
  });

  final String title;
  final String markdownContent;
  final Future<void> Function()? onDownload;

  @override
  State<_ArtifactBlock> createState() => _ArtifactBlockState();
}

class _ArtifactBlockState extends State<_ArtifactBlock> {
  bool _isDownloading = false;

  Future<void> _handleDownload() async {
    final onDownload = widget.onDownload;
    if (onDownload == null || _isDownloading) {
      return;
    }
    setState(() => _isDownloading = true);
    try {
      await onDownload();
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.markdownContent
        .replaceAll(RegExp(r'[#*_`>\[\]]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.tealBright.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.description_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
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
                  'DOCX document',
                  style: AppTextStyles.bodySecondary.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: widget.onDownload == null || _isDownloading
                ? null
                : _handleDownload,
            icon: Icon(
              _isDownloading
                  ? Icons.hourglass_top_rounded
                  : Icons.download_rounded,
              size: 16,
            ),
            label: Text(_isDownloading ? 'Preparing' : 'Download'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.tealBright,
              foregroundColor: Colors.black,
              textStyle: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final MarkdownStyleSheet _markdownStyleSheet = MarkdownStyleSheet(
  p: AppTextStyles.sans(
    color: AppColors.textMarkdownBody,
    fontSize: 15,
    height: 1.6,
    fontWeight: FontWeight.w400,
  ),
  h1: AppTextStyles.editorMono(
    color: AppColors.textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  ),
  h2: AppTextStyles.editorMono(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  ),
  h3: AppTextStyles.editorMono(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  ),
  h4: AppTextStyles.editorMono(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  ),
  strong: AppTextStyles.sans(
    color: AppColors.tealBright,
    fontWeight: FontWeight.w600,
  ),
  em: AppTextStyles.sans(
    color: AppColors.textMarkdownEmphasis,
    fontStyle: FontStyle.italic,
  ),
  code: AppTextStyles.codeMono(
    backgroundColor: AppColors.surfaceMarkdownCode,
    color: AppColors.tealBright,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  ),
  codeblockDecoration: const BoxDecoration(color: Colors.transparent),
  codeblockPadding: EdgeInsets.zero,
  listBullet: AppTextStyles.sans(color: AppColors.tealBright, fontSize: 16),
  listIndent: 24,
  blockquote: AppTextStyles.sans(
    color: AppColors.textSecondary,
    fontSize: 14,
    fontStyle: FontStyle.italic,
  ),
  blockquoteDecoration: BoxDecoration(
    color: AppColors.surfaceBlockquote,
    border: const Border(left: BorderSide(color: AppColors.teal, width: 3)),
  ),
  blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  a: AppTextStyles.sans(
    color: AppColors.tealBright,
    decoration: TextDecoration.none,
    fontWeight: FontWeight.w500,
  ),
  tableHead: AppTextStyles.sans(
    color: AppColors.textOnDarkStrong,
    fontWeight: FontWeight.w600,
    fontSize: 13,
  ),
  tableBody: AppTextStyles.sans(
    color: AppColors.textMarkdownBody,
    fontSize: 13,
  ),
  tableBorder: TableBorder.all(
    color: AppColors.borderMarkdownTable,
    width: 1,
    borderRadius: BorderRadius.circular(8),
  ),
  tableCellsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
);
