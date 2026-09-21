import 'package:flutter/material.dart';

/// Named routes for every pushed surface.
///
/// Screens that need constructor arguments (workspace, run detail) are pushed
/// directly with a `MaterialPageRoute` instead of a named route.
class AppRoutes {
  AppRoutes._();

  static const String chat = '/';
  static const String settings = '/settings';
  static const String workspace = '/workspace';
  static const String sandbox = '/sandbox';
  static const String mcpServers = '/mcp';
  static const String skills = '/skills';
  static const String memory = '/memory';
  static const String runs = '/runs';
}

/// One entry in the app's navigation drawer.
class NeroDestination {
  const NeroDestination({
    required this.route,
    required this.label,
    required this.icon,
    this.subtitle,
  });

  final String route;
  final String label;
  final IconData icon;
  final String? subtitle;
}
