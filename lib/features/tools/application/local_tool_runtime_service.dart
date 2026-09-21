import 'dart:async';
import 'dart:convert';

import '../../audit/application/audit_log_store.dart';
import '../../audit/domain/app_capability.dart';
import '../../audit/domain/audit_log_entry.dart';
import '../../packaging/application/project_packaging_orchestrator.dart';
import '../../projects/domain/project_artifact.dart';
import '../../workspace/application/workspace_store.dart';
import '../../workspace/domain/workspace_item.dart';
import '../domain/tool_runtime_models.dart';
import '../domain/tool_types.dart';
import '../../../platform/device/native_bridge_service.dart';

class LocalToolRuntimeService {
  LocalToolRuntimeService({
    required NativeBridgeService nativeBridgeService,
    WorkspaceStore? workspaceStore,
    AuditLogStore? auditLogStore,
    ZipPackagingOrchestrator? zipPackagingOrchestrator,
  })  : _nativeBridgeService = nativeBridgeService,
        _workspaceStore = workspaceStore ?? WorkspaceStore(),
        _auditLogStore = auditLogStore ?? AuditLogStore(),
        _zipPackagingOrchestrator =
            zipPackagingOrchestrator ?? ZipPackagingOrchestrator();

  final NativeBridgeService _nativeBridgeService;
  final WorkspaceStore _workspaceStore;
  final AuditLogStore _auditLogStore;
  final ZipPackagingOrchestrator _zipPackagingOrchestrator;

  final Map<String, Completer<ToolExecutionResult>> _pendingJobs =
      <String, Completer<ToolExecutionResult>>{};

  bool isToolAllowed(ToolType toolType) {
    return switch (toolType) {
      ToolType.generateDocx => true,
      ToolType.generateXlsx => true,
      ToolType.generateReportPdf => true,
      ToolType.materializeProjectTree => true,
      ToolType.writeProjectFiles => true,
      ToolType.packageZip => true,
      ToolType.validateProject => true,
      ToolType.openArtifact => true,
      ToolType.shareArtifact => true,
      ToolType.createTextFile => true,
      ToolType.editTextFile => true,
    };
  }

