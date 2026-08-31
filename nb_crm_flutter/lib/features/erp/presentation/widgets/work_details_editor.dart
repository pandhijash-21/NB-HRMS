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
    final towersAsync = widget.projectId == null
        ? const AsyncValue<List<ErpProjectTower>>.data([])
        : ref.watch(projectTowersProvider(widget.projectId!));

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Work Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedActivityId,
                    decoration: const InputDecoration(
                      labelText: 'Activity *',
                      border: OutlineInputBorder(),
                    ),
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
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_groups.isEmpty)
              const Text('Add an activity to start entering work details.')
            else
              towersAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (towers) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFE8F4FC)),
                    columns: const [
                      DataColumn(label: Text('SR#')),
                      DataColumn(label: Text('ACTIVITY')),
                      DataColumn(label: Text('WORK DETAILS')),
                      DataColumn(label: Text('BLOCK')),
                      DataColumn(label: Text('FLOOR')),
                      DataColumn(label: Text('UNIT')),
                      DataColumn(label: Text('QTY')),
                      DataColumn(label: Text('UNIT')),
                      DataColumn(label: Text('RATE')),
                      DataColumn(label: Text('AMOUNT')),
                      DataColumn(label: Text('')),
                    ],
                    rows: _buildRows(context, towers),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: ₹ ${_total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DataRow> _buildRows(BuildContext context, List<ErpProjectTower> towers) {
    final rows = <DataRow>[];
    var sr = 0;
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
              DataCell(Text('$sr')),
              DataCell(
                li == 0
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(g.activityName),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            tooltip: 'Add work line',
                            onPressed: () => _addLine(gi),
                          ),
                          if (_groups.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                              tooltip: 'Remove activity',
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
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                    onChanged: (v) => _updateLine(
                      gi,
                      li,
                      line.copyWith(workDetail: v),
                    ),
                  ),
                ),
              ),
              DataCell(
                TextButton(
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
                  child: Text(loc.towerLabel(towers)),
                ),
              ),
              DataCell(Text(loc.floorLabel())),
              DataCell(Text(loc.unitLabel())),
              DataCell(
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
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
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                    onChanged: (v) {
                      final r = double.tryParse(v);
                      final amt = r != null && line.quantity != null ? r * line.quantity! : null;
                      _updateLine(gi, li, line.copyWith(rate: r, amount: amt));
                    },
                  ),
                ),
              ),
              DataCell(Text((line.amount ?? 0).toStringAsFixed(2))),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
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
