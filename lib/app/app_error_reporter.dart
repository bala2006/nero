import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class AppErrorReporter {
  AppErrorReporter._();

  static final AppErrorReporter instance = AppErrorReporter._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final StreamController<String> _errors = StreamController<String>.broadcast();
  bool _dialogOpen = false;

  Stream<String> get errors => _errors.stream;

  void report(
    Object error, {
    StackTrace? stackTrace,
    String? message,
  }) {
    debugPrint('AppErrorReporter: $error');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
    final text = _normalizeMessage(message ?? error.toString());
    if (text.isEmpty) {
      return;
    }
    if (!_errors.isClosed) {
      _errors.add(text);
    }
    if (_shouldSuppressDialog(text)) {
      return;
    }
    unawaited(show(text));
  }

  Future<void> show(String message) async {
    final text = _normalizeMessage(message);
    if (text.isEmpty || _dialogOpen) {
      return;
    }

    _dialogOpen = true;
    try {
      if (SchedulerBinding.instance.schedulerPhase !=
          SchedulerPhase.idle) {
        await SchedulerBinding.instance.endOfFrame;
      }
      final overlay = navigatorKey.currentState?.overlay;
      if (overlay == null) {
        return;
      }
      await showDialog<void>(
        context: overlay.context, // ignore: use_build_context_synchronously
        barrierDismissible: true,
        builder: (context) {
          return AlertDialog(
            backgroundColor: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppColors.borderSoft),
            ),
            title: Text(
              'Something went wrong',
              style: AppTextStyles.title.copyWith(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
            content: Text(
              text,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'OK',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.orange,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } finally {
      _dialogOpen = false;
    }
  }

  String _normalizeMessage(String raw) {
    final message = raw.trim();
    if (message.isEmpty) {
      return '';
    }
    if (message.startsWith('Exception:')) {
      return message.substring('Exception:'.length).trim();
    }
    return message;
  }

  bool _shouldSuppressDialog(String message) {
    return message.startsWith('Build scheduled during frame.');
  }
}
