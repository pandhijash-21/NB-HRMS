import 'package:flutter/material.dart';

/// Same widget as [Icon]. Kept as a stable import for screens that already
/// reference `NbIcon` after the web icon-font work.
class NbIcon extends StatelessWidget {
  const NbIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.textDirection,
    this.shadows,
    this.applyTextScaling,
  });

  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final TextDirection? textDirection;
  final List<Shadow>? shadows;
  final bool? applyTextScaling;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
      textDirection: textDirection,
      shadows: shadows,
      applyTextScaling: applyTextScaling,
    );
  }
}
