import 'package:flutter/material.dart';

import '../features/memory/presentation/memory_screen.dart';
import '../features/mcp/presentation/mcp_servers_screen.dart';
import '../features/runtime/presentation/run_history_screen.dart';
import '../features/sandbox/presentation/sandbox_home_screen.dart';
import '../features/settings/presentation/nero_settings_screen.dart';
import '../features/skills/presentation/skills_screen.dart';
import 'app_services.dart';
import 'navigation.dart';

/// Named-route handler.
///
/// The builder closures resolve shared controllers from [AppServices] using
/// their own context, which is a descendant of the `AppServices` scope that
/// wraps `MaterialApp`.
class NeroRouter {
  NeroRouter._();

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.settings:
        return _page(
          settings,
          (context) => NeroSettingsScreen(
            controller: AppServices.maybeOf(context)?.settingsController,
          ),
        );
      case AppRoutes.sandbox:
        return _page(
          settings,
          (context) => SandboxHomeScreen(
            controller: AppServices.maybeOf(context)?.sandboxController,
          ),
        );
      case AppRoutes.mcpServers:
        return _page(settings, (context) => const McpServersScreen());
      case AppRoutes.skills:
        return _page(settings, (context) => const SkillsScreen());
      case AppRoutes.memory:
        return _page(settings, (context) => const MemoryScreen());
      case AppRoutes.runs:
        return _page(settings, (context) => const RunHistoryScreen());
      default:
        return null;
    }
  }

  static MaterialPageRoute<dynamic> _page(
    RouteSettings settings,
    WidgetBuilder builder,
  ) {
    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: builder,
    );
  }
}
