import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class NativeBridgeImportedItem {
  const NativeBridgeImportedItem({
    required this.title,
    this.sourceUri,
    this.localPath,
    this.mimeType,
    this.extension,
    this.sizeBytes,
  });

  final String title;
  final String? sourceUri;
  final String? localPath;
  final String? mimeType;
  final String? extension;
  final int? sizeBytes;

  factory NativeBridgeImportedItem.fromMap(Map<Object?, Object?> map) {
    return NativeBridgeImportedItem(
      title: map['title']?.toString() ?? 'Untitled',
      sourceUri: map['sourceUri']?.toString(),
      localPath: map['localPath']?.toString(),
      mimeType: map['mimeType']?.toString(),
      extension: map['extension']?.toString(),
      sizeBytes: _coerceInt(map['sizeBytes']),
    );
  }

  static int? _coerceInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }
}

class SharedContentPayload {
  const SharedContentPayload({
    required this.files,
    this.text,
  });

  final String? text;
  final List<NativeBridgeImportedItem> files;
  List<NativeBridgeImportedItem> get items => files;

  bool get isEmpty => (text == null || text!.trim().isEmpty) && files.isEmpty;

  factory SharedContentPayload.fromMap(Map<Object?, Object?> map) {
    final rawItems = map['files'] ?? map['items'];
    return SharedContentPayload(
      text: map['text']?.toString(),
      files: rawItems is List
          ? rawItems
              .whereType<Map<Object?, Object?>>()
              .map(NativeBridgeImportedItem.fromMap)
              .toList(growable: false)
          : const <NativeBridgeImportedItem>[],
    );
  }
}

class NativeBridgeService {
  NativeBridgeService();

  static const MethodChannel _channel = MethodChannel('nero/device_bridge');
  static final StreamController<SharedContentPayload> _sharedPayloads =
      StreamController<SharedContentPayload>.broadcast();
  static bool _initialized = false;

  Stream<SharedContentPayload> get sharedPayloads => _sharedPayloads.stream;

  void initialize() {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'sharedPayloadReceived') {
        return null;
      }
      final arguments = call.arguments;
      if (arguments is Map) {
        final payload = SharedContentPayload.fromMap(
          Map<Object?, Object?>.from(arguments),
        );
        if (!payload.isEmpty && !_sharedPayloads.isClosed) {
          _sharedPayloads.add(payload);
        }
      }
      return null;
    });
  }

  Future<List<NativeBridgeImportedItem>> pickImages() async {
    if (!Platform.isAndroid) {
      return const <NativeBridgeImportedItem>[];
    }
    final result = await _channel.invokeMethod<List<Object?>>('pickImages');
    if (result == null) {
      return const <NativeBridgeImportedItem>[];
    }
    return result
        .whereType<Map<Object?, Object?>>()
        .map(NativeBridgeImportedItem.fromMap)
        .toList(growable: false);
  }

  Future<NativeBridgeImportedItem?> captureImage() async {
    if (!Platform.isAndroid) {
      return null;
    }
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'captureImage',
    );
    if (result == null) {
      return null;
    }
    return NativeBridgeImportedItem.fromMap(result);
  }

  Future<void> shareText({
    required String text,
    String? subject,
  }) async {
    if (!Platform.isAndroid || text.trim().isEmpty) {
      return;
    }
    await _channel.invokeMethod<void>(
      'shareText',
      <String, Object?>{
        'text': text,
        'subject': subject,
      },
    );
  }

  Future<void> shareFiles({
    required List<String> filePaths,
    List<String> sourceUris = const <String>[],
    String? text,
    String? subject,
    String? mimeType,
  }) async {
    if (!Platform.isAndroid || (filePaths.isEmpty && sourceUris.isEmpty)) {
      return;
    }
    await _channel.invokeMethod<void>(
      'shareFiles',
      <String, Object?>{
        'paths': filePaths,
        'uris': sourceUris,
        'text': text,
        'subject': subject,
        'mimeType': mimeType,
      },
    );
  }

  Future<void> openFile({
    String? sourceUri,
    String? localPath,
    String? mimeType,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>(
      'openFile',
      <String, Object?>{
        'sourceUri': sourceUri,
        'localPath': localPath,
        'mimeType': mimeType,
      },
    );
  }

  Future<void> releasePersistedUriPermission(String uri) async {
    if (!Platform.isAndroid || uri.trim().isEmpty) {
      return;
    }
    await _channel.invokeMethod<void>(
      'releasePersistedUriPermission',
      <String, Object?>{
        'uri': uri,
      },
    );
  }

  Future<SharedContentPayload?> consumeSharedContent() async {
    if (!Platform.isAndroid) {
      return null;
    }
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'consumePendingSharedPayload',
    );
    if (result == null) {
      return null;
    }
    final payload = SharedContentPayload.fromMap(result);
    return payload.isEmpty ? null : payload;
  }

  Future<List<Map<String, dynamic>>> executeToolRequest(
    String jobId,
    String toolTypeName,
    Map<String, dynamic> parameters,
  ) async {
    if (!Platform.isAndroid) {
      return const [];
    }
    final result = await _channel.invokeMethod<List<Object?>>(
      'executeToolRequest',
      <String, Object?>{
        'jobId': jobId,
        'toolType': toolTypeName,
        'parameters': parameters,
      },
    );
    if (result == null) {
      return const [];
    }
    return result
        .whereType<Map<Object?, Object?>>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }
}
