import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../lookups/presentation/lookup_providers.dart';
import '../../../lookups/presentation/widgets/config_square_tiles.dart';
import '../../domain/contractor_lookup_keys.dart';
import '../../domain/dpr_lookup_keys.dart';
import '../../domain/project_lookup_keys.dart';
import '../../domain/work_order_lookup_keys.dart';

class ErpConfigurationsScreen extends ConsumerStatefulWidget {
  const ErpConfigurationsScreen({super.key});

  @override
  ConsumerState<ErpConfigurationsScreen> createState() => _ErpConfigurationsScreenState();
}

class _ErpConfigurationsScreenState extends ConsumerState<ErpConfigurationsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matches(List<String?> haystacks) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    for (final h in haystacks) {
      if (h != null && h.toLowerCase().contains(q)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupsAsync = ref.watch(lookupGroupsProvider);
    final q = _query.trim();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        title: const Text('Configurations', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: const AppBackButton(fallbackLocation: '/erp/home'),
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
          groupsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Failed to load lookups: $e'),
            data: (groups) {
              final project = groups
                  .where((g) => kProjectLookupKeys.contains(g.key))
                  .where((g) => _matches([g.label, g.description, g.key]))
                  .toList();
              final contractorLookups = groups
                  .where((g) => kContractorLookupKeys.contains(g.key))
                  .where((g) => _matches([g.label, g.description, g.key]))
                  .toList();
              final wo = groups
                  .where((g) => kWoLookupKeys.contains(g.key))
                  .where((g) => _matches([g.label, g.description, g.key]))
                  .toList();
              final dpr = groups
                  .where((g) => g.key == DprLookupKeys.grade || g.key == DprLookupKeys.status)
                  .where((g) => _matches([g.label, g.description, g.key]))
                  .toList();

              final resourceTiles = [
                if (_matches(['Materials', 'Stock', 'materials']))
                  ConfigSquareItem(
                    title: 'Materials',
                    subtitle: 'Stock & logs',
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xFF0d9488),
                    onTap: () => context.go('/erp/configurations/materials'),
                  ),
                if (_matches(['Machines', 'Equipment', 'machines']))
                  ConfigSquareItem(
                    title: 'Machines',
                    subtitle: 'Equipment',
                    icon: Icons.precision_manufacturing_outlined,
                    color: const Color(0xFF7c3aed),
                    onTap: () => context.go('/erp/configurations/machines'),
                  ),
                if (_matches(['Labour', 'Labor', 'rates', 'labour']))
                  ConfigSquareItem(
                    title: 'Labour',
                    subtitle: 'Types & rates',
                    icon: Icons.groups_outlined,
                    color: const Color(0xFFea580c),
                    onTap: () => context.go('/erp/configurations/labour'),
                  ),
              ];

              final woStatic = [
                if (_matches(['Activities', 'Work activities', 'activities']))
                  ConfigSquareItem(
                    title: 'Activities',
                    subtitle: 'Work activities',
                    icon: Icons.timeline_outlined,
                    color: const Color(0xFF1e3a5f),
                    onTap: () => context.go('/erp/configurations/activities'),
                  ),
                if (_matches(['Contractors', 'Vendors', 'contractors']))
                  ConfigSquareItem(
                    title: 'Contractors',
                    subtitle: 'Vendors',
                    icon: Icons.handshake_outlined,
                    color: const Color(0xFFdc2626),
                    onTap: () => context.go('/erp/configurations/contractors'),
                  ),
                for (final g in wo)
                  ConfigSquareItem(
                    title: g.label,
                    subtitle: '${g.options.where((o) => o.isActive).length} options',
                    icon: Icons.straighten_outlined,
                    color: const Color(0xFF64748b),
                    onTap: () => context.go('/erp/configurations/lookups/${g.key}'),
                  ),
              ];

              final any = project.isNotEmpty ||
                  resourceTiles.isNotEmpty ||
                  woStatic.isNotEmpty ||
                  contractorLookups.isNotEmpty ||
                  dpr.isNotEmpty;

              if (!any) {
                return Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    q.isEmpty ? 'No configurations found.' : 'No configurations match “$q”.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF607D8B)),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (project.isNotEmpty) ...[
                    _sectionTitle(isDark, 'Projects'),
                    _sectionHint(isDark, 'Manage every dropdown used on Add Project.'),
                    const SizedBox(height: 12),
                    ConfigSquareGrid(
                      tiles: [
                        for (final g in project)
                          ConfigSquareItem(
                            title: g.label,
                            subtitle: '${g.options.where((o) => o.isActive).length} options',
                            icon: Icons.apartment_rounded,
                            color: const Color(0xFF2563eb),
                            onTap: () => context.go('/erp/configurations/lookups/${g.key}'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                  ],
                  if (resourceTiles.isNotEmpty) ...[
                    _sectionTitle(isDark, 'BOQ & Resources'),
                    _sectionHint(isDark, 'Materials, machines, labour for BOQ costing.'),
                    const SizedBox(height: 12),
                    ConfigSquareGrid(tiles: resourceTiles),
                    const SizedBox(height: 28),
                  ],
                  if (woStatic.isNotEmpty || contractorLookups.isNotEmpty) ...[
                    _sectionTitle(isDark, 'Work Orders'),
                    _sectionHint(isDark, 'Activities, contractors, and measurement units.'),
                    const SizedBox(height: 12),
                    if (woStatic.isNotEmpty) ConfigSquareGrid(tiles: woStatic),
                    if (contractorLookups.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _sectionTitle(isDark, 'Contractor lookups', small: true),
                      const SizedBox(height: 10),
                      ConfigSquareGrid(
                        tiles: [
                          for (final g in contractorLookups)
                            ConfigSquareItem(
                              title: g.label,
                              subtitle: '${g.options.where((o) => o.isActive).length} options',
                              icon: Icons.list_alt_rounded,
                              color: const Color(0xFF0891b2),
                              onTap: () => context.go('/erp/configurations/lookups/${g.key}'),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 28),
                  ],
                  if (dpr.isNotEmpty) ...[
                    _sectionTitle(isDark, 'DPR'),
                    _sectionHint(isDark, 'Grade and status options for daily progress reports.'),
                    const SizedBox(height: 12),
                    ConfigSquareGrid(
                      tiles: [
                        for (final g in dpr)
                          ConfigSquareItem(
                            title: g.label,
                            subtitle: '${g.options.where((o) => o.isActive).length} options',
                            icon: g.key == DprLookupKeys.grade
                                ? Icons.grade_outlined
                                : Icons.flag_outlined,
                            color: const Color(0xFF1e3a5f),
                            onTap: () => context.go('/erp/configurations/lookups/${g.key}'),
                          ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(bool isDark, String text, {bool small = false}) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: small ? 13 : 15,
        color: isDark ? (small ? Colors.white70 : Colors.white) : const Color(0xFF212F3D),
      ),
    );
  }

  Widget _sectionHint(bool isDark, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white54 : const Color(0xFF607D8B),
        ),
      ),
    );
  }
}
