import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class JsonFileStore {
  JsonFileStore._(this._rootDirectoryFuture);

  factory JsonFileStore.system({String rootFolderName = 'nero'}) {
    return JsonFileStore._(() async {
      final baseDirectory = await getApplicationSupportDirectory();
      final root = Directory(
        '${baseDirectory.path}${Platform.pathSeparator}$rootFolderName',
      );
      if (!await root.exists()) {
        await root.create(recursive: true);
      }
      return root;
    });
  }

  factory JsonFileStore.forDirectory(Directory directory) {
    return JsonFileStore._(() async {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    });
  }

  final Future<Directory> Function() _rootDirectoryFuture;

  Future<Map<String, dynamic>> readObject(
    String fileName, {
    Map<String, dynamic> fallback = const <String, dynamic>{},
  }) async {
    try {
      final file = await _resolveFile(fileName);
      if (!await file.exists()) {
        return Map<String, dynamic>.from(fallback);
      }

      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return Map<String, dynamic>.from(fallback);
  }

  Future<File> _resolveFile(String fileName) async {
    final root = await _rootDirectoryFuture();
    final file = File(
      '${root.path}${Platform.pathSeparator}$fileName',
    );
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    return file;
  }
}
