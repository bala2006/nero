/// Shared widget kit used across every Nero feature screen.
///
/// Widgets that used to be private copies inside `nero_chat_screen.dart` and
/// `nero_settings_screen.dart` live here so new surfaces (MCP, sandbox, skills,
/// memory, runs) can reuse them instead of re-declaring them.
library;

export 'empty_state.dart';
export 'inline_banner.dart';
export 'nero_backdrop.dart';
export 'nero_bottom_sheet.dart';
export 'nero_tile.dart';
export 'nero_top_bar.dart';
export 'section_card.dart';
export 'shimmer_text.dart';
export 'status_pill.dart';
export 'thinking_animation.dart';
