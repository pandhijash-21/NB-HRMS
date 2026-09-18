import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../services/mr_nb_tour_service.dart';
import '../../theme/app_breakpoints.dart';
import '../availability/tour_availability.dart';
import '../engine/tour_engine.dart';
import '../tour_desktop.dart';
import '../mascot/mascot_clip_registry.dart';
import '../mascot/mascot_presenter.dart';
import '../mascot/mr_nb_intro.dart';
import '../models/tour_models.dart';
import '../registry/target_registry.dart';

class TourOverlayHost extends StatefulWidget {
  const TourOverlayHost({super.key});

  @override
  State<TourOverlayHost> createState() => _TourOverlayHostState();
}

class _TourOverlayHostState extends State<TourOverlayHost> {
  final _engine = TourEngine.instance;
  final _focus = FocusNode();
  late final Listenable _tourListenables = Listenable.merge([
    _engine,
    TargetRegistry.instance,
  ]);

  @override
  void initState() {
    super.initState();
    _engine.addListener(_onEngine);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAuth();
  }

  void _syncAuth() {
    final auth = context.read<AuthBloc>().state;
    _engine.updateAuth(
      userId: auth.user?.id,
      auth: TourAuthContext.fromUser(
        permissions: auth.permissions,
        enabledModules: auth.user?.enabledModules,
        role: auth.user?.role,
        employeeViewScope: auth.user?.employeeViewScope,
      ),
    );
  }

  void _onEngine() => _scheduleHostRebuild();

