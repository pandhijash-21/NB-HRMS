import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../domain/boq_models.dart';
import '../../domain/resource_models.dart';
import '../../domain/structure_models.dart';
import '../../domain/work_order_lookup_keys.dart';
import '../../domain/work_order_models.dart';
import '../boq_providers.dart';
import '../project_providers.dart';
import 'work_order_location_picker.dart';
import 'boq_summary_panel.dart';

class BoqTasksEditor extends ConsumerStatefulWidget {
  const BoqTasksEditor({
    super.key,
    required this.projectId,
    required this.tasks,
    required this.configActivities,
    required this.onChanged,
    this.showTaskIds = false,
  });

  final String? projectId;
  final List<ErpBoqTask> tasks;
  final List<ErpActivity> configActivities;
  final ValueChanged<List<ErpBoqTask>> onChanged;
  /// Task IDs are assigned by the server on save — show column only for saved BOQs.
  final bool showTaskIds;

  @override
  ConsumerState<BoqTasksEditor> createState() => _BoqTasksEditorState();
}

class _BoqTasksEditorState extends ConsumerState<BoqTasksEditor> {
  String? _selectedActivityId;

  List<ErpBoqTask> get _tasks => widget.tasks;

  void _emit(List<ErpBoqTask> tasks) {
    final ordered = [
      for (var i = 0; i < tasks.length; i++) tasks[i].copyWith(sortOrder: i),
    ];
    widget.onChanged(ordered);
  }

  List<ErpActivity> get _availableActivities {
    return widget.configActivities.where((a) {
      if (!a.isActive) return false;
      final subs = a.subtasks.where((s) => s.isActive).toList();
      if (subs.isEmpty) {
        return !_tasks.any((t) => t.activityId == a.id);
      }
      final usedSubIds = _tasks
          .where((t) => t.activityId == a.id)
          .map((t) => t.subtaskId)
          .whereType<String>()
          .toSet();
      return subs.any((s) => !usedSubIds.contains(s.id));
    }).toList();
  }

  String _activityLabel(ErpActivity a) {
    final subs = a.subtasks.where((s) => s.isActive).toList();
    if (subs.isEmpty) return a.name;
    final used = _tasks.where((t) => t.activityId == a.id).length;
    final remaining = subs.length - used;
    return '${a.name} ($remaining sub-activit${remaining == 1 ? 'y' : 'ies'} left)';
  }

  void _addActivity() {
    final act = widget.configActivities.where((a) => a.id == _selectedActivityId).firstOrNull;
    if (act == null) return;
    final existingSubIds = _tasks
        .where((t) => t.activityId == act.id)
        .map((t) => t.subtaskId)
        .whereType<String>()
        .toSet();
    final newTasks = <ErpBoqTask>[];
    final subs = act.subtasks.where((s) => s.isActive).toList();
    if (subs.isEmpty) {
      newTasks.add(ErpBoqTask(
        activityId: act.id,
        activityName: act.name,
        taskName: act.name,
        sortOrder: _tasks.length,
      ));
    } else {
      for (final s in subs) {
        if (existingSubIds.contains(s.id)) continue;
        newTasks.add(ErpBoqTask(
          activityId: act.id,
          activityName: act.name,
          subtaskId: s.id,
          taskName: s.name,
          taskDescription: s.description,
          sortOrder: _tasks.length + newTasks.length,
        ));
      }
    }
    if (newTasks.isEmpty) return;
    _emit([..._tasks, ...newTasks]);
    setState(() => _selectedActivityId = null);
  }

  void _addCustomSubtask(String activityId, String activityName) {
    _emit([
      ..._tasks,
      ErpBoqTask(
        activityId: activityId,
        activityName: activityName,
        taskName: '',
        isCustomSubtask: true,
        sortOrder: _tasks.length,
      ),
    ]);
  }

  void _updateTask(int i, ErpBoqTask task) {
    final next = [..._tasks];
    next[i] = task;
    _emit(next);
  }

  void _removeTask(int i) {
    final next = [..._tasks]..removeAt(i);
    _emit(next);
  }

