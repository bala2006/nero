import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/project_artifact.dart';

class ProjectMaterializationService {
  ProjectMaterializationService();

  Future<void> materializeProject({
    required ProjectArtifact project,
    required List<ProjectFileEntry> files,
  }) async {
    final rootPath = await _projectRootPath(project.id);
    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) {
      await rootDir.create(recursive: true);
    }

    for (final entry in files) {
      await _writeEntry(rootPath, entry);
    }

    final manifestFile = File(
      '$rootPath${Platform.pathSeparator}project_manifest.json',
    );
    await manifestFile.writeAsString(project.manifestJson, flush: true);
  }

  Future<bool> validateProject(Directory projectDir) async {
    if (!await projectDir.exists()) {
      return false;
    }

    final manifestFile = File(
      '${projectDir.path}${Platform.pathSeparator}project_manifest.json',
    );
    if (!await manifestFile.exists()) {
      return false;
    }

    try {
      final raw = await manifestFile.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> _projectRootPath(String artifactId) async {
    final directory = await getApplicationSupportDirectory();
    return '${directory.path}${Platform.pathSeparator}nero${Platform.pathSeparator}files${Platform.pathSeparator}workspace${Platform.pathSeparator}projects${Platform.pathSeparator}$artifactId';
  }

  Future<void> _writeEntry(String rootPath, ProjectFileEntry entry) async {
    if (entry.isDirectory) {
      final dirPath = '$rootPath${Platform.pathSeparator}${entry.path}';
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return;
    }

    final sanitized = _sanitizePath(entry.path);
    final filePath = '$rootPath${Platform.pathSeparator}$sanitized';
    final file = File(filePath);
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    final bytes = utf8.encode(entry.content);
    await file.writeAsBytes(bytes, flush: true);
  }

  String _sanitizePath(String path) {
    final normalized = path.replaceAll(RegExp(r'^[\\/]+'), '');
    return normalized.replaceAll(RegExp(r'[\\/]+'), Platform.pathSeparator);
  }
}
