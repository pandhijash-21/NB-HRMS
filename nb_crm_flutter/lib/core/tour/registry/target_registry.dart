import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class RegisteredTourTarget {
  RegisteredTourTarget(this.id, this.key);

  final String id;
  final GlobalKey key;

  bool get mounted {
    final ctx = key.currentContext;
    return ctx != null && ctx.mounted;
  }

  RenderBox? get box {
    final ctx = key.currentContext;
    if (ctx == null || !ctx.mounted) return null;
    return ctx.findRenderObject() as RenderBox?;
  }

  /// Raw render-box rect in global coordinates.
  Rect? get bounds {
    return _rectOf(box);
  }

  /// Rect used for the spotlight — the registered widget itself.
  Rect? get highlightBounds => bounds;

  bool get visible {
    final r = highlightBounds ?? bounds;
    if (r == null || r.isEmpty) return false;
    return r.width > 1 && r.height > 1;
  }
}

class TargetRegistry extends ChangeNotifier {
  TargetRegistry._();
  static final TargetRegistry instance = TargetRegistry._();

  final Map<String, RegisteredTourTarget> _targets = {};
  bool _postFrameNotifyScheduled = false;

  void register(String id, GlobalKey key) {
    rebind(id: id, key: key);
  }

  /// Keep the map accurate without notifying when nothing overlay-visible changed.
  void rebind({
    String? previousId,
    required String id,
    required GlobalKey key,
  }) {
    var changed = false;
    if (previousId != null && previousId != id) {
      final previous = _targets[previousId];
      if (previous != null && identical(previous.key, key)) {
        _targets.remove(previousId);
        changed = true;
      }
    }
    final existing = _targets[id];
    if (existing == null || !identical(existing.key, key)) {
      _targets[id] = RegisteredTourTarget(id, key);
      changed = true;
    }
    if (changed) _scheduleNotify();
  }

  void unregister(String id, GlobalKey key) {
    final existing = _targets[id];
    if (existing != null && identical(existing.key, key)) {
      _targets.remove(id);
      _scheduleNotify(forceDefer: true);
    }
  }

  /// [notifyListeners] is unsafe during build / finalizeTree (unmount).
  /// Coalesce bursts of register/unregister onto a single post-frame pulse.
  void _scheduleNotify({bool forceDefer = false}) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (!forceDefer && phase == SchedulerPhase.idle) {
      notifyListeners();
      return;
    }
    if (_postFrameNotifyScheduled) return;
    _postFrameNotifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _postFrameNotifyScheduled = false;
      notifyListeners();
    });
  }

  RegisteredTourTarget? find(String id) => _targets[id];

  bool isRegistered(String id) => _targets.containsKey(id);

  Iterable<String> get ids => _targets.keys;
}

Rect? _rectOf(RenderBox? box) {
  if (box == null || !box.hasSize || !box.attached) return null;
  try {
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  } catch (_) {
    return null;
  }
}
