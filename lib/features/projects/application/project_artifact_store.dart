import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/project_artifact.dart';

class ProjectArtifactStore {
  ProjectArtifactStore._(this._rootDirectoryFuture);

  factory ProjectArtifactStore.system() {
    return ProjectArtifactStore._(() async {
      final baseDirectory = await getApplicationSupportDirectory();
      final root = Directory(
        '${baseDirectory.path}${Platform.pathSeparator}nero${Platform.pathSeparator}projects',
      );
      if (!await root.exists()) {
        await root.create(recursive: true);
      }
      return root;
    });
  }

  static const String _artifactsFileName = 'artifacts.json';
  static const String _revisionsFileName = 'revisions.json';

  final Future<Directory> Function() _rootDirectoryFuture;

  Future<Map<String, dynamic>> readObject(
    String fileName, {
    Map<String, dynamic> fallback = const <String, dynamic>{},
  }) async {
    final file = await _resolveFile(fileName);
    if (!await file.exists()) {
      return Map<String, dynamic>.from(fallback);
    }
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return Map<String, dynamic>.from(fallback);
  }

  Future<void> writeObject(String fileName, Map<String, dynamic> data) async {
    final file = await _resolveFile(fileName);
    await file.writeAsString(jsonEncode(data), flush: true);
  }

  Future<File> _resolveFile(String fileName) async {
    final root = await _rootDirectoryFuture();
    final file = File('${root.path}${Platform.pathSeparator}$fileName');
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    return file;
  }

  Future<List<ProjectArtifact>> listArtifacts() async {
    final data = await readObject(_artifactsFileName);
    final rawList = data['items'];
    if (rawList is! List) {
      return const [];
    }
    return rawList
        .whereType<Map>()
        .map((raw) => ProjectArtifact.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<List<ProjectArtifact>> findByConversationId(String conversationId) async {
    final artifacts = await listArtifacts();
    return artifacts
        .where((a) => a.conversationId == conversationId)
        .toList(growable: false);
  }

  Future<ProjectArtifact?> getArtifact(String artifactId) async {
    final artifacts = await listArtifacts();
    for (final artifact in artifacts) {
      if (artifact.id == artifactId) {
        return artifact;
      }
    }
    return null;
  }

  Future<void> saveArtifact(ProjectArtifact artifact) async {
    final artifacts = await listArtifacts();
    final index = artifacts.indexWhere((a) => a.id == artifact.id);
    if (index >= 0) {
      artifacts[index] = artifact;
    } else {
      artifacts.add(artifact);
    }
    await _writeArtifacts(artifacts);
  }

  Future<void> deleteArtifact(String artifactId) async {
    final artifacts = await listArtifacts();
    artifacts.removeWhere((a) => a.id == artifactId);
    await _writeArtifacts(artifacts);

    final revisions = await listRevisions();
    revisions.removeWhere((r) => r.revisionId.startsWith(artifactId));
    await _writeRevisions(revisions);
  }

  Future<List<ProjectRevision>> listRevisions() async {
    final data = await readObject(_revisionsFileName);
    final rawList = data['items'];
    if (rawList is! List) {
      return const [];
    }
    return rawList
        .whereType<Map>()
        .map((raw) => ProjectRevision.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<List<ProjectRevision>> findRevisionsByArtifactId(String artifactId) async {
    final revisions = await listRevisions();
    return revisions
        .where((r) => r.revisionId.contains(artifactId))
        .toList(growable: false)
      ..sort((a, b) => a.createdAtEpochMs.compareTo(b.createdAtEpochMs));
  }

  Future<ProjectRevision?> getRevision(String revisionId) async {
    final revisions = await listRevisions();
    for (final revision in revisions) {
      if (revision.revisionId == revisionId) {
        return revision;
      }
    }
    return null;
  }

  Future<void> saveRevision(ProjectRevision revision) async {
    final revisions = await listRevisions();
    final index = revisions.indexWhere((r) => r.revisionId == revision.revisionId);
    if (index >= 0) {
      revisions[index] = revision;
    } else {
      revisions.add(revision);
    }
    await _writeRevisions(revisions);
  }

  Future<void> deleteRevision(String revisionId) async {
    final revisions = await listRevisions();
    revisions.removeWhere((r) => r.revisionId == revisionId);
    await _writeRevisions(revisions);
  }

  Future<void> _writeArtifacts(List<ProjectArtifact> artifacts) async {
    await writeObject(_artifactsFileName, <String, dynamic>{
      'items': artifacts.map((a) => a.toJson()).toList(growable: false),
    });
  }

  Future<void> _writeRevisions(List<ProjectRevision> revisions) async {
    await writeObject(_revisionsFileName, <String, dynamic>{
      'items': revisions.map((r) => r.toJson()).toList(growable: false),
    });
  }
}