  ErpBoqTask _withResourceTotals(ErpBoqTask task, List<ErpBoqTaskResource> resources) {
    final mat = resources.where((r) => r.resourceType == 'MATERIAL').fold(0.0, (s, r) => s + r.totalPrice);
    final mac = resources.where((r) => r.resourceType == 'MACHINE').fold(0.0, (s, r) => s + r.totalPrice);
    final lab = resources.where((r) => r.resourceType == 'LABOUR').fold(0.0, (s, r) => s + r.totalPrice);
    return task.copyWith(
      resources: resources,
      materialAmount: mat,
      machineAmount: mac,
      labourAmount: lab,
    );
  }

  Future<void> _openResourceManager(int taskIndex, String type) async {
    final task = _tasks[taskIndex];
    List<ErpMaterial> materials;
    List<ErpMachine> machines;
    List<ErpLabour> labour;
    try {
      materials = await ref.read(erpMaterialsProvider.future);
      machines = await ref.read(erpMachinesProvider.future);
      labour = await ref.read(erpLabourProvider.future);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load resources: $e')));
      }
      return;
    }

    if (!mounted) return;
    final updated = await showModalBottomSheet<List<ErpBoqTaskResource>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _ResourceManagerSheet(
        type: type,
        resources: task.resources.where((r) => r.resourceType == type).toList(),
        materials: materials,
        machines: machines,
        labour: labour,
      ),
    );
    if (updated == null) return;
    final other = task.resources.where((r) => r.resourceType != type).toList();
    _updateTask(taskIndex, _withResourceTotals(task, [...other, ...updated]));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Prefetch resource catalogs so add dialogs are populated.
    ref.watch(erpMaterialsProvider);
    ref.watch(erpMachinesProvider);
    ref.watch(erpLabourProvider);
    final towersAsync = widget.projectId == null
        ? const AsyncValue<List<ErpProjectTower>>.data([])
        : ref.watch(projectTowersProvider(widget.projectId!));

    final activityIds = <String>[];
    for (final t in _tasks) {
      final id = t.activityId;
      if (id != null && !activityIds.contains(id)) activityIds.add(id);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tasks & Sub-activities',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Pick an activity to add all configured sub-activities as separate rows. Task IDs are generated when you save.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedActivityId,
                  decoration: const InputDecoration(
                    labelText: 'Activity',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _availableActivities
                      .map((a) => DropdownMenuItem(value: a.id, child: Text(_activityLabel(a))))
                      .toList(),
                  onChanged: _availableActivities.isEmpty ? null : (v) => setState(() => _selectedActivityId = v),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _selectedActivityId == null ? null : _addActivity,
                child: const Text('Add activity'),
              ),
            ],
          ),
          if (activityIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: activityIds.map((aid) {
                final name = _tasks.firstWhere((t) => t.activityId == aid).activityName;
                return OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text('Custom sub-activity under $name'),
                  onPressed: () => _addCustomSubtask(aid, name),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          if (_tasks.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2622) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text('No tasks yet. Select an activity above to load its sub-activities.'),
              ),
            )
          else
            towersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (towers) => _TaskTable(
                tasks: _tasks,
                towers: towers,
                showTaskIds: widget.showTaskIds,
                onUpdate: _updateTask,
                onRemove: _removeTask,
                onManageResources: _openResourceManager,
              ),
            ),
          if (_tasks.isNotEmpty) ...[
            const SizedBox(height: 16),
            BoqSummaryTotals(tasks: _tasks),
          ],
        ],
      ),
    );
  }
}

class _TaskTable extends ConsumerStatefulWidget {
  const _TaskTable({
    required this.tasks,
    required this.towers,
    required this.showTaskIds,
    required this.onUpdate,
    required this.onRemove,
    required this.onManageResources,
  });

  final List<ErpBoqTask> tasks;
  final List<ErpProjectTower> towers;
  final bool showTaskIds;
  final void Function(int, ErpBoqTask) onUpdate;
  final void Function(int) onRemove;
  final Future<void> Function(int, String) onManageResources;

  @override
  ConsumerState<_TaskTable> createState() => _TaskTableState();
}

