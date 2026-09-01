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

  InputDecoration _dec(String label, {bool required = false, String? hint, Widget? suffix}) {
    return InputDecoration(
      labelText: required ? '$label *' : label,
      hintText: hint,
      suffixIcon: suffix,
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF252220)
          : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF3D3834)
              : const Color(0xFFE2E8F0),
        ),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _fieldGrid(List<Widget> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final cols = maxW >= 1100 ? 3 : maxW >= 720 ? 2 : 1;
        const gap = 14.0;
        final cellW = (maxW - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: fields.map((f) => SizedBox(width: cellW, child: f)).toList(),
        );
      },
    );
  }

  Widget _sectionCard(String title, String subtitle, List<Widget> fields) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? const Color(0xFFC5A059).withValues(alpha: 0.12)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF0d9488),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _fieldGrid(fields),
        ],
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    bool required = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: _dec(
          label,
          required: required,
          suffix: const Icon(Icons.calendar_today_outlined, size: 20),
        ),
        child: Text(
          value == null ? 'Select date' : _formatShortDate(value),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: value == null ? Colors.grey : null,
          ),
        ),
      ),
    );
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
    if (_contractorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a contractor')));
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        title: Text(
          widget.isEdit ? 'Edit Work Order' : 'Add Work Order',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: AppBackButton(
          fallbackLocation: widget.isEdit ? '/erp/work-orders/${widget.id}' : '/erp/work-orders',
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      children: [
                        _sectionCard(
                          'Basic Details',
                          'Work order header — project, contractor, and dates',
                          [
                            TextFormField(
                              controller: _woIdCtrl,
                              decoration: _dec('Work Order Id', required: true, hint: 'e.g. WONBR00001'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            _dateField(
                              label: 'Date',
                              value: _orderDate,
                              required: true,
                              onTap: () => _pickDate(due: false),
                            ),
                            _dateField(
                              label: 'Due Date',
                              value: _dueDate,
                              onTap: () => _pickDate(due: true),
                            ),
                            employeesAsync.when(
                              loading: () => const LinearProgressIndicator(),
                              error: (e, _) => Text('$e'),
                              data: (emps) => DropdownButtonFormField<int>(
                                isExpanded: true,
                                value: _ownerEmployeeId,
                                decoration: _dec('Tender Created By', required: true),
                                items: emps
                                    .map((e) => DropdownMenuItem(value: e.id, child: Text(e.fullName)))
                                    .toList(),
                                onChanged: (v) => setState(() => _ownerEmployeeId = v),
                              ),
                            ),
                            projectsAsync.when(
                              loading: () => const LinearProgressIndicator(),
                              error: (e, _) => Text('$e'),
                              data: (projects) => DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _projectId,
                                decoration: _dec('Project', required: true, hint: 'Select project'),
                                items: projects
                                    .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _projectId = v;
                                  _activities = [];
                                }),
                              ),
                            ),
                            contractorsAsync.when(
                              loading: () => const LinearProgressIndicator(),
                              error: (e, _) => Text('$e'),
                              data: (items) => DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _contractorId,
                                decoration: _dec('Contractor', required: true, hint: 'Select contractor'),
                                items: items
                                    .where((c) => c.isActive)
                                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                                    .toList(),
                                onChanged: (v) => setState(() => _contractorId = v),
                              ),
                            ),
                            TextFormField(
                              controller: _tenderCtrl,
                              readOnly: true,
                              decoration: _dec('Tender', hint: 'Coming soon'),
                              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Tender module will be added later.')),
                              ),
                            ),
                            lookupDropdown(
                              ref: ref,
                              category: kWoCategory,
                              value: _categoryCode,
                              label: 'Category',
                              onChanged: (v) => setState(() => _categoryCode = v),
                            ),
                            employeesAsync.when(
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                              data: (emps) => DropdownButtonFormField<int>(
                                isExpanded: true,
                                value: _approverEmployeeId,
                                decoration: _dec('Approver', hint: 'Who approves this WO'),
                                items: emps
                                    .map((e) => DropdownMenuItem(value: e.id, child: Text(e.fullName)))
                                    .toList(),
                                onChanged: (v) => setState(() => _approverEmployeeId = v),
                              ),
                            ),
                          ],
                        ),
                        configActivitiesAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (e, _) => Text('$e'),
                          data: (acts) => WorkDetailsEditor(
                            projectId: _projectId,
                            activities: _activities,
                            configActivities: acts,
                            onChanged: (groups) => setState(() => _activities = groups),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1816) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0d9488),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(widget.isEdit ? 'Save Changes' : 'Create Work Order'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _saving ? null : () => context.pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatShortDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
