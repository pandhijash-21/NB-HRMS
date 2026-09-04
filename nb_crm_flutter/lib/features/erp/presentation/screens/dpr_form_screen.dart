import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../domain/dpr_lookup_keys.dart';
import '../../domain/dpr_models.dart';
import '../../domain/structure_models.dart';
import '../../domain/work_order_models.dart';
import '../boq_providers.dart';
import '../dpr_providers.dart';
import '../project_providers.dart';
import '../work_order_providers.dart';

class DprFormScreen extends ConsumerStatefulWidget {
  const DprFormScreen({super.key});

  @override
  ConsumerState<DprFormScreen> createState() => _DprFormScreenState();
}

class _DprFormScreenState extends ConsumerState<DprFormScreen> {
  final _df = DateFormat('dd/MM/yyyy');
  DateTime _reportDate = DateTime.now();
  String? _projectId;
  final _createdByCtrl = TextEditingController();

  // Draft line
  String? _contractorId;
  String? _activityId;
  String? _subtaskId;
  String? _towerId; // null after clear; '__ALL__' for all blocks
  int? _floorNo;
  String? _unitId;
  String? _unitCode;
  final _consumedCtrl = TextEditingController(text: '0');
  String? _gradeCode;
  final _remarksCtrl = TextEditingController();
  String? _statusCode;
  final _completionCtrl = TextEditingController();
  DateTime? _actualStart;
  DateTime? _actualEnd;

  List<ErpDprMaterialLine> _draftMaterials = [];
  List<ErpDprLabourLine> _draftLabour = [];
  List<ErpDprMachineLine> _draftMachines = [];
  final List<ErpDprLine> _lines = [];

  int _resourceTab = 0; // 0 mat, 1 lab, 2 mac
  bool _saving = false;

