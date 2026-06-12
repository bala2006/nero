import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../audit/application/audit_log_store.dart';
import '../../audit/domain/app_capability.dart';
import '../../audit/domain/audit_log_entry.dart';
import '../../../platform/device/native_bridge_service.dart';
import '../domain/workspace_item.dart';
import 'workspace_store.dart';

class WorkspaceController extends ChangeNotifier {
  WorkspaceController({
    WorkspaceStore? workspaceStore,
    AuditLogStore? auditLogStore,
    NativeBridgeService? nativeBridgeService,
  })  : _workspaceStore = workspaceStore ?? WorkspaceStore(),
        _auditLogStore = auditLogStore ?? AuditLogStore(),
        _nativeBridgeService = nativeBridgeService ?? NativeBridgeService();

  final WorkspaceStore _workspaceStore;
  final AuditLogStore _auditLogStore;
  final NativeBridgeService _nativeBridgeService;

  bool _isLoading = false;
  String? _error;
  List<WorkspaceItem> _items = const <WorkspaceItem>[];
  String? _conversationId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<WorkspaceItem> get items => List<WorkspaceItem>.unmodifiable(_items);

  Future<void> load({
    String? conversationId,
  }) async {
    _isLoading = true;
    _error = null;
    _conversationId = conversationId;
    notifyListeners();
    try {
      _items = await _workspaceStore.listRecent(conversationId: conversationId);
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteItem(WorkspaceItem item) async {
    await _auditLogStore.record(
      capabilityKey: AppCapabilities.workspaceDeleteItem.key,
      title: AppCapabilities.workspaceDeleteItem.label,
      detail: 'Deleting ${item.title}.',
      status: AuditLogStatus.started,
      conversationId: item.conversationId,
    );
    try {
      await _workspaceStore.deleteItem(item.id);
      final localPath = item.localPath?.trim();
      if (localPath != null && localPath.isNotEmpty) {
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _items = _items.where((entry) => entry.id != item.id).toList(growable: false);
      notifyListeners();
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.workspaceDeleteItem.key,
        title: AppCapabilities.workspaceDeleteItem.label,
        detail: 'Deleted ${item.title}.',
        status: AuditLogStatus.success,
        conversationId: item.conversationId,
      );
    } catch (error) {
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.workspaceDeleteItem.key,
        title: AppCapabilities.workspaceDeleteItem.label,
        detail: error.toString(),
        status: AuditLogStatus.failed,
        conversationId: item.conversationId,
      );
      rethrow;
    }
  }

  Future<void> shareItem(WorkspaceItem item) async {
    final localPath = item.localPath?.trim();
    final sourceUri = item.sourceUri?.trim();
    if ((localPath == null || localPath.isEmpty) &&
        (sourceUri == null || sourceUri.isEmpty)) {
      return;
    }
    await _auditLogStore.record(
      capabilityKey: AppCapabilities.workspaceShareOut.key,
      title: AppCapabilities.workspaceShareOut.label,
      detail: 'Opening share sheet for ${item.title}.',
      status: AuditLogStatus.started,
      conversationId: item.conversationId,
    );
    try {
      await _nativeBridgeService.shareFiles(
        filePaths: localPath == null || localPath.isEmpty
            ? const <String>[]
            : <String>[localPath],
        sourceUris: sourceUri == null || sourceUri.isEmpty
            ? const <String>[]
            : <String>[sourceUri],
        subject: item.title,
        mimeType: item.mimeType,
      );
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.workspaceShareOut.key,
        title: AppCapabilities.workspaceShareOut.label,
        detail: 'Shared ${item.title}.',
        status: AuditLogStatus.success,
        conversationId: item.conversationId,
      );
    } catch (error) {
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.workspaceShareOut.key,
        title: AppCapabilities.workspaceShareOut.label,
        detail: error.toString(),
        status: AuditLogStatus.failed,
        conversationId: item.conversationId,
      );
      rethrow;
    }
  }

  Future<void> openItem(WorkspaceItem item) {
    return _nativeBridgeService.openFile(
      sourceUri: item.sourceUri,
      localPath: item.localPath,
      mimeType: item.mimeType,
    );
  }

  Future<void> refresh() => load(conversationId: _conversationId);
}
