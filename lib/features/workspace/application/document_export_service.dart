import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../audit/application/audit_log_store.dart';
import '../../audit/domain/app_capability.dart';
import '../../audit/domain/audit_log_entry.dart';
import '../../chat/domain/chat_message.dart';
import '../../../platform/device/native_bridge_service.dart';
import '../domain/workspace_item.dart';
import 'workspace_store.dart';

enum ExportDocumentFormat {
  markdown,
  text,
  pdf,
  zip,
}

extension ExportDocumentFormatX on ExportDocumentFormat {
  String get label => switch (this) {
        ExportDocumentFormat.markdown => 'Markdown',
        ExportDocumentFormat.text => 'Text',
        ExportDocumentFormat.pdf => 'PDF',
        ExportDocumentFormat.zip => 'ZIP Archive',
      };

  String get extension => switch (this) {
        ExportDocumentFormat.markdown => 'md',
        ExportDocumentFormat.text => 'txt',
        ExportDocumentFormat.pdf => 'pdf',
        ExportDocumentFormat.zip => 'zip',
      };

  String get mimeType => switch (this) {
        ExportDocumentFormat.markdown => 'text/markdown',
        ExportDocumentFormat.text => 'text/plain',
        ExportDocumentFormat.pdf => 'application/pdf',
        ExportDocumentFormat.zip => 'application/zip',
      };
}

class ExportDocumentResult {
  const ExportDocumentResult({
    required this.workspaceItem,
    required this.fileName,
  });

  final WorkspaceItem workspaceItem;
  final String fileName;
}

class DocumentExportService {
  DocumentExportService({
    WorkspaceStore? workspaceStore,
    AuditLogStore? auditLogStore,
    NativeBridgeService? nativeBridgeService,
    Future<Directory> Function()? temporaryDirectoryProvider,
  })  : _workspaceStore = workspaceStore ?? WorkspaceStore(),
        _auditLogStore = auditLogStore ?? AuditLogStore(),
        _nativeBridgeService = nativeBridgeService ?? NativeBridgeService(),
        _temporaryDirectoryProvider =
            temporaryDirectoryProvider ?? getTemporaryDirectory;

  static const MethodChannel _channel = MethodChannel(
    'nero/document_export',
  );

  final WorkspaceStore _workspaceStore;
  final AuditLogStore _auditLogStore;
  final NativeBridgeService _nativeBridgeService;
  final Future<Directory> Function() _temporaryDirectoryProvider;

  Future<ExportDocumentResult?> exportAssistantMessage({
    required ChatMessage message,
    required String conversationId,
    required ExportDocumentFormat format,
  }) async {
    final trimmedContent = message.content.trim();
    if (trimmedContent.isEmpty) {
      return null;
    }

    return exportDocument(
      title: _displayTitleForMessage(message),
      conversationId: conversationId,
      format: format,
      markdownContent: toMarkdown(trimmedContent),
      plainTextContent: toPlainText(trimmedContent),
      metadata: <String, Object?>{
        'sourceMessageId': message.id,
      },
    );
  }

  Future<ExportDocumentResult?> shareAssistantMessage({
    required ChatMessage message,
    required String conversationId,
    required ExportDocumentFormat format,
  }) async {
    final trimmedContent = message.content.trim();
    if (trimmedContent.isEmpty) {
      return null;
    }
    return shareDocument(
      title: _displayTitleForMessage(message),
      conversationId: conversationId,
      format: format,
      markdownContent: toMarkdown(trimmedContent),
      plainTextContent: toPlainText(trimmedContent),
      metadata: <String, Object?>{
        'sourceMessageId': message.id,
      },
    );
  }