  static const _allTower = '__ALL__';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final name = ref.read(authNotifierProvider).user?.name;
      if (name != null && _createdByCtrl.text.isEmpty) _createdByCtrl.text = name;
    });
  }

  @override
  void dispose() {
    _createdByCtrl.dispose();
    _consumedCtrl.dispose();
    _remarksCtrl.dispose();
    _completionCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {bool required = false, String? hint, bool readOnly = false}) {
    return InputDecoration(
      labelText: required ? '$label *' : label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      filled: true,
      fillColor: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  List<ErpProjectTower> get _towers {
    if (_projectId == null) return const [];
    return ref.read(projectTowersProvider(_projectId!)).asData?.value ?? const [];
  }

  List<int> get _floors {
    if (_towerId == null || _towerId == _allTower) {
      final set = <int>{};
      for (final t in _towers) {
        set.addAll(towerFloorNumbers(t));
      }
      final list = set.toList()..sort();
      return list;
    }
    final tower = _towers.where((t) => t.id == _towerId).firstOrNull;
    if (tower == null) return const [];
    return towerFloorNumbers(tower);
  }

  List<ErpProjectUnit> get _units {
    Iterable<ErpProjectUnit> all = _towers.expand((t) => t.units);
    if (_towerId != null && _towerId != _allTower) {
      all = all.where((u) => u.towerId == _towerId);
    }
    if (_floorNo != null) {
      all = all.where((u) => u.floorNo == _floorNo);
    }
    return all.toList();
  }

  List<ErpActivitySubtask> get _subtasks {
    final acts = ref.read(erpActivitiesProvider).asData?.value ?? const <ErpActivity>[];
    final act = acts.where((a) => a.id == _activityId).firstOrNull;
    return act?.subtasks.where((s) => s.isActive).toList() ?? const [];
  }

  void _clearDraft({bool keepHeader = true}) {
    setState(() {
      if (!keepHeader) {
        _projectId = null;
      }
      _contractorId = null;
      _activityId = null;
      _subtaskId = null;
      _towerId = null;
      _floorNo = null;
      _unitId = null;
      _unitCode = null;
      _consumedCtrl.text = '0';
      _gradeCode = null;
      _remarksCtrl.clear();
      _statusCode = null;
      _completionCtrl.clear();
      _actualStart = null;
      _actualEnd = null;
      _draftMaterials = [];
      _draftLabour = [];
      _draftMachines = [];
    });
  }

  Future<void> _pickDate({required void Function(DateTime) apply, DateTime? initial}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) setState(() => apply(picked));
  }

  void _addTask() {
    if (_projectId == null) {
      _toast('Select a project first');
      return;
    }
    if (_contractorId == null || _activityId == null || _unitCode == null) {
      _toast('Contractor, Activity and Unit (UOM) are required');
      return;
    }
    final consumed = double.tryParse(_consumedCtrl.text) ?? 0;
    final completion = double.tryParse(_completionCtrl.text);
    if (completion == null) {
      _toast('Total task completion % is required');
      return;
    }
    final contractors = ref.read(erpContractorsProvider).asData?.value ?? [];
    final activities = ref.read(erpActivitiesProvider).asData?.value ?? [];
    final contractor = contractors.where((c) => c.id == _contractorId).firstOrNull;
    final activity = activities.where((a) => a.id == _activityId).firstOrNull;
    final subtask = _subtasks.where((s) => s.id == _subtaskId).firstOrNull;
    String? towerName;
    if (_towerId == _allTower) {
      towerName = 'ALL';
    } else if (_towerId != null) {
      towerName = _towers.where((t) => t.id == _towerId).firstOrNull?.name;
    }
    final unit = _units.where((u) => u.id == _unitId).firstOrNull;

    setState(() {
      _lines.add(
        ErpDprLine(
          contractorId: _contractorId,
          contractorName: contractor?.name,
          activityId: _activityId,
          activityName: activity?.name,
          subtaskId: _subtaskId,
          taskName: subtask?.name,
          towerId: _towerId == _allTower ? null : _towerId,
          towerName: towerName,
          floorNo: _floorNo,
          unitId: _unitId,
          unitLabel: unit?.unitNo,
          unitCode: _unitCode,
          consumedQty: consumed,
          gradeCode: _gradeCode,
          remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
          statusCode: _statusCode,
          completionPct: completion,
          actualStartDate: _actualStart,
          actualEndDate: _actualEnd,
          materials: List.of(_draftMaterials),
          labour: List.of(_draftLabour),
          machines: List.of(_draftMachines),
        ),
      );
    });
    _clearDraft();
    _toast('Task added');
  }

  Future<void> _submit() async {
    if (_projectId == null) {
      _toast('Project is required');
      return;
    }
    if (_lines.isEmpty) {
      _toast('Add at least one task');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(dprRepositoryProvider).create({
        'reportDate': _reportDate.toIso8601String(),
        'projectId': _projectId,
        'createdByName': _createdByCtrl.text.trim().isEmpty ? null : _createdByCtrl.text.trim(),
        'lines': _lines.map((l) => l.toJson()).toList(),
      });
      ref.invalidate(dprListProvider);
      ref.invalidate(erpMaterialsProvider);
      ref.invalidate(erpMachinesProvider);
      if (mounted) context.go('/erp/dpr');
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _addMaterialDialog() async {
    final materials = ref.read(erpMaterialsProvider).asData?.value ?? [];
    String? selectedId;
    final qtyCtrl = TextEditingController(text: '0');
    final remCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final m = materials.where((x) => x.id == selectedId).firstOrNull;
          return AlertDialog(
            title: const Text('Add Material'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedId,
                    decoration: _dec('Item Name', required: true),
                    items: materials
                        .where((x) => x.isActive)
                        .map((x) => DropdownMenuItem(value: x.id, child: Text('${x.name}${x.brand != null ? ' (${x.brand})' : ''}')))
                        .toList(),
                    onChanged: (v) => setLocal(() => selectedId = v),
                  ),
                  if (m != null) ...[
                    const SizedBox(height: 8),
                    Text('Brand: ${m.brand ?? '—'} · UOM: ${m.unitCode ?? '—'} · Size: ${m.size ?? '—'} · Available: ${m.qtyAvailable.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12)),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('Consumed Qty', required: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: remCtrl, decoration: _dec('Remarks')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
            ],
          );
        },
      ),
    );
    if (ok != true || selectedId == null) return;
    final m = materials.where((x) => x.id == selectedId).firstOrNull;
    if (m == null) return;
    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    if (qty <= 0) {
      _toast('Enter consumed quantity');
      return;
    }
    setState(() {
      _draftMaterials = [
        ..._draftMaterials,
        ErpDprMaterialLine(
          materialId: m.id,
          itemName: m.name,
          brand: m.brand,
          unitCode: m.unitCode,
          size: m.size,
          consumedQty: qty,
          remarks: remCtrl.text.trim().isEmpty ? null : remCtrl.text.trim(),
        ),
      ];
    });
  }

  Future<void> _addLabourDialog() async {
    final labour = ref.read(erpLabourProvider).asData?.value ?? [];
    String? selectedId;
    final qtyCtrl = TextEditingController(text: '0');
    final remCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add Labour'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: selectedId,
                  decoration: _dec('Labour Type', required: true),
                  items: labour
                      .where((x) => x.isActive)
                      .map((x) => DropdownMenuItem(value: x.id, child: Text(x.name)))
                      .toList(),
                  onChanged: (v) => setLocal(() => selectedId = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _dec('Consumed Qty', required: true),
                ),
                const SizedBox(height: 10),
                TextField(controller: remCtrl, decoration: _dec('Remarks')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok != true || selectedId == null) return;
    final lb = labour.where((x) => x.id == selectedId).firstOrNull;
    if (lb == null) return;
    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    setState(() {
      _draftLabour = [
        ..._draftLabour,
        ErpDprLabourLine(
          labourId: lb.id,
          name: lb.name,
          unitCode: lb.unitCode,
          consumedQty: qty,
          remarks: remCtrl.text.trim().isEmpty ? null : remCtrl.text.trim(),
        ),
      ];
    });
  }

  Future<void> _addMachineDialog() async {
    final machines = ref.read(erpMachinesProvider).asData?.value ?? [];
    String? selectedId;
    final qtyCtrl = TextEditingController(text: '0');
    final remCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final m = machines.where((x) => x.id == selectedId).firstOrNull;
          return AlertDialog(
            title: const Text('Add Machinery'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedId,
                    decoration: _dec('Machine', required: true),
                    items: machines
                        .where((x) => x.isActive)
                        .map((x) => DropdownMenuItem(value: x.id, child: Text(x.name)))
                        .toList(),
                    onChanged: (v) => setLocal(() => selectedId = v),
                  ),
                  if (m != null) ...[
                    const SizedBox(height: 8),
                    Text('Brand: ${m.brand ?? '—'} · Available: ${m.qtyAvailable.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12)),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('Consumed Qty', required: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: remCtrl, decoration: _dec('Remarks')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
            ],
          );
        },
      ),
    );
    if (ok != true || selectedId == null) return;
    final m = machines.where((x) => x.id == selectedId).firstOrNull;
    if (m == null) return;
    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    setState(() {
      _draftMachines = [
        ..._draftMachines,
        ErpDprMachineLine(
          machineId: m.id,
          itemName: m.name,
          brand: m.brand,
          unitCode: m.unitCode,
          size: m.size,
          consumedQty: qty,
          remarks: remCtrl.text.trim().isEmpty ? null : remCtrl.text.trim(),
        ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsListProvider);
    final contractorsAsync = ref.watch(erpContractorsProvider);
    final activitiesAsync = ref.watch(erpActivitiesProvider);
    ref.watch(erpMaterialsProvider);
    ref.watch(erpMachinesProvider);
    ref.watch(erpLabourProvider);
    if (_projectId != null) ref.watch(projectTowersProvider(_projectId!));

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Daily Progress Report'),
        leading: const AppBackButton(fallbackLocation: '/erp/dpr'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _card(
                        isDark,
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: 200,
                              child: InkWell(
                                onTap: () => _pickDate(apply: (d) => _reportDate = d, initial: _reportDate),
                                child: InputDecorator(
                                  decoration: _dec('Date'),
                                  child: Text(_df.format(_reportDate)),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 320,
                              child: projectsAsync.when(
                                loading: () => const LinearProgressIndicator(),
                                error: (e, _) => Text('$e'),
                                data: (projects) => DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: _projectId,
                                  decoration: _dec('Project', required: true),
                                  hint: const Text('Select Project'),
                                  items: projects
                                      .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)))
                                      .toList(),
                                  onChanged: (v) => setState(() {
                                    _projectId = v;
                                    _towerId = null;
                                    _floorNo = null;
                                    _unitId = null;
                                  }),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 240,
                              child: TextFormField(
                                controller: _createdByCtrl,
                                readOnly: true,
                                decoration: _dec('DPR Created By', readOnly: true),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _card(
                        isDark,
                        child: Column(
                          children: [
                            _grid([
                              contractorsAsync.when(
                                loading: () => const LinearProgressIndicator(),
                                error: (e, _) => Text('$e'),
                                data: (list) => DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: _contractorId,
                                  decoration: _dec('Contractor', required: true),
                                  hint: const Text('Select Contractor'),
                                  items: list
                                      .where((c) => c.isActive)
                                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)))
                                      .toList(),
                                  onChanged: (v) => setState(() => _contractorId = v),
                                ),
                              ),
                              activitiesAsync.when(
                                loading: () => const LinearProgressIndicator(),
                                error: (e, _) => Text('$e'),
                                data: (list) => DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: _activityId,
                                  decoration: _dec('Activity', required: true),
                                  hint: const Text('Select Activity'),
                                  items: list
                                      .where((a) => a.isActive)
                                      .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis)))
                                      .toList(),
                                  onChanged: (v) => setState(() {
                                    _activityId = v;
                                    _subtaskId = null;
                                  }),
                                ),
                              ),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _subtaskId,
                                decoration: _dec('Task'),
                                hint: const Text('Select Work Details'),
                                items: _subtasks
                                    .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)))
                                    .toList(),
                                onChanged: _activityId == null ? null : (v) => setState(() => _subtaskId = v),
                              ),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _towerId,
                                decoration: _dec('Property Block'),
                                hint: const Text('Select Block'),
                                items: [
                                  const DropdownMenuItem(value: _allTower, child: Text('ALL')),
                                  ..._towers.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                                ],
                                onChanged: _projectId == null
                                    ? null
                                    : (v) => setState(() {
                                          _towerId = v;
                                          _floorNo = null;
                                          _unitId = null;
                                        }),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            _grid([
                              DropdownButtonFormField<int>(
                                isExpanded: true,
                                value: _floorNo,
                                decoration: _dec('Property Floor'),
                                hint: const Text('Select Floor'),
                                items: _floors.map((f) => DropdownMenuItem(value: f, child: Text('Floor $f'))).toList(),
                                onChanged: _towerId == null
                                    ? null
                                    : (v) => setState(() {
                                          _floorNo = v;
                                          _unitId = null;
                                        }),
                              ),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _unitId,
                                decoration: _dec('Property Unit'),
                                hint: const Text('Select Unit'),
                                items: _units
                                    .map((u) => DropdownMenuItem(value: u.id, child: Text(u.unitNo)))
                                    .toList(),
                                onChanged: (v) => setState(() => _unitId = v),
                              ),
                              lookupDropdown(
                                ref: ref,
                                category: DprLookupKeys.measurementUnit,
                                label: 'Unit',
                                value: _unitCode,
                                required: true,
                                onChanged: (v) => setState(() => _unitCode = v),
                              ),
                              TextFormField(
                                controller: _consumedCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                decoration: _dec("Today's Consumed Work Qty", required: true),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            _grid([
                              lookupDropdown(
                                ref: ref,
                                category: DprLookupKeys.grade,
                                label: 'Grade',
                                value: _gradeCode,
                                onChanged: (v) => setState(() => _gradeCode = v),
                              ),
                              TextFormField(
                                controller: _remarksCtrl,
                                maxLines: 2,
                                decoration: _dec('Remarks', hint: 'Enter Remark'),
                              ),
                              lookupDropdown(
                                ref: ref,
                                category: DprLookupKeys.status,
                                label: 'Status',
                                value: _statusCode,
                                onChanged: (v) => setState(() => _statusCode = v),
                              ),
                              TextFormField(
                                controller: _completionCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _dec('Total Task Completion(%)', required: true, hint: 'Enter Completion Percentage'),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            _grid([
                              InkWell(
                                onTap: () => _pickDate(apply: (d) => _actualStart = d, initial: _actualStart),
                                child: InputDecorator(
                                  decoration: _dec('Actual Start Date', readOnly: true),
                                  child: Text(_actualStart == null ? 'Select Start Date' : _df.format(_actualStart!)),
                                ),
                              ),
                              InkWell(
                                onTap: () => _pickDate(apply: (d) => _actualEnd = d, initial: _actualEnd),
                                child: InputDecorator(
                                  decoration: _dec('Actual End Date', readOnly: true),
                                  child: Text(_actualEnd == null ? 'Select End Date' : _df.format(_actualEnd!)),
                                ),
                              ),
                              InputDecorator(
                                decoration: _dec('Material Rate', readOnly: true),
                                child: const Text('No'),
                              ),
                              InputDecorator(
                                decoration: _dec('Labour Rate', readOnly: true),
                                child: const Text('No'),
                              ),
                              InputDecorator(
                                decoration: _dec('Machine Rate', readOnly: true),
                                child: const Text('No'),
                              ),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _resourceSection(isDark),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: _addTask,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Task'),
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1e3a5f)),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: () => _clearDraft(),
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC5A059)),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _taskTable(isDark),
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
              border: Border(top: BorderSide(color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1e3a5f),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Submit'),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _saving ? null : () => context.go('/erp/dpr'),
                  child: const Text('Go to DPR'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resourceSection(bool isDark) {
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _tabChip('Material', 0),
              const SizedBox(width: 8),
              _tabChip('Labour', 1),
              const SizedBox(width: 8),
              _tabChip('Machinery', 2),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  if (_resourceTab == 0) _addMaterialDialog();
                  if (_resourceTab == 1) _addLabourDialog();
                  if (_resourceTab == 2) _addMachineDialog();
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1e3a5f)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_resourceTab == 0) _materialTable(),
          if (_resourceTab == 1) _labourTable(),
          if (_resourceTab == 2) _machineTable(),
        ],
      ),
    );
  }

  Widget _tabChip(String label, int index) {
    final on = _resourceTab == index;
    return ChoiceChip(
      label: Text(label),
      selected: on,
      onSelected: (_) => setState(() => _resourceTab = index),
      selectedColor: const Color(0xFF1e3a5f),
      labelStyle: TextStyle(color: on ? Colors.white : null, fontWeight: FontWeight.w700),
    );
  }

  Widget _materialTable() {
    if (_draftMaterials.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No materials added for this task draft.'),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('SR#')),
          DataColumn(label: Text('ITEM CODE')),
          DataColumn(label: Text('ITEM NAME')),
          DataColumn(label: Text('BRAND')),
          DataColumn(label: Text('UOM')),
          DataColumn(label: Text('SIZE')),
          DataColumn(label: Text('CONSUMED QTY')),
          DataColumn(label: Text('REMARKS')),
          DataColumn(label: Text('ACTION')),
        ],
        rows: [
          for (var i = 0; i < _draftMaterials.length; i++)
            DataRow(
              cells: [
                DataCell(Text('${i + 1}')),
                DataCell(Text(_draftMaterials[i].itemCode ?? '—')),
                DataCell(Text(_draftMaterials[i].itemName)),
                DataCell(Text(_draftMaterials[i].brand ?? '—')),
                DataCell(Text(_draftMaterials[i].unitCode ?? '—')),
                DataCell(Text(_draftMaterials[i].size ?? '—')),
                DataCell(Text(_draftMaterials[i].consumedQty.toStringAsFixed(2))),
                DataCell(Text(_draftMaterials[i].remarks ?? '—')),
                DataCell(IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _draftMaterials = [..._draftMaterials]..removeAt(i)),
                )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _labourTable() {
    if (_draftLabour.isEmpty) {
      return const Padding(padding: EdgeInsets.all(12), child: Text('No labour added for this task draft.'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('SR#')),
          DataColumn(label: Text('NAME')),
          DataColumn(label: Text('UOM')),
          DataColumn(label: Text('CONSUMED QTY')),
          DataColumn(label: Text('REMARKS')),
          DataColumn(label: Text('ACTION')),
        ],
        rows: [
          for (var i = 0; i < _draftLabour.length; i++)
            DataRow(
              cells: [
                DataCell(Text('${i + 1}')),
                DataCell(Text(_draftLabour[i].name)),
                DataCell(Text(_draftLabour[i].unitCode ?? '—')),
                DataCell(Text(_draftLabour[i].consumedQty.toStringAsFixed(2))),
                DataCell(Text(_draftLabour[i].remarks ?? '—')),
                DataCell(IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _draftLabour = [..._draftLabour]..removeAt(i)),
                )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _machineTable() {
    if (_draftMachines.isEmpty) {
      return const Padding(padding: EdgeInsets.all(12), child: Text('No machinery added for this task draft.'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('SR#')),
          DataColumn(label: Text('NAME')),
          DataColumn(label: Text('BRAND')),
          DataColumn(label: Text('UOM')),
          DataColumn(label: Text('CONSUMED QTY')),
          DataColumn(label: Text('REMARKS')),
          DataColumn(label: Text('ACTION')),
        ],
        rows: [
          for (var i = 0; i < _draftMachines.length; i++)
            DataRow(
              cells: [
                DataCell(Text('${i + 1}')),
                DataCell(Text(_draftMachines[i].itemName)),
                DataCell(Text(_draftMachines[i].brand ?? '—')),
                DataCell(Text(_draftMachines[i].unitCode ?? '—')),
                DataCell(Text(_draftMachines[i].consumedQty.toStringAsFixed(2))),
                DataCell(Text(_draftMachines[i].remarks ?? '—')),
                DataCell(IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _draftMachines = [..._draftMachines]..removeAt(i)),
                )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _taskTable(bool isDark) {
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Task List', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          if (_lines.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No data available in table.')),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('SR#')),
                  DataColumn(label: Text('CONTRACTOR')),
                  DataColumn(label: Text('ACTIVITY')),
                  DataColumn(label: Text('TASK')),
                  DataColumn(label: Text('BLOCK')),
                  DataColumn(label: Text('FLOOR')),
                  DataColumn(label: Text('UNIT')),
                  DataColumn(label: Text("TODAY'S QTY")),
                  DataColumn(label: Text('GRADE')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('COMPLETION %')),
                  DataColumn(label: Text('ACTION')),
                ],
                rows: [
                  for (var i = 0; i < _lines.length; i++)
                    DataRow(
                      cells: [
                        DataCell(Text('${i + 1}')),
                        DataCell(Text(_lines[i].contractorName ?? '—')),
                        DataCell(Text(_lines[i].activityName ?? '—')),
                        DataCell(Text(_lines[i].taskName ?? '—')),
                        DataCell(Text(_lines[i].towerName ?? '—')),
                        DataCell(Text(_lines[i].floorNo?.toString() ?? '—')),
                        DataCell(Text(_lines[i].unitLabel ?? '—')),
                        DataCell(Text(_lines[i].consumedQty.toStringAsFixed(2))),
                        DataCell(Text(_lines[i].gradeCode ?? '—')),
                        DataCell(Text(_lines[i].statusCode ?? '—')),
                        DataCell(Text(_lines[i].completionPct?.toStringAsFixed(1) ?? '—')),
                        DataCell(IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => setState(() => _lines.removeAt(i)),
                        )),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(bool isDark, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }

  Widget _grid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        if (!wide) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                children[i],
              ],
            ],
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children
              .map((w) => SizedBox(width: (c.maxWidth - 36) / 4, child: w))
              .toList(),
        );
      },
    );
  }
}

extension _FirstOrNullX<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
