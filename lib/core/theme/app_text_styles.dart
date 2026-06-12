import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  static const List<String> _sansFallback = <String>[
    'Inter',
    'Segoe UI',
    'Roboto',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  static const List<String> _displayFallback = <String>[
    'Outfit',
    'Aptos Display',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  static const List<String> _monoFallback = <String>[
    'JetBrains Mono',
    'Cascadia Code',
    'Consolas',
    'Courier New',
    'monospace',
  ];

  static const List<String> _editorFallback = <String>[
    'Space Mono',
    'JetBrains Mono',
    'Cascadia Code',
    'Consolas',
    'monospace',
  ];

  static TextStyle sans({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    FontStyle? fontStyle,
    double? letterSpacing,
    TextDecoration? decoration,
    Color? backgroundColor,
  }) {
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      decoration: decoration,
      backgroundColor: backgroundColor,
      fontFamilyFallback: _sansFallback,
    );
  }

  static TextStyle displayMono({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      fontFamilyFallback: _displayFallback,
    );
  }

  static TextStyle editorMono({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    Color? backgroundColor,
  }) {
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      backgroundColor: backgroundColor,
      fontFamilyFallback: _editorFallback,
    );
  }

  static TextStyle codeMono({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    Color? backgroundColor,
  }) {
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      backgroundColor: backgroundColor,
      fontFamilyFallback: _monoFallback,
    );
  }

  static TextStyle get display => displayMono(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get title => displayMono(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get titleSmall => displayMono(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get body => sans(
        color: AppColors.textPrimary,
        fontSize: 14,
      );

  static TextStyle get bodySecondary => sans(
        color: AppColors.textSecondary,
        fontSize: 12.5,
      );

  static TextStyle get bodySmall => sans(
        color: AppColors.textSecondary,
        fontSize: 11.5,
      );

  static TextStyle get caption => sans(
        color: AppColors.textTertiary,
        fontSize: 11,
      );

  static TextStyle get hint => sans(
        color: AppColors.textMuted,
        fontSize: 12.5,
      );

  static TextStyle get chip => sans(
        color: AppColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      );
}
