import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/bloc/load_status.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../../core/widgets/header_action_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/project_repository.dart';
import '../../domain/structure_models.dart';
import '../bloc/erp_structure_bloc.dart';

class TowerUnitsScreen extends StatelessWidget {
  const TowerUnitsScreen({
    super.key,
    required this.projectId,
    required this.towerId,
  });

  final String projectId;
  final String towerId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ErpStructureBloc>(
      create: (ctx) => ErpStructureBloc(
        projectRepository: ctx.read<ProjectRepository>(),
      )..add(ErpStructureTowerDetailRequested(
          projectId: projectId,
          towerId: towerId,
        )),
      child: _TowerUnitsView(
        projectId: projectId,
        towerId: towerId,
      ),
    );
  }
}

class _TowerUnitsView extends StatelessWidget {
  const _TowerUnitsView({
    required this.projectId,
    required this.towerId,
  });

  final String projectId;
  final String towerId;

  Future<void> _regenerate(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate units?'),
        content: const Text(
          'This replaces all unit records for this tower using floors × flats per floor. Existing unit details and duplex configurations will be reset.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Regenerate')),
        ],
      ),
    );
    if (ok != true) return;
    if (context.mounted) {
      context.read<ErpStructureBloc>().add(
            ErpStructureUnitsRegenerated(projectId: projectId, towerId: towerId),
          );
    }
  }

  Future<void> _deleteUnit(BuildContext context, ErpProjectUnit unit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete unit ${unit.unitNo}?'),
        content: Text(
          'Are you sure you want to delete unit ${unit.unitNo} from ${floorLabel(unit.floorNo)}? This will reduce the unit count by 1.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Unit'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (context.mounted) {
      context.read<ErpStructureBloc>().add(
            ErpStructureUnitDeleted(
              projectId: projectId,
              towerId: towerId,
              unitId: unit.id,
            ),
          );
    }
  }

  Future<void> _addUnitToFloor(BuildContext context, int floorNo) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Unit to ${floorLabel(floorNo)}'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Unit No (e.g. B-505)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add Unit'),
          ),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty && context.mounted) {
      context.read<ErpStructureBloc>().add(
            ErpStructureUnitCreated(
              projectId: projectId,
              towerId: towerId,
              body: {
                'unitNo': ctrl.text.trim(),
                'floorNo': floorNo,
              },
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final canWrite = Permissions.canWriteProjects(auth.permissions, auth.user?.role);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<ErpStructureBloc, ErpStructureState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
        if (state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.actionMessage!)),
          );
        }
      },
      builder: (context, state) {
        final tower = state.selectedTower;
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
            elevation: 0,
            title: Text(
              tower?.name ?? 'Manage Tower',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            leading: AppBackButton(fallbackLocation: '/erp/structure/$projectId'),
            actions: [
              if (canWrite)
                HeaderActionButton(
                  tooltip: 'Regenerate units from floors × flats',
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: 'Regenerate',
                  onPressed: () {
                    if (!state.isActing) _regenerate(context);
                  },
                ),
            ],
          ),
          body: () {
            if (state.status == LoadStatus.loading && tower == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.status == LoadStatus.failure && tower == null) {
              return Center(child: Text(state.errorMessage ?? 'Failed to load tower'));
            }
            if (tower == null) {
              return const Center(child: Text('Tower not found'));
            }

            final complete = tower.units.where((u) => u.isComplete).length;
            final duplexBaseUnits = tower.units.where((u) => u.isDuplexBase).toList();
            final duplexUpperUnits = tower.units.where((u) => u.isDuplexUpper).toList();
            final totalSellable = tower.units.length - duplexUpperUnits.length;

            final grouped = <int, List<ErpProjectUnit>>{};
            for (final u in tower.units) {
              grouped.putIfAbsent(u.floorNo, () => []).add(u);
            }

            // Also check all expected floors according to tower structure
            final allExpectedFloors = towerFloorNumbers(tower);
            final allDisplayFloors = <int>{...allExpectedFloors, ...grouped.keys}.toList()..sort();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                _SummaryCard(
                  tower: tower,
                  complete: complete,
                  duplexCount: duplexBaseUnits.length,
                  totalSellable: totalSellable,
                ),
                const SizedBox(height: 14),
                if (tower.units.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: Text('No units. Tap Regenerate to create them.')),
                  )
                else
                  for (final floor in allDisplayFloors) ...[
                    Builder(
                      builder: (context) {
                        final unitsOnFloor = grouped[floor] ?? const <ErpProjectUnit>[];
                        final hasBaseDuplexes = unitsOnFloor.any((u) => u.isDuplexBase);
                        final hasUpperDuplexes = unitsOnFloor.any((u) => u.isDuplexUpper);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                              child: Row(
                                children: [
                                  Text(
                                    floorLabel(floor),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${unitsOnFloor.length} ${unitsOnFloor.length == 1 ? 'unit' : 'units'}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white70 : const Color(0xFF607D8B),
                                      ),
                                    ),
                                  ),
                                  if (hasBaseDuplexes) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563eb).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'DUPLEX LOWER LEVEL',
                                        style: TextStyle(
                                          color: Color(0xFF2563eb),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (hasUpperDuplexes) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'DUPLEX UPPER LEVEL',
                                        style: TextStyle(
                                          color: Color(0xFF7C3AED),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  if (canWrite)
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('Add unit', style: TextStyle(fontSize: 12)),
                                      onPressed: () => _addUnitToFloor(context, floor),
                                    ),
                                ],
                              ),
                            ),
                            if (unitsOnFloor.isEmpty)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  'No units on this floor.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: isDark ? Colors.white54 : const Color(0xFF78909C),
                                  ),
                                ),
                              )
                            else
                              for (final unit in unitsOnFloor)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _UnitTile(
                                    unit: unit,
                                    enabled: canWrite,
                                    onTap: () => context.go(
                                      '/erp/structure/$projectId/towers/$towerId/units/${unit.id}',
                                    ),
                                    onDelete: canWrite ? () => _deleteUnit(context, unit) : null,
                                  ),
                                ),
                          ],
                        );
                      },
                    ),
                  ],
              ],
            );
          }(),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.tower,
    required this.complete,
    required this.duplexCount,
    required this.totalSellable,
  });

  final ErpProjectTower tower;
  final int complete;
  final int duplexCount;
  final int totalSellable;

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
          Row(
            children: [
              Text(
                tower.name,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563eb).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  duplexCount > 0
                      ? '$totalSellable Sellable Units ($duplexCount Duplex)'
                      : '${tower.units.length} Total Units',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2563eb),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${tower.floorCount} floors × ${tower.flatsPerFloor} flats'
            '${tower.hasGround ? '  ·  flats from floor 0' : '  ·  GF parking, flats from floor 1'}'
            '${duplexCount > 0 ? '  ·  $totalSellable units ($duplexCount Duplex • ${tower.units.length} physical units)' : ''}',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : const Color(0xFF607D8B),
            ),
          ),
          if (duplexCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Note: Duplex units span 2 floors each. Upper level floors are kept intact, named with -2, and auto-occupied.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563eb),
                ),
              ),
            ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: tower.units.isEmpty ? 0 : complete / tower.units.length,
            minHeight: 6,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 6),
          Text(
            '$complete of ${tower.units.length} unit spaces configured',
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
    this.onDelete,
  });

  final ErpProjectUnit unit;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUpper = unit.isDuplexUpper;
    final isBase = unit.isDuplexBase;

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
              color: isUpper
                  ? const Color(0xFF7C3AED).withValues(alpha: 0.35)
                  : (isBase
                      ? const Color(0xFF2563eb).withValues(alpha: 0.3)
                      : (isDark
                          ? const Color(0xFFC5A059).withValues(alpha: 0.15)
                          : const Color(0xFFCFD8DC))),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUpper
                      ? const Color(0xFF7C3AED)
                      : (unit.isComplete ? const Color(0xFF16A34A) : const Color(0xFFF59E0B)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          unit.unitNo,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF212F3D),
                          ),
                        ),
                        if (isUpper) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Text(
                              'DUPLEX UPPER (Level 2)',
                              style: TextStyle(
                                color: Color(0xFF7C3AED),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ] else if (isBase) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563eb).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF2563eb).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              'DUPLEX (${floorLabel(unit.floorNo)} + ${floorLabel(unit.floorNo + 1)})',
                              style: const TextStyle(
                                color: Color(0xFF2563eb),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isUpper
                          ? [
                              'Upper Floor Continuation',
                              unit.unitTypeCode ?? 'Duplex Flat',
                              unit.statusCode ?? 'OCCUPIED',
                              if (unit.remarks?.isNotEmpty ?? false) unit.remarks!,
                            ].join(' • ')
                          : [
                              unit.unitTypeCode ?? 'Type not set',
                              if (unit.superBuiltUp != null) '${unit.superBuiltUp} sqft',
                              if (unit.baseRate != null) '₹${unit.baseRate!.toStringAsFixed(0)}/sqft',
                              if (unit.plc != null && unit.plc! > 0) 'PLC: ₹${unit.plc!.toStringAsFixed(0)}/sqft',
                              if (unit.frc != null && unit.frc! > 0) 'FRC: ₹${unit.frc!.toStringAsFixed(0)}/sqft',
                              if (unit.developmentCharge != null && unit.developmentCharge! > 0)
                                'Dev/AMC: ₹${unit.developmentCharge!.toStringAsFixed(0)}/sqft',
                              unit.statusCode ?? 'Status not set',
                              if (unit.totalUnitValue != null)
                                'Unit Val: ${_formatInr(unit.totalUnitValue!)}',
                              if (unit.effectiveGrandTotal > 0)
                                'Total (All Costs): ${_formatInr(unit.effectiveGrandTotal)}',
                            ].join(' • '),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete Unit',
                  icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFEF4444)),
                  onPressed: onDelete,
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

  String _formatInr(double value) {
    if (value >= 10000000) {
      final cr = value / 10000000;
      final crStr = cr == cr.roundToDouble() ? cr.toStringAsFixed(0) : cr.toStringAsFixed(2);
      return '₹${_formatCommas(value.round())} ($crStr Cr)';
    } else if (value >= 100000) {
      final l = value / 100000;
      final lStr = l == l.roundToDouble() ? l.toStringAsFixed(0) : l.toStringAsFixed(2);
      return '₹${_formatCommas(value.round())} ($lStr L)';
    }
    return '₹${_formatCommas(value.round())}';
  }

  String _formatCommas(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    final remaining = s.substring(0, s.length - 3);
    final parts = <String>[];
    var rem = remaining;
    while (rem.length > 2) {
      parts.insert(0, rem.substring(rem.length - 2));
      rem = rem.substring(0, rem.length - 2);
    }
    if (rem.isNotEmpty) parts.insert(0, rem);
    return '${parts.join(',')},$last3';
  }
}
