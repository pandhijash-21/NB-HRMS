import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/widgets/header_action_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/structure_models.dart';
import '../project_providers.dart';

class TowerUnitsScreen extends ConsumerWidget {
  const TowerUnitsScreen({
    super.key,
    required this.projectId,
    required this.towerId,
  });

  final String projectId;
  final String towerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final canWrite = Permissions.hasPermission(auth.permissions, 'PROJECTS', 'WRITE');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(
      projectTowerDetailProvider((projectId: projectId, towerId: towerId)),
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        title: Text(
          async.asData?.value.name ?? 'Manage Tower',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: AppBackButton(fallbackLocation: '/erp/structure/$projectId'),
        actions: [
          if (canWrite)
            HeaderActionButton(
              tooltip: 'Regenerate units from floors × flats',
              icon: const Icon(Icons.restart_alt_rounded),
              label: 'Regenerate',
              onPressed: () => _regenerate(context, ref),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (tower) {
          final complete = tower.units.where((u) => u.isComplete).length;
          final grouped = <int, List<ErpProjectUnit>>{};
          for (final u in tower.units) {
            grouped.putIfAbsent(u.floorNo, () => []).add(u);
          }
          final floors = grouped.keys.toList()..sort();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              _SummaryCard(tower: tower, complete: complete),
              const SizedBox(height: 14),
              if (tower.units.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: Text('No units. Tap Regenerate to create them.')),
                )
              else
                for (final floor in floors) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                    child: Text(
                      '${floorLabel(floor)}  ·  ${grouped[floor]!.length} units',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white70 : const Color(0xFF455A64),
                      ),
                    ),
                  ),
                  for (final unit in grouped[floor]!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _UnitTile(
                        unit: unit,
                        enabled: canWrite,
                        onTap: () => context.go(
                          '/erp/structure/$projectId/towers/$towerId/units/${unit.id}',
                        ),
                      ),
                    ),
                ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _regenerate(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate units?'),
        content: const Text(
          'This replaces all unit records for this tower using floors × flats per floor. Existing unit details will be lost.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Regenerate')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(projectRepositoryProvider).regenerateUnits(projectId, towerId);
      ref.invalidate(projectTowerDetailProvider((projectId: projectId, towerId: towerId)));
      ref.invalidate(projectTowersProvider(projectId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.tower, required this.complete});

  final ErpProjectTower tower;
  final int complete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFFC5A059).withValues(alpha: 0.15)
              : const Color(0xFFCFD8DC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tower.name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${tower.floorCount} floors × ${tower.flatsPerFloor} flats = ${tower.plannedUnits} units'
                  '${tower.hasGround ? '  ·  flats from floor 0' : '  ·  GF parking, flats from floor 1'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                  ),
                ),
              ),
              Tooltip(
                message: tower.hasGround
                    ? 'Ground floor has flats. Numbering starts at 0 (Ground, then 1, 2, …).'
                    : 'Ground floor is parking. Flats start from floor 1.',
                waitDuration: const Duration(milliseconds: 200),
                child: const Icon(Icons.info_outline, size: 18, color: Color(0xFF2563eb)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: tower.units.isEmpty ? 0 : complete / tower.units.length,
            minHeight: 6,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 6),
          Text(
            '$complete of ${tower.units.length} units fully filled',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : const Color(0xFF607D8B),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitTile extends StatelessWidget {
  const _UnitTile({
    required this.unit,
    required this.enabled,
    required this.onTap,
  });

  final ErpProjectUnit unit;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? const Color(0xFFC5A059).withValues(alpha: 0.15)
                  : const Color(0xFFCFD8DC),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unit.isComplete ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.unitNo,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    Text(
                      [
                        unit.unitTypeCode ?? 'Type not set',
                        unit.statusCode ?? 'Status not set',
                        if (unit.totalValue != null)
                          '₹${unit.totalValue!.toStringAsFixed(0)}',
                      ].join(' • '),
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
