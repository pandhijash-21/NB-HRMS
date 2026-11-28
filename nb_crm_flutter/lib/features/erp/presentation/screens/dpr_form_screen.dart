import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/realtime/app_event_bus.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../../core/services/form_draft_service.dart';
import '../../../../core/widgets/form_draft_banner.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../data/boq_repository.dart';
import '../../data/dpr_repository.dart';
import '../../data/project_repository.dart';
import '../../data/work_order_repository.dart';
import '../../domain/dpr_lookup_keys.dart';
import '../../domain/dpr_models.dart';
import '../../domain/project_models.dart';
import '../../domain/resource_models.dart';
import '../../domain/structure_models.dart';
import '../../domain/work_order_models.dart';
import '../widgets/quick_create_masters.dart';
import '../widgets/quick_create_vendor_dialog.dart';

class DprFormScreen extends StatefulWidget {
  const DprFormScreen({super.key, this.dprId});

  /// When set, form loads this DPR for edit (within admin edit window).
  final String? dprId;

  @override
  State<DprFormScreen> createState() => _DprFormScreenState();
}

class _DprFormScreenState extends State<DprFormScreen> {
  final _df = DateFormat('dd/MM/yyyy');
  DateTime _reportDate = DateTime.now();
  String? _projectId;
  final _createdByCtrl = TextEditingController();

  // Multi-draft management
  String _currentDraftId = 'dpr_${DateTime.now().millisecondsSinceEpoch}';
  List<MultiDraftSummary> _savedDrafts = [];
  bool _isAutoSaving = false;

  // Draft line
  String? _contractorId;
  String? _activityId;
  /// Multi-select work details (subtasks) under the chosen activity.
  final Set<String> _selectedSubtaskIds = {};
  String? _towerId; // null after clear; '__ALL__' for all blocks
  int? _floorNo; // null unset; -1 = ALL floors
  String? _unitId; // null unset; '__ALL__' = ALL units
  String? _unitCode;
  final _consumedCtrl = TextEditingController();
  String? _gradeCode;
  final _remarksCtrl = TextEditingController();
  String? _statusCode;
  final _completionCtrl = TextEditingController();
  DateTime? _actualStart;
  DateTime? _actualEnd;

  List<ErpDprMaterialLine> _draftMaterials = [];
  /// labourId -> qty text (inline on main form; all labour masters shown)
  final Map<String, TextEditingController> _labourQtyCtrls = {};
  List<ErpDprMachineLine> _draftMachines = [];
  final List<ErpDprLine> _lines = [];
  String? _editingDprId;
  int _editWindowDays = 10;
  bool _editLocked = false;
  StreamSubscription<ErpRealtimeEvent>? _erpSub;
  bool _remoteReloadQueued = false;

  List<ErpProject> _projects = [];
  List<ErpContractor> _contractors = [];
  List<ErpActivity> _activities = [];
  List<ErpMaterial> _materials = [];
  List<ErpMachine> _machines = [];
  List<ErpLabour> _labour = [];
  final Map<String, List<ErpProjectTower>> _projectTowers = {};
  bool _loadingInitial = true;

  int _resourceTab = 0; // 0 mat, 1 lab, 2 mac
  bool _saving = false;
  FormDraftInfo? _draftInfo;

  static const _allTower = '__ALL__';
  static const _allFloor = -1;
  static const _allUnit = '__ALL__';

