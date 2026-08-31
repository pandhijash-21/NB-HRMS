import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../lookups/presentation/lookup_providers.dart';
import '../../domain/project_lookup_keys.dart';
import '../../domain/work_order_lookup_keys.dart';

class ErpConfigurationsScreen extends ConsumerWidget {
  const ErpConfigurationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupsAsync = ref.watch(lookupGroupsProvider);

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
          Text(
            'Projects',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: isDark ? Colors.white : const Color(0xFF212F3D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage every dropdown used on Add Project.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : const Color(0xFF607D8B),
            ),
          ),
          const SizedBox(height: 12),
          groupsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Failed to load lookups: $e'),
            data: (groups) {
              final project = groups
                  .where((g) => kProjectLookupKeys.contains(g.key))
                  .toList();
              if (project.isEmpty) {
                return const Text(
                  'Project lookups not seeded yet. Restart backend after seed.',
                );
              }
              return Column(
                children: [
                  for (final g in project) ...[
                    _CfgTile(
                      title: g.label,
                      subtitle: g.description ??
                          '${g.options.where((o) => o.isActive).length} active options',
                      onTap: () => context.go(
                        '/erp/configurations/lookups/${g.key}',
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Work Orders',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: isDark ? Colors.white : const Color(0xFF212F3D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Activities, contractors, and measurement units.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : const Color(0xFF607D8B),
            ),
          ),
          const SizedBox(height: 12),
          _CfgTile(
            title: 'Activities',
            subtitle: 'Work order activities — add and toggle active/inactive',
            onTap: () => context.go('/erp/configurations/activities'),
          ),
          const SizedBox(height: 10),
          _CfgTile(
            title: 'Contractors',
            subtitle: 'Manage contractors for work orders',
            onTap: () => context.go('/erp/configurations/contractors'),
          ),
          const SizedBox(height: 10),
          groupsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (groups) {
              final wo = groups.where((g) => kWoLookupKeys.contains(g.key)).toList();
              return Column(
                children: [
                  for (final g in wo) ...[
                    _CfgTile(
                      title: g.label,
                      subtitle: g.description ??
                          '${g.options.where((o) => o.isActive).length} active options',
                      onTap: () => context.go('/erp/configurations/lookups/${g.key}'),
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

class _CfgTile extends StatelessWidget {
  const _CfgTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
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
                  color: const Color(0xFF2563eb).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tune_rounded, color: Color(0xFF2563eb), size: 22),
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
