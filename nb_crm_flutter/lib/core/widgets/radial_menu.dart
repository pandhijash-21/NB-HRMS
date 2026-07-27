import 'dart:math';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';

class RadialMenu extends StatefulWidget {
  final List<RadialMenuItem> items;
  final Color? primaryColor;
  final Color? onPrimaryColor;
  final IconData openIcon;
  final IconData closeIcon;

  const RadialMenu({
    super.key,
    required this.items,
    this.primaryColor,
    this.onPrimaryColor,
    this.openIcon = Icons.apps_rounded,
    this.closeIcon = Icons.close_rounded,
  });

  @override
  State<RadialMenu> createState() => _RadialMenuState();
}

class RadialMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;

  RadialMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.backgroundColor,
    this.foregroundColor,
  });
}

class _RadialMenuState extends State<RadialMenu> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isOpen = false;
  bool _isStickyHidden = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _startHideTimer();
  }

  @override
  void dispose() {
    _cancelHideTimer();
    _controller.dispose();
    super.dispose();
  }

  void _startHideTimer() {
    _cancelHideTimer();
    if (_isOpen || _isStickyHidden) return;
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isStickyHidden = true;
        });
      }
    });
  }

  void _cancelHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _resetHideTimer() {
    if (!_isOpen && !_isStickyHidden) {
      _startHideTimer();
    }
  }

  void _toggle() {
    _cancelHideTimer();
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
        _startHideTimer();
      }
    });
  }

  Widget _buildItem(RadialMenuItem item, int index, int total, BuildContext context) {
    final double startAngle = pi + 0.25; 
    final double endAngle = 1.5 * pi;
    final double angle = startAngle + (endAngle - startAngle) * (index / (total > 1 ? total - 1 : 1));
    final double distance = 140.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double animValue = Curves.easeOutBack.transform(_controller.value);
        final double x = cos(angle) * distance * animValue;
        final double y = sin(angle) * distance * animValue;

        return Positioned(
          right: 20 - x,
          bottom: 95 - y,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: _controller.value,
                child: Opacity(
                  opacity: _controller.value.clamp(0.0, 1.0),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          item.backgroundColor ?? Theme.of(context).colorScheme.surface,
                          (item.backgroundColor ?? Theme.of(context).colorScheme.surface).withOpacity(0.9),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withOpacity(0.08),
                        width: 1.5,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () {
                          _toggle();
                          item.onTap();
                        },
                        customBorder: const CircleBorder(),
                        child: Center(
                          child: Icon(
                            item.icon,
                            size: 24,
                            color: item.foregroundColor ?? Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (item.label.isNotEmpty)
                Positioned(
                  top: 60,
                  child: Transform.scale(
                    scale: _controller.value,
                    child: Opacity(
                      opacity: _controller.value.clamp(0.0, 1.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1E1E1E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: Border.all(
                            color: Theme.of(context).dividerColor.withOpacity(0.05),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            letterSpacing: 0.3,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.primaryColor ?? Theme.of(context).colorScheme.primary;
    final onThemeColor = widget.onPrimaryColor ?? Theme.of(context).colorScheme.onPrimary;

    return Stack(
      alignment: Alignment.bottomRight,
      clipBehavior: Clip.none,
      children: [
        // Background overlay with blur
        if (_isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggle,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 250),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5 * value, sigmaY: 5 * value),
                    child: Container(
                      color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black.withOpacity(0.4 * value)
                              : Colors.white.withOpacity(0.3 * value),
                    ),
                  );
                },
              ),
            ),
          ),
        // Items
        ...List.generate(widget.items.length, (index) {
          return _buildItem(widget.items[index], index, widget.items.length, context);
        }),
        
        // Sticky chevron tab (slides in from the right when the main button is hidden)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          right: _isStickyHidden ? 0 : -60,
          bottom: 100,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isStickyHidden = false;
              });
              _startHideTimer();
            },
            child: Container(
              width: 28,
              height: 48,
              decoration: BoxDecoration(
                color: themeColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(-2, 2),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.chevron_left_rounded,
                color: onThemeColor,
                size: 20,
              ),
            ),
          ),
        ),

        // Main circular button (slides off-screen to the right when hidden)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          right: _isStickyHidden ? -80 : 20,
          bottom: 95,
          child: MouseRegion(
            onHover: (_) => _resetHideTimer(),
            child: GestureDetector(
              onTapDown: (_) => _resetHideTimer(),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      themeColor,
                      themeColor.withOpacity(0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: _toggle,
                    customBorder: const CircleBorder(),
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _controller.value * (pi / 2),
                          child: Icon(
                            _isOpen ? widget.closeIcon : widget.openIcon,
                            color: onThemeColor,
                            size: 26,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
