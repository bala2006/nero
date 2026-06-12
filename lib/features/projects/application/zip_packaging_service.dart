import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

class ZipPackagingResult {
  const ZipPackagingResult({
    required this.zipFilePath,
    required this.sizeBytes,
    required this.fileCount,
  });

  final String zipFilePath;
  final int sizeBytes;
  final int fileCount;
}

class ZipPackagingService {
  ZipPackagingService();

  Future<ZipPackagingResult> packageProjectAsZip({
    required String projectDirectoryPath,
    required String artifactId,
    String? suggestedFileName,
  }) async {
    final projectDir = Directory(projectDirectoryPath);
    if (!await projectDir.exists()) {
      throw StateError('Project directory does not exist: $projectDirectoryPath');
    }

    final packagesDir = await _packagesDirectory();
    final baseName = suggestedFileName ?? artifactId;
    final zipFileName = '${baseName.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')}.zip';
    final zipFilePath = '${packagesDir.path}${Platform.pathSeparator}$zipFileName';

    final archive = Archive();
    final collectedFiles = <String>[];

    await _collectFiles(projectDir, projectDir.path, archive, collectedFiles);

    final encoder = ZipEncoder();
    final zipData = encoder.encode(archive);

    final zipFile = File(zipFilePath);
    await zipFile.writeAsBytes(zipData, flush: true);

    return ZipPackagingResult(
      zipFilePath: zipFilePath,
      sizeBytes: zipData.length,
      fileCount: collectedFiles.length,
    );
  }

  Future<Directory> _packagesDirectory() async {
    final directory = await getApplicationSupportDirectory();
    final packagesDir = Directory(
      '${directory.path}${Platform.pathSeparator}nero${Platform.pathSeparator}files${Platform.pathSeparator}workspace${Platform.pathSeparator}packages',
    );
    if (!await packagesDir.exists()) {
      await packagesDir.create(recursive: true);
    }
    return packagesDir;
  }

  Future<void> _collectFiles(
    Directory dir,
    String basePath,
    Archive archive,
    List<String> collectedPaths,
  ) async {
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final relativePath = entity.path.substring(basePath.length + 1);
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(
          relativePath,
          bytes.length,
          bytes,
        ));
        collectedPaths.add(relativePath);
      }
    }
  }
}
