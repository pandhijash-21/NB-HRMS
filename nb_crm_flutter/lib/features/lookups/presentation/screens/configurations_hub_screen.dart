import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../erp/domain/project_lookup_keys.dart';
import '../lookup_providers.dart';
import '../widgets/config_square_tiles.dart';

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

    final orgTiles = <ConfigSquareItem>[
      ConfigSquareItem(
        icon: Icons.account_balance_rounded,
        title: 'Organizations',
        subtitle: 'Companies',
        color: const Color(0xFF0369a1),
        onTap: () => context.go('/admin/configurations/organizations'),
      ),
      ConfigSquareItem(
        icon: Icons.business_rounded,
        title: 'Institutes',
        subtitle: 'Campuses',
        color: const Color(0xFFc2410c),
        onTap: () => context.go('/admin/institutes'),
      ),
      ConfigSquareItem(
        icon: Icons.badge_rounded,
        title: 'Designations',
        subtitle: 'Job titles',
        color: const Color(0xFFdb2777),
        onTap: () => context.go('/admin/designations'),
      ),
      ConfigSquareItem(
        icon: Icons.description_outlined,
        title: 'Letters',
        subtitle: 'Templates',
        color: const Color(0xFF0d9488),
        onTap: () => context.go('/admin/configurations/letters'),
      ),
      if (Permissions.isAdmin(role))
        ConfigSquareItem(
          icon: Icons.cloud_rounded,
          title: 'Storage',
          subtitle: 'Capacity',
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
          ConfigSearchField(
            controller: _searchCtrl,
            query: q,
            onChanged: (v) => setState(() => _query = v),
            onClear: () {
              _searchCtrl.clear();
              setState(() => _query = '');
            },
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
            ConfigSquareGrid(tiles: orgTiles),
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
                    const SizedBox(height: 24),
                    Text(
                      'Projects',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConfigSquareGrid(
                      tiles: [
                        for (final g in project)
                          ConfigSquareItem(
                            icon: Icons.apartment_outlined,
                            title: g.label,
                            subtitle:
                                '${g.options.where((o) => o.isActive).length} options',
                            color: const Color(0xFF2563eb),
                            onTap: () => context.go(
                              '/admin/configurations/lookups/${g.key}',
                            ),
                          ),
                      ],
                    ),
                  ] else if (q.isEmpty &&
                      groups.where((g) => kProjectLookupKeys.contains(g.key)).isEmpty) ...[
                    const SizedBox(height: 24),
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
                    ConfigSquareGrid(
                      tiles: [
                        for (final g in recruitment)
                          ConfigSquareItem(
                            icon: Icons.work_outline_rounded,
                            title: g.label,
                            subtitle:
                                '${g.options.where((o) => o.isActive).length} options',
                            color: const Color(0xFF2563eb),
                            onTap: () => context.go(
                              '/admin/configurations/lookups/${g.key}',
                            ),
                          ),
                      ],
                    ),
                  ] else if (q.isEmpty &&
                      groups.where((g) => _recruitmentKeys.contains(g.key)).isEmpty) ...[
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
                    const Text(
                      'Recruitment lookups not seeded yet. Run backend seed.',
                    ),
                  ],
                  if (other.isNotEmpty) ...[
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
                    ConfigSquareGrid(
                      tiles: [
                        for (final g in other)
                          ConfigSquareItem(
                            icon: Icons.list_alt_rounded,
                            title: g.label,
                            subtitle:
                                '${g.options.where((o) => o.isActive).length} options',
                            color: const Color(0xFF0d9488),
                            onTap: () => context.go(
                              '/admin/configurations/lookups/${g.key}',
                            ),
                          ),
                      ],
                    ),
                  ] else if (q.isEmpty) ...[
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
