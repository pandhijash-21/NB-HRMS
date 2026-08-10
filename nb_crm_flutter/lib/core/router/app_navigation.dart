import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../logging/app_logger.dart';

/// Logs all GoRouter navigations (push / pop / replace).
class AppGoRouterObserver extends NavigatorObserver {
  AppGoRouterObserver({AppLogger? logger}) : _log = logger ?? AppLogger.router;

  final AppLogger _log;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log.i(
      'push → ${_routeName(route)} (from ${_routeName(previousRoute)})',
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log.i(
      'pop ← ${_routeName(route)} (to ${_routeName(previousRoute)})',
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _log.i(
      'replace ${_routeName(oldRoute)} → ${_routeName(newRoute)}',
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log.i(
      'remove ${_routeName(route)} (prev ${_routeName(previousRoute)})',
    );
  }

  String _routeName(Route<dynamic>? route) {
    if (route == null) return 'null';
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) return name;
    final args = route.settings.arguments;
    if (args != null) return '${route.runtimeType}($args)';
    return route.runtimeType.toString();
  }
}

/// GoRouter-aware navigation helpers for screens & dialogs.
extension AppGoRouterX on BuildContext {
  /// Prefer this over [Navigator.pop] for routes and dialogs.
  void goPop<T extends Object?>([T? result]) {
    if (canPop()) {
      pop(result);
    } else {
      AppLogger.router.w('goPop ignored — nothing to pop at $currentLocation');
    }
  }

  String get currentLocation {
    try {
      return GoRouterState.of(this).uri.toString();
    } catch (_) {
      return '(unknown)';
    }
  }
}
