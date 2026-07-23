import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../lookup_providers.dart';

/// Hub for institutes, designations, and all dropdown masters.
class ConfigurationsHubScreen extends ConsumerWidget {
  const ConfigurationsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final role = auth.user?.role ?? '';
    final canField = Permissions.hasPermission(auth.permissions, 'FIELD_MGMT', 'READ') ||
        Permissions.canManageInstitutes(auth.permissions, role) ||
        Permissions.canManageUsers(auth.permissions, role);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!canField) {
      return Scaffold(
        body: Center(
          child: Text(
            'You do not have access to Configurations.',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      );
    }

    final groupsAsync = ref.watch(lookupGroupsProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        title: Text(
          'Configurations',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFC5A059)),
            onPressed: () => ref.invalidate(lookupGroupsProvider),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'Manage institutes, designations, and every dropdown used across the app.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : const Color(0xFF607D8B),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Organization masters',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: isDark ? Colors.white : const Color(0xFF212F3D),
            ),
          ),
          const SizedBox(height: 10),
          _HubTile(
            icon: Icons.business_rounded,
            title: 'Institutes',
            subtitle: 'Campuses / sub-organizations (active, inactive, delete)',
            color: const Color(0xFFc2410c),
            onTap: () => context.go('/admin/institutes'),
          ),
          const SizedBox(height: 10),
          _HubTile(
            icon: Icons.badge_rounded,
            title: 'Designations',
            subtitle: 'Job titles for employees',
            color: const Color(0xFFdb2777),
            onTap: () => context.go('/admin/designations'),
          ),
          const SizedBox(height: 10),
          _HubTile(
            icon: Icons.description_outlined,
            title: 'Letters',
            subtitle: 'Offer letter, LOR, exit templates',
            color: const Color(0xFF0d9488),
            onTap: () => context.go('/admin/configurations/letters'),
          ),
          const SizedBox(height: 24),
          Text(
            'Recruitment',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: isDark ? Colors.white : const Color(0xFF212F3D),
            ),
          ),
          const SizedBox(height: 10),
          groupsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (groups) {
              const recruitmentKeys = {
                'INTERVIEW_TYPE',
                'INTERVIEW_STATUS',
                'CANDIDATE_SOURCE',
              };
              final recruitment = groups.where((g) => recruitmentKeys.contains(g.key)).toList();
              if (recruitment.isEmpty) {
                return const Text(
                  'Recruitment lookups not seeded yet. Run backend seed.',
                );
              }
              return Column(
                children: [
                  for (final g in recruitment) ...[
                    _HubTile(
                      icon: Icons.work_outline_rounded,
                      title: g.label,
                      subtitle: g.description ??
                          '${g.options.where((o) => o.isActive).length} active options',
                      color: const Color(0xFF2563eb),
                      onTap: () => context.go('/admin/configurations/lookups/${g.key}'),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Dropdown options',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: isDark ? Colors.white : const Color(0xFF212F3D),
            ),
          ),
          const SizedBox(height: 10),
          groupsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Failed to load lookups: $e'),
            data: (groups) {
              const recruitmentKeys = {
                'INTERVIEW_TYPE',
                'INTERVIEW_STATUS',
                'CANDIDATE_SOURCE',
              };
              final other = groups.where((g) => !recruitmentKeys.contains(g.key)).toList();
              if (other.isEmpty) {
                return const Text('No lookup categories found. Run backend seed.');
              }
              return Column(
                children: [
                  for (final g in other) ...[
                    _HubTile(
                      icon: Icons.list_alt_rounded,
                      title: g.label,
                      subtitle: g.description ??
                          '${g.options.where((o) => o.isActive).length} active options',
                      color: const Color(0xFF0d9488),
                      onTap: () => context.go('/admin/configurations/lookups/${g.key}'),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
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
              color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
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
