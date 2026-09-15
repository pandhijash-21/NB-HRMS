import 'package:flutter/material.dart';

import '../../domain/earth_kinds.dart';

class EarthPropertyPin extends StatelessWidget {
  const EarthPropertyPin({
    super.key,
    required this.kind,
    this.imageUrl,
    this.size = 36,
    this.selected = false,
    this.label,
  });

  final String kind;
  final String? imageUrl;
  final double size;
  final bool selected;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final def = earthKindOf(kind);
    final has = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final pin = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: def.color,
        border: Border.all(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.92),
          width: selected ? 3 : 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: def.color.withValues(alpha: 0.45),
            blurRadius: selected ? 10 : 6,
            spreadRadius: selected ? 1 : 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: has
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(def),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _fallback(def);
              },
            )
          : _fallback(def),
    );

    if (label == null || label!.trim().isEmpty) return pin;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        pin,
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _fallback(EarthKindDef def) {
    return ColoredBox(
      color: def.color,
      child: Icon(def.icon, color: Colors.white, size: size * 0.5),
    );
  }
}
