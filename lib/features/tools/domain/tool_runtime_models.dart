import 'dart:convert';

import 'tool_types.dart';

enum RuntimeJobStatus {
  pending,
  running,
  completed,
  failed,
  cancelled,
}

extension RuntimeJobStatusX on RuntimeJobStatus {
  String get name => switch (this) {
        RuntimeJobStatus.pending => 'pending',
        RuntimeJobStatus.running => 'running',
        RuntimeJobStatus.completed => 'completed',
        RuntimeJobStatus.failed => 'failed',
        RuntimeJobStatus.cancelled => 'cancelled',
      };

  static RuntimeJobStatus? fromName(String name) {
    return switch (name) {
      'pending' => RuntimeJobStatus.pending,
      'running' => RuntimeJobStatus.running,
      'completed' => RuntimeJobStatus.completed,
      'failed' => RuntimeJobStatus.failed,
      'cancelled' => RuntimeJobStatus.cancelled,
      _ => null,
    };
  }
}

class ToolRuntimeProfile {
  const ToolRuntimeProfile({
    required this.version,
    required this.supportedTools,
    this.workingDirectory,
  });

  final String version;
  final List<ToolType> supportedTools;
  final String? workingDirectory;
}

class ToolExecutionRequest {
  const ToolExecutionRequest({
    required this.jobId,
    required this.toolType,
    required this.parameters,
    this.conversationId,
    this.messageId,
    this.timeoutMs,
  });

  final String jobId;
  final ToolType toolType;
  final Map<String, dynamic> parameters;
  final String? conversationId;
  final String? messageId;
  final int? timeoutMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'jobId': jobId,
        'toolType': toolType.name,
        'parameters': parameters,
        'conversationId': conversationId,
        'messageId': messageId,
        'timeoutMs': timeoutMs,
      };

  factory ToolExecutionRequest.fromJson(Map<String, dynamic> json) {
    final toolTypeName = json['toolType']?.toString();
    final toolType = ToolTypeX.fromName(toolTypeName ?? '');
    if (toolType == null) {
      throw ArgumentError('Unknown tool type: $toolTypeName');
    }
    return ToolExecutionRequest(
      jobId: json['jobId']?.toString() ?? '',
      toolType: toolType,
      parameters: json['parameters'] is Map
          ? Map<String, dynamic>.from(json['parameters'])
          : <String, dynamic>{},
      conversationId: json['conversationId']?.toString(),
      messageId: json['messageId']?.toString(),
      timeoutMs: (json['timeoutMs'] as num?)?.toInt(),
    );
  }
}

class ToolExecutionResult {
  const ToolExecutionResult({
    required this.jobId,
    required this.status,
    this.artifacts = const [],
    this.errorMessage,
    this.durationMs,
  });

  final String jobId;
  final RuntimeJobStatus status;
  final List<GeneratedArtifactDescriptor> artifacts;
  final String? errorMessage;
  final int? durationMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'jobId': jobId,
        'status': status.name,
        'artifacts': artifacts.map((a) => a.toJson()).toList(growable: false),
        'errorMessage': errorMessage,
        'durationMs': durationMs,
      };

  factory ToolExecutionResult.fromJson(Map<String, dynamic> json) {
    final statusName = json['status']?.toString();
    final status = RuntimeJobStatusX.fromName(statusName ?? '') ??
        RuntimeJobStatus.failed;
    final rawArtifacts = json['artifacts'];
    return ToolExecutionResult(
      jobId: json['jobId']?.toString() ?? '',
      status: status,
      artifacts: rawArtifacts is List
          ? rawArtifacts
              .whereType<Map>()
              .map((a) => GeneratedArtifactDescriptor.fromJson(
                    Map<String, dynamic>.from(a),
                  ))
              .toList(growable: false)
          : const [],
      errorMessage: json['errorMessage']?.toString(),
      durationMs: (json['durationMs'] as num?)?.toInt(),
    );
  }
}

class GeneratedArtifactDescriptor {
  const GeneratedArtifactDescriptor({
    required this.id,
    required this.title,
    required this.kindLabel,
    required this.localPath,
    this.extension,
    this.mimeType,
    this.sizeBytes,
    this.sourceUri,
    this.metadata = const {},
  });

  final String id;
  final String title;
  final String kindLabel;
  final String localPath;
  final String? extension;
  final String? mimeType;
  final int? sizeBytes;
  final String? sourceUri;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'kindLabel': kindLabel,
        'localPath': localPath,
        'extension': extension,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'sourceUri': sourceUri,
        'metadata': metadata,
      };

  factory GeneratedArtifactDescriptor.fromJson(Map<String, dynamic> json) {
    return GeneratedArtifactDescriptor(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      kindLabel: json['kindLabel']?.toString() ?? 'Artifact',
      localPath: json['localPath']?.toString() ?? '',
      extension: json['extension']?.toString(),
      mimeType: json['mimeType']?.toString(),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      sourceUri: json['sourceUri']?.toString(),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'])
          : const {},
    );
  }

  String get metadataJson => jsonEncode(metadata);
}
