import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../data/project_repository.dart';
import '../../data/tender_repository.dart';
import '../../data/work_order_repository.dart';
import '../../domain/project_models.dart';
import '../../domain/tender_models.dart';
import '../../domain/work_order_lookup_keys.dart';
import '../../domain/work_order_models.dart';
import '../bloc/erp_work_orders_bloc.dart';
import '../widgets/work_details_editor.dart';

class WorkOrderFormScreen extends StatefulWidget {
  const WorkOrderFormScreen({super.key, this.id});

  final String? id;

  bool get isEdit => id != null && id!.isNotEmpty;

  @override
  State<WorkOrderFormScreen> createState() => _WorkOrderFormScreenState();
}

class _WorkOrderFormScreenState extends State<WorkOrderFormScreen> {
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
  bool _loadingInitial = true;

  List<ErpProject> _projects = [];
  List<ProjectEmployeeOption> _employees = [];
  List<ErpContractor> _contractors = [];
  List<ErpActivity> _configActivities = [];
  List<ErpTenderApplication> _approvedTenders = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final projectRepo = context.read<ProjectRepository>();
    final workOrderRepo = context.read<WorkOrderRepository>();
    final tenderRepo = context.read<TenderRepository>();
    final authState = context.read<AuthBloc>().state;

    setState(() => _loadingInitial = true);
    try {
      final futures = await Future.wait([
        projectRepo.list(),
        projectRepo.listEmployees(),
        workOrderRepo.listContractors(),
        workOrderRepo.listActivities(),
        tenderRepo.listApplications(status: 'APPROVED'),
        if (widget.isEdit) workOrderRepo.getById(widget.id!) else Future.value(null),
      ]);

      if (!mounted) return;

      final projects = futures[0] as List<ErpProject>;
      final employees = futures[1] as List<ProjectEmployeeOption>;
      final contractors = futures[2] as List<ErpContractor>;
      final activities = futures[3] as List<ErpActivity>;
      final tenders = futures[4] as List<ErpTenderApplication>;
      final existingWo = futures[5] as ErpWorkOrder?;

      setState(() {
        _projects = projects;
        _employees = employees;
        _contractors = contractors;
        _configActivities = activities;
        _approvedTenders = tenders;
        _loadingInitial = false;

        if (existingWo != null) {
          _hydrate(existingWo);
        } else if (!_hydrated && authState.user?.employeeId != null) {
          _ownerEmployeeId = authState.user!.employeeId;
          _hydrated = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingInitial = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

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
      final repo = context.read<WorkOrderRepository>();
      if (widget.isEdit) {
        await repo.update(widget.id!, body);
        if (mounted) {
          try {
            context.read<ErpWorkOrdersBloc>().add(const ErpWorkOrdersListRequested());
          } catch (_) {}
          context.go('/erp/work-orders/${widget.id}');
        }
      } else {
        final created = await repo.create(body);
        if (mounted) {
          try {
            context.read<ErpWorkOrdersBloc>().add(const ErpWorkOrdersListRequested());
          } catch (_) {}
          context.go('/erp/work-orders/${created.id}');
        }
      }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                            if (_loadingInitial)
                              const LinearProgressIndicator()
                            else
                              DropdownButtonFormField<int>(
                                isExpanded: true,
                                initialValue: _ownerEmployeeId,
                                decoration: _dec('Tender Created By', required: true),
                                items: _employees
                                    .map((e) => DropdownMenuItem(value: e.id, child: Text(e.fullName)))
                                    .toList(),
                                onChanged: (v) => setState(() => _ownerEmployeeId = v),
                              ),
                            if (_loadingInitial)
                              const LinearProgressIndicator()
                            else
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _projectId,
                                decoration: _dec('Project', required: true, hint: 'Select project'),
                                items: _projects
                                    .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _projectId = v;
                                  _activities = [];
                                }),
                              ),
                            if (_loadingInitial)
                              const LinearProgressIndicator()
                            else
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _contractorId,
                                decoration: _dec('Contractor', required: true, hint: 'Select contractor'),
                                items: _contractors
                                    .where((c) => c.isActive)
                                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                                    .toList(),
                                onChanged: (v) => setState(() => _contractorId = v),
                              ),
                            if (_loadingInitial)
                              const LinearProgressIndicator()
                            else
                              Builder(
                                builder: (context) {
                                  final allApps = _approvedTenders;
                                  final projectApps = _projectId != null
                                      ? allApps.where((a) => a.projectId == _projectId || a.tenderNo == _tenderCtrl.text).toList()
                                      : allApps;
                                  final displayApps = projectApps.isNotEmpty ? projectApps : allApps;
                                  final currentVal = _tenderCtrl.text.trim().isNotEmpty ? _tenderCtrl.text.trim() : null;
                                  final matchingApp = displayApps.where((a) => (a.tenderNo ?? a.applicationNo) == currentVal).firstOrNull;

                                  return DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: matchingApp != null ? (matchingApp.tenderNo ?? matchingApp.applicationNo) : currentVal,
                                    decoration: _dec('Tender', hint: displayApps.isEmpty ? 'No approved tenders' : 'Select approved tender'),
                                    items: [
                                      if (currentVal != null && matchingApp == null)
                                        DropdownMenuItem(
                                          value: currentVal,
                                          child: Text(currentVal, overflow: TextOverflow.ellipsis),
                                        ),
                                      ...displayApps.map((a) {
                                        final val = a.tenderNo ?? a.applicationNo;
                                        final title = [
                                          if (a.tenderNo != null) a.tenderNo!,
                                          a.applicationNo,
                                          if (a.contractorName != null || a.vendorName.isNotEmpty)
                                            '(${a.contractorName ?? a.vendorName})',
                                        ].join(' · ');
                                        return DropdownMenuItem(
                                          value: val,
                                          child: Text(title, overflow: TextOverflow.ellipsis),
                                        );
                                      }),
                                    ],
                                    onChanged: (selectedVal) {
                                      if (selectedVal == null) return;
                                      final selectedApp = displayApps.where((a) => (a.tenderNo ?? a.applicationNo) == selectedVal).firstOrNull;
                                      setState(() {
                                        _tenderCtrl.text = selectedVal;
                                        if (selectedApp != null) {
                                          if (selectedApp.projectId != null && selectedApp.projectId!.isNotEmpty) {
                                            _projectId = selectedApp.projectId;
                                          }
                                          if (selectedApp.contractorId != null && selectedApp.contractorId!.isNotEmpty) {
                                            _contractorId = selectedApp.contractorId;
                                          }
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                            lookupDropdown(
                              context: context,
                              category: kWoCategory,
                              value: _categoryCode,
                              label: 'Category',
                              onChanged: (v) => setState(() => _categoryCode = v),
                            ),
                            if (_loadingInitial)
                              const SizedBox.shrink()
                            else
                              DropdownButtonFormField<int>(
                                isExpanded: true,
                                initialValue: _approverEmployeeId,
                                decoration: _dec('Approver', hint: 'Who approves this WO'),
                                items: _employees
                                    .map((e) => DropdownMenuItem(value: e.id, child: Text(e.fullName)))
                                    .toList(),
                                onChanged: (v) => setState(() => _approverEmployeeId = v),
                              ),
                          ],
                        ),
                        if (_loadingInitial)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          WorkDetailsEditor(
                            projectId: _projectId,
                            activities: _activities,
                            configActivities: _configActivities,
                            onChanged: (groups) => setState(() => _activities = groups),
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
