import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../data/boq_repository.dart';
import '../../data/work_order_repository.dart';
import '../../domain/resource_models.dart';
import '../../domain/work_order_lookup_keys.dart';
import '../../domain/work_order_models.dart';

class LabourConfigScreen extends StatefulWidget {
  const LabourConfigScreen({super.key});

  @override
  State<LabourConfigScreen> createState() => _LabourConfigScreenState();
}

class _LabourConfigScreenState extends State<LabourConfigScreen> {
  final _nameCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  String? _unitCode;
  String? _activityId;
  String? _subtaskId;

  List<ErpLabour> _labour = [];
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
        boqRepo.listLabour(),
        workRepo.listActivities(),
      ]);
      if (mounted) {
        setState(() {
          _labour = results[0] as List<ErpLabour>;
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
    _nameCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      await context.read<BoqRepository>().createLabour({
        'name': name,
        'unitCode': _unitCode,
        'defaultRate': double.tryParse(_rateCtrl.text),
        'activityId': _activityId,
        'subtaskId': _subtaskId,
      });
      _nameCtrl.clear();
      _rateCtrl.clear();
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

  Future<void> _delete(String id) async {
    try {
      await context.read<BoqRepository>().removeLabour(id);
      _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Labour'),
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
                  const Text('Add Labour Type', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  lookupDropdown(
                    context: context,
                    category: kWoMeasurementUnit,
                    value: _unitCode,
                    label: 'Unit',
                    onChanged: (v) => setState(() => _unitCode = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _rateCtrl,
                    decoration: const InputDecoration(labelText: 'Default rate (optional)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
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
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _save, child: const Text('Save Labour')),
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
              children: [
                for (final l in _labour)
                  Card(
                    child: ListTile(
                      title: Text(l.name),
                      subtitle: Text(
                        '${l.unitCode ?? '—'}${l.defaultRate != null ? ' · Rate ${l.defaultRate}' : ''}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(l.id),
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
