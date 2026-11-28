import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../logging/app_logger.dart';

/// Central navigation coordinator for routing outside the widget tree
/// (e.g. from local notifications, push alerts, in-app banners, or deep-links).
class AppNavigationService {
  AppNavigationService._();

  static GoRouter? _router;
  static GlobalKey<NavigatorState>? _rootNavKey;
  static String? _pendingPayload;

  static void attach(GoRouter router, GlobalKey<NavigatorState> rootNavKey) {
    _router = router;
    _rootNavKey = rootNavKey;

    if (_pendingPayload != null) {
      final payload = _pendingPayload!;
      _pendingPayload = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigateTo(payload);
      });
    }
  }

  static BuildContext? get currentContext => _rootNavKey?.currentContext;

  static void navigateTo(String path) {
    final clean = path.trim();
    if (clean.isEmpty) return;

    final target = clean.startsWith('/') ? clean : '/$clean';
    AppLogger.app.i('AppNavigationService.navigateTo: $target');

    if (_router != null) {
      _router!.go(target);
      return;
    }

    final ctx = currentContext;
    if (ctx != null && ctx.mounted) {
      GoRouter.of(ctx).go(target);
      return;
    }

    // Queue for when router is attached
    _pendingPayload = target;
  }
}