  void _scheduleHostRebuild() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(() {});
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _engine.removeListener(_onEngine);
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_engine.isActive || event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _engine.exit();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      _engine.next();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _engine.next();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _engine.back();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (p, c) =>
          p.isAuthenticated != c.isAuthenticated ||
          p.user?.id != c.user?.id ||
          p.permissions != c.permissions,
      listener: (_, __) => _syncAuth(),
      child: _buildOverlay(),
    );
  }

  Widget _buildOverlay() {
    final snap = _engine.snapshot;
    if (!snap.isActive || snap.current == null) {
      return const SizedBox.shrink();
    }
    if (!TourDesktop.supported(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (TourEngine.instance.isActive) TourEngine.instance.exit();
      });
      return const SizedBox.shrink();
    }
    return SizedBox.expand(
      child: Overlay(
        key: const ValueKey('nb-tour-overlay'),
        initialEntries: [
          OverlayEntry(
            opaque: false,
            builder: (overlayContext) {
              return _DeferredListenableBuilder(
                listenable: _tourListenables,
                builder: (context) => _TourLayer(
                  overlayContext: overlayContext,
                  focusNode: _focus,
                  onKey: _onKey,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Listens like [ListenableBuilder], but never setStates during build/unmount.
class _DeferredListenableBuilder extends StatefulWidget {
  const _DeferredListenableBuilder({
    required this.listenable,
    required this.builder,
  });

  final Listenable listenable;
  final WidgetBuilder builder;

  @override
  State<_DeferredListenableBuilder> createState() =>
      _DeferredListenableBuilderState();
}

class _DeferredListenableBuilderState extends State<_DeferredListenableBuilder> {
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_onChange);
  }

  @override
  void didUpdateWidget(covariant _DeferredListenableBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_onChange);
      widget.listenable.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(() {});
      return;
    }
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

class _TourLayer extends StatefulWidget {
  const _TourLayer({
    required this.overlayContext,
    required this.focusNode,
    required this.onKey,
  });

  final BuildContext overlayContext;
  final FocusNode focusNode;
  final KeyEventResult Function(FocusNode, KeyEvent) onKey;

  @override
  State<_TourLayer> createState() => _TourLayerState();
}

class _TourLayerState extends State<_TourLayer> {
  Timer? _boundsPoll;

  @override
  void initState() {
    super.initState();
    _boundsPoll = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _boundsPoll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snap = TourEngine.instance.snapshot;
    if (!snap.isActive || snap.current == null) {
      return const SizedBox.shrink();
    }
    final item = snap.current;
    final hole = _holeInOverlay(widget.overlayContext, item?.step.targetId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.focusNode.hasFocus) widget.focusNode.requestFocus();
    });

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: widget.onKey,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            const Positioned.fill(
              child: ModalBarrier(
                dismissible: false,
                color: Colors.transparent,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _SpotlightPainter(hole: hole),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            if (item != null) _TourCard(snapshot: snap, hole: hole),
          ],
        ),
      ),
    );
  }
}

Rect? _holeInOverlay(BuildContext overlayContext, String? targetId) {
  if (targetId == null) return null;
  final global = TargetRegistry.instance.find(targetId)?.highlightBounds;
  if (global == null || global.isEmpty) return null;

  final box = overlayContext.findRenderObject() as RenderBox?;
  Rect local = global;
  if (box != null && box.hasSize && box.attached) {
    local = Rect.fromPoints(
      box.globalToLocal(global.topLeft),
      box.globalToLocal(global.bottomRight),
    );
  }

  final size = box?.size ?? MediaQuery.maybeSizeOf(overlayContext);
  if (size != null &&
      local.width >= size.width * 0.8 &&
      local.height >= size.height * 0.8) {
    return null;
  }
  if (local.width < 8 || local.height < 8) return null;
  return local;
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({this.hole});
  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(Offset.zero & size);
    if (hole != null) {
      final r = hole!.inflate(10);
      overlay.addRRect(RRect.fromRectAndRadius(r, const Radius.circular(16)));
      overlay.fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(overlay, Paint()..color = Colors.black.withValues(alpha: 0.58));
    if (hole != null) {
      final rrect = RRect.fromRectAndRadius(hole!.inflate(10), const Radius.circular(16));
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = const Color(0xFFC5A36A).withValues(alpha: 0.28),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0xFFC5A36A),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) => oldDelegate.hole != hole;
}

class _TourCard extends StatelessWidget {
  const _TourCard({required this.snapshot, this.hole});
  final TourSnapshot snapshot;
  final Rect? hole;

  @override
  Widget build(BuildContext context) {
    final item = snapshot.current!;
    final step = item.step;
    final wide = AppBreakpoints.isWide(context);
    final clip = MascotClipRegistry.instance.resolve(step: step);
    final engine = TourEngine.instance;
    final isLast = snapshot.index >= snapshot.total - 1;
    final isMeetMrNb = MrNbIntro.isIntro(step);
    const gold = Color(0xFFC5A36A);

    final longCopy = step.description.length > 160;
    final idealMascot = isMeetMrNb
        ? (wide ? 176.0 : 148.0)
        : longCopy
            ? (wide ? 96.0 : 84.0)
            : (wide ? 148.0 : 124.0);

    final card = Material(
      color: const Color(0xFF1A201C),
      elevation: 12,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, c) {
            const chrome = 208.0;
            var mascotSize = idealMascot;
            if (clip != null && mascotSize + chrome + 64 > c.maxHeight) {
              mascotSize = (c.maxHeight - chrome - 64).clamp(0.0, idealMascot);
            }
            final showMascot = clip != null && mascotSize >= 56;
            final descMax = (c.maxHeight -
                    chrome -
                    (showMascot ? mascotSize + 10 : 0))
                .clamp(48.0, c.maxHeight);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${snapshot.index + 1} / ${snapshot.total}',
                      style: const TextStyle(
                        color: Color(0xFFC5A36A),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Replay voice',
                      icon: const Icon(Icons.record_voice_over, color: Colors.white70, size: 18),
                      onPressed: () {
                        MrNbTourService.instance.unlock();
                        engine.speakCurrent();
                      },
                    ),
                    IconButton(
                      tooltip: MrNbTourService.instance.isMuted ? 'Unmute' : 'Mute',
                      icon: Icon(
                        MrNbTourService.instance.isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white70,
                        size: 18,
                      ),
                      onPressed: () {
                        MrNbTourService.instance.toggleMute();
                        if (!MrNbTourService.instance.isMuted) {
                          engine.speakCurrent();
                        }
                        (context as Element).markNeedsBuild();
                      },
                    ),
                    IconButton(
                      tooltip: 'Close tour',
                      icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                      onPressed: engine.exit,
                    ),
                  ],
                ),
                Text(
                  isMeetMrNb ? 'Your guide' : '${item.module.title} · ${item.section.title}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
                ),
                if (showMascot) ...[
                  const SizedBox(height: 10),
                  Center(child: MascotPresenter(clip: clip, size: mascotSize)),
                ],
                const SizedBox(height: 12),
                Text(
                  step.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: descMax),
                  child: SingleChildScrollView(
                    child: Text(
                      step.description,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.86), height: 1.45),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: snapshot.index > 0
                          ? () {
                              MrNbTourService.instance.unlock();
                              engine.back();
                            }
                          : null,
                      child: const Text('Back'),
                    ),
                    TextButton(
                      onPressed: isMeetMrNb
                          ? null
                          : () {
                              MrNbTourService.instance.unlock();
                              engine.skip();
                            },
                      child: const Text('Skip'),
                    ),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black),
                      onPressed: () {
                        MrNbTourService.instance.unlock();
                        engine.next();
                      },
                      child: Text(isMeetMrNb ? "Let's begin" : (isLast ? 'Finish' : 'Next')),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );

    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _TourCardPlacement(
          hole: hole,
          padding: MediaQuery.paddingOf(context),
          center: isMeetMrNb,
          contentLeft: wide ? 268.0 : 16.0,
          maxCardWidth: wide ? 420.0 : 340.0,
        ),
        child: Semantics(
          label: 'Software tour: ${step.title}',
          child: card,
        ),
      ),
    );
  }
}

