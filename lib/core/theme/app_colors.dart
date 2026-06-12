import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF20201E);
  static const backgroundDeep = Color(0xFF181816);
  static const backgroundBackdrop = Color(0xFF20201E);
  static const surface = Color(0xFF2A2927);
  static const surfaceElevated = Color(0xFF31302E);
  static const surfaceSoft = Color(0xFF252422);
  static const surfaceHighlight = Color(0x14FFFFFF);
  static const cardBackground = Color(0xFF31302E);
  static const dropdownBackground = Color(0xFF2F2E2B);
  static const surfaceGlass = Color(0xB82A2927);
  static const surfaceOverlay = Color(0x0DFFFFFF);
  static const surfaceOverlayStrong = Color(0x14FFFFFF);
  static const surfaceComposer = Color(0xFF2F2D2A);
  static const surfaceChatBubbleUser = Color(0xFF161616);
  static const surfaceMarkdownCode = Color(0x26C16F50);
  static const surfaceBlockquote = Color(0x1AC16F50);

  static const primaryGrey = Color(0xFFD6D1CA);
  static const textPrimary = Color(0xFFF3F1ED);
  static const textSecondary = Color(0xFFD6D0C8);
  static const textTertiary = Color(0x99D6D0C8);
  static const textMuted = Color(0xFF9C968F);
  static const textInverse = Color(0xFF000000);
  static const textOnDarkStrong = Color(0xFFFFFFFF);
  static const textOnDarkMuted = Color(0xB3FFFFFF);
  static const textMarkdownBody = Color(0xFFD1D5DB);
  static const textMarkdownEmphasis = Color(0xFFF3F4F6);
  static const textComposerFooter = Color(0xFFD8D0C8);
  static const textComposerIcon = Color(0xFFC5BFB7);

  static const borderSoft = Color(0x14FFFFFF);
  static const borderMedium = Color(0x22FFFFFF);
  static const borderStrong = Color(0x36FFFFFF);
  static const borderComposer = Color(0x14FFFFFF);
  static const borderMarkdownTable = Color(0x1AFFFFFF);

  static const teal = Color(0xFFC16F50);
  static const tealDark = Color(0xFFA85E43);
  static const tealBright = Color(0xFFE07B52);
  static const purple = Color(0xFF7F7A73);
  static const red = Color(0xFFD95D4F);
  static const orange = Color(0xFFE07B52);
  static const blue = Color(0xFF716B64);
  static const amber = Color(0xFFB89B72);
  static const error = Color(0xFFEF4444);
  static const backdropGlowPrimary = Color(0x12E07B52);
  static const backdropGlowSecondary = Color(0x0D7F7A73);
  static const backdropGlowWarm = Color(0x1AE07B52);

  static const accentGradient = LinearGradient(
    colors: [tealBright, amber],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const headerGradient = LinearGradient(
    colors: [Color(0xFF1D1C1A), Color(0xFF262523), Color(0xFF20201E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
