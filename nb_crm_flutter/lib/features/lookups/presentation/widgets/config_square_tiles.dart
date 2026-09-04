import 'package:flutter/material.dart';

/// Shared compact square tiles + search field for ERP / HRMS configuration hubs.
class ConfigSquareItem {
  const ConfigSquareItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class ConfigSearchField extends StatelessWidget {
  const ConfigSearchField({
    super.key,
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
    this.hintText = 'Search configurations…',
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: isDark ? Colors.white30 : const Color(0xFF607D8B).withValues(alpha: 0.6),
        ),
        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFC5A059), size: 20),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: Icon(
                  Icons.clear_rounded,
                  size: 18,
                  color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                ),
                onPressed: onClear,
              ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? const Color(0xFFC5A059).withValues(alpha: 0.2)
                : const Color(0xFFCFD8DC),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? const Color(0xFFC5A059).withValues(alpha: 0.15)
                : const Color(0xFFCFD8DC),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFC5A059), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF212F3D),
        fontSize: 14,
      ),
    );
  }
}

class ConfigSquareGrid extends StatelessWidget {
  const ConfigSquareGrid({super.key, required this.tiles, this.size = 112});

  final List<ConfigSquareItem> tiles;
  final double size;

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final t in tiles)
          SizedBox(
            width: size,
            height: size,
            child: _ConfigSquare(item: t),
          ),
      ],
    );
  }
}

class _ConfigSquare extends StatelessWidget {
  const _ConfigSquare({required this.item});

  final ConfigSquareItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? const Color(0xFFC5A059).withValues(alpha: 0.18)
                  : const Color(0xFFCFD8DC),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, color: item.color, size: 18),
              ),
              const Spacer(),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  height: 1.15,
                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.2,
                  color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
