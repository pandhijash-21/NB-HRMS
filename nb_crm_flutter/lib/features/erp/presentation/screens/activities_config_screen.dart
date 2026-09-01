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

class _ActivitiesConfigScreenState extends ConsumerState<ActivitiesConfigScreen> {
  final _nameCtrl = TextEditingController();
  final _subtaskCtrl = TextEditingController();
  final List<String> _subtasks = [];
  String? _editingId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subtaskCtrl.dispose();
    super.dispose();
  }

  void _resetForm() {
    _nameCtrl.clear();
    _subtaskCtrl.clear();
    _subtasks.clear();
    _editingId = null;
    setState(() {});
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(workOrderRepositoryProvider);
    final body = {
      'name': name,
      'subtasks': _subtasks.map((s) => {'name': s}).toList(),
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
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _edit(ErpActivity item) {
    _editingId = item.id;
    _nameCtrl.text = item.name;
    _subtasks
      ..clear()
      ..addAll(item.subtasks.map((s) => s.name));
    setState(() {});
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
                  Text(_editingId == null ? 'Add Activity' : 'Edit Activity',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Activity Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _subtaskCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Sub-task (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          final s = _subtaskCtrl.text.trim();
                          if (s.isEmpty) return;
                          setState(() {
                            _subtasks.add(s);
                            _subtaskCtrl.clear();
                          });
                        },
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: _subtasks
                        .map(
                          (s) => Chip(
                            label: Text(s),
                            onDeleted: () => setState(() => _subtasks.remove(s)),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton(onPressed: _save, child: const Text('Save')),
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
            data: (items) => Card(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('SR#')),
                  DataColumn(label: Text('ACTIVITY NAME')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('ACTION')),
                ],
                rows: [
                  for (var i = 0; i < items.length; i++)
                    DataRow(
                      cells: [
                        DataCell(Text('${i + 1}')),
                        DataCell(Text(items[i].name)),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: items[i].isActive ? Colors.green : Colors.grey,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              items[i].isActive ? 'Active' : 'Inactive',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _edit(items[i]),
                              ),
                              IconButton(
                                icon: Icon(
                                  items[i].isActive ? Icons.toggle_on : Icons.toggle_off,
                                ),
                                onPressed: () => _toggle(items[i].id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _delete(items[i].id),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