class _TourCardPlacement extends SingleChildLayoutDelegate {
  _TourCardPlacement({
    required this.hole,
    required this.padding,
    required this.center,
    required this.contentLeft,
    required this.maxCardWidth,
  });

  final Rect? hole;
  final EdgeInsets padding;
  final bool center;
  final double contentLeft;
  final double maxCardWidth;

  static const _margin = 16.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxW = math.min(maxCardWidth, math.max(80.0, constraints.maxWidth - _margin * 2));
    final maxH = math.max(80.0, constraints.maxHeight - _margin * 2);
    return BoxConstraints(maxWidth: maxW, maxHeight: maxH);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final minX = _margin;
    final minY = math.max(_margin, padding.top + _margin);
    final maxX = math.max(minX, size.width - childSize.width - _margin);
    final maxY = math.max(minY, size.height - childSize.height - _margin);
    final preferMinX = math.min(math.max(contentLeft, minX), maxX);

    double x;
    double y;

    if (center || hole == null) {
      x = (size.width - childSize.width) / 2;
      y = center ? size.height * 0.10 : (size.height - childSize.height) / 2;
      return Offset(x.clamp(minX, maxX), y.clamp(minY, maxY));
    }

    final h = hole!;
    final gap = 16.0;
    final spaceRight = size.width - h.right - _margin;
    final spaceLeft = h.left - _margin;
    final spaceBelow = size.height - h.bottom - _margin;
    final spaceAbove = h.top - minY;
    final inSidebar = h.center.dx < contentLeft + 8;

    if (inSidebar && spaceRight >= childSize.width + gap) {
      x = h.right + gap;
      y = h.top;
    } else if (spaceRight >= childSize.width + gap && h.width < size.width * 0.55) {
      x = h.right + gap;
      y = h.top;
    } else if (spaceLeft >= childSize.width + gap) {
      x = h.left - childSize.width - gap;
      y = h.top;
    } else if (spaceBelow >= childSize.height + gap) {
      x = h.left;
      y = h.bottom + gap;
    } else if (spaceAbove >= childSize.height + gap) {
      x = h.left;
      y = h.top - childSize.height - gap;
    } else {
      x = h.center.dx > size.width / 2 ? preferMinX : maxX;
      y = h.center.dy > size.height / 2 ? minY : maxY;
    }

    if (x < preferMinX && maxX >= preferMinX && !inSidebar) {
      x = preferMinX;
    }

    return Offset(x.clamp(minX, maxX), y.clamp(minY, maxY));
  }

  @override
  bool shouldRelayout(covariant _TourCardPlacement oldDelegate) {
    return oldDelegate.hole != hole ||
        oldDelegate.padding != padding ||
        oldDelegate.center != center ||
        oldDelegate.contentLeft != contentLeft ||
        oldDelegate.maxCardWidth != maxCardWidth;
  }
}
