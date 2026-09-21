import 'package:flutter/material.dart';

import '../features/audit/application/audit_log_store.dart';
import '../features/chat/application/chat_history_controller.dart';
import '../features/mcp/application/mcp_registry.dart';
import '../features/sandbox/application/sandbox_controller.dart';
import '../features/sandbox/application/webview_sandbox_runner.dart';
import '../features/settings/settings_controller.dart';
import '../features/workspace/application/workspace_store.dart';
import '../platform/device/native_bridge_service.dart';

/// App-lifetime service container.
///
/// Before this existed, [NeroChatScreen] and [NeroSettingsScreen] each built
/// their own `SettingsController`/`AuditLogStore`/`WorkspaceStore`, so settings
/// edits in one surface could be invisible to the other until a reload. The
/// container owns one instance of each and disposes them together.
///
/// Construction is lazy: a service is only built the first time it is read, so
/// screens that never touch a service pay nothing for it. Tests can inject
/// substitutes through [AppServicesOverrides].
class AppServicesController {
  AppServicesController({
    this.overrides = const AppServicesOverrides(),
  });

  final AppServicesOverrides overrides;

  SettingsController? _settingsController;
  ChatHistoryController? _chatHistoryController;
  WorkspaceStore? _workspaceStore;
  AuditLogStore? _auditLogStore;
  NativeBridgeService? _nativeBridgeService;
  McpRegistry? _mcpRegistry;
  SandboxController? _sandboxController;

  SettingsController get settingsController =>
      _settingsController ??= overrides.settingsController;

  ChatHistoryController get chatHistoryController =>
      _chatHistoryController ??= overrides.chatHistoryController;

  WorkspaceStore get workspaceStore =>
      _workspaceStore ??= overrides.workspaceStore;

  AuditLogStore get auditLogStore => _auditLogStore ??= overrides.auditLogStore;

  NativeBridgeService get nativeBridgeService =>
      _nativeBridgeService ??= overrides.nativeBridgeService;

  /// Owns every MCP server, its discovered tools and the capability provider
  /// that exposes them to the model.
  McpRegistry get mcpRegistry => _mcpRegistry ??= overrides.mcpRegistry;

  /// App-lifetime sandbox. Its WebView must stay mounted for snippets to run,
  /// so it is owned here rather than by the sandbox screen: the agent's
  /// `sandbox_run_code` tool has to work while no sandbox screen is open.
  SandboxController get sandboxController =>
      _sandboxController ??= overrides.sandboxController;

  /// The off-screen WebView host that keeps [sandboxController] runnable.
  Widget get sandboxWebViewHost =>
      _sandboxWebViewHost ??= _buildSandboxHost();

  Widget? _sandboxWebViewHost;

  Widget _buildSandboxHost() {
    final controller = sandboxController;
    final runner = controller.runner;
    if (runner is! WebViewSandboxRunner) {
      return const SizedBox.shrink();
    }
    return runner.buildHost();
  }

  /// Loads persisted state once so every screen sees the same values.
  Future<void> bootstrap() async {
    if (!settingsController.isLoaded) {
      await settingsController.load();
    }
    if (!mcpRegistry.isLoaded) {
      await mcpRegistry.load();
    }
    if (sandboxController.isLoading) {
      await sandboxController.load();
    }
  }

  void dispose() {
    _settingsController?.dispose();
    _chatHistoryController?.dispose();
    _mcpRegistry?.dispose();
    _sandboxController?.dispose();
  }
}

/// Optional overrides for tests. Every field defaults to the real service.
class AppServicesOverrides {
  const AppServicesOverrides({
    SettingsController? settingsController,
    ChatHistoryController? chatHistoryController,
    WorkspaceStore? workspaceStore,
    AuditLogStore? auditLogStore,
    NativeBridgeService? nativeBridgeService,
    McpRegistry? mcpRegistry,
    SandboxController? sandboxController,
  }) : _settingsController = settingsController,
       _chatHistoryController = chatHistoryController,
       _workspaceStore = workspaceStore,
       _auditLogStore = auditLogStore,
       _nativeBridgeService = nativeBridgeService,
       _mcpRegistry = mcpRegistry,
       _sandboxController = sandboxController;

  final SettingsController? _settingsController;
  final ChatHistoryController? _chatHistoryController;
  final WorkspaceStore? _workspaceStore;
  final AuditLogStore? _auditLogStore;
  final NativeBridgeService? _nativeBridgeService;
  final McpRegistry? _mcpRegistry;
  final SandboxController? _sandboxController;

  SettingsController get settingsController =>
      _settingsController ?? SettingsController();

  ChatHistoryController get chatHistoryController =>
      _chatHistoryController ?? ChatHistoryController();

  WorkspaceStore get workspaceStore => _workspaceStore ?? WorkspaceStore();

  AuditLogStore get auditLogStore => _auditLogStore ?? AuditLogStore();

  NativeBridgeService get nativeBridgeService =>
      _nativeBridgeService ?? NativeBridgeService();

  McpRegistry get mcpRegistry => _mcpRegistry ?? McpRegistry();

  SandboxController get sandboxController =>
      _sandboxController ??
      SandboxController(runner: WebViewSandboxRunner());
}

/// Provides [AppServicesController] to the widget tree.
class AppServices extends StatefulWidget {
  const AppServices({
    super.key,
    required this.child,
    this.overrides = const AppServicesOverrides(),
  });

  final Widget child;
  final AppServicesOverrides overrides;

  static AppServicesController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_AppServicesScope>();
    if (scope == null) {
      throw FlutterError(
        'AppServices.of() was called with a context that does not contain an '
        'AppServices widget. Wrap the app root in `AppServices`.',
      );
    }
    return scope.controller;
  }

  /// Non-throwing lookup for leaf widgets that may render outside the scope
  /// (for example inside a standalone widget test).
  static AppServicesController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_AppServicesScope>()
        ?.controller;
  }

  @override
  State<AppServices> createState() => _AppServicesState();
}

class _AppServicesState extends State<AppServices> {
  late final AppServicesController _controller = AppServicesController(
    overrides: widget.overrides,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AppServicesScope(controller: _controller, child: widget.child);
  }
}

class _AppServicesScope extends InheritedWidget {
  const _AppServicesScope({required this.controller, required super.child});

  final AppServicesController controller;

  @override
  bool updateShouldNotify(_AppServicesScope oldWidget) {
    return !identical(controller, oldWidget.controller);
  }
}