  Future<ToolExecutionResult> executeToolRequest({
    required ToolExecutionRequest request,
    void Function(RuntimeJobStatus)? onStatusChange,
  }) async {
    if (!isToolAllowed(request.toolType)) {
      return ToolExecutionResult(
        jobId: request.jobId,
        status: RuntimeJobStatus.failed,
        errorMessage: 'Tool type ${request.toolType.name} is not allowed',
      );
    }

    // Handle packageZip on the Dart side to avoid unnecessary native round-trips.
    if (request.toolType == ToolType.packageZip) {
      return _executePackageZip(request, onStatusChange);
    }

    final timeoutMs = request.timeoutMs ?? 120000;
    final timeoutTimer = Timer(Duration(milliseconds: timeoutMs), () {
      final completer = _pendingJobs.remove(request.jobId);
      if (completer != null && !completer.isCompleted) {
        completer.complete(
          ToolExecutionResult(
            jobId: request.jobId,
            status: RuntimeJobStatus.failed,
            errorMessage: 'Job timed out after ${timeoutMs}ms',
          ),
        );
      }
    });

    try {
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.toolExecution.key,
        title: AppCapabilities.toolExecution.label,
        detail: 'Starting tool ${request.toolType.name} with job ${request.jobId}',
        status: AuditLogStatus.started,
        conversationId: request.conversationId,
      );

      onStatusChange?.call(RuntimeJobStatus.running);

      final artifactsResult = await _nativeBridgeService.executeToolRequest(
        request.jobId,
        request.toolType.name,
        request.parameters,
      );

      final artifacts = artifactsResult
          .map(
            (a) => GeneratedArtifactDescriptor(
              id: a['id']?.toString() ?? 'artifact_${DateTime.now().microsecondsSinceEpoch}',
              title: a['title']?.toString() ?? 'Untitled',
              kindLabel: a['kindLabel']?.toString() ?? 'Artifact',
              localPath: a['localPath']?.toString() ?? '',
              extension: a['extension']?.toString(),
              mimeType: a['mimeType']?.toString(),
              sizeBytes: (a['sizeBytes'] as num?)?.toInt(),
              sourceUri: a['sourceUri']?.toString(),
              metadata:
                  a['metadata'] is Map ? Map<String, dynamic>.from(a['metadata']) : {},
            ),
          )
          .toList(growable: false);

      if (artifacts.isNotEmpty) {
        await _persistArtifacts(artifacts, request.conversationId);
      }

      final result = ToolExecutionResult(
        jobId: request.jobId,
        status: RuntimeJobStatus.completed,
        artifacts: artifacts,
        durationMs: DateTime.now().millisecondsSinceEpoch,
      );

      await _auditLogStore.record(
        capabilityKey: AppCapabilities.toolExecution.key,
        title: AppCapabilities.toolExecution.label,
        detail: 'Completed tool ${request.toolType.name} with ${artifacts.length} artifact(s)',
        status: AuditLogStatus.success,
        conversationId: request.conversationId,
      );

      onStatusChange?.call(RuntimeJobStatus.completed);
      return result;
    } catch (error) {
      final result = ToolExecutionResult(
        jobId: request.jobId,
        status: RuntimeJobStatus.failed,
        errorMessage: error.toString(),
      );

      await _auditLogStore.record(
        capabilityKey: AppCapabilities.toolExecution.key,
        title: AppCapabilities.toolExecution.label,
        detail: 'Failed tool ${request.toolType.name}: $error',
        status: AuditLogStatus.failed,
        conversationId: request.conversationId,
      );

      onStatusChange?.call(RuntimeJobStatus.failed);
      return result;
    } finally {
      timeoutTimer.cancel();
    }
  }

  Future<ToolExecutionResult> _executePackageZip(
    ToolExecutionRequest request,
    void Function(RuntimeJobStatus)? onStatusChange,
  ) async {
    final timeoutMs = request.timeoutMs ?? 120000;
    final timeoutTimer = Timer(Duration(milliseconds: timeoutMs), () {
      final completer = _pendingJobs.remove(request.jobId);
      if (completer != null && !completer.isCompleted) {
        completer.complete(
          ToolExecutionResult(
            jobId: request.jobId,
            status: RuntimeJobStatus.failed,
            errorMessage: 'Job timed out after ${timeoutMs}ms',
          ),
        );
      }
    });

    try {
      await _auditLogStore.record(
        capabilityKey: AppCapabilities.toolExecution.key,
        title: AppCapabilities.toolExecution.label,
        detail: 'Starting packageZip with job ${request.jobId}',
        status: AuditLogStatus.started,
        conversationId: request.conversationId,
      );

      onStatusChange?.call(RuntimeJobStatus.running);

      final parameters = request.parameters;
      final projectJson = parameters['project'];
      final filesRaw = parameters['files'];

      if (projectJson is! Map<String, dynamic>) {
        throw ArgumentError('Missing or invalid project parameter');
      }

      final project = ProjectArtifact.fromJson(projectJson);
      final files = (filesRaw as List?)
              ?.whereType<Map>()
              .map((f) => ProjectFileEntry.fromJson(Map<String, dynamic>.from(f)))
              .toList(growable: false) ??
          const <ProjectFileEntry>[];

      final workspaceItem = await _zipPackagingOrchestrator.packageProjectAsZip(
        project: project,
        files: files,
        conversationId: request.conversationId,
      );

      final artifact = GeneratedArtifactDescriptor(
        id: workspaceItem.id,
        title: workspaceItem.title,
        kindLabel: 'Packaged Project',
        localPath: workspaceItem.localPath ?? '',
        extension: workspaceItem.extension,
        mimeType: workspaceItem.mimeType,
        sizeBytes: workspaceItem.sizeBytes,
        metadata: _parseMetadata(workspaceItem.metadataJson),
      );

      final result = ToolExecutionResult(
        jobId: request.jobId,
        status: RuntimeJobStatus.completed,
        artifacts: [artifact],
        durationMs: DateTime.now().millisecondsSinceEpoch,
      );

      await _auditLogStore.record(
        capabilityKey: AppCapabilities.toolExecution.key,
        title: AppCapabilities.toolExecution.label,
        detail: 'Completed packageZip with 1 artifact(s)',
        status: AuditLogStatus.success,
        conversationId: request.conversationId,
      );

      onStatusChange?.call(RuntimeJobStatus.completed);
      return result;
    } catch (error) {
      final result = ToolExecutionResult(
        jobId: request.jobId,
        status: RuntimeJobStatus.failed,
        errorMessage: error.toString(),
      );

      await _auditLogStore.record(
        capabilityKey: AppCapabilities.toolExecution.key,
        title: AppCapabilities.toolExecution.label,
        detail: 'Failed packageZip: $error',
        status: AuditLogStatus.failed,
        conversationId: request.conversationId,
      );

      onStatusChange?.call(RuntimeJobStatus.failed);
      return result;
    } finally {
      timeoutTimer.cancel();
    }
  }

  Future<void> cancelJob(String jobId) async {
    final completer = _pendingJobs.remove(jobId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(
        ToolExecutionResult(
          jobId: jobId,
          status: RuntimeJobStatus.cancelled,
          errorMessage: 'Job was cancelled',
        ),
      );
    }
  }

  Future<void> _persistArtifacts(
    List<GeneratedArtifactDescriptor> artifacts,
    String? conversationId,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final items = artifacts
        .map(
          (a) => WorkspaceItem(
            id: a.id,
            conversationId: conversationId ?? 'standalone',
            type: WorkspaceItemType.generatedArtifact,
            title: a.title,
            createdAtEpochMs: now,
            updatedAtEpochMs: now,
            localPath: a.localPath,
            mimeType: a.mimeType,
            extension: a.extension,
            sizeBytes: a.sizeBytes,
            metadataJson: a.metadataJson,
          ),
        )
        .toList(growable: false);

    if (items.isEmpty) {
      return;
    }

    await _workspaceStore.insertItems(items);
  }

  Future<List<WorkspaceItem>> listArtifactsForJob(String jobId) async {
    return _workspaceStore.listRecent(limit: 100, conversationId: jobId);
  }

  Map<String, dynamic> _parseMetadata(String? metadataJson) {
    if (metadataJson == null || metadataJson.trim().isEmpty) {
      return const {};
    }
    try {
      final decoded = jsonDecode(metadataJson);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return const {};
    } catch (_) {
      return const {};
    }
  }
}
