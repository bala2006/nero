import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../audit/application/audit_log_store.dart';
import '../../audit/domain/app_capability.dart';
import '../../audit/domain/audit_log_entry.dart';
import '../../workspace/application/workspace_store.dart';
import '../../workspace/domain/workspace_item.dart';
import '../../../platform/device/native_bridge_service.dart';
import '../domain/doc_models.dart';

class DocGenerationService {
  DocGenerationService({
    WorkspaceStore? workspaceStore,
    AuditLogStore? auditLogStore,
    NativeBridgeService? nativeBridgeService,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _workspaceStore = workspaceStore ?? WorkspaceStore(),
       _auditLogStore = auditLogStore ?? AuditLogStore(),
       _nativeBridgeService = nativeBridgeService ?? NativeBridgeService(),
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final WorkspaceStore _workspaceStore;
  final AuditLogStore _auditLogStore;
  final NativeBridgeService _nativeBridgeService;
  final Future<Directory> Function() _documentsDirectoryProvider;

  Future<WorkspaceItem> generateDocx({
    required DocRequest request,
    String? conversationId,
    String? messageId,
  }) async {
    final jobId = 'doc_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch;

    await _auditLogStore.record(
      capabilityKey: AppCapabilities.toolExecution.key,
      title: AppCapabilities.toolExecution.label,
      detail:
          'Starting DOCX generation for "${request.title}" with job $jobId.',
      status: AuditLogStatus.started,
      conversationId: conversationId,
    );

    try {
      final jobDir = await _createJobDirectory(jobId);
      final requestJson = request.toJson();
      final jobFile = File(
        '${jobDir.path}${Platform.pathSeparator}request.json',
      );
      await jobFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(requestJson),
        flush: true,
      );

      final nativeArtifacts = await _nativeBridgeService.executeToolRequest(
        jobId,
        'generate_docx',
        <String, dynamic>{'jobDir': jobDir.path, 'request': requestJson},
      );
      final nativeWorkspaceItem = _workspaceItemFromNativeArtifact(
        nativeArtifacts: nativeArtifacts,
        conversationId: conversationId ?? 'standalone',
        messageId: messageId,
        generatedAtEpochMs: now,
        fallbackTitle: request.title,
        request: request,
      );
      if (nativeWorkspaceItem != null) {
        await _workspaceStore.upsertItem(nativeWorkspaceItem);
        await _auditLogStore.record(
          capabilityKey: AppCapabilities.toolExecution.key,
          title: AppCapabilities.toolExecution.label,
          detail: 'Completed DOCX generation: ${nativeWorkspaceItem.title}.',
          status: AuditLogStatus.success,
          conversationId: conversationId,
        );
        return nativeWorkspaceItem;
      }
      throw StateError(
        'Native DOCX generation did not return a DOCX artifact. DOCX creation must be handled by the native POI pipeline.',
      );
    } catch (error) {
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.toolExecution.key,
        title: AppCapabilities.toolExecution.label,
        detail: 'Failed DOCX generation: $error',
        status: AuditLogStatus.failed,
        conversationId: conversationId,
      );
      rethrow;
    }
  }

  Future<Directory> _createJobDirectory(String jobId) async {
    final appDir = await _documentsDirectoryProvider();
    final jobDir = Directory(
      '${appDir.path}${Platform.pathSeparator}nero_tool_jobs${Platform.pathSeparator}$jobId',
    );
    if (!await jobDir.exists()) {
      await jobDir.create(recursive: true);
    }
    return jobDir;
  }

  WorkspaceItem? _workspaceItemFromNativeArtifact({
    required List<Map<String, dynamic>> nativeArtifacts,
    required String conversationId,
    required String? messageId,
    required int generatedAtEpochMs,
    required String fallbackTitle,
    required DocRequest request,
  }) {
    Map<String, dynamic>? artifact;
    for (final candidate in nativeArtifacts) {
      final localPath = candidate['localPath']?.toString() ?? '';
      final extension = candidate['extension']?.toString().toLowerCase();
      if (localPath.isNotEmpty && extension == 'docx') {
        artifact = candidate;
        break;
      }
    }
    if (artifact == null) {
      return null;
    }

    final localPath = artifact['localPath']?.toString();
    if (localPath == null || localPath.isEmpty) {
      return null;
    }
    final sizeBytes = _coerceInt(artifact['sizeBytes']);
    final title =
        artifact['title']?.toString().trim().isNotEmpty == true
            ? artifact['title']!.toString()
            : _withDocxExtension(_safeFileName(fallbackTitle));
    final metadata = <String, Object?>{
      'jobId': artifact['metadata'] is Map
          ? (artifact['metadata'] as Map)['jobId']
          : null,
      'messageId': messageId,
      'generatedAtEpochMs': generatedAtEpochMs,
      'cachedLocalPath': localPath,
      'nativeTool': 'generate_docx',
      'nativeArtifact': artifact,
      'previewMarkdown': _previewMarkdownFor(request: request, artifact: artifact),
    };

    return WorkspaceItem(
      id:
          artifact['id']?.toString().trim().isNotEmpty == true
              ? artifact['id']!.toString()
              : 'artifact_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversationId,
      type: WorkspaceItemType.generatedArtifact,
      title: title,
      createdAtEpochMs: generatedAtEpochMs,
      updatedAtEpochMs: generatedAtEpochMs,
      localPath: localPath,
      extension: 'docx',
      mimeType:
          artifact['mimeType']?.toString() ??
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      sizeBytes: sizeBytes,
      metadataJson: jsonEncode(metadata),
    );
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

  String? _previewMarkdownFor({
    required DocRequest? request,
    required Map<String, dynamic>? artifact,
  }) {
    if (artifact != null && artifact['metadata'] is Map) {
      final metadata = Map<String, dynamic>.from(artifact['metadata'] as Map);
      final preview = metadata['previewMarkdown']?.toString().trim();
      if (preview != null && preview.isNotEmpty) {
        return preview;
      }
    }
    if (request == null) {
      return null;
    }
    return _docRequestToMarkdown(request);
  }

  String _docRequestToMarkdown(DocRequest request) {
    final buffer = StringBuffer();
    for (final block in request.blocks) {
      switch (block) {
        case HeadingBlock():
          buffer
            ..writeln('${'#' * block.level.clamp(1, 6)} ${block.text}')
            ..writeln();
        case ParagraphBlock():
          buffer
            ..writeln(block.text)
            ..writeln();
        case BulletListBlock():
          for (final item in block.items) {
            buffer.writeln('- $item');
          }
          buffer.writeln();
        case NumberedListBlock():
          for (var index = 0; index < block.items.length; index++) {
            buffer.writeln('${index + 1}. ${block.items[index]}');
          }
          buffer.writeln();
        case TableBlock():
          if (block.rows.isNotEmpty) {
            final header = block.rows.first;
            buffer.writeln('| ${header.join(' | ')} |');
            buffer.writeln(
              '| ${List<String>.filled(header.length, '---').join(' | ')} |',
            );
            for (final row in block.rows.skip(1)) {
              buffer.writeln('| ${row.join(' | ')} |');
            }
            buffer.writeln();
          }
      }
    }
    return buffer.toString().trim();
  }

  String _safeFileName(String title) {
    final normalized = title
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return normalized.isEmpty ? 'nero_document' : normalized;
  }

  String _withDocxExtension(String fileName) {
    return fileName.toLowerCase().endsWith('.docx')
        ? fileName
        : '$fileName.docx';
  }
}
