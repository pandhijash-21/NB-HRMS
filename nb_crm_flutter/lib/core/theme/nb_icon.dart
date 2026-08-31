import 'package:flutter/material.dart';

/// Material icon that paints from the full bundled `NbMaterialIcons` font.
///
/// Flutter web tree-shakes `MaterialIcons`, so `Icon(Icons.videocam)` and
/// `Icon(someVariable)` often render as empty boxes. This widget always uses
/// the complete font file shipped in pubspec.
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

  static IconData data(IconData icon) {
    if (icon.fontFamily != null &&
        icon.fontFamily != 'MaterialIcons' &&
        icon.fontFamily != 'NbMaterialIcons') {
      return icon;
    }
    // ignore: non_const_argument_for_const_parameter
    return IconData(
      icon.codePoint,
      fontFamily: 'NbMaterialIcons',
      matchTextDirection: icon.matchTextDirection,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Icon(
      data(icon),
      size: size,
      color: color,
      semanticLabel: semanticLabel,
      textDirection: textDirection,
      shadows: shadows,
      applyTextScaling: applyTextScaling,
    );
  }
}
