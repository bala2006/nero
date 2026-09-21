import 'dart:async';

import 'package:flutter/material.dart';

import '../features/chat/presentation/nero_chat_screen.dart';
import 'app_services.dart';
import 'navigation.dart';

/// Root shell: owns the app's navigation destinations and hands shared
/// services down to the chat screen.
///
/// The chat screen remains the primary surface; every other feature is one
/// drawer tap away. The shell is also where app-wide infrastructure that must
/// outlive a single screen is mounted (currently the shared service container,
/// later the sandbox WebView pool).
class NeroHomeShell extends StatefulWidget {
  const NeroHomeShell({super.key});

  @override
  State<NeroHomeShell> createState() => _NeroHomeShellState();
}

class _NeroHomeShellState extends State<NeroHomeShell> {
  bool _bootstrapped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) {
      return;
    }
    _bootstrapped = true;
    final services = AppServices.of(context);
    // Persisted settings and MCP servers are loaded once for the whole app.
    unawaited(services.bootstrap());
  }

  static const List<NeroDestination> _destinations = <NeroDestination>[
    NeroDestination(
      route: AppRoutes.workspace,
      label: 'Workspace',
      icon: Icons.folder_open_rounded,
      subtitle: 'Imported files and generated artifacts',
    ),
    NeroDestination(
      route: AppRoutes.sandbox,
      label: 'Sandbox',
      icon: Icons.terminal_rounded,
      subtitle: 'Run code on-device',
    ),
    NeroDestination(
      route: AppRoutes.mcpServers,
      label: 'MCP servers',
      icon: Icons.hub_outlined,
      subtitle: 'Connect external tool servers',
    ),
    NeroDestination(
      route: AppRoutes.skills,
      label: 'Skills',
      icon: Icons.auto_awesome_rounded,
      subtitle: 'Built-in agent workflows',
    ),
    NeroDestination(
      route: AppRoutes.memory,
      label: 'Memory',
      icon: Icons.psychology_rounded,
      subtitle: 'What Nero remembers',
    ),
    NeroDestination(
      route: AppRoutes.runs,
      label: 'Runs',
      icon: Icons.timeline_rounded,
      subtitle: 'Agent run history and resume',
    ),
    NeroDestination(
      route: AppRoutes.settings,
      label: 'Settings',
      icon: Icons.tune_rounded,
      subtitle: 'Model, reasoning and policy',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    return Stack(
      children: <Widget>[
        NeroChatScreen(
          destinations: _destinations,
          onOpenDestination: (destination) async {
            await Navigator.of(context).pushNamed(destination.route);
          },
          settingsController: services.settingsController,
          historyController: services.chatHistoryController,
          workspaceStore: services.workspaceStore,
          auditLogStore: services.auditLogStore,
          nativeBridgeService: services.nativeBridgeService,
          mcpRegistry: services.mcpRegistry,
          sandboxController: services.sandboxController,
        ),
        // App-lifetime sandbox execution host. A WebView only runs JavaScript
        // while it is in the render tree, so the shell keeps one mounted at 1x1
        // off-screen: that is what lets the agent run sandbox code while no
        // sandbox screen is open. The Sandbox screen reuses this same runner.
        services.sandboxWebViewHost,
      ],
    );
  }
}
