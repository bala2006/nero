import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../../../platform/device/native_bridge_service.dart';
import '../domain/workspace_item.dart';

class FileIngestionResult {
  const FileIngestionResult({
    required this.items,
    required this.cancelled,
  });

  final List<WorkspaceItem> items;
  final bool cancelled;
}

class FileIngestionService {
  FileIngestionService({
    NativeBridgeService? nativeBridgeService,
  }) : _nativeBridgeService = nativeBridgeService ?? NativeBridgeService();

  final NativeBridgeService _nativeBridgeService;

  Future<FileIngestionResult> pickFiles({
    required String conversationId,
  }) async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      lockParentWindow: true,
      type: FileType.custom,
      allowedExtensions: const <String>[
        'pdf',
        'txt',
        'md',
        'csv',
        'json',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'png',
        'jpg',
        'jpeg',
        'webp',
        'heic',
      ],
    );

    if (picked == null || picked.files.isEmpty) {
      return const FileIngestionResult(items: <WorkspaceItem>[], cancelled: true);
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final items = picked.files.indexed.map((entry) {
      final index = entry.$1;
      final file = entry.$2;
      final itemId =
          'workspace_${now}_${index}_${file.name.hashCode}_${file.size}';
      return WorkspaceItem(
        id: itemId,
        conversationId: conversationId,
        type: WorkspaceItemType.importedFile,
        title: file.name,
        createdAtEpochMs: now,
        updatedAtEpochMs: now,
        sourceUri: file.identifier,
        localPath: file.path,
        extension: file.extension,
        sizeBytes: file.size <= 0 ? null : file.size,
        metadataJson: jsonEncode(<String, Object?>{
          'picker': 'file_picker',
          'name': file.name,
          'identifier': file.identifier,
          'path': file.path,
          'size': file.size,
          'extension': file.extension,
        }),
      );
    }).toList(growable: false);

    return FileIngestionResult(items: items, cancelled: false);
  }

  Future<FileIngestionResult> pickImages({
    required String conversationId,
  }) async {
    final imported = await _nativeBridgeService.pickImages();
    if (imported.isEmpty) {
      return const FileIngestionResult(items: <WorkspaceItem>[], cancelled: true);
    }
    return FileIngestionResult(
      items: workspaceItemsFromNativeItems(
        imported,
        conversationId: conversationId,
        source: 'photo_picker',
      ),
      cancelled: false,
    );
  }

  Future<FileIngestionResult> captureImage({
    required String conversationId,
  }) async {
    final imported = await _nativeBridgeService.captureImage();
    if (imported == null) {
      return const FileIngestionResult(items: <WorkspaceItem>[], cancelled: true);
    }
    return FileIngestionResult(
      items: workspaceItemsFromNativeItems(
        <NativeBridgeImportedItem>[imported],
        conversationId: conversationId,
        source: 'camera_capture',
      ),
      cancelled: false,
    );
  }

  List<WorkspaceItem> workspaceItemsFromNativeItems(
    List<NativeBridgeImportedItem> items, {
    required String conversationId,
    required String source,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return items.indexed.map((entry) {
      final index = entry.$1;
      final item = entry.$2;
      final itemId =
          'workspace_${source}_${now}_${index}_${item.title.hashCode}_${item.sizeBytes ?? 0}';
      return WorkspaceItem(
        id: itemId,
        conversationId: conversationId,
        type: WorkspaceItemType.importedFile,
        title: item.title,
        createdAtEpochMs: now,
        updatedAtEpochMs: now,
        sourceUri: item.sourceUri,
        localPath: item.localPath,
        mimeType: item.mimeType,
        extension: item.extension,
        sizeBytes: item.sizeBytes,
        metadataJson: jsonEncode(<String, Object?>{
          'picker': source,
          'sourceUri': item.sourceUri,
          'localPath': item.localPath,
          'mimeType': item.mimeType,
          'extension': item.extension,
          'sizeBytes': item.sizeBytes,
        }),
      );
    }).toList(growable: false);
  }
}
