import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../domain/work_order_lookup_keys.dart';
import '../boq_providers.dart';
import '../work_order_providers.dart';

class LabourConfigScreen extends ConsumerStatefulWidget {
  const LabourConfigScreen({super.key});

  @override
  ConsumerState<LabourConfigScreen> createState() => _LabourConfigScreenState();
}

class _LabourConfigScreenState extends ConsumerState<LabourConfigScreen> {
  final _nameCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  String? _unitCode;
  String? _activityId;
  String? _subtaskId;

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
      await ref.read(boqRepositoryProvider).createLabour({
        'name': name,
        'unitCode': _unitCode,
        'defaultRate': double.tryParse(_rateCtrl.text),
        'activityId': _activityId,
        'subtaskId': _subtaskId,
      });
      ref.invalidate(erpLabourProvider);
      _nameCtrl.clear();
      _rateCtrl.clear();
      setState(() {
        _unitCode = null;
        _activityId = null;
        _subtaskId = null;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final labourAsync = ref.watch(erpLabourProvider);
    final activitiesAsync = ref.watch(erpActivitiesAdminProvider);

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
                    ref: ref,
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
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _save, child: const Text('Save Labour')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          labourAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (items) => Column(
              children: [
                for (final l in items)
                  Card(
                    child: ListTile(
                      title: Text(l.name),
                      subtitle: Text(
                        '${l.unitCode ?? '—'}${l.defaultRate != null ? ' · Rate ${l.defaultRate}' : ''}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await ref.read(boqRepositoryProvider).removeLabour(l.id);
                          ref.invalidate(erpLabourProvider);
                        },
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
