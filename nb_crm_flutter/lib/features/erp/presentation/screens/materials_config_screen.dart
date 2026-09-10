import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../data/boq_repository.dart';
import '../../data/work_order_repository.dart';
import '../../domain/resource_models.dart';
import '../../domain/work_order_lookup_keys.dart';
import '../../domain/work_order_models.dart';

class MaterialsConfigScreen extends StatefulWidget {
  const MaterialsConfigScreen({super.key});

  @override
  State<MaterialsConfigScreen> createState() => _MaterialsConfigScreenState();
}

class _MaterialsConfigScreenState extends State<MaterialsConfigScreen> {
  final _brandCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '0');
  String? _unitCode;
  String? _activityId;
  String? _subtaskId;

  List<ErpMaterial> _materials = [];
  List<ErpActivity> _activities = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    try {
      final boqRepo = context.read<BoqRepository>();
      final workRepo = context.read<WorkOrderRepository>();
      final results = await Future.wait([
        boqRepo.listMaterials(),
        workRepo.listActivities(),
      ]);
      if (mounted) {
        setState(() {
          _materials = results[0] as List<ErpMaterial>;
          _activities = results[1] as List<ErpActivity>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

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
      await context.read<BoqRepository>().createMaterial({
        'brand': _brandCtrl.text.trim(),
        'name': name,
        'unitCode': _unitCode,
        'size': _sizeCtrl.text.trim(),
        'activityId': _activityId,
        'subtaskId': _subtaskId,
        'qtyOnHand': double.tryParse(_qtyCtrl.text) ?? 0,
      });
      _brandCtrl.clear();
      _nameCtrl.clear();
      _sizeCtrl.clear();
      _qtyCtrl.text = '0';
      setState(() {
        _unitCode = null;
        _activityId = null;
        _subtaskId = null;
      });
      _loadData();
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
      await context.read<BoqRepository>().addMaterialStock(id, {
        'quantity': double.tryParse(qtyCtrl.text) ?? 0,
        'logType': 'PURCHASE',
        'remarks': remarksCtrl.text.trim(),
      });
      _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    context: context,
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
                  DropdownButtonFormField<String>(
                    initialValue: _activityId,
                    decoration: const InputDecoration(labelText: 'Activity (optional)', border: OutlineInputBorder()),
                    items: _activities.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                    onChanged: (v) => setState(() {
                      _activityId = v;
                      _subtaskId = null;
                    }),
                  ),
                  if (_activityId != null) ...[
                    () {
                      final act = _activities.where((a) => a.id == _activityId).firstOrNull;
                      if (act == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: DropdownButtonFormField<String>(
                          initialValue: _subtaskId,
                          decoration: const InputDecoration(labelText: 'Sub-activity (optional)', border: OutlineInputBorder()),
                          items: act.subtasks.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                          onChanged: (v) => setState(() => _subtaskId = v),
                        ),
                      );
                    }(),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _save, child: const Text('Save Material')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Text(_error!)
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Stock summary', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final m in _materials)
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
