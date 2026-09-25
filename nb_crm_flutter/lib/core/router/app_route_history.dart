import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../logging/app_logger.dart';

/// Screens opened inside the app shell, oldest first.
///
/// Sidebar navigation uses [GoRouter.go], which replaces the navigator stack,
/// so [BuildContext.canPop] is often false. This trail is what Back uses.
class AppRouteHistory {
  AppRouteHistory._();

  static final List<String> _stack = <String>[];

  static void record(String location) {
    final loc = location.trim().isEmpty ? '/' : location.trim();
    if (_stack.isNotEmpty && _stack.last == loc) return;
    _stack.add(loc);
    if (_stack.length > 50) {
      _stack.removeRange(0, _stack.length - 50);
    }
  }

  /// Screen under [current], if the user has opened something before it.
  static String? previousOf(String current) {
    if (_stack.length < 2) return null;
    var index = _stack.length - 1;
    if (_stack[index] == current) index -= 1;
    if (index < 0) return null;
    final prev = _stack[index];
    if (prev == current) return null;
    return prev;
  }

  /// Drop [current] when it is the latest entry, after a successful back.
  static void dropThrough(String current) {
    if (_stack.length >= 2 && _stack.last == current) {
      _stack.removeLast();
    }
  }
}

/// Pop a pushed route, otherwise return to the previous shell screen.
///
/// Returns false when there is nowhere to go (caller may show an exit prompt).
bool tryAppGoBack(BuildContext context, {String? fallback}) {
  var current = '';
  try {
    current = GoRouterState.of(context).uri.toString();
  } catch (_) {}

  if (context.canPop()) {
    AppRouteHistory.dropThrough(current);
    AppLogger.router.d('back pop @ $current');
    context.pop();
    return true;
  }

  final prev = AppRouteHistory.previousOf(current);
  if (prev != null) {
    AppRouteHistory.dropThrough(current);
    AppLogger.router.d('back go → $prev (from $current)');
    context.go(prev);
    return true;
  }

  if (fallback != null && fallback.isNotEmpty && fallback != current) {
    AppLogger.router.d('back fallback → $fallback');
    context.go(fallback);
    return true;
  }
  return false;
}
