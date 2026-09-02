import 'package:flutter/material.dart';

import '../../domain/boq_models.dart';
import '../../domain/structure_models.dart';
import 'work_order_location_picker.dart';

/// Read-only BOQ task table — used on the BOQ list page.
class BoqSummaryPanel extends StatelessWidget {
  const BoqSummaryPanel({
    super.key,
    required this.tasks,
    this.towers = const [],
    this.showTotals = false,
  });

  final List<ErpBoqTask> tasks;
  final List<ErpProjectTower> towers;
  final bool showTotals;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No tasks in this BOQ yet.',
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BoqTasksSummaryTable(tasks: tasks, towers: towers),
        if (showTotals) ...[
          const SizedBox(height: 12),
          BoqSummaryTotals(tasks: tasks),
        ],
      ],
    );
  }
}

class BoqTasksSummaryTable extends StatelessWidget {
  const BoqTasksSummaryTable({
    super.key,
    required this.tasks,
    this.towers = const [],
  });

  final List<ErpBoqTask> tasks;
  final List<ErpProjectTower> towers;

  bool _showActivityName(int i) {
    if (i == 0) return true;
    return tasks[i].activityId != tasks[i - 1].activityId;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? const Color(0xFF252220) : const Color(0xFFE8F4FC);
    const headerStyle = TextStyle(fontWeight: FontWeight.w700, fontSize: 11);
    const cellStyle = TextStyle(fontSize: 12);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth;
        return Container(
          width: tableWidth,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: tableWidth),
              child: DataTable(
                headingRowHeight: 38,
                dataRowMinHeight: 42,
                dataRowMaxHeight: 52,
                headingRowColor: WidgetStateProperty.all(headerBg),
                columnSpacing: 12,
                horizontalMargin: 10,
                columns: const [
                  DataColumn(label: Text('SR#', style: headerStyle)),
                  DataColumn(label: Text('ACTIVITY', style: headerStyle)),
                  DataColumn(label: Text('SUB-ACTIVITY', style: headerStyle)),
                  DataColumn(label: Text('BLOCK', style: headerStyle)),
                  DataColumn(label: Text('FLOOR', style: headerStyle)),
                  DataColumn(label: Text('UNITS', style: headerStyle)),
                  DataColumn(label: Text('QOW', style: headerStyle)),
                  DataColumn(label: Text('UNIT', style: headerStyle)),
                  DataColumn(label: Text('RATE', style: headerStyle)),
                  DataColumn(label: Text('AMOUNT', style: headerStyle)),
                  DataColumn(label: Text('MAT', style: headerStyle)),
                  DataColumn(label: Text('MCH', style: headerStyle)),
                  DataColumn(label: Text('LAB', style: headerStyle)),
                ],
                rows: [
                  for (var i = 0; i < tasks.length; i++) _row(i, tasks[i], isDark, cellStyle, towers),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  DataRow _row(int i, ErpBoqTask task, bool isDark, TextStyle cellStyle, List<ErpProjectTower> towers) {
    final loc = LocationSelection(
      towerIds: task.towerIds,
      floorNos: task.floorNos,
      unitIds: task.unitIds,
    );

    return DataRow(
      color: WidgetStateProperty.all(
        i.isEven
            ? (isDark ? const Color(0xFF1E1B18) : Colors.white)
            : (isDark ? const Color(0xFF252220) : const Color(0xFFF8FAFC)),
      ),
      cells: [
        DataCell(Text('${i + 1}', style: cellStyle.copyWith(fontWeight: FontWeight.w600))),
        DataCell(
          Text(
            _showActivityName(i) ? task.activityName : '↳',
            style: cellStyle.copyWith(
              fontWeight: _showActivityName(i) ? FontWeight.w600 : FontWeight.normal,
              color: _showActivityName(i) ? null : Colors.grey,
            ),
          ),
        ),
        DataCell(Text(task.taskName, style: cellStyle)),
        DataCell(Text(loc.towerLabel(towers), style: cellStyle.copyWith(color: const Color(0xFF2563eb)))),
        DataCell(Text(loc.floorLabel(), style: cellStyle)),
        DataCell(Text(loc.unitLabel(), style: cellStyle)),
        DataCell(Text(task.quantity?.toStringAsFixed(2) ?? '—', style: cellStyle)),
        DataCell(Text(task.unitCode ?? '—', style: cellStyle)),
        DataCell(Text(task.rate?.toStringAsFixed(2) ?? '—', style: cellStyle)),
        DataCell(Text(
          task.computedAmount.toStringAsFixed(2),
          style: cellStyle.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF0d9488)),
        )),
        DataCell(Text(task.materialAmount.toStringAsFixed(0), style: cellStyle.copyWith(fontSize: 11))),
        DataCell(Text(task.machineAmount.toStringAsFixed(0), style: cellStyle.copyWith(fontSize: 11))),
        DataCell(Text(task.labourAmount.toStringAsFixed(0), style: cellStyle.copyWith(fontSize: 11))),
      ],
    );
  }
}

class BoqSummaryTotals extends StatelessWidget {
  const BoqSummaryTotals({super.key, required this.tasks});

  final List<ErpBoqTask> tasks;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalQty = tasks.fold(0.0, (s, t) => s + (t.quantity ?? 0));
    final totalAmt = tasks.fold(0.0, (s, t) => s + t.computedAmount);
    final totalMat = tasks.fold(0.0, (s, t) => s + t.materialAmount);
    final totalMac = tasks.fold(0.0, (s, t) => s + t.machineAmount);
    final totalLab = tasks.fold(0.0, (s, t) => s + t.labourAmount);
    final grand = totalAmt + totalMat + totalMac + totalLab;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BOQ Summary',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 560;
              final tiles = [
                _SummaryTile(label: 'Total Qty', value: totalQty.toStringAsFixed(2), icon: Icons.straighten),
                _SummaryTile(label: 'Work Amount', value: totalAmt.toStringAsFixed(2), icon: Icons.payments_outlined, accent: const Color(0xFF2563eb)),
                _SummaryTile(label: 'Material', value: totalMat.toStringAsFixed(2), icon: Icons.inventory_2_outlined, accent: const Color(0xFF0EA5E9)),
                _SummaryTile(label: 'Machine', value: totalMac.toStringAsFixed(2), icon: Icons.precision_manufacturing_outlined, accent: const Color(0xFF8B5CF6)),
                _SummaryTile(label: 'Labour', value: totalLab.toStringAsFixed(2), icon: Icons.engineering_outlined, accent: const Color(0xFFF59E0B)),
              ];
              if (wide) {
                return Row(
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: tiles[i]),
                    ],
                  ],
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tiles.map((t) => SizedBox(width: (constraints.maxWidth - 8) / 2, child: t)).toList(),
              );
            },
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2563eb), Color(0xFF1d4ed8)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.summarize_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Grand Total (Work + Material + Machine + Labour)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                Text(
                  grand.toStringAsFixed(2),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = accent ?? (isDark ? Colors.white70 : const Color(0xFF64748B));
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2622) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
