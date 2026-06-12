import 'package:flutter/material.dart';

import 'app_error_reporter.dart';
import '../core/theme/app_theme.dart';
import '../features/chat/presentation/nero_chat_screen.dart';

class NeroApp extends StatelessWidget {
  const NeroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nero',
      navigatorKey: AppErrorReporter.instance.navigatorKey,
      theme: AppTheme.dark(),
      home: const NeroChatScreen(),
    );
  }
}
