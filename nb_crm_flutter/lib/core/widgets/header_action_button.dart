import 'package:flutter/material.dart';

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
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color ?? (isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        icon: icon,
        label: Text(label),
      ),
    );
  }
}
