import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class DiagramArtifactRecord {
  const DiagramArtifactRecord({
    required this.id,
    required this.imagePath,
    required this.sourcePath,
  });

  final String id;
  final String imagePath;
  final String sourcePath;
}

class DiagramArtifactStore {
  const DiagramArtifactStore();

  static final Future<Directory> _directoryFuture = _createDirectory();

  Future<DiagramArtifactRecord?> load(String mermaidSource) async {
    final normalized = mermaidSource.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final directory = await _ensureDirectory();
    final id = _diagramId(normalized);
    final imageFile = File('${directory.path}${Platform.pathSeparator}$id.png');
    final sourceFile = File('${directory.path}${Platform.pathSeparator}$id.mmd');
    if (!await imageFile.exists() || !await sourceFile.exists()) {
      return null;
    }
    return DiagramArtifactRecord(
      id: id,
      imagePath: imageFile.path,
      sourcePath: sourceFile.path,
    );
  }

  Future<DiagramArtifactRecord> save({
    required String mermaidSource,
    required List<int> pngBytes,
  }) async {
    final normalizedSource = mermaidSource.trim();
    final directory = await _ensureDirectory();
    final id = _diagramId(normalizedSource);
    final imageFile = File('${directory.path}${Platform.pathSeparator}$id.png');
    final sourceFile = File('${directory.path}${Platform.pathSeparator}$id.mmd');
    await sourceFile.writeAsString(normalizedSource, flush: true);
    await imageFile.writeAsBytes(pngBytes, flush: true);
    return DiagramArtifactRecord(
      id: id,
      imagePath: imageFile.path,
      sourcePath: sourceFile.path,
    );
  }

  Future<Directory> _ensureDirectory() async {
    return _directoryFuture;
  }

  static Future<Directory> _createDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}${Platform.pathSeparator}diagram_artifacts',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _diagramId(String source) {
    return sha1.convert(utf8.encode(source)).toString();
  }
}
