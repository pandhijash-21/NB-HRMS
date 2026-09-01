import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../domain/structure_models.dart';
import '../../domain/work_order_lookup_keys.dart';
import '../../domain/work_order_models.dart';
import '../project_providers.dart';
import 'work_order_location_picker.dart';

class WorkDetailsEditor extends ConsumerStatefulWidget {
  const WorkDetailsEditor({
    super.key,
    required this.projectId,
    required this.activities,
    required this.configActivities,
    required this.onChanged,
  });

  final String? projectId;
  final List<WorkOrderActivityGroup> activities;
  final List<ErpActivity> configActivities;
  final ValueChanged<List<WorkOrderActivityGroup>> onChanged;

  @override
  ConsumerState<WorkDetailsEditor> createState() => _WorkDetailsEditorState();
}

class _WorkDetailsEditorState extends ConsumerState<WorkDetailsEditor> {
  String? _selectedActivityId;

  List<WorkOrderActivityGroup> get _groups => widget.activities;

  void _emit(List<WorkOrderActivityGroup> groups) => widget.onChanged(groups);

  double get _total =>
      _groups.fold(0, (sum, g) => sum + g.lines.fold(0, (s, l) => s + (l.amount ?? 0)));

  void _addActivity() {
    final act = widget.configActivities.where((a) => a.id == _selectedActivityId).firstOrNull;
    if (act == null) return;
    final lines = act.subtasks.isNotEmpty
        ? act.subtasks
            .where((s) => s.isActive)
            .map((s) => WorkOrderLine(workDetail: s.name))
            .toList()
        : [const WorkOrderLine(workDetail: '')];
    _emit([
      ..._groups,
      WorkOrderActivityGroup(
        activityId: act.id,
        activityName: act.name,
        sortOrder: _groups.length,
        lines: lines,
      ),
    ]);
    setState(() => _selectedActivityId = null);
  }

  void _addLine(int groupIndex) {
    final g = _groups[groupIndex];
    final lines = [...g.lines, const WorkOrderLine(workDetail: '')];
    final next = [..._groups];
    next[groupIndex] = WorkOrderActivityGroup(
      id: g.id,
      activityId: g.activityId,
      activityName: g.activityName,
      sortOrder: g.sortOrder,
      lines: lines,
    );
    _emit(next);
  }

  void _removeLine(int groupIndex, int lineIndex) {
    final g = _groups[groupIndex];
    if (g.lines.length <= 1) return;
    final lines = [...g.lines]..removeAt(lineIndex);
    final next = [..._groups];
    next[groupIndex] = WorkOrderActivityGroup(
      id: g.id,
      activityId: g.activityId,
      activityName: g.activityName,
      sortOrder: g.sortOrder,
      lines: lines,
    );
    _emit(next);
  }

  void _updateLine(int groupIndex, int lineIndex, WorkOrderLine line) {
    final g = _groups[groupIndex];
    final lines = [...g.lines];
    lines[lineIndex] = line;
    final next = [..._groups];
    next[groupIndex] = WorkOrderActivityGroup(
      id: g.id,
      activityId: g.activityId,
      activityName: g.activityName,
      sortOrder: g.sortOrder,
      lines: lines,
    );
    _emit(next);
  }