class _TaskTableState extends ConsumerState<_TaskTable> {
  InputDecoration _cellInput(bool isDark, {String? hint}) => InputDecoration(
        isDense: true,
        hintText: hint,
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2622) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2563eb), width: 1.5),
        ),
      );

  bool _showActivityName(int i) {
    if (i == 0) return true;
    return widget.tasks[i].activityId != widget.tasks[i - 1].activityId;
  }

  String _rowKey(ErpBoqTask task, int index) =>
      'row-${task.activityId ?? ''}-${task.subtaskId ?? ''}-${task.sortOrder}-$index';

  final Map<String, _BoqRowFields> _fields = {};

  @override
  void dispose() {
    for (final f in _fields.values) {
      f.dispose();
    }
    _fields.clear();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _TaskTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final liveKeys = <String>{};
    for (var i = 0; i < widget.tasks.length; i++) {
      liveKeys.add(_rowKey(widget.tasks[i], i));
    }
    final stale = _fields.keys.where((k) => !liveKeys.contains(k)).toList();
    for (final k in stale) {
      _fields.remove(k)?.dispose();
    }
  }

  _BoqRowFields _fieldsFor(int index, ErpBoqTask task) {
    final key = _rowKey(task, index);
    final existing = _fields[key];
    if (existing != null) {
      existing.syncFrom(task);
      return existing;
    }
    final created = _BoqRowFields(task);
    created.qtyFocus.addListener(() {
      if (!created.qtyFocus.hasFocus) _commitQtyRate(index, task, created);
    });
    created.rateFocus.addListener(() {
      if (!created.rateFocus.hasFocus) _commitQtyRate(index, task, created);
    });
    _fields[key] = created;
    return created;
  }

  double _previewAmount(ErpBoqTask task, _BoqRowFields fields) {
    final q = double.tryParse(fields.qty.text.trim());
    final r = double.tryParse(fields.rate.text.trim());
    if (q != null && r != null) return q * r;
    return task.computedAmount;
  }

  void _commitQtyRate(int index, ErpBoqTask task, _BoqRowFields fields) {
    final q = double.tryParse(fields.qty.text.trim());
    final r = double.tryParse(fields.rate.text.trim());
    final amt = q != null && r != null ? q * r : task.amount;
    widget.onUpdate(index, task.copyWith(quantity: q, rate: r, amount: amt));
  }

  void _commitDesc(int index, ErpBoqTask task, _BoqRowFields fields) {
    final v = fields.desc.text.trim();
    widget.onUpdate(index, task.copyWith(taskDescription: v.isEmpty ? null : v));
  }

  void _commitName(int index, ErpBoqTask task, _BoqRowFields fields) {
    if (fields.name == null) return;
    widget.onUpdate(index, task.copyWith(taskName: fields.name!.text));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? const Color(0xFF252220) : const Color(0xFFE8F4FC);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 44,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 80,
          headingRowColor: WidgetStateProperty.all(headerBg),
          columnSpacing: 12,
          horizontalMargin: 14,
          columns: [
            const DataColumn(label: Text('SR#', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            const DataColumn(label: Text('ACTIVITY', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            if (widget.showTaskIds)
              const DataColumn(label: Text('TASK ID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            const DataColumn(label: Text('SUB-ACTIVITY', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            const DataColumn(label: Text('DESCRIPTION', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            const DataColumn(label: Text('RESOURCES', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            const DataColumn(label: Text('BLOCK', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            const DataColumn(label: Text('FLOOR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            const DataColumn(label: Text('UNITS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            const DataColumn(label: Text('QOW', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            const DataColumn(label: Text('UNIT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            const DataColumn(label: Text('RATE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            const DataColumn(label: Text('AMOUNT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            const DataColumn(label: Text('')),
          ],
          rows: [
            for (var i = 0; i < widget.tasks.length; i++)
              _buildRow(context, i, widget.tasks[i], isDark),
          ],
        ),
      ),
    );
  }

  DataRow _buildRow(BuildContext context, int i, ErpBoqTask task, bool isDark) {
    final fields = _fieldsFor(i, task);
    final loc = LocationSelection(
      towerIds: task.towerIds,
      floorNos: task.floorNos,
      unitIds: task.unitIds,
    );
    final input = _cellInput(isDark);
    final amount = _previewAmount(task, fields);

    return DataRow(
      color: WidgetStateProperty.all(
        i.isEven
            ? (isDark ? const Color(0xFF1E1B18) : Colors.white)
            : (isDark ? const Color(0xFF252220) : const Color(0xFFF8FAFC)),
      ),
      cells: [
        DataCell(Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(
          SizedBox(
            width: 110,
            child: _showActivityName(i)
                ? Text(task.activityName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))
                : const Text('↳', style: TextStyle(color: Colors.grey)),
          ),
        ),
        if (widget.showTaskIds)
          DataCell(
            task.taskId != null && task.taskId!.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(task.taskId!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  )
                : const Text('—', style: TextStyle(color: Colors.grey)),
          ),
        DataCell(
          SizedBox(
            width: 130,
            child: task.isCustomSubtask
                ? TextField(
                    controller: fields.name,
                    style: const TextStyle(fontSize: 13),
                    decoration: input.copyWith(hintText: 'Sub-activity'),
                    onEditingComplete: () => _commitName(i, task, fields),
                    onSubmitted: (_) => _commitName(i, task, fields),
                  )
                : Text(task.taskName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ),
        DataCell(
          SizedBox(
            width: 160,
            child: TextField(
              controller: fields.desc,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              decoration: input.copyWith(hintText: 'Description'),
              onEditingComplete: () => _commitDesc(i, task, fields),
              onSubmitted: (_) => _commitDesc(i, task, fields),
            ),
          ),
        ),
        DataCell(_ResourceButtons(
          task: task,
          onManage: (type) => widget.onManageResources(i, type),
        )),
        DataCell(
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2563eb),
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            onPressed: () async {
              final sel = await showWorkOrderLocationPicker(
                context: context,
                towers: widget.towers,
                initial: loc,
              );
              if (sel == null) return;
              widget.onUpdate(
                i,
                task.copyWith(towerIds: sel.towerIds, floorNos: sel.floorNos, unitIds: sel.unitIds),
              );
            },
            child: Text(loc.towerLabel(widget.towers), style: const TextStyle(fontSize: 12)),
          ),
        ),
        DataCell(Text(loc.floorLabel(), style: const TextStyle(fontSize: 12))),
        DataCell(Text(loc.unitLabel(), style: const TextStyle(fontSize: 12))),
        DataCell(
          SizedBox(
            width: 76,
            child: TextField(
              controller: fields.qty,
              focusNode: fields.qtyFocus,
              style: const TextStyle(fontSize: 13),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: input.copyWith(hintText: '0'),
              onChanged: (_) => setState(() {}),
              onEditingComplete: () => _commitQtyRate(i, task, fields),
              onSubmitted: (_) => _commitQtyRate(i, task, fields),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 108,
            child: lookupDropdown(
              ref: ref,
              category: kWoMeasurementUnit,
              value: task.unitCode,
              label: '',
              onChanged: (v) => widget.onUpdate(i, task.copyWith(unitCode: v)),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 76,
            child: TextField(
              controller: fields.rate,
              focusNode: fields.rateFocus,
              style: const TextStyle(fontSize: 13),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: input.copyWith(hintText: '0'),
              onChanged: (_) => setState(() {}),
              onEditingComplete: () => _commitQtyRate(i, task, fields),
              onSubmitted: (_) => _commitQtyRate(i, task, fields),
            ),
          ),
        ),
        DataCell(
          Text(
            amount.toStringAsFixed(2),
            style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0d9488)),
          ),
        ),
        DataCell(
          IconButton(
            tooltip: 'Remove task',
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            onPressed: () => widget.onRemove(i),
          ),
        ),
      ],
    );
  }
}

class _BoqRowFields {
  _BoqRowFields(ErpBoqTask task)
      : qty = TextEditingController(text: _BoqRowFields._numText(task.quantity)),
        rate = TextEditingController(text: _BoqRowFields._numText(task.rate)),
        desc = TextEditingController(text: task.taskDescription ?? ''),
        name = task.isCustomSubtask ? TextEditingController(text: task.taskName) : null,
        qtyFocus = FocusNode(),
        rateFocus = FocusNode();

  final TextEditingController qty;
  final TextEditingController rate;
  final TextEditingController desc;
  final TextEditingController? name;
  final FocusNode qtyFocus;
  final FocusNode rateFocus;

  static String _numText(double? v) {
    if (v == null) return '';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  void syncFrom(ErpBoqTask task) {
    if (!qtyFocus.hasFocus) qty.text = _numText(task.quantity);
    if (!rateFocus.hasFocus) rate.text = _numText(task.rate);
    if (task.taskDescription != desc.text) {
      desc.text = task.taskDescription ?? '';
    }
    if (name != null && task.taskName != name!.text) {
      name!.text = task.taskName;
    }
  }

  void dispose() {
    qty.dispose();
    rate.dispose();
    desc.dispose();
    name?.dispose();
    qtyFocus.dispose();
    rateFocus.dispose();
  }
}

class _ResourceButtons extends StatelessWidget {
  const _ResourceButtons({required this.task, required this.onManage});

  final ErpBoqTask task;
  final void Function(String type) onManage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CompactResourceBtn(
          tooltip: 'Material',
          label: 'Mat',
          icon: Icons.inventory_2_outlined,
          color: const Color(0xFF0EA5E9),
          count: task.resources.where((r) => r.resourceType == 'MATERIAL').length,
          amount: task.materialAmount,
          onTap: () => onManage('MATERIAL'),
        ),
        const SizedBox(width: 6),
        _CompactResourceBtn(
          tooltip: 'Machine',
          label: 'Mch',
          icon: Icons.precision_manufacturing_outlined,
          color: const Color(0xFF8B5CF6),
          count: task.resources.where((r) => r.resourceType == 'MACHINE').length,
          amount: task.machineAmount,
          onTap: () => onManage('MACHINE'),
        ),
        const SizedBox(width: 6),
        _CompactResourceBtn(
          tooltip: 'Labour',
          label: 'Lab',
          icon: Icons.engineering_outlined,
          color: const Color(0xFFF59E0B),
          count: task.resources.where((r) => r.resourceType == 'LABOUR').length,
          amount: task.labourAmount,
          onTap: () => onManage('LABOUR'),
        ),
      ],
    );
  }
}

class _CompactResourceBtn extends StatelessWidget {
  const _CompactResourceBtn({
    required this.tooltip,
    required this.label,
    required this.icon,
    required this.color,
    required this.count,
    required this.amount,
    required this.onTap,
  });

  final String tooltip;
  final String label;
  final IconData icon;
  final Color color;
  final int count;
  final double amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amountLabel = amount > 0 ? amount.toStringAsFixed(0) : null;
    return Tooltip(
      message: [
        tooltip,
        if (count > 0) '$count item${count == 1 ? '' : 's'}',
        if (amountLabel != null) '₹$amountLabel',
      ].join(' · '),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                backgroundColor: color,
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
              if (amountLabel != null)
                Text(amountLabel, style: TextStyle(fontSize: 8, color: color.withValues(alpha: 0.85))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceManagerSheet extends StatefulWidget {
  const _ResourceManagerSheet({
    required this.type,
    required this.resources,
    required this.materials,
    required this.machines,
    required this.labour,
  });

  final String type;
  final List<ErpBoqTaskResource> resources;
  final List<ErpMaterial> materials;
  final List<ErpMachine> machines;
  final List<ErpLabour> labour;

  @override
  State<_ResourceManagerSheet> createState() => _ResourceManagerSheetState();
}

class _ResourceManagerSheetState extends State<_ResourceManagerSheet> {
  late List<ErpBoqTaskResource> _items;

  @override
  void initState() {
    super.initState();
    _items = [...widget.resources];
  }

  String get _title {
    return switch (widget.type) {
      'MATERIAL' => 'Materials',
      'MACHINE' => 'Machines',
      _ => 'Labour',
    };
  }

  Future<void> _addItem() async {
    final picked = await showDialog<ErpBoqTaskResource>(
      context: context,
      builder: (ctx) => _ResourceAddDialog(
        type: widget.type,
        materials: widget.materials,
        machines: widget.machines,
        labour: widget.labour,
      ),
    );
    if (picked == null) return;
    setState(() => _items = [..._items, picked]);
  }

  void _updateItem(int i, ErpBoqTaskResource r) {
    setState(() {
      final next = [..._items];
      next[i] = r;
      _items = next;
    });
  }

  void _removeItem(int i) {
    setState(() => _items = [..._items]..removeAt(i));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(_title, style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              FilledButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No items added yet.')),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final r = _items[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      [
                        if (r.brand != null && r.brand!.isNotEmpty) r.brand,
                        if (r.unitCode != null) r.unitCode,
                        'Qty ${r.quantity} × ${r.unitPrice.toStringAsFixed(2)} = ${r.totalPrice.toStringAsFixed(2)}',
                        if (r.remarks != null) r.remarks,
                      ].whereType<String>().join(' · '),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () async {
                            final edited = await showDialog<ErpBoqTaskResource>(
                              context: context,
                              builder: (c) => _ResourceEditDialog(
                                resource: r,
                                type: widget.type,
                                materials: widget.materials,
                                machines: widget.machines,
                              ),
                            );
                            if (edited != null) _updateItem(i, edited);
                          },
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          onPressed: () => _removeItem(i),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(context, _items),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _ResourceAddDialog extends StatefulWidget {
  const _ResourceAddDialog({
    required this.type,
    required this.materials,
    required this.machines,
    required this.labour,
  });

  final String type;
  final List<ErpMaterial> materials;
  final List<ErpMachine> machines;
  final List<ErpLabour> labour;

  @override
  State<_ResourceAddDialog> createState() => _ResourceAddDialogState();
}

class _ResourceAddDialogState extends State<_ResourceAddDialog> {
  String? _selectedId;
  final _searchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  String? _qtyError;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  _ResourceTypeMeta get _meta => _ResourceTypeMeta.forType(widget.type);

  bool get _tracksStock => widget.type == 'MATERIAL' || widget.type == 'MACHINE';

  InputDecoration _fieldDec(String label, {String? hint, String? error}) => InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        isDense: true,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _meta.color, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  List<_ResourcePickItem> get _catalog {
    if (widget.type == 'MATERIAL') {
      return widget.materials
          .where((m) => m.isActive)
          .map((m) => _ResourcePickItem(
                id: m.id,
                title: '${m.brand != null && m.brand!.isNotEmpty ? '${m.brand} · ' : ''}${m.name}',
                subtitle: [
                  if (m.size != null && m.size!.isNotEmpty) m.size,
                  if (m.unitCode != null) m.unitCode,
                  '${m.qtyAvailable.toStringAsFixed(2)} available',
                ].join(' · '),
                availableQty: m.qtyAvailable,
              ))
          .toList();
    }
    if (widget.type == 'MACHINE') {
      return widget.machines
          .where((m) => m.isActive)
          .map((m) => _ResourcePickItem(
                id: m.id,
                title: '${m.brand != null && m.brand!.isNotEmpty ? '${m.brand} · ' : ''}${m.name}',
                subtitle: [
                  if (m.size != null && m.size!.isNotEmpty) m.size,
                  if (m.unitCode != null) m.unitCode,
                  '${m.qtyAvailable.toStringAsFixed(2)} available',
                ].join(' · '),
                availableQty: m.qtyAvailable,
              ))
          .toList();
    }
    return widget.labour
        .where((l) => l.isActive)
        .map((l) => _ResourcePickItem(
              id: l.id,
              title: l.name,
              subtitle: [
                if (l.unitCode != null) l.unitCode,
                if (l.defaultRate != null) 'Default rate ${l.defaultRate}',
              ].join(' · '),
            ))
        .toList();
  }

  List<_ResourcePickItem> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _catalog;
    return _catalog
        .where((e) => e.title.toLowerCase().contains(q) || e.subtitle.toLowerCase().contains(q))
        .toList();
  }

  _ResourcePickItem? get _selected =>
      _selectedId == null ? null : _catalog.where((e) => e.id == _selectedId).firstOrNull;

  double? get _availableQty => _selected?.availableQty;

  void _validateQty() {
    if (!_tracksStock) {
      setState(() => _qtyError = null);
      return;
    }
    final avail = _availableQty;
    final qty = double.tryParse(_qtyCtrl.text.trim());
    if (avail == null) {
      setState(() => _qtyError = null);
      return;
    }
    if (qty == null || qty <= 0) {
      setState(() => _qtyError = 'Enter a valid quantity');
      return;
    }
    if (qty > avail) {
      setState(() => _qtyError = 'Only ${avail.toStringAsFixed(2)} available in stock');
      return;
    }
    setState(() => _qtyError = null);
  }

  void _selectItem(_ResourcePickItem item) {
    setState(() {
      _selectedId = item.id;
      _qtyError = null;
      if (widget.type == 'LABOUR') {
        final rate = widget.labour.where((l) => l.id == item.id).firstOrNull?.defaultRate;
        if (rate != null) _priceCtrl.text = rate.toString();
      }
    });
    _validateQty();
  }

  void _submit() {
    if (_selectedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a ${_meta.label.toLowerCase()}')),
      );
      return;
    }
    _validateQty();
    if (_qtyError != null) return;
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final item = _resolveItem(_selectedId!);
    if (item == null) return;
    Navigator.pop(
      context,
      ErpBoqTaskResource(
        resourceType: widget.type,
        configMaterialId: widget.type == 'MATERIAL' ? _selectedId : null,
        configMachineId: widget.type == 'MACHINE' ? _selectedId : null,
        configLabourId: widget.type == 'LABOUR' ? _selectedId : null,
        name: item.name,
        brand: item.brand,
        unitCode: item.unitCode,
        size: item.size,
        quantity: qty,
        unitPrice: price,
        totalPrice: qty * price,
        remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
      ),
    );
  }

  ({String name, String? brand, String? unitCode, String? size})? _resolveItem(String id) {
    if (widget.type == 'MATERIAL') {
      final m = widget.materials.where((x) => x.id == id).firstOrNull;
      if (m == null) return null;
      return (name: m.name, brand: m.brand, unitCode: m.unitCode, size: m.size);
    }
    if (widget.type == 'MACHINE') {
      final m = widget.machines.where((x) => x.id == id).firstOrNull;
      if (m == null) return null;
      return (name: m.name, brand: m.brand, unitCode: m.unitCode, size: m.size);
    }
    final l = widget.labour.where((x) => x.id == id).firstOrNull;
    if (l == null) return null;
    return (name: l.name, brand: null, unitCode: l.unitCode, size: null);
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final selected = _selected;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                color: _meta.color.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(_meta.icon, color: _meta.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Add ${_meta.label}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      decoration: _fieldDec('Search ${_meta.label.toLowerCase()}', hint: 'Type to filter…'),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    if (_catalog.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Text(
                          'No ${_meta.label.toLowerCase()} configured yet. Add them under ERP → Configurations.',
                          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
                        ),
                      )
                    else ...[
                      Text(
                        'Select ${_meta.label.toLowerCase()}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: items.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'No matches for "${_searchCtrl.text}"',
                                    style: TextStyle(color: Theme.of(context).hintColor),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: items.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (ctx, i) {
                                  final item = items[i];
                                  final isSelected = item.id == _selectedId;
                                  return Material(
                                    color: isSelected ? _meta.color.withValues(alpha: 0.12) : null,
                                    child: ListTile(
                                      dense: true,
                                      selected: isSelected,
                                      leading: Icon(
                                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                                        color: isSelected ? _meta.color : Colors.grey,
                                        size: 20,
                                      ),
                                      title: Text(item.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      subtitle: item.subtitle.isNotEmpty
                                          ? Text(item.subtitle, style: const TextStyle(fontSize: 11))
                                          : null,
                                      onTap: () => _selectItem(item),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                    if (selected != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _meta.color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _meta.color.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(_meta.icon, size: 18, color: _meta.color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selected.title,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            if (_tracksStock && _availableQty != null)
                              Text(
                                '${_availableQty!.toStringAsFixed(2)} avail.',
                                style: TextStyle(fontSize: 12, color: _meta.color, fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextField(
                      controller: _qtyCtrl,
                      decoration: _fieldDec('Quantity', error: _qtyError),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _validateQty(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _priceCtrl,
                      decoration: _fieldDec('Unit price', hint: '0.00'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _remarksCtrl,
                      decoration: _fieldDec('Remarks (optional)'),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(backgroundColor: _meta.color),
                    child: const Text('Add'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourcePickItem {
  const _ResourcePickItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.availableQty,
  });

  final String id;
  final String title;
  final String subtitle;
  final double? availableQty;
}

class _ResourceTypeMeta {
  const _ResourceTypeMeta({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  static _ResourceTypeMeta forType(String type) => switch (type) {
        'MATERIAL' => const _ResourceTypeMeta(
            label: 'Material',
            icon: Icons.inventory_2_outlined,
            color: Color(0xFF0EA5E9),
          ),
        'MACHINE' => const _ResourceTypeMeta(
            label: 'Machine',
            icon: Icons.precision_manufacturing_outlined,
            color: Color(0xFF8B5CF6),
          ),
        _ => const _ResourceTypeMeta(
            label: 'Labour',
            icon: Icons.engineering_outlined,
            color: Color(0xFFF59E0B),
          ),
      };
}

class _ResourceEditDialog extends StatefulWidget {
  const _ResourceEditDialog({
    required this.resource,
    required this.type,
    required this.materials,
    required this.machines,
  });

  final ErpBoqTaskResource resource;
  final String type;
  final List<ErpMaterial> materials;
  final List<ErpMachine> machines;

  @override
  State<_ResourceEditDialog> createState() => _ResourceEditDialogState();
}

class _ResourceEditDialogState extends State<_ResourceEditDialog> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _remarksCtrl;
  String? _qtyError;

  _ResourceTypeMeta get _meta => _ResourceTypeMeta.forType(widget.type);

  bool get _tracksStock => widget.type == 'MATERIAL' || widget.type == 'MACHINE';

  double? get _availableQty {
    final r = widget.resource;
    if (widget.type == 'MATERIAL' && r.configMaterialId != null) {
      return widget.materials.where((m) => m.id == r.configMaterialId).firstOrNull?.qtyAvailable;
    }
    if (widget.type == 'MACHINE' && r.configMachineId != null) {
      return widget.machines.where((m) => m.id == r.configMachineId).firstOrNull?.qtyAvailable;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final r = widget.resource;
    _qtyCtrl = TextEditingController(text: r.quantity.toString());
    _priceCtrl = TextEditingController(text: r.unitPrice.toString());
    _remarksCtrl = TextEditingController(text: r.remarks ?? '');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDec(String label, {String? error}) => InputDecoration(
        labelText: label,
        errorText: error,
        isDense: true,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  void _validateQty() {
    if (!_tracksStock) {
      setState(() => _qtyError = null);
      return;
    }
    final avail = _availableQty;
    final qty = double.tryParse(_qtyCtrl.text.trim());
    if (avail == null) {
      setState(() => _qtyError = null);
      return;
    }
    if (qty == null || qty <= 0) {
      setState(() => _qtyError = 'Enter a valid quantity');
      return;
    }
    if (qty > avail) {
      setState(() => _qtyError = 'Only ${avail.toStringAsFixed(2)} available in stock');
      return;
    }
    setState(() => _qtyError = null);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resource;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(_meta.icon, color: _meta.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Edit ${r.name}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  ),
                ],
              ),
              if (_tracksStock && _availableQty != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${_availableQty!.toStringAsFixed(2)} available in stock',
                  style: TextStyle(fontSize: 12, color: _meta.color, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _qtyCtrl,
                decoration: _fieldDec('Quantity', error: _qtyError),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _validateQty(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceCtrl,
                decoration: _fieldDec('Unit price'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _remarksCtrl,
                decoration: _fieldDec('Remarks'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      _validateQty();
                      if (_qtyError != null) return;
                      final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
                      final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
                      Navigator.pop(
                        context,
                        r.copyWith(
                          quantity: qty,
                          unitPrice: price,
                          totalPrice: qty * price,
                          remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(backgroundColor: _meta.color),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
