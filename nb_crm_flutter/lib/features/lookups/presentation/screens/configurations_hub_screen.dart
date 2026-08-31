import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../erp/domain/project_lookup_keys.dart';
import '../lookup_providers.dart';

/// Hub for institutes, designations, and all dropdown masters.
class ConfigurationsHubScreen extends ConsumerStatefulWidget {
  const ConfigurationsHubScreen({super.key});

  @override
  ConsumerState<ConfigurationsHubScreen> createState() =>
      _ConfigurationsHubScreenState();
}

class _ConfigurationsHubScreenState
    extends ConsumerState<ConfigurationsHubScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  static const _recruitmentKeys = {
    'INTERVIEW_TYPE',
    'INTERVIEW_STATUS',
    'CANDIDATE_SOURCE',
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matches(String query, List<String?> haystacks) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    for (final h in haystacks) {
      if (h != null && h.toLowerCase().contains(q)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
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
    final q = _query.trim();

    final orgTiles = <_StaticHubItem>[
      _StaticHubItem(
        icon: Icons.account_balance_rounded,
        title: 'Organizations',
        subtitle: 'Companies with contact, tax, address & bank details',
        color: const Color(0xFF0369a1),
        onTap: () => context.go('/admin/configurations/organizations'),
      ),
      _StaticHubItem(
        icon: Icons.business_rounded,
        title: 'Institutes',
        subtitle: 'Campuses / sub-organizations (child company optional)',
        color: const Color(0xFFc2410c),
        onTap: () => context.go('/admin/institutes'),
      ),
      _StaticHubItem(
        icon: Icons.badge_rounded,
        title: 'Designations',
        subtitle: 'Job titles for employees',
        color: const Color(0xFFdb2777),
        onTap: () => context.go('/admin/designations'),
      ),
      _StaticHubItem(
        icon: Icons.description_outlined,
        title: 'Letters',
        subtitle: 'Offer letter, LOR, exit templates',
        color: const Color(0xFF0d9488),
        onTap: () => context.go('/admin/configurations/letters'),
      ),
      if (Permissions.isAdmin(role))
        _StaticHubItem(
          icon: Icons.cloud_rounded,
          title: 'Storage',
          subtitle: 'Used space, remaining capacity, and wipe documents',
          color: const Color(0xFF7c3aed),
          onTap: () => context.go('/admin/storage'),
        ),
    ].where((t) => _matches(q, [t.title, t.subtitle])).toList();

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
        leading: const AppBackButton(),
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
            'Manage organizations, institutes, designations, and every dropdown used across the app.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : const Color(0xFF607D8B),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search configurations…',
              hintStyle: TextStyle(
                color: isDark
                    ? Colors.white30
                    : const Color(0xFF607D8B).withValues(alpha: 0.6),
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFFC5A059),
                size: 20,
              ),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: Icon(
                        Icons.clear_rounded,
                        size: 18,
                        color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                      ),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
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
                borderSide: const BorderSide(
                  color: Color(0xFFC5A059),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
            ),
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF212F3D),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          if (orgTiles.isNotEmpty) ...[
            Text(
              'Organization masters',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: isDark ? Colors.white : const Color(0xFF212F3D),
              ),
            ),
            const SizedBox(height: 10),
            for (final t in orgTiles) ...[
              _HubTile(
                icon: t.icon,
                title: t.title,
                subtitle: t.subtitle,
                color: t.color,
                onTap: t.onTap,
              ),
              const SizedBox(height: 10),
            ],
          ],
          groupsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Failed to load lookups: $e'),
            data: (groups) {
              final recruitment = groups
                  .where((g) => _recruitmentKeys.contains(g.key))
                  .where((g) => _matches(q, [g.label, g.description, g.key]))
                  .toList();
              // ORGANIZATION is managed under Organization masters now — hide legacy lookup.
              final project = groups
                  .where((g) => kProjectLookupKeys.contains(g.key))
                  .where((g) => _matches(q, [g.label, g.description, g.key]))
                  .toList();
              final other = groups
                  .where((g) =>
                      !_recruitmentKeys.contains(g.key) &&
                      g.key != 'ORGANIZATION' &&
                      !kProjectLookupKeys.contains(g.key))
                  .where((g) => _matches(q, [g.label, g.description, g.key]))
                  .toList();

              if (orgTiles.isEmpty &&
                  recruitment.isEmpty &&
                  project.isEmpty &&
                  other.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    q.isEmpty
                        ? 'No configurations found.'
                        : 'No configurations match “$q”.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (project.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Projects',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final g in project) ...[
                      _HubTile(
                        icon: Icons.apartment_outlined,
                        title: g.label,
                        subtitle: g.description ??
                            '${g.options.where((o) => o.isActive).length} active options',
                        color: const Color(0xFF2563eb),
                        onTap: () =>
                            context.go('/admin/configurations/lookups/${g.key}'),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ] else if (q.isEmpty &&
                      groups
                          .where((g) => kProjectLookupKeys.contains(g.key))
                          .isEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Projects',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Project lookups not seeded yet. Run ERP bootstrap on backend.',
                    ),
                  ],
                  if (recruitment.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Recruitment',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final g in recruitment) ...[
                      _HubTile(
                        icon: Icons.work_outline_rounded,
                        title: g.label,
                        subtitle: g.description ??
                            '${g.options.where((o) => o.isActive).length} active options',
                        color: const Color(0xFF2563eb),
                        onTap: () =>
                            context.go('/admin/configurations/lookups/${g.key}'),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ] else if (q.isEmpty &&
                      groups
                          .where((g) => _recruitmentKeys.contains(g.key))
                          .isEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Recruitment',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Recruitment lookups not seeded yet. Run backend seed.',
                    ),
                  ],
                  if (other.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Dropdown options',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final g in other) ...[
                      _HubTile(
                        icon: Icons.list_alt_rounded,
                        title: g.label,
                        subtitle: g.description ??
                            '${g.options.where((o) => o.isActive).length} active options',
                        color: const Color(0xFF0d9488),
                        onTap: () =>
                            context.go('/admin/configurations/lookups/${g.key}'),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ] else if (q.isEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Dropdown options',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('No lookup categories found. Run backend seed.'),
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

class _StaticHubItem {
  const _StaticHubItem({
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
