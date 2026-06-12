import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'app/app_error_reporter.dart';
import 'app/nero_app.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        AppErrorReporter.instance.report(
          details.exception,
          stackTrace: details.stack,
          message: details.exceptionAsString(),
        );
      };
      PlatformDispatcher.instance.onError = (error, stackTrace) {
        AppErrorReporter.instance.report(error, stackTrace: stackTrace);
        return true;
      };
      runApp(const NeroAppBootstrap());
    },
    (error, stackTrace) {
      AppErrorReporter.instance.report(error, stackTrace: stackTrace);
    },
  );
}

class NeroAppBootstrap extends StatelessWidget {
  const NeroAppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return const NeroApp();
  }
}
