import 'package:flutter/material.dart';

import 'app_error_reporter.dart';
import 'app_router.dart';
import 'app_services.dart';
import 'nero_home_shell.dart';
import '../core/theme/app_theme.dart';

class NeroApp extends StatelessWidget {
  const NeroApp({
    super.key,
    this.overrides = const AppServicesOverrides(),
  });

  /// Test and preview hook for substituting app-lifetime services.
  final AppServicesOverrides overrides;

  @override
  Widget build(BuildContext context) {
    return AppServices(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Nero',
        navigatorKey: AppErrorReporter.instance.navigatorKey,
        theme: AppTheme.dark(),
        onGenerateRoute: NeroRouter.onGenerateRoute,
        home: const NeroHomeShell(),
      ),
    );
  }
}