  void _removeGroup(int groupIndex) {
    final next = [..._groups]..removeAt(groupIndex);
    _emit(next);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final towersAsync = widget.projectId == null
        ? const AsyncValue<List<ErpProjectTower>>.data([])
        : ref.watch(projectTowersProvider(widget.projectId!));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? const Color(0xFFC5A059).withValues(alpha: 0.12)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563eb),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add Work Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(
                      'Select activities, then fill quantity, unit, and rate per line',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252220) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedActivityId,
                    decoration: InputDecoration(
                      labelText: 'Activity *',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    hint: const Text('Select activity'),
                    items: widget.configActivities
                        .where((a) => a.isActive)
                        .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedActivityId = v),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _selectedActivityId == null ? null : _addActivity,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563eb),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_groups.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0),
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.table_rows_outlined, size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'No work lines yet',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.projectId == null
                        ? 'Select a project first, then add an activity.'
                        : 'Pick an activity above and tap Add.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            towersAsync.when(
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )),
              error: (e, _) => Text('$e'),
              data: (towers) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 44,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 72,
                    headingRowColor: WidgetStateProperty.all(
                      isDark ? const Color(0xFF252220) : const Color(0xFFE8F4FC),
                    ),
                    columnSpacing: 16,
                    horizontalMargin: 16,
                    columns: const [
                      DataColumn(label: Text('SR#', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('ACTIVITY', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('WORK DETAILS', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('BLOCK', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('FLOOR', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('UNIT', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('QTY', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('UNIT', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('RATE', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('AMOUNT', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('')),
                    ],
                    rows: _buildRows(context, towers, isDark),
                  ),
                ),
              ),
            ),
          if (_groups.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0d9488).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF0d9488).withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  Text(
                    '₹ ${_total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Color(0xFF0d9488),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<DataRow> _buildRows(BuildContext context, List<ErpProjectTower> towers, bool isDark) {
    final rows = <DataRow>[];
    var sr = 0;
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
    );

    for (var gi = 0; gi < _groups.length; gi++) {
      final g = _groups[gi];
      for (var li = 0; li < g.lines.length; li++) {
        sr++;
        final line = g.lines[li];
        final loc = LocationSelection(
          towerIds: line.towerIds,
          floorNos: line.floorNos,
          unitIds: line.unitIds,
        );
        final qtyCtrl = TextEditingController(text: line.quantity?.toString() ?? '');
        final rateCtrl = TextEditingController(text: line.rate?.toString() ?? '');
        final detailCtrl = TextEditingController(text: line.workDetail);

        rows.add(
          DataRow(
            cells: [
              DataCell(Text('$sr', style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(
                li == 0
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563eb).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              g.activityName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563eb),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            tooltip: 'Add work line',
                            color: const Color(0xFF2563eb),
                            onPressed: () => _addLine(gi),
                          ),
                          if (_groups.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              tooltip: 'Remove activity',
                              color: Colors.red.shade400,
                              onPressed: () => _removeGroup(gi),
                            ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              DataCell(
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: detailCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Work detail',
                      border: inputBorder,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onChanged: (v) => _updateLine(gi, li, line.copyWith(workDetail: v)),
                  ),
                ),
              ),
              DataCell(
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2563eb),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: widget.projectId == null
                      ? null
                      : () async {
                          final picked = await showWorkOrderLocationPicker(
                            context: context,
                            towers: towers,
                            initial: loc,
                          );
                          if (picked != null) {
                            _updateLine(
                              gi,
                              li,
                              line.copyWith(
                                towerIds: picked.towerIds,
                                floorNos: picked.floorNos,
                                unitIds: picked.unitIds,
                              ),
                            );
                          }
                        },
                  child: Text(loc.towerLabel(towers), style: const TextStyle(fontSize: 12)),
                ),
              ),
              DataCell(Text(loc.floorLabel(), style: const TextStyle(fontSize: 12))),
              DataCell(Text(loc.unitLabel(), style: const TextStyle(fontSize: 12))),
              DataCell(
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      border: inputBorder,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onChanged: (v) {
                      final q = double.tryParse(v);
                      final amt = q != null && line.rate != null ? q * line.rate! : null;
                      _updateLine(gi, li, line.copyWith(quantity: q, amount: amt));
                    },
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 100,
                  child: lookupDropdown(
                    ref: ref,
                    category: kWoMeasurementUnit,
                    value: line.unitCode,
                    label: '',
                    onChanged: (v) => _updateLine(gi, li, line.copyWith(unitCode: v)),
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: rateCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      border: inputBorder,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onChanged: (v) {
                      final r = double.tryParse(v);
                      final amt = r != null && line.quantity != null ? r * line.quantity! : null;
                      _updateLine(gi, li, line.copyWith(rate: r, amount: amt));
                    },
                  ),
                ),
              ),
              DataCell(
                Text(
                  (line.amount ?? 0).toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              DataCell(
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400, size: 20),
                  onPressed: g.lines.length > 1 ? () => _removeLine(gi, li) : null,
                ),
              ),
            ],
          ),
        );
      }
    }
    return rows;
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
