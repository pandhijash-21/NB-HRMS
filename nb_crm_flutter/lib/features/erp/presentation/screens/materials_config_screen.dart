import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../domain/work_order_lookup_keys.dart';
import '../boq_providers.dart';
import '../work_order_providers.dart';

class MaterialsConfigScreen extends ConsumerStatefulWidget {
  const MaterialsConfigScreen({super.key});

  @override
  ConsumerState<MaterialsConfigScreen> createState() => _MaterialsConfigScreenState();
}

class _MaterialsConfigScreenState extends ConsumerState<MaterialsConfigScreen> {
  final _brandCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '0');
  String? _unitCode;
  String? _activityId;
  String? _subtaskId;

  @override
  void dispose() {
    _brandCtrl.dispose();
    _nameCtrl.dispose();
    _sizeCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      await ref.read(boqRepositoryProvider).createMaterial({
        'brand': _brandCtrl.text.trim(),
        'name': name,
        'unitCode': _unitCode,
        'size': _sizeCtrl.text.trim(),
        'activityId': _activityId,
        'subtaskId': _subtaskId,
        'qtyOnHand': double.tryParse(_qtyCtrl.text) ?? 0,
      });
      ref.invalidate(erpMaterialsProvider);
      _brandCtrl.clear();
      _nameCtrl.clear();
      _sizeCtrl.clear();
      _qtyCtrl.text = '0';
      setState(() {
        _unitCode = null;
        _activityId = null;
        _subtaskId = null;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _addStock(String id) async {
    final qtyCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add stock (purchase)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
            TextField(controller: remarksCtrl, decoration: const InputDecoration(labelText: 'Remarks')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(boqRepositoryProvider).addMaterialStock(id, {
        'quantity': double.tryParse(qtyCtrl.text) ?? 0,
        'logType': 'PURCHASE',
        'remarks': remarksCtrl.text.trim(),
      });
      ref.invalidate(erpMaterialsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final materialsAsync = ref.watch(erpMaterialsProvider);
    final activitiesAsync = ref.watch(erpActivitiesAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Materials'),
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
                  const Text('Add Material', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextField(controller: _brandCtrl, decoration: const InputDecoration(labelText: 'Brand', border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  const SizedBox(height: 8),
                  lookupDropdown(
                    ref: ref,
                    category: kWoMeasurementUnit,
                    value: _unitCode,
                    label: 'Unit',
                    onChanged: (v) => setState(() => _unitCode = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: _sizeCtrl, decoration: const InputDecoration(labelText: 'Size', border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  TextField(controller: _qtyCtrl, decoration: const InputDecoration(labelText: 'Qty on hand', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  activitiesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (acts) => DropdownButtonFormField<String>(
                      value: _activityId,
                      decoration: const InputDecoration(labelText: 'Activity (optional)', border: OutlineInputBorder()),
                      items: acts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                      onChanged: (v) => setState(() {
                        _activityId = v;
                        _subtaskId = null;
                      }),
                    ),
                  ),
                  if (_activityId != null)
                    activitiesAsync.maybeWhen(
                      data: (acts) {
                        final act = acts.where((a) => a.id == _activityId).firstOrNull;
                        if (act == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: DropdownButtonFormField<String>(
                            value: _subtaskId,
                            decoration: const InputDecoration(labelText: 'Sub-activity (optional)', border: OutlineInputBorder()),
                            items: act.subtasks.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                            onChanged: (v) => setState(() => _subtaskId = v),
                          ),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _save, child: const Text('Save Material')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          materialsAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (items) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Stock summary', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final m in items)
                  Card(
                    child: ListTile(
                      title: Text('${m.brand != null ? '${m.brand} ' : ''}${m.name}'),
                      subtitle: Text(
                        'Total: ${m.qtyTotal} · Used: ${m.qtyUsed} · Available: ${m.qtyAvailable}${m.unitCode != null ? ' ${m.unitCode}' : ''}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_shopping_cart_outlined),
                        tooltip: 'Add purchase',
                        onPressed: () => _addStock(m.id),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
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
