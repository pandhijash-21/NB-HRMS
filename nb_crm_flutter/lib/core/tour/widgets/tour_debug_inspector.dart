import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../engine/tour_engine.dart';
import '../registry/target_registry.dart';

class TourDebugInspector extends StatefulWidget {
  const TourDebugInspector({super.key});

  @override
  State<TourDebugInspector> createState() => _TourDebugInspectorState();
}

class _TourDebugInspectorState extends State<TourDebugInspector> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: Listenable.merge([TourEngine.instance, TargetRegistry.instance]),
      builder: (context, _) {
        final snap = TourEngine.instance.snapshot;
        if (!snap.isActive) {
          if (_open) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _open) setState(() => _open = false);
            });
          }
          return const SizedBox.shrink();
        }
        final item = snap.current;
        final targetId = item?.step.targetId;
        final target = targetId == null ? null : TargetRegistry.instance.find(targetId);
        return Positioned(
          left: 12,
          bottom: 12,
          child: Material(
            color: Colors.transparent,
            child: _open
                ? ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
                        child: DefaultTextStyle(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Text('TOUR DEBUG', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: 'Hide debug',
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    icon: const Icon(Icons.close, size: 16, color: Colors.white70),
                                    onPressed: () => setState(() => _open = false),
                                  ),
                                ],
                              ),
                              Text('State: ${snap.phase.name}'),
                              Text('Module: ${item?.module.title ?? '-'}'),
                              Text('Section: ${item?.section.title ?? '-'}'),
                              Text('Step: ${snap.index + 1}/${snap.total}'),
                              Text('Route: ${item?.step.route ?? '-'}'),
                              Text('Target: ${targetId ?? '-'}'),
                              Text('Registered: ${target != null}'),
                              Text('Mounted: ${target?.mounted ?? false}'),
                              Text('Visible: ${target?.visible ?? false}'),
                              Text('Bounds: ${target?.bounds}'),
                              Text('Highlight: ${target?.highlightBounds}'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : Material(
                    color: Colors.black.withValues(alpha: 0.72),
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _open = true),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.info_outline, color: Color(0xFFC5A36A), size: 18),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
