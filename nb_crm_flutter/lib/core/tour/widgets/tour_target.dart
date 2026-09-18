import 'package:flutter/material.dart';

import '../engine/tour_engine.dart';
import '../registry/target_registry.dart';

class TourTarget extends StatefulWidget {
  const TourTarget({
    super.key,
    required this.id,
    required this.child,
  });

  final String id;
  final Widget child;

  @override
  State<TourTarget> createState() => _TourTargetState();
}

class _TourTargetState extends State<TourTarget> {
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) TargetRegistry.instance.register(widget.id, _key);
    });
  }

  @override
  void didUpdateWidget(covariant TourTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id == widget.id) return;
    // Keep the registry map accurate this frame; TargetRegistry defers
    // overlay notify so we do not markNeedsBuild during this build.
    TargetRegistry.instance.rebind(
      previousId: oldWidget.id,
      id: widget.id,
      key: _key,
    );
  }

  @override
  void dispose() {
    TargetRegistry.instance.unregister(widget.id, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: widget.child,
    );
  }
}

/// Wraps a tappable child and notifies the engine for interactive steps.
class TourActionTarget extends StatelessWidget {
  const TourActionTarget({
    super.key,
    required this.id,
    required this.child,
  });

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TourTarget(
      id: id,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => TourEngine.instance.reportTargetAction(id),
        child: child,
      ),
    );
  }
}
