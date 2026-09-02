import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_back_button.dart';
import '../../domain/work_order_models.dart';
import '../work_order_providers.dart';

class ActivitiesConfigScreen extends ConsumerStatefulWidget {
  const ActivitiesConfigScreen({super.key});

  @override
  ConsumerState<ActivitiesConfigScreen> createState() => _ActivitiesConfigScreenState();
}

class _SubtaskDraft {
  _SubtaskDraft({required this.name, this.description = ''});
  String name;
  String description;
}

class _ActivitiesConfigScreenState extends ConsumerState<ActivitiesConfigScreen> {
  final _nameCtrl = TextEditingController();
  final List<_SubtaskDraft> _subtasks = [];
  String? _editingId;
  final Set<String> _expanded = {};

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _resetForm() {
    _nameCtrl.clear();
    _subtasks.clear();
    _editingId = null;
    setState(() {});
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final validSubtasks = _subtasks.where((s) => s.name.trim().isNotEmpty).toList();
    final repo = ref.read(workOrderRepositoryProvider);
    final body = {
      'name': name,
      'subtasks': validSubtasks
          .map((s) => {
                'name': s.name.trim(),
                if (s.description.trim().isNotEmpty) 'description': s.description.trim(),
              })
          .toList(),
    };
    try {
      if (_editingId != null) {
        await repo.updateActivity(_editingId!, body);
      } else {
        await repo.createActivity(body);
      }
      ref.invalidate(erpActivitiesAdminProvider);
      ref.invalidate(erpActivitiesProvider);
      _resetForm();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _toggle(String id) async {
    try {
      await ref.read(workOrderRepositoryProvider).toggleActivity(id);
      ref.invalidate(erpActivitiesAdminProvider);
      ref.invalidate(erpActivitiesProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete activity?'),
        content: const Text('This will remove the activity and all its sub-activities from configuration.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(workOrderRepositoryProvider).removeActivity(id);
      ref.invalidate(erpActivitiesAdminProvider);
      ref.invalidate(erpActivitiesProvider);
      if (_editingId == id) _resetForm();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _edit(ErpActivity item) {
    _editingId = item.id;
    _nameCtrl.text = item.name;
    _subtasks
      ..clear()
      ..addAll(item.subtasks.map((s) => _SubtaskDraft(name: s.name, description: s.description ?? '')));
    setState(() {});
  }

  void _addSubtaskRow() {
    setState(() => _subtasks.add(_SubtaskDraft(name: '', description: '')));
  }

  void _toggleExpanded(String id) {
    setState(() {
      if (_expanded.contains(id)) {
        _expanded.remove(id);
      } else {
        _expanded.add(id);
      }
    });
  }

  Widget _subtaskEditorTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Sub-activities', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton.icon(
              onPressed: _addSubtaskRow,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add row'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_subtasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'No sub-activities yet. Add rows for each task under this activity (e.g. wall color, ceiling color).',
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Table(
              columnWidths: const {
                0: FixedColumnWidth(44),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(3),
                3: FixedColumnWidth(48),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                  children: const [
                    Padding(padding: EdgeInsets.all(10), child: Text('SR', style: TextStyle(fontWeight: FontWeight.w700))),
                    Padding(padding: EdgeInsets.all(10), child: Text('SUB-ACTIVITY *', style: TextStyle(fontWeight: FontWeight.w700))),
                    Padding(padding: EdgeInsets.all(10), child: Text('DESCRIPTION', style: TextStyle(fontWeight: FontWeight.w700))),
                    SizedBox.shrink(),
                  ],
                ),
                for (var i = 0; i < _subtasks.length; i++)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('${i + 1}'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextFormField(
                          key: ValueKey('st-name-$i-$_editingId-${_subtasks[i].hashCode}'),
                          initialValue: _subtasks[i].name,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Sub-activity name',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => _subtasks[i].name = v,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextFormField(
                          key: ValueKey('st-desc-$i-$_editingId-${_subtasks[i].hashCode}'),
                          initialValue: _subtasks[i].description,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Description',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => _subtasks[i].description = v,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove row',
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => setState(() => _subtasks.removeAt(i)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(erpActivitiesAdminProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activities'),
        leading: const AppBackButton(fallbackLocation: '/erp/configurations'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _editingId == null ? 'Add Activity' : 'Edit Activity',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Activity Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _subtaskEditorTable(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      FilledButton(onPressed: _save, child: Text(_editingId == null ? 'Save activity' : 'Update activity')),
                      if (_editingId != null) ...[
                        const SizedBox(width: 8),
                        TextButton(onPressed: _resetForm, child: const Text('Cancel edit')),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e'),
            data: (items) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Configured activities (${items.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No activities configured yet.')),
                    ),
                  )
                else
                  ...items.map((item) {
                    final expanded = _expanded.contains(item.id);
                    final activeSubs = item.subtasks.where((s) => s.isActive).toList();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${activeSubs.length} sub-activit${activeSubs.length == 1 ? 'y' : 'ies'}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: item.isActive ? Colors.green : Colors.grey,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.isActive ? 'Active' : 'Inactive',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _edit(item),
                                ),
                                IconButton(
                                  tooltip: item.isActive ? 'Deactivate' : 'Activate',
                                  icon: Icon(item.isActive ? Icons.toggle_on : Icons.toggle_off),
                                  onPressed: () => _toggle(item.id),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () => _delete(item.id),
                                ),
                                IconButton(
                                  tooltip: expanded ? 'Collapse' : 'Expand sub-activities',
                                  icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                                  onPressed: () => _toggleExpanded(item.id),
                                ),
                              ],
                            ),
                          ),
                          if (expanded)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: activeSubs.isEmpty
                                  ? Text(
                                      'No sub-activities. Click Edit to add them.',
                                      style: TextStyle(color: Theme.of(context).hintColor),
                                    )
                                  : Table(
                                      columnWidths: const {
                                        0: FixedColumnWidth(40),
                                        1: FlexColumnWidth(2),
                                        2: FlexColumnWidth(3),
                                      },
                                      children: [
                                        const TableRow(
                                          children: [
                                            Padding(padding: EdgeInsets.all(8), child: Text('SR', style: TextStyle(fontWeight: FontWeight.w700))),
                                            Padding(padding: EdgeInsets.all(8), child: Text('SUB-ACTIVITY', style: TextStyle(fontWeight: FontWeight.w700))),
                                            Padding(padding: EdgeInsets.all(8), child: Text('DESCRIPTION', style: TextStyle(fontWeight: FontWeight.w700))),
                                          ],
                                        ),
                                        for (var i = 0; i < activeSubs.length; i++)
                                          TableRow(
                                            children: [
                                              Padding(padding: const EdgeInsets.all(8), child: Text('${i + 1}')),
                                              Padding(padding: const EdgeInsets.all(8), child: Text(activeSubs[i].name)),
                                              Padding(
                                                padding: const EdgeInsets.all(8),
                                                child: Text(
                                                  activeSubs[i].description?.isNotEmpty == true
                                                      ? activeSubs[i].description!
                                                      : '—',
                                                  style: TextStyle(
                                                    color: activeSubs[i].description?.isNotEmpty == true
                                                        ? null
                                                        : Theme.of(context).hintColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                            ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
