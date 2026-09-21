import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Accent colour used for an attachment's file-type badge.
Color attachmentAccentForExtension(String? extension) {
  final normalized = extension?.toLowerCase();
  return switch (normalized) {
    'pdf' => AppColors.red,
    'doc' || 'docx' => const Color(0xFF1E88FF),
    'xls' || 'xlsx' || 'csv' => AppColors.amber,
    'ppt' || 'pptx' => const Color(0xFF8E8E8E),
    'txt' || 'md' || 'json' => const Color(0xFF8E8E8E),
    'zip' || 'apk' => const Color(0xFFB07A4A),
    'dart' || 'js' || 'ts' || 'py' => const Color(0xFF4AA3B0),
    'html' || 'css' => const Color(0xFFB0603A),
    _ => const Color(0xFF8E8E8E),
  };
}

/// Icon used for an attachment's file-type badge.
IconData attachmentIconForExtension(String? extension) {
  final normalized = extension?.toLowerCase();
  return switch (normalized) {
    'pdf' => Icons.picture_as_pdf_rounded,
    'doc' || 'docx' => Icons.description_rounded,
    'xls' || 'xlsx' || 'csv' => Icons.table_chart_rounded,
    'ppt' || 'pptx' => Icons.slideshow_rounded,
    'txt' || 'md' || 'json' => Icons.description_rounded,
    'zip' || 'apk' => Icons.folder_zip_rounded,
    'dart' || 'js' || 'ts' || 'py' => Icons.code_rounded,
    'html' || 'css' => Icons.web_rounded,
    _ => Icons.description_outlined,
  };
}

/// Human-readable type label for an attachment.
String attachmentTypeLabelForExtension(String? extension) {
  final normalized = extension?.toLowerCase();
  return switch (normalized) {
    'pdf' => 'PDF document',
    'doc' || 'docx' => 'Document',
    'xls' || 'xlsx' => 'Spreadsheet',
    'csv' => 'CSV document',
    'ppt' || 'pptx' => 'Presentation',
    'md' => 'Markdown document',
    'txt' => 'Text document',
    'json' => 'JSON document',
    'dart' => 'Dart source',
    'js' || 'ts' => 'JavaScript source',
    'html' => 'HTML page',
    'zip' || 'apk' => 'Archive',
    _ => 'File',
  };
}
