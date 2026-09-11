import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class ErpHomeScreen extends StatelessWidget {
  const ErpHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final canReadProjects = Permissions.canReadProjects(auth.permissions, auth.user?.role);
    final canReadWorkOrders = Permissions.canReadWorkOrders(auth.permissions, auth.user?.role);
    final canReadBoq = Permissions.canReadBoq(auth.permissions, auth.user?.role);
    final canReadStore = Permissions.canReadStore(auth.permissions, auth.user?.role);
    final canReadTenders = Permissions.canReadTenders(auth.permissions, auth.user?.role);
    final canReadTenderApplications = Permissions.canReadTenderApplications(auth.permissions, auth.user?.role);
    final canReadDpr = Permissions.canReadDpr(auth.permissions, auth.user?.role);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasAny = canReadProjects ||
        canReadWorkOrders ||
        canReadBoq ||
        canReadStore ||
        canReadTenders ||
        canReadTenderApplications ||
        canReadDpr;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        title: const Text('ERP', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: !hasAny
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 48, color: isDark ? Colors.white30 : Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    'No ERP modules are assigned to your role.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                if (canReadProjects) ...[
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
                    onTap: () => context.go('/erp/projects'),
                  ),
                  const SizedBox(height: 16),
                ],
                if (canReadWorkOrders || canReadBoq || canReadStore) ...[
                  Text(
                    'Work Orders & Resources',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (canReadWorkOrders) ...[
                    _ErpTile(
                      icon: Icons.assignment_outlined,
                      title: 'Work Orders',
                      subtitle: 'Create and track contractor work orders',
                      color: const Color(0xFF0d9488),
                      onTap: () => context.go('/erp/work-orders'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (canReadBoq) ...[
                    _ErpTile(
                      icon: Icons.receipt_long_outlined,
                      title: 'BOQ',
                      subtitle: 'Bill of quantities — activities, materials, machines & labour',
                      color: const Color(0xFF7c3aed),
                      onTap: () => context.go('/erp/boq'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (canReadStore) ...[
                    _ErpTile(
                      icon: Icons.storefront_outlined,
                      title: 'Store',
                      subtitle: 'Material inward/outward inventory & machine equipment',
                      color: const Color(0xFF0d9488),
                      onTap: () => context.go('/erp/store'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 6),
                ],
                if (canReadTenders || canReadTenderApplications) ...[
                  Text(
                    'Tenders',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (canReadTenders) ...[
                    _ErpTile(
                      icon: Icons.gavel_outlined,
                      title: 'Tenders',
                      subtitle: 'Create tenders against projects / BOQ activities',
                      color: const Color(0xFFdc2626),
                      onTap: () => context.go('/erp/tenders'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (canReadTenderApplications) ...[
                    _ErpTile(
                      icon: Icons.handshake_outlined,
                      title: 'Tender Applications',
                      subtitle: 'Vendor applications against open tenders',
                      color: const Color(0xFFea580c),
                      onTap: () => context.go('/erp/tender-applications'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 6),
                ],
                if (canReadDpr) ...[
                  Text(
                    'Progress',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ErpTile(
                    icon: Icons.assignment_turned_in_outlined,
                    title: 'DPR',
                    subtitle: 'Daily progress reports — tasks, materials, labour & machinery',
                    color: const Color(0xFF1e3a5f),
                    onTap: () => context.go('/erp/dpr'),
                  ),
                ],
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
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
      );
  }
}
