import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_back_button.dart';
import '../../domain/work_order_models.dart';
import '../work_order_providers.dart';

class ContractorsConfigScreen extends ConsumerStatefulWidget {
  const ContractorsConfigScreen({super.key});

  @override
  ConsumerState<ContractorsConfigScreen> createState() => _ContractorsConfigScreenState();
}

class _ContractorsConfigScreenState extends ConsumerState<ContractorsConfigScreen> {
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _editingId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _reset() {
    _nameCtrl.clear();
    _contactCtrl.clear();
    _phoneCtrl.clear();
    _editingId = null;
    setState(() {});
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final body = {
      'name': name,
      'contactPerson': _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
    };
    try {
      final repo = ref.read(workOrderRepositoryProvider);
      if (_editingId != null) {
        await repo.updateContractor(_editingId!, body);
      } else {
        await repo.createContractor(body);
      }
      ref.invalidate(erpContractorsProvider);
      _reset();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _toggle(String id) async {
    try {
      await ref.read(workOrderRepositoryProvider).toggleContractor(id);
      ref.invalidate(erpContractorsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _edit(ErpContractor c) {
    _editingId = c.id;
    _nameCtrl.text = c.name;
    _contactCtrl.text = c.contactPerson ?? '';
    _phoneCtrl.text = c.phone ?? '';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(erpContractorsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contractors'),
        leading: const AppBackButton(fallbackLocation: '/erp/configurations'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Contractor Name *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _contactCtrl,
                    decoration: const InputDecoration(labelText: 'Contact Person', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton(onPressed: _save, child: const Text('Save')),
                      if (_editingId != null) ...[
                        const SizedBox(width: 8),
                        TextButton(onPressed: _reset, child: const Text('Cancel')),
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
                  DataColumn(label: Text('NAME')),
                  DataColumn(label: Text('CONTACT')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('ACTION')),
                ],
                rows: items
                    .map(
                      (c) => DataRow(
                        cells: [
                          DataCell(Text(c.name)),
                          DataCell(Text(c.contactPerson ?? '—')),
                          DataCell(Text(c.isActive ? 'Active' : 'Inactive')),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(c)),
                                IconButton(
                                  icon: Icon(c.isActive ? Icons.toggle_on : Icons.toggle_off),
                                  onPressed: () => _toggle(c.id),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
