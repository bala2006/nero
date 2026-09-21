import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../chat/domain/chat_message.dart';

/// Persists binary content returned by an MCP tool into the workspace.
///
/// The model never sees base64 blobs — they are stripped from the tool output
/// and replaced with an artifact reference, which keeps the prompt small and
/// lets the user actually open the image or file the server produced.
class McpArtifactWriter {
  McpArtifactWriter({Future<Directory> Function()? rootDirectoryProvider})
    : _rootDirectoryProvider = rootDirectoryProvider ?? _defaultRoot;

  final Future<Directory> Function() _rootDirectoryProvider;

  static Future<Directory> _defaultRoot() async {
    final support = await getApplicationSupportDirectory();
    return Directory(
      '${support.path}${Platform.pathSeparator}nero'
      '${Platform.pathSeparator}files'
      '${Platform.pathSeparator}workspace'
      '${Platform.pathSeparator}mcp',
    );
  }

  /// Decodes [base64Data] and writes it under `<workspace>/mcp/<serverId>/`.
  ///
  /// Returns null when the payload cannot be decoded, so a malformed response
  /// degrades to "no artifact" rather than failing the whole tool call.
  Future<GeneratedArtifactReference?> writeBase64({
    required String serverId,
    required String toolName,
    required String base64Data,
    String? mimeType,
    String? suggestedName,
  }) async {
    try {
      final bytes = base64Decode(base64Data.trim());
      final extension = _extensionFor(mimeType, suggestedName);
      final safeTool = _slug(toolName);
      final directory = Directory(
        '${(await _rootDirectoryProvider()).path}'
        '${Platform.pathSeparator}${_slug(serverId)}',
      );
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final fileName =
          '${safeTool}_${DateTime.now().millisecondsSinceEpoch}$extension';
      final file = File('${directory.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);
      return GeneratedArtifactReference(
        id: 'mcp_${_slug(serverId)}_${DateTime.now().microsecondsSinceEpoch}',
        title: suggestedName?.trim().isNotEmpty == true
            ? suggestedName!.trim()
            : fileName,
        kindLabel: _kindLabelFor(mimeType),
        extension: extension.replaceFirst('.', ''),
        mimeType: mimeType,
        localPath: file.path,
        sizeBytes: bytes.length,
      );
    } catch (_) {
      return null;
    }
  }

  /// A `resource_link`/`resource` item that Nero does not download: the URL is
  /// all we have, so it becomes a link-only artifact.
  GeneratedArtifactReference linkArtifact({
    required String serverId,
    required String uri,
    String? name,
    String? mimeType,
  }) {
    return GeneratedArtifactReference(
      id: 'mcp_link_${_slug(serverId)}_${DateTime.now().microsecondsSinceEpoch}',
      title: (name != null && name.trim().isNotEmpty) ? name.trim() : uri,
      kindLabel: _kindLabelFor(mimeType),
      mimeType: mimeType,
      sourceUri: uri,
    );
  }

  String _extensionFor(String? mimeType, String? suggestedName) {
    final fromName = _extensionFromName(suggestedName);
    if (fromName != null) {
      return fromName;
    }
    return switch (mimeType) {
      'image/png' => '.png',
      'image/jpeg' || 'image/jpg' => '.jpg',
      'image/gif' => '.gif',
      'image/webp' => '.webp',
      'image/svg+xml' => '.svg',
      'application/pdf' => '.pdf',
      'application/json' => '.json',
      'text/csv' => '.csv',
      'text/plain' => '.txt',
      'text/markdown' => '.md',
      'application/zip' => '.zip',
      _ => '.bin',
    };
  }

  String? _extensionFromName(String? name) {
    if (name == null) {
      return null;
    }
    final index = name.lastIndexOf('.');
    if (index <= 0 || index == name.length - 1) {
      return null;
    }
    final extension = name.substring(index).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(extension) ? extension : null;
  }

  String _kindLabelFor(String? mimeType) {
    if (mimeType == null || mimeType.isEmpty) {
      return 'Resource';
    }
    if (mimeType.startsWith('image/')) {
      return 'Image';
    }
    if (mimeType == 'application/pdf') {
      return 'PDF';
    }
    if (mimeType.startsWith('text/')) {
      return 'Text';
    }
    return 'File';
  }

  String _slug(String value) {
    final slug = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return slug.isEmpty ? 'mcp' : slug;
  }
}
