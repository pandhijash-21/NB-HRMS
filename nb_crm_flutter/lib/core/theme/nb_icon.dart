import 'package:flutter/material.dart';

/// Material icon painted from the full bundled `CRMIcons` font.
///
/// Flutter web subsets the built-in `MaterialIcons` family, so Chat/Meet and
/// other glyphs become missing characters (Noto fallback errors). `CRMIcons`
/// is the same official Material icon file, registered as a normal asset
/// font that is not tree-shaken.
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

  static const fontFamily = 'CRMIcons';

  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final TextDirection? textDirection;
  final List<Shadow>? shadows;
  final bool? applyTextScaling;

  static IconData data(IconData icon) {
    final family = icon.fontFamily;
    if (family != null && family != 'MaterialIcons' && family != fontFamily) {
      return icon;
    }
    // ignore: non_const_argument_for_const_parameter
    return IconData(
      icon.codePoint,
      fontFamily: fontFamily,
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