  Future<ExportDocumentResult?> exportDocument({
    required String title,
    required String conversationId,
    required ExportDocumentFormat format,
    required String markdownContent,
    String? plainTextContent,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) async {
    final suggestedName = _suggestedFileNameForTitle(title, format);
    final bytes = _buildDocumentBytes(
      format: format,
      title: title,
      markdownContent: markdownContent,
      plainTextContent: plainTextContent,
    );
    final tempFile = await _writeTempDocument(
      fileName: suggestedName,
      bytes: bytes,
    );

    await _auditLogStore.record(
      capabilityKey: AppCapabilities.workspaceExportFile.key,
      title: AppCapabilities.workspaceExportFile.label,
      detail: 'Opening save dialog for $suggestedName.',
      status: AuditLogStatus.started,
      conversationId: conversationId,
    );

    try {
      final uri = await _channel.invokeMethod<String>(
        'createDocument',
        <String, Object?>{
          'suggestedName': suggestedName,
          'mimeType': format.mimeType,
        },
      );
      if (uri == null || uri.trim().isEmpty) {
        await _deleteIfExists(tempFile);
        await _auditLogStore.record(
          capabilityKey: AppCapabilities.workspaceExportFile.key,
          title: AppCapabilities.workspaceExportFile.label,
          detail: 'User cancelled document export.',
          status: AuditLogStatus.success,
          conversationId: conversationId,
        );
        return null;
      }

      final writeResult = await _channel.invokeMethod<Map<Object?, Object?>>(
        'writeDocument',
        <String, Object?>{
          'uri': uri,
          'bytes': bytes,
        },
      );
      final fileSize = _coerceInt(writeResult?['sizeBytes']) ?? bytes.length;
      final now = DateTime.now().millisecondsSinceEpoch;
      final workspaceItem = WorkspaceItem(
        id: 'artifact_${DateTime.now().microsecondsSinceEpoch}',
        conversationId: conversationId,
        type: WorkspaceItemType.generatedArtifact,
        title: suggestedName,
        createdAtEpochMs: now,
        updatedAtEpochMs: now,
        sourceUri: uri,
        localPath: tempFile.path,
        mimeType: format.mimeType,
        extension: format.extension,
        sizeBytes: fileSize,
        metadataJson: jsonEncode(
          <String, Object?>{
            ...metadata,
            'format': format.name,
            'exportedAtEpochMs': now,
            'cachedLocalPath': tempFile.path,
          },
        ),
      );
      await _workspaceStore.upsertItem(workspaceItem);
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.workspaceExportFile.key,
        title: AppCapabilities.workspaceExportFile.label,
        detail: 'Saved $suggestedName.',
        status: AuditLogStatus.success,
        conversationId: conversationId,
      );
      return ExportDocumentResult(
        workspaceItem: workspaceItem,
        fileName: suggestedName,
      );
    } catch (error) {
      await _deleteIfExists(tempFile);
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.workspaceExportFile.key,
        title: AppCapabilities.workspaceExportFile.label,
        detail: error.toString(),
        status: AuditLogStatus.failed,
        conversationId: conversationId,
      );
      rethrow;
    }
  }

  Future<ExportDocumentResult?> shareDocument({
    required String title,
    required String conversationId,
    required ExportDocumentFormat format,
    required String markdownContent,
    String? plainTextContent,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) async {
    final suggestedName = _suggestedFileNameForTitle(title, format);
    File? tempFile;
    await _auditLogStore.record(
      capabilityKey: AppCapabilities.workspaceShareOut.key,
      title: AppCapabilities.workspaceShareOut.label,
      detail: 'Opening share sheet for $suggestedName.',
      status: AuditLogStatus.started,
      conversationId: conversationId,
    );

    try {
      final bytes = _buildDocumentBytes(
        format: format,
        title: title,
        markdownContent: markdownContent,
        plainTextContent: plainTextContent,
      );
      tempFile = await _writeTempDocument(
        fileName: suggestedName,
        bytes: bytes,
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      final workspaceItem = WorkspaceItem(
        id: 'artifact_${DateTime.now().microsecondsSinceEpoch}',
        conversationId: conversationId,
        type: WorkspaceItemType.generatedArtifact,
        title: suggestedName,
        createdAtEpochMs: now,
        updatedAtEpochMs: now,
        localPath: tempFile.path,
        mimeType: format.mimeType,
        extension: format.extension,
        sizeBytes: bytes.length,
        metadataJson: jsonEncode(
          <String, Object?>{
            ...metadata,
            'format': format.name,
            'sharedAtEpochMs': now,
            'cachedLocalPath': tempFile.path,
          },
        ),
      );
      await _workspaceStore.upsertItem(workspaceItem);
      await _nativeBridgeService.shareFiles(
        filePaths: <String>[tempFile.path],
        subject: title,
        mimeType: format.mimeType,
      );
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.workspaceShareOut.key,
        title: AppCapabilities.workspaceShareOut.label,
        detail: 'Shared $suggestedName.',
        status: AuditLogStatus.success,
        conversationId: conversationId,
      );
      return ExportDocumentResult(
        workspaceItem: workspaceItem,
        fileName: suggestedName,
      );
    } catch (error) {
      if (tempFile != null) {
        await _deleteIfExists(tempFile);
      }
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.workspaceShareOut.key,
        title: AppCapabilities.workspaceShareOut.label,
        detail: error.toString(),
        status: AuditLogStatus.failed,
        conversationId: conversationId,
      );
      rethrow;
    }
  }

  Future<ExportDocumentResult?> exportExistingWorkspaceItem({
    required WorkspaceItem item,
    required String conversationId,
  }) async {
    final localPath = item.localPath?.trim();
    if (localPath == null || localPath.isEmpty) {
      return null;
    }
    final sourceFile = File(localPath);
    if (!await sourceFile.exists()) {
      return null;
    }

    final bytes = await sourceFile.readAsBytes();
    final suggestedName = _withExtension(item.title, item.extension);
    await _auditLogStore.record(
      capabilityKey: AppCapabilities.workspaceExportFile.key,
      title: AppCapabilities.workspaceExportFile.label,
      detail: 'Opening save dialog for $suggestedName.',
      status: AuditLogStatus.started,
      conversationId: conversationId,
    );

    try {
      final uri = await _channel.invokeMethod<String>(
        'createDocument',
        <String, Object?>{
          'suggestedName': suggestedName,
          'mimeType': item.mimeType ?? 'application/octet-stream',
        },
      );
      if (uri == null || uri.trim().isEmpty) {
        await _auditLogStore.record(
          capabilityKey: AppCapabilities.workspaceExportFile.key,
          title: AppCapabilities.workspaceExportFile.label,
          detail: 'User cancelled document export.',
          status: AuditLogStatus.success,
          conversationId: conversationId,
        );
        return null;
      }
      await _channel.invokeMethod<Map<Object?, Object?>>(
        'writeDocument',
        <String, Object?>{
          'uri': uri,
          'bytes': bytes,
        },
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      final existingMetadata = _decodeMetadata(item.metadataJson);
      final exportedItem = item.copyWith(
        sourceUri: uri,
        updatedAtEpochMs: now,
        sizeBytes: bytes.length,
        metadataJson: jsonEncode(
          <String, Object?>{
            ...existingMetadata,
            'exportedAtEpochMs': now,
            'cachedLocalPath': sourceFile.path,
          },
        ),
      );
      await _workspaceStore.upsertItem(exportedItem);
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.workspaceExportFile.key,
        title: AppCapabilities.workspaceExportFile.label,
        detail: 'Saved $suggestedName.',
        status: AuditLogStatus.success,
        conversationId: conversationId,
      );
      return ExportDocumentResult(
        workspaceItem: exportedItem,
        fileName: suggestedName,
      );
    } catch (error) {
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.workspaceExportFile.key,
        title: AppCapabilities.workspaceExportFile.label,
        detail: error.toString(),
        status: AuditLogStatus.failed,
        conversationId: conversationId,
      );
      rethrow;
    }
  }

  String markdownForTest(String raw) => toMarkdown(raw);

  String plainTextForTest(String raw) => toPlainText(raw);

  String toMarkdown(String raw) => _toMarkdown(raw);

  String toPlainText(String raw) => _toPlainText(raw);

  String _suggestedFileNameForTitle(
    String title,
    ExportDocumentFormat format,
  ) {
    final base = title
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final normalizedBase = base.isEmpty ? 'nero_export' : base;
    return '$normalizedBase.${format.extension}';
  }

  String _displayTitleForMessage(ChatMessage message) {
    final normalized = _toPlainText(message.content)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) {
      return 'nero_export';
    }
    const maxLength = 36;
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return normalized.substring(0, maxLength).trimRight();
  }

  static final _codeBlockStartRegex = RegExp(
    r'^\s*\[\[NERO_BLOCK:CODE(?:\s+lang=([A-Za-z0-9_+\-#.]+))?\]\]\s*$',
  );
  static final _diagramBlockStartRegex = RegExp(
    r'^\s*\[\[NERO_BLOCK:DIAGRAM(?:\s+lang=([A-Za-z0-9_+\-#.]+))?\]\]\s*$',
  );
  static final _tableBlockStartRegex = RegExp(
    r'^\s*\[\[NERO_BLOCK:TABLE\]\]\s*$',
  );
  static final _neroBlockEndRegex = RegExp(
    r'^\s*\[\[/NERO_BLOCK\]\]\s*$',
  );
  static final _codeFenceRegex = RegExp(r'```[A-Za-z0-9_+\-#.]*');
  static final _markdownHeadingRegex = RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true);
  static final _bulletListRegex = RegExp(r'^\s*[-*]\s+', multiLine: true);
  static final _numberedListRegex = RegExp(r'^\s*\d+\.\s+', multiLine: true);

  String _toMarkdown(String raw) {
    final lines = raw.replaceAll('\r\n', '\n').split('\n');
    final buffer = StringBuffer();
    ExportDocumentFormat? activeBlock;
    String? activeLanguage;

    for (final line in lines) {
      final codeStart = _codeBlockStartRegex.firstMatch(line);
      if (codeStart != null) {
        activeBlock = ExportDocumentFormat.markdown;
        activeLanguage = codeStart.group(1)?.trim();
        buffer.writeln('```${activeLanguage ?? ''}'.trimRight());
        continue;
      }

      final diagramStart = _diagramBlockStartRegex.firstMatch(line);
      if (diagramStart != null) {
        activeBlock = ExportDocumentFormat.pdf;
        activeLanguage = diagramStart.group(1)?.trim() ?? 'mermaid';
        buffer.writeln('```$activeLanguage');
        continue;
      }

      if (_tableBlockStartRegex.hasMatch(line)) {
        activeBlock = ExportDocumentFormat.text;
        activeLanguage = null;
        continue;
      }

      if (_neroBlockEndRegex.hasMatch(line)) {
        if (activeBlock == ExportDocumentFormat.markdown ||
            activeBlock == ExportDocumentFormat.pdf) {
          buffer.writeln('```');
        }
        activeBlock = null;
        activeLanguage = null;
        continue;
      }

      buffer.writeln(line);
    }

    final normalized = buffer.toString().trim();
    return normalized.isEmpty ? raw.trim() : normalized;
  }

  String _toPlainText(String raw) {
    final markdown = _toMarkdown(raw);
    return markdown
        .replaceAll(_codeFenceRegex, '')
        .replaceAll('```', '')
        .replaceAllMapped(
          _markdownHeadingRegex,
          (_) => '',
        )
        .replaceAllMapped(
          _bulletListRegex,
          (_) => '- ',
        )
        .replaceAllMapped(
          _numberedListRegex,
          (match) => match.group(0) ?? '',
        )
        .trim();
  }

  Uint8List _buildPdfBytes({
    required String title,
    required String content,
  }) {
    final document = PdfDocument();
    try {
      final page = document.pages.add();
      final pageSize = page.getClientSize();
      final titleFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        16,
        style: PdfFontStyle.bold,
      );
      final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 11);

      page.graphics.drawString(
        title,
        titleFont,
        bounds: Rect.fromLTWH(0, 0, pageSize.width, 24),
      );
      PdfTextElement(
        text: content,
        font: bodyFont,
      ).draw(
        page: page,
        bounds: Rect.fromLTWH(0, 32, pageSize.width, pageSize.height - 32),
        format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
      );
      return Uint8List.fromList(document.saveSync());
    } finally {
      document.dispose();
    }
  }

  Uint8List _buildDocumentBytes({
    required ExportDocumentFormat format,
    required String title,
    required String markdownContent,
    String? plainTextContent,
  }) {
    final normalizedPlainText = plainTextContent?.trim().isNotEmpty == true
        ? plainTextContent!.trim()
        : toPlainText(markdownContent);
    return switch (format) {
      ExportDocumentFormat.markdown => Uint8List.fromList(
          utf8.encode(markdownContent.trim()),
        ),
      ExportDocumentFormat.text => Uint8List.fromList(
          utf8.encode(normalizedPlainText),
        ),
      ExportDocumentFormat.pdf => _buildPdfBytes(
          title: title,
          content: normalizedPlainText,
        ),
      ExportDocumentFormat.zip => _buildZipBytes(
          title: title,
          markdownContent: markdownContent,
          plainTextContent: normalizedPlainText,
        ),
    };
  }

  Uint8List _buildZipBytes({
    required String title,
    required String markdownContent,
    required String plainTextContent,
  }) {
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          '${_safeBaseFileName(title)}.md',
          utf8.encode(markdownContent.trim()).length,
          utf8.encode(markdownContent.trim()),
        ),
      )
      ..addFile(
        ArchiveFile(
          '${_safeBaseFileName(title)}.txt',
          utf8.encode(plainTextContent).length,
          utf8.encode(plainTextContent),
        ),
      );
    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  Future<File> _writeTempDocument({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final directory = await _temporaryDirectoryProvider();
    final exportDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}nero_exports',
    );
    if (!await exportDirectory.exists()) {
      await exportDirectory.create(recursive: true);
    }
    final file = File(
      '${exportDirectory.path}${Platform.pathSeparator}$fileName',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _safeBaseFileName(String title) {
    final normalized = title
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return normalized.isEmpty ? 'nero_export' : normalized;
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

  Map<String, Object?> _decodeMetadata(String? metadataJson) {
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

  String _withExtension(String fileName, String? extension) {
    final normalizedExtension = extension?.trim();
    if (normalizedExtension == null || normalizedExtension.isEmpty) {
      return fileName;
    }
    if (fileName.toLowerCase().endsWith('.${normalizedExtension.toLowerCase()}')) {
      return fileName;
    }
    return '$fileName.$normalizedExtension';
  }
}
