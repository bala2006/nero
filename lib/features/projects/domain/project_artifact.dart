import 'dart:convert';

enum ProjectKind {
  app,
  web,
}

extension ProjectKindX on ProjectKind {
  String get name => switch (this) {
        ProjectKind.app => 'app',
        ProjectKind.web => 'web',
      };

  static ProjectKind? fromName(String? value) {
    return switch (value) {
      'app' => ProjectKind.app,
      'web' => ProjectKind.web,
      _ => null,
    };
  }
}

class ProjectFileEntry {
  const ProjectFileEntry({
    required this.path,
    required this.content,
    required this.isDirectory,
    this.sizeBytes,
    this.mimeType,
  });

  final String path;
  final String content;
  final bool isDirectory;
  final int? sizeBytes;
  final String? mimeType;

  int get computedSizeBytes => sizeBytes ?? utf8.encode(content).length;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'path': path,
        'content': content,
        'isDirectory': isDirectory,
        'sizeBytes': sizeBytes,
        'mimeType': mimeType,
      };

  factory ProjectFileEntry.fromJson(Map<String, dynamic> json) {
    return ProjectFileEntry(
      path: json['path']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      isDirectory: json['isDirectory'] == true,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      mimeType: json['mimeType']?.toString(),
    );
  }

  ProjectFileEntry copyWith({
    String? path,
    String? content,
    bool? isDirectory,
    int? sizeBytes,
    String? mimeType,
    bool clearSizeBytes = false,
    bool clearMimeType = false,
  }) {
    return ProjectFileEntry(
      path: path ?? this.path,
      content: content ?? this.content,
      isDirectory: isDirectory ?? this.isDirectory,
      sizeBytes: clearSizeBytes ? null : sizeBytes ?? this.sizeBytes,
      mimeType: clearMimeType ? null : mimeType ?? this.mimeType,
    );
  }
}

class ProjectRevision {
  const ProjectRevision({
    required this.revisionId,
    required this.createdAtEpochMs,
    required this.description,
    required this.changedFiles,
  });

  final String revisionId;
  final int createdAtEpochMs;
  final String description;
  final List<ProjectFileEntry> changedFiles;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'revisionId': revisionId,
        'createdAtEpochMs': createdAtEpochMs,
        'description': description,
        'changedFiles': changedFiles.map((f) => f.toJson()).toList(growable: false),
      };

  factory ProjectRevision.fromJson(Map<String, dynamic> json) {
    final rawChangedFiles = json['changedFiles'];
    return ProjectRevision(
      revisionId: json['revisionId']?.toString() ?? '',
      createdAtEpochMs: (json['createdAtEpochMs'] as num?)?.toInt() ?? 0,
      description: json['description']?.toString() ?? '',
      changedFiles: rawChangedFiles is List
          ? rawChangedFiles
              .whereType<Map>()
              .map((f) => ProjectFileEntry.fromJson(
                    Map<String, dynamic>.from(f),
                  ))
              .toList(growable: false)
          : const <ProjectFileEntry>[],
    );
  }

  ProjectRevision copyWith({
    String? revisionId,
    int? createdAtEpochMs,
    String? description,
    List<ProjectFileEntry>? changedFiles,
  }) {
    return ProjectRevision(
      revisionId: revisionId ?? this.revisionId,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      description: description ?? this.description,
      changedFiles: changedFiles ?? this.changedFiles,
    );
  }
}

class ProjectArtifact {
  const ProjectArtifact({
    required this.id,
    required this.conversationId,
    required this.title,
    required this.description,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    required this.rootPath,
    required this.manifestJson,
    required this.fileCount,
    required this.sizeBytes,
    required this.tags,
    required this.metadataJson,
  });

  final String id;
  final String conversationId;
  final String title;
  final String description;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  final String rootPath;
  final String manifestJson;
  final int fileCount;
  final int sizeBytes;
  final List<String> tags;
  final String metadataJson;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'conversationId': conversationId,
        'title': title,
        'description': description,
        'createdAtEpochMs': createdAtEpochMs,
        'updatedAtEpochMs': updatedAtEpochMs,
        'rootPath': rootPath,
        'manifestJson': manifestJson,
        'fileCount': fileCount,
        'sizeBytes': sizeBytes,
        'tags': tags,
        'metadataJson': metadataJson,
      };

  factory ProjectArtifact.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    return ProjectArtifact(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdAtEpochMs: (json['createdAtEpochMs'] as num?)?.toInt() ?? 0,
      updatedAtEpochMs: (json['updatedAtEpochMs'] as num?)?.toInt() ?? 0,
      rootPath: json['rootPath']?.toString() ?? '',
      manifestJson: json['manifestJson']?.toString() ?? '{}',
      fileCount: (json['fileCount'] as num?)?.toInt() ?? 0,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      tags: rawTags is List ? rawTags.map((t) => t.toString()).toList(growable: false) : const <String>[],
      metadataJson: json['metadataJson']?.toString() ?? '{}',
    );
  }

  ProjectArtifact copyWith({
    String? id,
    String? conversationId,
    String? title,
    String? description,
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
    String? rootPath,
    String? manifestJson,
    int? fileCount,
    int? sizeBytes,
    List<String>? tags,
    String? metadataJson,
  }) {
    return ProjectArtifact(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      rootPath: rootPath ?? this.rootPath,
      manifestJson: manifestJson ?? this.manifestJson,
      fileCount: fileCount ?? this.fileCount,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      tags: tags ?? this.tags,
      metadataJson: metadataJson ?? this.metadataJson,
    );
  }
}
