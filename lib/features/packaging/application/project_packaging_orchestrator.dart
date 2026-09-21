import 'dart:convert';

import '../../projects/application/project_artifact_store.dart';
import '../../projects/application/project_materialization_service.dart';
import '../../projects/application/zip_packaging_service.dart' as projects;
import '../../projects/domain/project_artifact.dart';
import '../../workspace/application/workspace_store.dart';
import '../../workspace/domain/workspace_item.dart';

class ZipPackagingOrchestrator {
  ZipPackagingOrchestrator({
    WorkspaceStore? workspaceStore,
    ProjectArtifactStore? projectArtifactStore,
    ProjectMaterializationService? materializationService,
  })  : _workspaceStore = workspaceStore ?? WorkspaceStore(),
        _projectArtifactStore = projectArtifactStore ?? ProjectArtifactStore.system(),
        _materializationService =
            materializationService ?? ProjectMaterializationService(),
        _zipService = projects.ZipPackagingService();

  final WorkspaceStore _workspaceStore;
  final ProjectArtifactStore _projectArtifactStore;
  final ProjectMaterializationService _materializationService;
  final projects.ZipPackagingService _zipService;

  /// Packages a project artifact and its files as a ZIP archive.
  ///
  /// If the project files are not yet materialized on disk, this will first
  /// write them to the project directory, then create the ZIP bundle.
  ///
  /// Returns a [WorkspaceItem] of type [WorkspaceItemType.packagedArtifact]
  /// representing the created ZIP file.
  Future<WorkspaceItem> packageProjectAsZip({
    required ProjectArtifact project,
    required List<ProjectFileEntry> files,
    String? conversationId,
  }) async {
    final effectiveConversationId = conversationId ?? project.conversationId;

    // Materialize the project files to disk if they are not already there.
    await _materializationService.materializeProject(
      project: project,
      files: files,
    );

    // Create the ZIP archive.
    final result = await _zipService.packageProjectAsZip(
      projectDirectoryPath: project.rootPath,
      artifactId: project.id,
      suggestedFileName: project.title,
    );

    // Update the project artifact's rootPath to point to the zip file.
    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedArtifact = project.copyWith(
      rootPath: result.zipFilePath,
      updatedAtEpochMs: now,
      sizeBytes: result.sizeBytes,
      fileCount: result.fileCount,
      metadataJson: jsonEncode(
        <String, Object?>{
          ..._parseMetadata(project.metadataJson),
          'packagedAtEpochMs': now,
          'packageFileName': '${project.title}.zip',
          'packageFileCount': result.fileCount,
        },
      ),
    );
    await _projectArtifactStore.saveArtifact(updatedArtifact);

    // Create and persist the workspace item.
    final workspaceItem = WorkspaceItem(
      id: 'artifact_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: effectiveConversationId,
      type: WorkspaceItemType.packagedArtifact,
      title: '${project.title}.zip',
      createdAtEpochMs: now,
      updatedAtEpochMs: now,
      localPath: result.zipFilePath,
      mimeType: 'application/zip',
      extension: 'zip',
      sizeBytes: result.sizeBytes,
      metadataJson: jsonEncode(
        <String, Object?>{
          'artifactId': project.id,
          'packagedAtEpochMs': now,
          'originalFileCount': result.fileCount,
        },
      ),
    );
    await _workspaceStore.upsertItem(workspaceItem);

    return workspaceItem;
  }
  Map<String, Object?> _parseMetadata(String? metadataJson) {
    if (metadataJson == null || metadataJson.trim().isEmpty) {
      return <String, Object?>{};
    }
    try {
      final decoded = jsonDecode(metadataJson);
      if (decoded is Map) {
        return Map<String, Object?>.from(decoded);
      }
      return <String, Object?>{};
    } catch (_) {
      return <String, Object?>{};
    }
  }
}
