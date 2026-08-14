import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Fades and slides a child up when it enters the scroll viewport.
class ScrollReveal extends StatefulWidget {
  const ScrollReveal({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 520),
    this.delay = Duration.zero,
    this.offset = 36,
    this.curve = Curves.easeOutCubic,
    this.once = true,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offset;
  final Curve curve;
  final bool once;

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;
  ScrollPosition? _position;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _t = CurvedAnimation(parent: _controller, curve: widget.curve);
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluate());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (!identical(next, _position)) {
      _position?.removeListener(_evaluate);
      _position = next;
      _position?.addListener(_evaluate);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_evaluate);
    _controller.dispose();
    super.dispose();
  }

  void _evaluate() {
    if (!mounted) return;
    if (_revealed && widget.once) return;

    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _evaluate());
      return;
    }

    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) {
      _reveal();
      return;
    }

    final topLeft = box.localToGlobal(Offset.zero);
    final bottom = topLeft.dy + box.size.height;
    final screenH = MediaQuery.sizeOf(context).height;
    // Reveal when any part crosses ~88% of the viewport from the top.
    final inView = bottom > 0 && topLeft.dy < screenH * 0.88;

    if (inView) {
      _reveal();
    } else if (!widget.once && _revealed && _controller.isCompleted) {
      _revealed = false;
      _controller.reverse();
    }
  }

  Future<void> _reveal() async {
    if (_revealed) return;
    _revealed = true;
    if (widget.delay > Duration.zero) {
      await Future<void>.delayed(widget.delay);
      if (!mounted) return;
    }
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        final v = _t.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - v)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Page AppBar title with an accent icon that rises from below and docks
/// beside the title as the user scrolls down.
class ScrollDockTitle extends StatelessWidget {
  const ScrollDockTitle({
    super.key,
    required this.title,
    required this.icon,
    required this.progress,
    this.color,
    this.accentColor = const Color(0xFFC5A059),
  });

  final String title;
  final IconData icon;
  final double progress;
  final Color? color;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        color ?? (isDark ? Colors.white : const Color(0xFF212F3D));
    final t = progress.clamp(0.0, 1.0);

    return Row(
      children: [
        Transform.translate(
          offset: Offset(0, 18 * (1 - t)),
          child: Opacity(
            opacity: t,
            child: Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: accentColor.withOpacity(isDark ? 0.35 : 0.28),
                ),
              ),
              child: Icon(icon, size: 16, color: accentColor),
            ),
          ),
        ),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Exposes a [ScrollController] and 0→1 scroll progress for AppBar title docking.
class ScrollProgressScope extends StatefulWidget {
  const ScrollProgressScope({
    super.key,
    required this.builder,
    this.dockDistance = 72,
  });

  final Widget Function(
    BuildContext context,
    ScrollController controller,
    double progress,
  ) builder;
  final double dockDistance;

  @override
  State<ScrollProgressScope> createState() => _ScrollProgressScopeState();
}

class _ScrollProgressScopeState extends State<ScrollProgressScope> {
  final _controller = ScrollController();
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    final next = (_controller.offset / widget.dockDistance).clamp(0.0, 1.0);
    if ((next - _progress).abs() > 0.008) {
      setState(() => _progress = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _controller, _progress);
  }
}

/// Scaffold helper: scroll-linked title accent + staggered body reveals.
class ScrollAnimatedScaffold extends StatefulWidget {
  const ScrollAnimatedScaffold({
    super.key,
    required this.title,
    required this.titleIcon,
    required this.children,
    this.leading,
    this.actions,
    this.backgroundColor,
    this.appBarBackgroundColor,
    this.accentColor = const Color(0xFFC5A059),
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    this.floatingActionButton,
    this.bottom,
  });

  final String title;
  final IconData titleIcon;
  final List<Widget> children;
  final Widget? leading;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Color? appBarBackgroundColor;
  final Color accentColor;
  final EdgeInsetsGeometry padding;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;

  @override
  State<ScrollAnimatedScaffold> createState() => _ScrollAnimatedScaffoldState();
}

class _ScrollAnimatedScaffoldState extends State<ScrollAnimatedScaffold> {
  final _controller = ScrollController();
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    final next = (_controller.offset / 72).clamp(0.0, 1.0);
    if ((next - _progress).abs() > 0.01) {
      setState(() => _progress = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.backgroundColor ??
        (isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC));
    final appBarBg = widget.appBarBackgroundColor ??
        (isDark ? const Color(0xFF1A1816) : Colors.white);

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: widget.floatingActionButton,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: widget.leading,
        actions: widget.actions,
        title: ScrollDockTitle(
          title: widget.title,
          icon: widget.titleIcon,
          progress: _progress,
          accentColor: widget.accentColor,
        ),
        bottom: widget.bottom ??
            PreferredSize(
              preferredSize: const Size.fromHeight(1.5),
              child: Container(
                color: isDark
                    ? widget.accentColor.withOpacity(0.15)
                    : const Color(0xFFCFD8DC),
                height: 1.5,
              ),
            ),
      ),
      body: ListView.builder(
        controller: _controller,
        padding: widget.padding,
        itemCount: widget.children.length,
        itemBuilder: (context, index) {
          return ScrollReveal(
            delay: Duration(milliseconds: 40 * index.clamp(0, 8)),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: index == widget.children.length - 1 ? 0 : 20,
              ),
              child: widget.children[index],
            ),
          );
        },
      ),
    );
  }
}
