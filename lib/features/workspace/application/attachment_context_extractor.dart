import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

import '../domain/workspace_item.dart';

class AttachmentContextExtractor {
  const AttachmentContextExtractor();

  static const int _maxContextChars = 3200;
  static const int _cacheLimit = 24;
  static final LinkedHashMap<String, Future<String?>> _extractionCache =
      LinkedHashMap<String, Future<String?>>();

  Future<WorkspaceItem> enrichItem(WorkspaceItem item) async {
    final extractedText = await _extractText(item);
    final metadata = _decodeMetadata(item.metadataJson);
    if (extractedText != null && extractedText.trim().isNotEmpty) {
      metadata['extractedText'] = _clip(extractedText);
      metadata['extractedAtEpochMs'] = DateTime.now().millisecondsSinceEpoch;
    }
    return item.copyWith(
      metadataJson: jsonEncode(metadata),
      updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  String? extractCachedContext(WorkspaceItem item) {
    final metadata = _decodeMetadata(item.metadataJson);
    final text = metadata['extractedText']?.toString();
    if (text == null || text.trim().isEmpty) {
      return null;
    }
    return text.trim();
  }

  Future<String?> _extractText(WorkspaceItem item) async {
    final path = item.localPath?.trim();
    if (path == null || path.isEmpty) {
      return null;
    }
    final extension = item.extension?.toLowerCase();
    final cacheKey = await _cacheKeyFor(path, extension);
    final cached = _extractionCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final future = _extractTextForPath(path, extension);
    _extractionCache[cacheKey] = future;
    if (_extractionCache.length > _cacheLimit) {
      _extractionCache.remove(_extractionCache.keys.first);
    }
    return future;
  }

  Future<String?> _extractTextForPath(String path, String? extension) async {
    switch (extension) {
      case 'txt':
      case 'md':
      case 'csv':
      case 'json':
        return _readPlainText(path);
      case 'docx':
        return _readDocxText(path);
      case 'pdf':
        return _readPdfText(path);
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
      case 'heic':
        return _performImageOcr(path);
      default:
        return null;
    }
  }

  Future<String?> _readPlainText(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  Future<String?> _readPdfText(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    final document = PdfDocument(inputBytes: await file.readAsBytes());
    try {
      return PdfTextExtractor(document).extractText();
    } finally {
      document.dispose();
    }
  }

  Future<String?> _performImageOcr(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(path);
      final result = await recognizer.processImage(inputImage);
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  Future<String?> _readDocxText(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    final documentEntry = archive.findFile('word/document.xml');
    if (documentEntry == null) {
      return null;
    }
    final xmlContent = utf8.decode(documentEntry.content as List<int>);
    final document = XmlDocument.parse(xmlContent);
    final textBuffer = StringBuffer();
    for (final paragraph in document.findAllElements('w:p')) {
      final parts = paragraph
          .findAllElements('w:t')
          .map((node) => node.innerText)
          .where((text) => text.trim().isNotEmpty)
          .toList(growable: false);
      if (parts.isEmpty) {
        continue;
      }
      if (textBuffer.isNotEmpty) {
        textBuffer.writeln();
      }
      textBuffer.write(parts.join());
    }
    return textBuffer.toString();
  }

  Future<String> _cacheKeyFor(String path, String? extension) async {
    final file = File(path);
    if (!await file.exists()) {
      return 'missing|$path|$extension';
    }
    final stat = await file.stat();
    return [
      path,
      extension ?? '',
      stat.size.toString(),
      stat.modified.toUtc().microsecondsSinceEpoch.toString(),
    ].join('|');
  }

  Map<String, Object?> _decodeMetadata(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, Object?>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, Object?>.from(decoded);
      }
    } catch (_) {}
    return <String, Object?>{};
  }

  String _clip(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= _maxContextChars) {
      return normalized;
    }
    return '${normalized.substring(0, _maxContextChars).trimRight()}…';
  }
}
