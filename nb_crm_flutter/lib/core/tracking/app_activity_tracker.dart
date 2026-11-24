import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../di/app_repositories.dart';

/// Captures user clicks, page views, and actions in the Flutter app
/// and micro-batches them to POST admin/audit-logs/track.
class AppActivityTracker {
  AppActivityTracker._() {
    _startPeriodicFlush();
  }

  static final AppActivityTracker instance = AppActivityTracker._();

  final List<Map<String, dynamic>> _queue = [];
  Timer? _flushTimer;
  bool _isFlushing = false;

  String _currentRoute = '/';
  String? _lastClickText;
  DateTime? _lastClickTime;

  String get currentRoute => _currentRoute;

  void setCurrentRoute(String route) {
    if (route.isEmpty) return;
    if (_currentRoute != route) {
      final prev = _currentRoute;
      _currentRoute = route;
      trackNavigation(route, fromRoute: prev);
    }
  }

  /// Records a page navigation event.
  void trackNavigation(String route, {String? fromRoute}) {
    _enqueue({
      'type': 'VIEW',
      'recordId': route,
      'fieldName': 'Navigation',
      'newValue': route,
      'oldValue': fromRoute,
      'details': {
        'route': route,
        'from': fromRoute,
        'timestamp': DateTime.now().toIso8601String(),
      },
    });
  }

  /// Records a pointer click/tap event by resolving the tapped visual element.
  void trackPointerDown(PointerDownEvent event) {
    try {
      final now = DateTime.now();
      String? extractedLabel;

      final result = HitTestResult();
      WidgetsBinding.instance.hitTestInView(result, event.position, event.viewId);

      for (final entry in result.path) {
        final target = entry.target;
        if (target is RenderParagraph) {
          final plain = target.text.toPlainText().trim();
          if (plain.isNotEmpty && plain.length < 120 && !plain.contains('\n\n')) {
            extractedLabel = plain;
            break;
          }
        }
        if (target is RenderSemanticsAnnotations) {
          final label = target.properties.label;
          final tooltip = target.properties.tooltip;
          if (tooltip != null && tooltip.isNotEmpty) {
            extractedLabel = tooltip.trim();
            break;
          }
          if (label != null && label.isNotEmpty && label.length < 120) {
            extractedLabel = label.trim();
            break;
          }
        }
      }

      final label = extractedLabel ?? 'Tap (${event.position.dx.toInt()}, ${event.position.dy.toInt()})';

      // Debounce duplicate clicks on identical label within 350ms
      if (_lastClickText == label &&
          _lastClickTime != null &&
          now.difference(_lastClickTime!).inMilliseconds < 350) {
        return;
      }

      _lastClickText = label;
      _lastClickTime = now;

      _enqueue({
        'type': 'CLICK',
        'recordId': _currentRoute,
        'fieldName': label,
        'newValue': 'Clicked',
        'details': {
          'text': label,
          'screen': _currentRoute,
          'x': event.position.dx.toInt(),
          'y': event.position.dy.toInt(),
          'timestamp': now.toIso8601String(),
        },
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppActivityTracker] error in trackPointerDown: $e');
      }
    }
  }

  /// Records an explicit business or user action (e.g. Punch In, Filter Changed).
  void trackAction(String actionName, {String? target, Map<String, dynamic>? details}) {
    _enqueue({
      'type': 'ACTION',
      'recordId': target ?? _currentRoute,
      'fieldName': actionName,
      'newValue': 'Triggered',
      'details': details ?? {},
    });
  }

  void _enqueue(Map<String, dynamic> item) {
    _queue.add(item);
    if (_queue.length >= 30) {
      _flush();
    }
  }

  void _startPeriodicFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      _flush();
    });
  }

  Future<void> _flush() async {
    if (_isFlushing || _queue.isEmpty) return;
    _isFlushing = true;

    final batch = List<Map<String, dynamic>>.from(_queue.take(40));
    _queue.removeRange(0, batch.length);

    try {
      final dio = AppRepositories().dioClient;
      await dio.dio.post(
        'admin/audit-logs/track',
        data: {'events': batch},
      );
    } catch (_) {
      // Fail silently â€” tracking should never disturb user UX or crash requests.
    } finally {
      _isFlushing = false;
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }
}
