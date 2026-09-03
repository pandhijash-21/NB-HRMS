import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';

class ErpHomeScreen extends ConsumerWidget {
  const ErpHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final canRead = Permissions.hasPermission(auth.permissions, 'PROJECTS', 'READ') ||
        Permissions.hasPermission(auth.permissions, 'WORK_ORDERS', 'READ') ||
        Permissions.canAccessAdminPortal(auth.permissions, auth.user?.employeeViewScope);
    final canReadWo = Permissions.hasPermission(auth.permissions, 'WORK_ORDERS', 'READ') ||
        Permissions.canAccessAdminPortal(auth.permissions, auth.user?.employeeViewScope);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        title: const Text('ERP', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'Projects',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: isDark ? Colors.white : const Color(0xFF212F3D),
            ),
          ),
          const SizedBox(height: 10),
          _ErpTile(
            icon: Icons.apartment_rounded,
            title: 'Projects',
            subtitle: 'Sites we are developing — add and manage projects',
            color: const Color(0xFF2563eb),
            enabled: canRead,
            onTap: () => context.go('/erp/projects'),
          ),
          const SizedBox(height: 10),
          Text(
            'Work Orders',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: isDark ? Colors.white : const Color(0xFF212F3D),
            ),
          ),
          const SizedBox(height: 10),
          _ErpTile(
            icon: Icons.assignment_outlined,
            title: 'Work Orders',
            subtitle: 'Create and track contractor work orders',
            color: const Color(0xFF0d9488),
            enabled: canReadWo,
            onTap: () => context.go('/erp/work-orders'),
          ),
          const SizedBox(height: 10),
          _ErpTile(
            icon: Icons.receipt_long_outlined,
            title: 'BOQ',
            subtitle: 'Bill of quantities — activities, materials, machines & labour',
            color: const Color(0xFF7c3aed),
            enabled: canReadWo,
            onTap: () => context.go('/erp/boq'),
          ),
          const SizedBox(height: 10),
          Text(
            'Tenders',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: isDark ? Colors.white : const Color(0xFF212F3D),
            ),
          ),
          const SizedBox(height: 10),
          _ErpTile(
            icon: Icons.gavel_outlined,
            title: 'Tenders',
            subtitle: 'Create tenders against projects / BOQ activities',
            color: const Color(0xFFdc2626),
            enabled: canReadWo,
            onTap: () => context.go('/erp/tenders'),
          ),
          const SizedBox(height: 10),
          _ErpTile(
            icon: Icons.handshake_outlined,
            title: 'Tender Applications',
            subtitle: 'Vendor applications against open tenders',
            color: const Color(0xFFea580c),
            enabled: canReadWo,
            onTap: () => context.go('/erp/tender-applications'),
          ),
        ],
      ),
    );
  }
}

class _ErpTile extends StatelessWidget {
  const _ErpTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? const Color(0xFFC5A059).withValues(alpha: 0.15)
                    : const Color(0xFFCFD8DC),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF212F3D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white24 : Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
