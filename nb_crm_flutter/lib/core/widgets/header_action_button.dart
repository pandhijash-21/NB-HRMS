import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';

class HeaderActionButton extends StatelessWidget {
  final String tooltip;
  final String label;
  final Widget icon;
  final VoidCallback onPressed;
  final Color? color;

  const HeaderActionButton({
    super.key,
    required this.tooltip,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg =
        color ?? (isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238));
    // Icon-only on narrow phones to keep AppBar actions from overflowing.
    final compact = AppBreakpoints.isPhone(context);

    if (compact) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        color: fg,
        icon: icon,
      );
    }

    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: fg,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        icon: icon,
        label: Text(label),
      ),
    );
  }
}
