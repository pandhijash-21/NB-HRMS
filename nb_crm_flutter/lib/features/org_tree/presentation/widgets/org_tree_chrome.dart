import 'package:flutter/material.dart';

import '../../domain/org_tree_models.dart';

Color orgKindColor(String kind, bool isDark) {
  switch (kind) {
    case 'organization':
      return isDark ? const Color(0xFFC5A059) : const Color(0xFF1D4ED8);
    case 'department':
      return isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    case 'lead':
      return isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
    case 'group':
      return isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    default:
      return isDark ? const Color(0xFF34D399) : const Color(0xFF0F766E);
  }
}

IconData orgKindIcon(String kind) {
  switch (kind) {
    case 'organization':
      return Icons.apartment_rounded;
    case 'department':
      return Icons.account_tree_rounded;
    case 'lead':
      return Icons.star_rounded;
    case 'group':
      return Icons.groups_2_rounded;
    default:
      return Icons.person_rounded;
  }
}

String orgKindLabel(String kind) {
  switch (kind) {
    case 'organization':
      return 'ORG';
    case 'department':
      return 'DEPT';
    case 'lead':
      return 'LEAD';
    case 'group':
      return 'OTHER';
    default:
      return 'STAFF';
  }
}

class OrgAvatar extends StatelessWidget {
  const OrgAvatar({super.key, required this.node, this.size = 36});

  final OrgTreeNode node;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = orgKindColor(node.kind, isDark);
    final initials = _initials(node.title);
    final url = node.photoUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.95), color.withValues(alpha: 0.55)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: size < 28 ? 0.18 : 0.28),
            blurRadius: size < 28 ? 4 : 10,
            offset: Offset(0, size < 28 ? 1 : 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(initials),
            )
          : _fallback(initials),
    );
  }

  Widget _fallback(String initials) {
    if (node.isPerson) {
      return Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.32,
            letterSpacing: 0.4,
          ),
        ),
      );
    }
    return Icon(orgKindIcon(node.kind), color: Colors.white, size: size * 0.48);
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