  @override
  void initState() {
    super.initState();
    _editingDprId = widget.dprId;
    _remarksCtrl.addListener(_autoSaveDraft);
    _consumedCtrl.addListener(_autoSaveDraft);
    _completionCtrl.addListener(_autoSaveDraft);
    _erpSub = AppEventBus.instance.on<ErpRealtimeEvent>().listen((e) {
      if (_editingDprId == null) return;
      if (e.module != 'dpr' && e.module != 'erp' && e.module != 'store-inward') return;
      if (e.entityId != null && e.entityId != _editingDprId && e.entityId != 'settings') return;
      if (_remoteReloadQueued || _saving) return;
      _remoteReloadQueued = true;
      Future<void>.delayed(const Duration(milliseconds: 400), () async {
        _remoteReloadQueued = false;
        if (!mounted || _editingDprId == null) return;
        await _loadExistingDpr(_editingDprId!);
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final name = context.read<AuthBloc>().state.user?.name;
      if (name != null && _createdByCtrl.text.isEmpty) _createdByCtrl.text = name;
      _loadInitialData();
    });
  }

  List<ErpDprLabourLine> _collectLabourFromForm() {
    final out = <ErpDprLabourLine>[];
    for (final lb in _labour) {
      final ctrl = _labourQtyCtrls[lb.id];
      if (ctrl == null) continue;
      final qty = double.tryParse(ctrl.text.trim()) ?? 0;
      if (qty <= 0) continue;
      out.add(ErpDprLabourLine(
        labourId: lb.id,
        name: lb.name,
        unitCode: lb.unitCode,
        consumedQty: qty,
      ));
    }
    return out;
  }

  void _syncLabourQtyControllers() {
    for (final lb in _labour) {
      _labourQtyCtrls.putIfAbsent(lb.id, () => TextEditingController(text: ''));
    }
  }

  void _applyLabourToControllers(List<ErpDprLabourLine> labour) {
    _syncLabourQtyControllers();
    for (final c in _labourQtyCtrls.values) {
      c.text = '';
    }
    for (final row in labour) {
      final id = row.labourId;
      if (id == null) continue;
      final ctrl = _labourQtyCtrls[id];
      if (ctrl != null) ctrl.text = row.consumedQty > 0 ? row.consumedQty.toString() : '';
    }
  }

  String get _currentDraftTitle {
    final proj = _projects.where((p) => p.id == _projectId).firstOrNull?.name ?? 'Untitled Project';
    final dateStr = DateFormat('d MMM').format(_reportDate);
    final count = _lines.length;
    return '$proj • $dateStr${count > 0 ? ' ($count tasks)' : ''}';
  }

  void _autoSaveDraft({bool immediate = false}) {
    if (_saving || _loadingInitial) return;
    final projectName = _projects.where((p) => p.id == _projectId).firstOrNull?.name ?? 'Untitled Project';
    final dateStr = DateFormat('d MMM').format(_reportDate);
    final count = _lines.length;
    final title = '$projectName ($dateStr${count > 0 ? ' • $count tasks' : ''})';
    final data = {
      'reportDate': _reportDate.toIso8601String(),
      'projectId': _projectId,
      'createdByName': _createdByCtrl.text.trim(),
      'contractorId': _contractorId,
      'activityId': _activityId,
      'subtaskIds': _selectedSubtaskIds.toList(),
      'towerId': _towerId,
      'floorNo': _floorNo,
      'unitId': _unitId,
      'unitCode': _unitCode,
      'consumed': _consumedCtrl.text.trim(),
      'gradeCode': _gradeCode,
      'remarks': _remarksCtrl.text.trim(),
      'statusCode': _statusCode,
      'completion': _completionCtrl.text.trim(),
      'lines': _lines.map((l) => l.toJson()).toList(),
      'draftMaterials': _draftMaterials.map((m) => m.toJson()).toList(),
      'draftLabour': _collectLabourFromForm().map((l) => l.toJson()).toList(),
      'draftMachines': _draftMachines.map((m) => m.toJson()).toList(),
    };

    if (mounted) setState(() => _isAutoSaving = true);

    FormDraftService.instance.autoSaveMultiDraft(
      formId: 'erp_dpr',
      draftId: _currentDraftId,
      title: title,
      subtitle: '$count tasks added',
      data: data,
      immediate: immediate,
      onSaved: () {
        if (mounted) {
          setState(() => _isAutoSaving = false);
          _refreshSavedDraftsList();
        }
      },
    );
  }

  Future<void> _refreshSavedDraftsList() async {
    final list = await FormDraftService.instance.listMultiDrafts('erp_dpr');
    if (mounted) {
      setState(() => _savedDrafts = list);
    }
  }

  Future<void> _fetchTowersForProject(String pId) async {
    if (!_projectTowers.containsKey(pId)) {
      try {
        final towers = await context.read<ProjectRepository>().listTowers(pId);
        if (mounted) {
          setState(() {
            _projectTowers[pId] = towers;
          });
        }
      } catch (e) {
        debugPrint('Failed to load towers for project $pId: $e');
      }
    }
  }

  Future<void> _restoreDraftIfAny() async {
    await _refreshSavedDraftsList();
    final activeId = await FormDraftService.instance.getActiveMultiDraftId('erp_dpr');
    MultiDraftSummary? target;
    if (activeId != null && activeId.isNotEmpty) {
      target = _savedDrafts.where((d) => d.draftId == activeId).firstOrNull;
    }
    target ??= _savedDrafts.firstOrNull;

    if (target != null && mounted) {
      await _openDraft(target, promptSaveCurrent: false);
    }
  }

  Future<void> _openDraft(MultiDraftSummary draft, {bool promptSaveCurrent = true}) async {
    if (promptSaveCurrent && _lines.isNotEmpty) {
      _autoSaveDraft(immediate: true);
    }

    final d = draft.data;
    _currentDraftId = draft.draftId;
    _draftInfo = FormDraftInfo(
      formId: 'erp_dpr',
      draftId: draft.draftId,
      savedAt: draft.savedAt,
      data: d,
    );

    if (d['reportDate'] != null) {
      _reportDate = DateTime.tryParse(d['reportDate'].toString()) ?? _reportDate;
    }
    _projectId = d['projectId'] as String?;
    if ((d['createdByName'] as String?)?.isNotEmpty == true) {
      _createdByCtrl.text = d['createdByName'];
    }
    _contractorId = d['contractorId'] as String?;
    _activityId = d['activityId'] as String?;
    _selectedSubtaskIds
      ..clear()
      ..addAll(
        (d['subtaskIds'] is List)
            ? (d['subtaskIds'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty)
            : (d['subtaskId'] != null ? [d['subtaskId'].toString()] : const <String>[]),
      );
    _towerId = d['towerId'] as String?;
    _floorNo = d['floorNo'] as int?;
    _unitId = d['unitId'] as String?;
    _unitCode = d['unitCode'] as String?;
    if (d['consumed'] != null) _consumedCtrl.text = d['consumed'].toString();
    _gradeCode = d['gradeCode'] as String?;
    if (d['remarks'] != null) _remarksCtrl.text = d['remarks'].toString();
    _statusCode = d['statusCode'] as String?;
    if (d['completion'] != null) _completionCtrl.text = d['completion'].toString();

    if (d['lines'] is List) {
      try {
        _lines
          ..clear()
          ..addAll((d['lines'] as List).map((l) => ErpDprLine.fromJson(l as Map<String, dynamic>)));
      } catch (_) {}
    }
    if (d['draftMaterials'] is List) {
      try {
        _draftMaterials = (d['draftMaterials'] as List).map((m) => ErpDprMaterialLine.fromJson(m as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    if (d['draftLabour'] is List) {
      try {
        final labour = (d['draftLabour'] as List)
            .map((l) => ErpDprLabourLine.fromJson(l as Map<String, dynamic>))
            .toList();
        _applyLabourToControllers(labour);
      } catch (_) {}
    }
    if (d['draftMachines'] is List) {
      try {
        _draftMachines = (d['draftMachines'] as List).map((m) => ErpDprMachineLine.fromJson(m as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    await FormDraftService.instance.setActiveMultiDraftId('erp_dpr', draft.draftId);

    if (mounted) setState(() {});

    if (_projectId != null) {
      await _fetchTowersForProject(_projectId!);
    }
    if (_contractorId != null) {
      await _fetchContractorResources(_contractorId, _reportDate);
    }
    if (mounted) setState(() {});
  }

  void _createNewDraft() {
    // Save current draft if it has content
    if (_lines.isNotEmpty || _projectId != null) {
      _autoSaveDraft(immediate: true);
    }
    setState(() {
      _currentDraftId = 'dpr_${DateTime.now().millisecondsSinceEpoch}';
      _draftInfo = null;
      _lines.clear();
      _projectId = null;
      _contractorId = null;
      _activityId = null;
      _selectedSubtaskIds.clear();
      _towerId = null;
      _floorNo = null;
      _unitId = null;
      _unitCode = null;
      _consumedCtrl.clear();
      _remarksCtrl.clear();
      _completionCtrl.clear();
      _draftMaterials = [];
      _applyLabourToControllers(const []);
      _draftMachines = [];
    });
    FormDraftService.instance.setActiveMultiDraftId('erp_dpr', _currentDraftId);
    _toast('Started new DPR draft');
  }

  Future<void> _discardCurrentDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Draft?'),
        content: const Text('Are you sure you want to discard this DPR draft? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await FormDraftService.instance.deleteMultiDraft('erp_dpr', _currentDraftId);
    await _refreshSavedDraftsList();

    if (_savedDrafts.isNotEmpty) {
      await _openDraft(_savedDrafts.first, promptSaveCurrent: false);
      _toast('Switched to draft: ${_savedDrafts.first.title}');
    } else {
      _createNewDraft();
    }
  }

  Future<void> _deleteSpecificDraft(String draftId) async {
    await FormDraftService.instance.deleteMultiDraft('erp_dpr', draftId);
    await _refreshSavedDraftsList();
    if (_currentDraftId == draftId) {
      if (_savedDrafts.isNotEmpty) {
        await _openDraft(_savedDrafts.first, promptSaveCurrent: false);
      } else {
        _createNewDraft();
      }
    } else {
      if (mounted) setState(() {});
    }
    _toast('Draft deleted');
  }

  void _saveDraftExplicitly() {
    _autoSaveDraft(immediate: true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('DPR saved as draft successfully!'),
        backgroundColor: Color(0xFF0F766E),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showDraftsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.folder_open_rounded, color: Color(0xFF0D9488)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Saved DPR Drafts (${_savedDrafts.length})', style: const TextStyle(fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF0D9488)),
                tooltip: 'Create New Draft',
                onPressed: () {
                  Navigator.pop(ctx);
                  _createNewDraft();
                },
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: _savedDrafts.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No saved drafts found.')),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _savedDrafts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final draft = _savedDrafts[idx];
                      final isActive = draft.draftId == _currentDraftId;
                      final isDark = Theme.of(ctx).brightness == Brightness.dark;
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        color: isActive
                            ? (isDark ? const Color(0xFF132A26) : const Color(0xFFF0FDF4))
                            : Colors.transparent,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          draft.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: isActive ? const Color(0xFF0D9488) : null,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isActive)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'ACTIVE',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0D9488),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Saved ${draft.formattedTime}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!isActive)
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _openDraft(draft);
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF0D9488),
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                child: const Text('Resume'),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                              tooltip: 'Delete Draft',
                              onPressed: () async {
                                await _deleteSpecificDraft(draft.draftId);
                                setDlg(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _createNewDraft();
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('+ New DPR Draft'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadInitialData() async {
    try {
      final projectRepo = context.read<ProjectRepository>();
      final workRepo = context.read<WorkOrderRepository>();
      final boqRepo = context.read<BoqRepository>();
      final dprRepo = context.read<DprRepository>();
      final res = await Future.wait([
        projectRepo.list(),
        workRepo.listContractors(),
        workRepo.listActivities(),
        boqRepo.listMaterials(),
        boqRepo.listMachines(),
        boqRepo.listLabour(),
        dprRepo.getSettings(),
      ]);
      if (!mounted) return;
      setState(() {
        _projects = res[0] as List<ErpProject>;
        _contractors = res[1] as List<ErpContractor>;
        _activities = res[2] as List<ErpActivity>;
        _materials = res[3] as List<ErpMaterial>;
        _machines = res[4] as List<ErpMachine>;
        _labour = res[5] as List<ErpLabour>;
        _editWindowDays = (res[6] as ErpDprSettings).editWindowDays;
        _syncLabourQtyControllers();
        _loadingInitial = false;
      });
      if (_editingDprId != null) {
        await _loadExistingDpr(_editingDprId!);
      } else {
        await _restoreDraftIfAny();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingInitial = false);
        _toast('Failed to load initial data: $e');
      }
    }
  }

  Future<void> _loadExistingDpr(String id) async {
    try {
      final dpr = await context.read<DprRepository>().getById(id);
      if (!mounted) return;
      final today = DateTime.now();
      final report = DateTime(dpr.reportDate.year, dpr.reportDate.month, dpr.reportDate.day);
      final now = DateTime(today.year, today.month, today.day);
      final diffDays = now.difference(report).inDays;
      setState(() {
        _editingDprId = dpr.id;
        _reportDate = dpr.reportDate;
        _projectId = dpr.projectId;
        if (dpr.createdByName != null) _createdByCtrl.text = dpr.createdByName!;
        _lines
          ..clear()
          ..addAll(dpr.lines);
        _editLocked = diffDays > _editWindowDays;
      });
      if (_projectId != null) await _fetchTowersForProject(_projectId!);
      if (_editLocked && mounted) {
        _toast('Edit window of $_editWindowDays day(s) has expired for this DPR');
      }
    } catch (e) {
      if (mounted) _toast('Failed to load DPR: $e');
    }
  }

  Future<void> _onProjectChanged(String? pId) async {
    setState(() {
      _projectId = pId;
      _towerId = null;
      _floorNo = null;
      _unitId = null;
    });
    _autoSaveDraft();
    if (pId != null) {
      await _fetchTowersForProject(pId);
    }
  }

  @override
  void dispose() {
    _erpSub?.cancel();
    if (_editingDprId == null) _autoSaveDraft(immediate: true);
    _createdByCtrl.dispose();
    _consumedCtrl.dispose();
    _remarksCtrl.dispose();
    _completionCtrl.dispose();
    for (final c in _labourQtyCtrls.values) {
      c.dispose();
    }
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
    return _projectTowers[_projectId] ?? const [];
  }

  List<int> get _floors {
    if (_towerId == null) return const [];
    if (_towerId == _allTower) {
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
    if (_floorNo != null && _floorNo != _allFloor) {
      all = all.where((u) => u.floorNo == _floorNo);
    }
    return all.toList();
  }

  List<ErpActivitySubtask> get _subtasks {
    final act = _activities.where((a) => a.id == _activityId).firstOrNull;
    return act?.subtasks.where((s) => s.isActive).toList() ?? const [];
  }

  void _clearDraft({bool keepHeader = true}) {
    setState(() {
      if (!keepHeader) {
        _projectId = null;
      }
      _contractorId = null;
      _activityId = null;
      _selectedSubtaskIds.clear();
      _towerId = null;
      _floorNo = null;
      _unitId = null;
      _unitCode = null;
      _consumedCtrl.clear();
      _gradeCode = null;
      _remarksCtrl.clear();
      _statusCode = null;
      _completionCtrl.clear();
      _actualStart = null;
      _actualEnd = null;
      _draftMaterials = [];
      _applyLabourToControllers(const []);
      _draftMachines = [];
    });
  }

  Future<void> _fetchContractorResources(String? contractorId, DateTime date) async {
    if (contractorId == null) {
      setState(() {
        _draftMaterials = [];
        _draftMachines = [];
      });
      return;
    }
    try {
      final res = await context.read<DprRepository>().getContractorResources(contractorId, date: date);
      final mats = (res['materials'] as List<ErpDprMaterialLine>?) ?? [];
      final macs = (res['machines'] as List<ErpDprMachineLine>?) ?? [];
      if (mounted) {
        setState(() {
          _draftMaterials = mats;
          _draftMachines = macs;
        });
      }
    } catch (e) {
      debugPrint('Error fetching contractor resources for DPR: $e');
    }
  }

  Future<void> _pickDate({required void Function(DateTime) apply, DateTime? initial}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(() => apply(picked));
      _autoSaveDraft();
    }
  }

  void _addTask() {
    if (_editLocked) {
      _toast('This DPR can no longer be edited');
      return;
    }
    if (_projectId == null || _projectId!.isEmpty) {
      _toast('Select a project first');
      return;
    }
    final contractorId = _contractorId?.trim();
    final activityId = _activityId?.trim();
    final unitCode = _unitCode?.trim();
    if (contractorId == null || contractorId.isEmpty) {
      _toast('Agency is required');
      return;
    }
    if (activityId == null || activityId.isEmpty) {
      _toast('Activity is required');
      return;
    }
    if (unitCode == null || unitCode.isEmpty) {
      _toast('Unit (UOM) is required');
      return;
    }
    final consumed = double.tryParse(_consumedCtrl.text.trim()) ?? 0;
    final completion = double.tryParse(_completionCtrl.text.trim());
    if (completion == null) {
      _toast('Total task completion % is required');
      return;
    }
    final contractor = _contractors.where((c) => c.id == contractorId).firstOrNull;
    final activity = _activities.where((a) => a.id == activityId).firstOrNull;
    final selectedSubtasks = _subtasks.where((s) => _selectedSubtaskIds.contains(s.id)).toList();
    // One DPR line covering all selected work details for this activity.
    final taskName = selectedSubtasks.isEmpty
        ? null
        : selectedSubtasks.map((s) => s.name).join(', ');
    final primarySubtaskId = selectedSubtasks.length == 1 ? selectedSubtasks.first.id : null;
    String? towerName;
    if (_towerId == _allTower) {
      towerName = 'ALL';
    } else if (_towerId != null) {
      towerName = _towers.where((t) => t.id == _towerId).firstOrNull?.name;
    }
    String? unitLabel;
    String? unitId;
    if (_unitId == _allUnit) {
      unitLabel = 'ALL';
      unitId = null;
    } else if (_unitId != null) {
      unitId = _unitId;
      unitLabel = _units.where((u) => u.id == _unitId).firstOrNull?.unitNo;
    }
    final floorNo = _floorNo; // may be -1 for ALL

    setState(() {
      _lines.add(
        ErpDprLine(
          contractorId: contractorId,
          contractorName: contractor?.name,
          activityId: activityId,
          activityName: activity?.name,
          subtaskId: primarySubtaskId,
          taskName: taskName,
          towerId: _towerId == _allTower ? null : _towerId,
          towerName: towerName,
          floorNo: floorNo,
          unitId: unitId,
          unitLabel: unitLabel,
          unitCode: unitCode,
          consumedQty: consumed,
          gradeCode: _gradeCode,
          remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
          statusCode: _statusCode,
          completionPct: completion,
          actualStartDate: _actualStart,
          actualEndDate: _actualEnd,
          materials: List.of(_draftMaterials),
          labour: _collectLabourFromForm(),
          machines: List.of(_draftMachines),
        ),
      );
    });
    _clearDraft();
    _autoSaveDraft();
    _toast(selectedSubtasks.length > 1
        ? 'Task added with ${selectedSubtasks.length} work details'
        : 'Task added');
  }

  Future<void> _submit() async {
    if (_editLocked) {
      _toast('This DPR can no longer be edited');
      return;
    }
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
      final body = {
        'reportDate': _reportDate.toIso8601String(),
        'projectId': _projectId,
        'createdByName': _createdByCtrl.text.trim().isEmpty ? null : _createdByCtrl.text.trim(),
        'lines': _lines.map((l) => l.toJson()).toList(),
      };
      final ErpDpr saved;
      if (_editingDprId != null) {
        saved = await context.read<DprRepository>().update(_editingDprId!, body);
      } else {
        saved = await context.read<DprRepository>().create(body);
      }
      await FormDraftService.instance.clearSubmittedMultiDraft('erp_dpr', _currentDraftId);
      await FormDraftService.instance.clearDraft('erp_dpr');
      await _refreshSavedDraftsList();
      if (!mounted) return;
      context.go('/erp/dpr/${saved.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${saved.dprNo} ${_editingDprId != null ? 'updated' : 'saved'} — view / print Daily Report'),
          backgroundColor: Colors.green.shade700,
        ),
      );
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
    var materials = List<ErpMaterial>.from(_materials);
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
                  MaterialDropdownWithCreate(
                    value: selectedId,
                    materials: materials,
                    required: true,
                    decoration: _dec('Item Name', required: true),
                    itemLabel: (x) =>
                        '${x.name}${x.brand != null ? ' (${x.brand})' : ''}',
                    onChanged: (v) => setLocal(() => selectedId = v),
                    onMaterialCreated: (created) {
                      setState(() => _materials = [..._materials, created]);
                      setLocal(() {
                        materials = [...materials, created];
                        selectedId = created.id;
                      });
                    },
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
    _autoSaveDraft();
  }

  Future<void> _addMachineDialog() async {
    var machines = List<ErpMachine>.from(_machines);
    String? selectedId;
    final qtyCtrl = TextEditingController(text: '1');
    final remCtrl = TextEditingController();
    final slots = <({TimeOfDay? from, TimeOfDay? to})>[(from: null, to: null)];
    String fmt(TimeOfDay? t) =>
        t == null ? '—' : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    Future<TimeOfDay?> pickTime(TimeOfDay? initial) => showTimePicker(
          context: context,
          initialTime: initial ?? TimeOfDay.now(),
        );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final m = machines.where((x) => x.id == selectedId).firstOrNull;
          return AlertDialog(
            title: const Text('Add Machinery'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MachineDropdownWithCreate(
                      value: selectedId,
                      machines: machines,
                      required: true,
                      decoration: _dec('Machine', required: true),
                      itemLabel: (x) => x.name,
                      onChanged: (v) => setLocal(() => selectedId = v),
                      onMachineCreated: (created) {
                        setState(() => _machines = [..._machines, created]);
                        setLocal(() {
                          machines = [...machines, created];
                          selectedId = created.id;
                        });
                      },
                    ),
                    if (m != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Brand: ${m.brand ?? '—'} · Available: ${m.qtyAvailable.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _dec('Qty', required: true),
                    ),
                    const SizedBox(height: 12),
                    const Text('Time slots', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    for (var i = 0; i < slots.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final t = await pickTime(slots[i].from);
                                  if (t != null) {
                                    setLocal(() => slots[i] = (from: t, to: slots[i].to));
                                  }
                                },
                                child: Text('From ${fmt(slots[i].from)}'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final t = await pickTime(slots[i].to);
                                  if (t != null) {
                                    setLocal(() => slots[i] = (from: slots[i].from, to: t));
                                  }
                                },
                                child: Text('To ${fmt(slots[i].to)}'),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove slot',
                              onPressed: slots.length <= 1
                                  ? null
                                  : () => setLocal(() => slots.removeAt(i)),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setLocal(() => slots.add((from: null, to: null))),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add time slot'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(controller: remCtrl, decoration: _dec('Remarks')),
                  ],
                ),
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
    final timeSlots = slots
        .where((s) => s.from != null && s.to != null)
        .map((s) => ErpDprMachineTimeSlot(from: fmt(s.from), to: fmt(s.to)))
        .toList();
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
          timeSlots: timeSlots,
          remarks: remCtrl.text.trim().isEmpty ? null : remCtrl.text.trim(),
        ),
      ];
    });
    _autoSaveDraft();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        _autoSaveDraft(immediate: true);
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: Text(_editingDprId != null ? 'Edit Daily Progress Report' : 'Daily Progress Report'),
          leading: const AppBackButton(fallbackLocation: '/erp/dpr'),
          actions: [
            if (_savedDrafts.isNotEmpty)
              TextButton.icon(
                onPressed: _showDraftsDialog,
                icon: const Icon(Icons.folder_open_rounded, size: 16),
                label: Text('Drafts (${_savedDrafts.length})'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFC5A059),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            TextButton.icon(
              onPressed: _createNewDraft,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('+ New Draft'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
          ],
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
                        FormDraftBanner(
                          formId: 'erp_dpr',
                          draftInfo: _draftInfo,
                          customTitle: _draftInfo != null ? 'Draft: $_currentDraftTitle' : null,
                          draftCount: _savedDrafts.length,
                          isSaving: _isAutoSaving,
                          onManageDrafts: _savedDrafts.isNotEmpty ? _showDraftsDialog : null,
                          onNewDraft: _createNewDraft,
                          onDiscard: _draftInfo != null ? _discardCurrentDraft : null,
                        ),
                        _card(
                          isDark,
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: 200,
                                child: InkWell(
                                  onTap: () => _pickDate(
                                    apply: (d) {
                                      _reportDate = d;
                                      if (_contractorId != null) {
                                        _fetchContractorResources(_contractorId, d);
                                      }
                                    },
                                    initial: _reportDate,
                                  ),
                                  child: InputDecorator(
                                    decoration: _dec('Date'),
                                    child: Text(_df.format(_reportDate)),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 320,
                                child: _loadingInitial
                                    ? const LinearProgressIndicator()
                                    : DropdownButtonFormField<String>(
                                        key: ValueKey('project_$_projectId'),
                                        isExpanded: true,
                                        initialValue: _projectId,
                                        decoration: _dec('Project', required: true),
                                        hint: const Text('Select Project'),
                                        items: _projects
                                            .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)))
                                            .toList(),
                                        onChanged: _onProjectChanged,
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
                                _loadingInitial
                                    ? const LinearProgressIndicator()
                                    : VendorDropdownWithCreate(
                                        value: _contractorId,
                                        vendors: _contractors,
                                        required: true,
                                        decoration: _dec('Agency', required: true),
                                        hint: const Text('Select Agency'),
                                        onChanged: (v) {
                                          setState(() => _contractorId = v);
                                          _fetchContractorResources(v, _reportDate);
                                          _autoSaveDraft();
                                        },
                                        onVendorCreated: (created) {
                                          setState(() {
                                            _contractors = [..._contractors, created];
                                            _contractorId = created.id;
                                          });
                                          _fetchContractorResources(created.id, _reportDate);
                                          _autoSaveDraft();
                                        },
                                      ),
                                _loadingInitial
                                    ? const LinearProgressIndicator()
                                    : ActivityDropdownWithCreate(
                                        value: _activityId,
                                        activities: _activities,
                                        required: true,
                                        decoration: _dec('Activity', required: true),
                                        hint: const Text('Select Activity'),
                                        onChanged: (v) => setState(() {
                                          _activityId = v;
                                          _selectedSubtaskIds.clear();
                                          _autoSaveDraft();
                                        }),
                                        onActivityCreated: (created) => setState(() {
                                          _activities = [..._activities, created];
                                          _activityId = created.id;
                                          _selectedSubtaskIds.clear();
                                          _autoSaveDraft();
                                        }),
                                      ),
                                DropdownButtonFormField<String>(
                                  key: ValueKey('tower_$_towerId'),
                                  isExpanded: true,
                                  initialValue: _towerId,
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
                                            _autoSaveDraft();
                                          }),
                                ),
                                InputDecorator(
                                  decoration: _dec('Tasks / Work Details'),
                                  child: _activityId == null
                                      ? Text('Select activity first', style: TextStyle(color: Theme.of(context).hintColor))
                                      : _subtasks.isEmpty
                                          ? Text('No tasks under this activity', style: TextStyle(color: Theme.of(context).hintColor))
                                          : Wrap(
                                              spacing: 4,
                                              runSpacing: 0,
                                              children: [
                                                for (final s in _subtasks)
                                                  FilterChip(
                                                    label: Text(s.name, overflow: TextOverflow.ellipsis),
                                                    selected: _selectedSubtaskIds.contains(s.id),
                                                    onSelected: (on) => setState(() {
                                                      if (on) {
                                                        _selectedSubtaskIds.add(s.id);
                                                      } else {
                                                        _selectedSubtaskIds.remove(s.id);
                                                      }
                                                      _autoSaveDraft();
                                                    }),
                                                  ),
                                              ],
                                            ),
                                ),
                              ]),
                              const SizedBox(height: 12),
                              _grid([
                                DropdownButtonFormField<int>(
                                  key: ValueKey('floor_$_floorNo'),
                                  isExpanded: true,
                                  initialValue: _floorNo,
                                  decoration: _dec('Property Floor'),
                                  hint: const Text('Select Floor'),
                                  items: [
                                    const DropdownMenuItem(value: _allFloor, child: Text('ALL')),
                                    ..._floors.map((f) => DropdownMenuItem(value: f, child: Text('Floor $f'))),
                                  ],
                                  onChanged: _towerId == null
                                      ? null
                                      : (v) => setState(() {
                                            _floorNo = v;
                                            _unitId = null;
                                            _autoSaveDraft();
                                          }),
                                ),
                                DropdownButtonFormField<String>(
                                  key: ValueKey('unit_$_unitId'),
                                  isExpanded: true,
                                  initialValue: _unitId,
                                  decoration: _dec('Property Unit'),
                                  hint: const Text('Select Unit'),
                                  items: [
                                    const DropdownMenuItem(value: _allUnit, child: Text('ALL')),
                                    ..._units.map((u) => DropdownMenuItem(value: u.id, child: Text(u.unitNo))),
                                  ],
                                  onChanged: _towerId == null
                                      ? null
                                      : (v) => setState(() {
                                            _unitId = v;
                                            _autoSaveDraft();
                                          }),
                                ),
                                lookupDropdown(
                                  context: context,
                                  category: DprLookupKeys.measurementUnit,
                                  label: 'Unit',
                                  value: _unitCode,
                                  required: true,
                                  onChanged: (v) => setState(() {
                                    _unitCode = v;
                                    _autoSaveDraft();
                                  }),
                                ),
                                TextFormField(
                                  controller: _consumedCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                  decoration: _dec("Today's Consumed Work Qty", hint: 'Optional'),
                                ),
                              ]),
                              const SizedBox(height: 12),
                              _grid([
                                lookupDropdown(
                                  context: context,
                                  category: DprLookupKeys.grade,
                                  label: 'Grade',
                                  value: _gradeCode,
                                  onChanged: (v) => setState(() {
                                    _gradeCode = v;
                                    _autoSaveDraft();
                                  }),
                                ),
                                TextFormField(
                                  controller: _remarksCtrl,
                                  maxLines: 2,
                                  decoration: _dec('Remarks', hint: 'Enter Remark'),
                                ),
                                lookupDropdown(
                                  context: context,
                                  category: DprLookupKeys.status,
                                  label: 'Status',
                                  value: _statusCode,
                                  onChanged: (v) => setState(() {
                                    _statusCode = v;
                                    _autoSaveDraft();
                                  }),
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
                        : Text(_editingDprId != null ? 'Update DPR' : 'Submit'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _saveDraftExplicitly,
                    icon: const Icon(Icons.bookmark_outline, size: 16),
                    label: const Text('Save Draft'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFF0F766E)),
                    ),
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
              if (_resourceTab == 0)
                FilledButton.icon(
                  onPressed: _addMaterialDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Material'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1e3a5f)),
                ),
              if (_resourceTab == 1)
                Text(
                  'Enter qty for each labour type',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                ),
              if (_resourceTab == 2)
                FilledButton.icon(
                  onPressed: _addMachineDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Machine'),
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
                  onPressed: () {
                    setState(() => _draftMaterials = [..._draftMaterials]..removeAt(i));
                    _autoSaveDraft();
                  },
                )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _labourTable() {
    _syncLabourQtyControllers();
    if (_labour.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No labour types configured. Add them under BOQ / Labour masters.'),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < _labour.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(width: 36, child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(
                  flex: 3,
                  child: Text(_labour[i].name, overflow: TextOverflow.ellipsis),
                ),
                SizedBox(
                  width: 72,
                  child: Text(_labour[i].unitCode ?? '—', style: TextStyle(color: Theme.of(context).hintColor)),
                ),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _labourQtyCtrls[_labour[i].id],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _autoSaveDraft(),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _machineTable() {
    if (_draftMachines.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No machinery currently checked out by this contractor in Store.'),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('SR#')),
          DataColumn(label: Text('NAME')),
          DataColumn(label: Text('BRAND')),
          DataColumn(label: Text('UOM')),
          DataColumn(label: Text('TIME SLOTS')),
          DataColumn(label: Text('QTY')),
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
                DataCell(
                  Text(
                    _draftMachines[i].timeSlots.isEmpty
                        ? '—'
                        : _draftMachines[i].timeSlots.map((s) => '${s.from}–${s.to}').join(', '),
                  ),
                ),
                DataCell(Text(_draftMachines[i].consumedQty.toStringAsFixed(2))),
                DataCell(Text(_draftMachines[i].remarks ?? '—')),
                DataCell(IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() => _draftMachines = [..._draftMachines]..removeAt(i));
                    _autoSaveDraft();
                  },
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
                          onPressed: () {
                            setState(() => _lines.removeAt(i));
                            _autoSaveDraft();
                          },
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
