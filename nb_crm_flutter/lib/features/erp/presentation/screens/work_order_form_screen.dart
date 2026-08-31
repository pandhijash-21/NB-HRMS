import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../domain/work_order_lookup_keys.dart';
import '../../domain/work_order_models.dart';
import '../project_providers.dart';
import '../work_order_providers.dart';
import '../widgets/work_details_editor.dart';

class WorkOrderFormScreen extends ConsumerStatefulWidget {
  const WorkOrderFormScreen({super.key, this.id});

  final String? id;

  bool get isEdit => id != null && id!.isNotEmpty;

  @override
  ConsumerState<WorkOrderFormScreen> createState() => _WorkOrderFormScreenState();
}

class _WorkOrderFormScreenState extends ConsumerState<WorkOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _woIdCtrl = TextEditingController();
  final _tenderCtrl = TextEditingController();

  DateTime _orderDate = DateTime.now();
  DateTime? _dueDate;
  String? _projectId;
  String? _contractorId;
  String? _categoryCode;
  int? _ownerEmployeeId;
  int? _approverEmployeeId;
  List<WorkOrderActivityGroup> _activities = [];
  bool _hydrated = false;
  bool _saving = false;

  @override
  void dispose() {
    _woIdCtrl.dispose();
    _tenderCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool due}) async {
    final initial = due ? (_dueDate ?? DateTime.now()) : _orderDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (due) {
        _dueDate = picked;
      } else {
        _orderDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a project')));
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'workOrderId': _woIdCtrl.text.trim(),
        'orderDate': _orderDate.toIso8601String().split('T').first,
        if (_dueDate != null) 'dueDate': _dueDate!.toIso8601String().split('T').first,
        'projectId': _projectId,
        'tenderRef': _tenderCtrl.text.trim().isEmpty ? null : _tenderCtrl.text.trim(),
        'contractorId': _contractorId,
        'categoryCode': _categoryCode,
        if (_ownerEmployeeId != null) 'ownerEmployeeId': _ownerEmployeeId,
        if (_approverEmployeeId != null) 'approverEmployeeId': _approverEmployeeId,
        'activities': _activities.map((a) => a.toJson()).toList(),
      };
      final repo = ref.read(workOrderRepositoryProvider);
      if (widget.isEdit) {
        await repo.update(widget.id!, body);
        if (mounted) context.go('/erp/work-orders/${widget.id}');
      } else {
        final created = await repo.create(body);
        if (mounted) context.go('/erp/work-orders/${created.id}');
      }
      ref.invalidate(workOrdersListProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _hydrate(ErpWorkOrder wo) {
    if (_hydrated) return;
    _hydrated = true;
    _woIdCtrl.text = wo.workOrderId;
    _tenderCtrl.text = wo.tenderRef ?? '';
    _orderDate = wo.orderDate;
    _dueDate = wo.dueDate;
    _projectId = wo.projectId;
    _contractorId = wo.contractorId;
    _categoryCode = wo.categoryCode;
    _ownerEmployeeId = wo.ownerEmployeeId;
    _approverEmployeeId = wo.approverEmployeeId;
    _activities = wo.activities;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final dateFmt = _formatShortDate;
    final projectsAsync = ref.watch(projectsListProvider);
    final contractorsAsync = ref.watch(erpContractorsProvider);
    final employeesAsync = ref.watch(projectEmployeesProvider);
    final configActivitiesAsync = ref.watch(erpActivitiesProvider);

    if (widget.isEdit) {
      ref.watch(workOrderDetailProvider(widget.id!)).whenData(_hydrate);
    } else if (!_hydrated && auth.user?.employeeId != null) {
      _ownerEmployeeId = auth.user!.employeeId;
      _hydrated = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Work Order' : 'Add Work Order'),
        leading: AppBackButton(
          fallbackLocation: widget.isEdit ? '/erp/work-orders/${widget.id}' : '/erp/work-orders',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Basic Details', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _woIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Work Order Id *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Date * — ${dateFmt.format(_orderDate)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () => _pickDate(due: false),
                      ),
                    ),
                    employeesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('$e'),
                      data: (emps) => DropdownButtonFormField<int>(
                        value: _ownerEmployeeId,
                        decoration: const InputDecoration(
                          labelText: 'Tender Created By *',
                          border: OutlineInputBorder(),
                        ),
                        items: emps
                            .map((e) => DropdownMenuItem(value: e.id, child: Text(e.fullName)))
                            .toList(),
                        onChanged: (v) => setState(() => _ownerEmployeeId = v),
                      ),
                    ),
                    const SizedBox(height: 12),
                    projectsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('$e'),
                      data: (projects) => DropdownButtonFormField<String>(
                        value: _projectId,
                        decoration: const InputDecoration(
                          labelText: 'Project *',
                          border: OutlineInputBorder(),
                        ),
                        items: projects
                            .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _projectId = v;
                          _activities = [];
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tenderCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tender (approved tenders — coming soon)',
                        hintText: 'Select Tender',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tender module will be added later.')),
                      ),
                    ),
                    const SizedBox(height: 12),
                    contractorsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('$e'),
                      data: (items) => DropdownButtonFormField<String>(
                        value: _contractorId,
                        decoration: const InputDecoration(
                          labelText: 'Contractor *',
                          border: OutlineInputBorder(),
                        ),
                        items: items
                            .where((c) => c.isActive)
                            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                            .toList(),
                        onChanged: (v) => setState(() => _contractorId = v),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _dueDate == null ? 'Due Date' : 'Due Date — ${dateFmt.format(_dueDate!)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () => _pickDate(due: true),
                      ),
                    ),
                    const SizedBox(height: 12),
                    lookupDropdown(
                      ref: ref,
                      category: kWoCategory,
                      value: _categoryCode,
                      label: 'Category',
                      onChanged: (v) => setState(() => _categoryCode = v),
                    ),
                    const SizedBox(height: 12),
                    employeesAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (emps) => DropdownButtonFormField<int>(
                        value: _approverEmployeeId,
                        decoration: const InputDecoration(
                          labelText: 'Approver',
                          border: OutlineInputBorder(),
                        ),
                        items: emps
                            .map((e) => DropdownMenuItem(value: e.id, child: Text(e.fullName)))
                            .toList(),
                        onChanged: (v) => setState(() => _approverEmployeeId = v),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            configActivitiesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (acts) => WorkDetailsEditor(
                projectId: _projectId,
                activities: _activities,
                configActivities: acts,
                onChanged: (groups) => setState(() => _activities = groups),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _saving ? null : () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatShortDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

