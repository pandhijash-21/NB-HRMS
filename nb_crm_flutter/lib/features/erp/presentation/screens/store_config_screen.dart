import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../domain/resource_models.dart';
import '../../domain/work_order_lookup_keys.dart';
import '../boq_providers.dart';
import '../work_order_providers.dart';

class StoreConfigScreen extends ConsumerStatefulWidget {
  const StoreConfigScreen({super.key, this.initialTab = 0});

  /// 0 for Material, 1 for Machine
  final int initialTab;

  @override
  ConsumerState<StoreConfigScreen> createState() => _StoreConfigScreenState();
}

class _StoreConfigScreenState extends ConsumerState<StoreConfigScreen>
    with TickerProviderStateMixin {
  late TabController _storeTabController;
  late TabController _materialTabController;
  late TabController _machineTabController;

  // ── Material Inward Form Controllers ──
  final _matBrandCtrl = TextEditingController();
  final _matNameCtrl = TextEditingController();
  final _matSizeCtrl = TextEditingController();
  final _matQtyCtrl = TextEditingController(text: '0');
  String? _matUnitCode;
  String? _matActivityId;
  String? _matSubtaskId;

  // ── Material Outward Form Controllers ──
  String? _outwardMaterialId;
  String? _outwardContractorId;
  final _outwardQtyCtrl = TextEditingController();
  final _outwardRemarksCtrl = TextEditingController();
  bool _isDispatching = false;

  // ── Machine Inward Form Controllers ──
  final _macBrandCtrl = TextEditingController();
  final _macNameCtrl = TextEditingController();
  final _macSizeCtrl = TextEditingController();
  final _macQtyCtrl = TextEditingController(text: '0');
  String? _macUnitCode;
  String? _macActivityId;
  String? _macSubtaskId;

  // ── Machine Issue (Outward) Form Controllers ──
  String? _issueMachineId;
  String? _issueContractorId;
  DateTime _issueDate = DateTime.now();
  final _issueQtyCtrl = TextEditingController();
  final _issueRemarksCtrl = TextEditingController();
  bool _isIssuingMachine = false;

  @override
  void initState() {
    super.initState();
    _storeTabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _materialTabController = TabController(length: 2, vsync: this);
    _machineTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _storeTabController.dispose();
    _materialTabController.dispose();
    _machineTabController.dispose();

    _matBrandCtrl.dispose();
    _matNameCtrl.dispose();
    _matSizeCtrl.dispose();
    _matQtyCtrl.dispose();

    _outwardQtyCtrl.dispose();
    _outwardRemarksCtrl.dispose();

    _macBrandCtrl.dispose();
    _macNameCtrl.dispose();
    _macSizeCtrl.dispose();
    _macQtyCtrl.dispose();

    _issueQtyCtrl.dispose();
    _issueRemarksCtrl.dispose();

    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Material Inward Methods
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _saveMaterial() async {
    final name = _matNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Material name is required')),
      );
      return;
    }
    try {
      await ref.read(boqRepositoryProvider).createMaterial({
        'brand': _matBrandCtrl.text.trim(),
        'name': name,
        'unitCode': _matUnitCode,
        'size': _matSizeCtrl.text.trim(),
        'activityId': _matActivityId,
        'subtaskId': _matSubtaskId,
        'qtyOnHand': double.tryParse(_matQtyCtrl.text) ?? 0,
      });
      ref.invalidate(erpMaterialsProvider);
      _matBrandCtrl.clear();
      _matNameCtrl.clear();
      _matSizeCtrl.clear();
      _matQtyCtrl.text = '0';
      setState(() {
        _matUnitCode = null;
        _matActivityId = null;
        _matSubtaskId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Material saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _addMaterialStock(String id) async {
    final qtyCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Stock (Purchase / Inward)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              decoration: const InputDecoration(
                labelText: 'Quantity to Add',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarksCtrl,
              decoration: const InputDecoration(
                labelText: 'Remarks / Supplier (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add Stock'),
          ),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Material Outward Methods
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _dispatchOutward(List<ErpMaterial> materials) async {
    if (_outwardMaterialId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a material')),
      );
      return;
    }
    if (_outwardContractorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a contractor (Used by)')),
      );
      return;
    }
    final qty = double.tryParse(_outwardQtyCtrl.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity greater than 0')),
      );
      return;
    }

    final selectedMat = materials.firstWhere(
      (m) => m.id == _outwardMaterialId,
      orElse: () => materials.first,
    );

    if (qty > selectedMat.qtyAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot issue more than available quantity (${selectedMat.qtyAvailable} ${selectedMat.unitCode ?? ''})',
          ),
        ),
      );
      return;
    }

    setState(() => _isDispatching = true);
    try {
      await ref.read(boqRepositoryProvider).dispatchMaterialOutward(
            _outwardMaterialId!,
            quantity: qty,
            contractorId: _outwardContractorId!,
            remarks: _outwardRemarksCtrl.text.trim(),
          );
      ref.invalidate(erpMaterialsProvider);
      _outwardQtyCtrl.clear();
      _outwardRemarksCtrl.clear();
      setState(() {
        _outwardMaterialId = null;
        _outwardContractorId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully dispatched $qty ${selectedMat.unitCode ?? ''} of ${selectedMat.name}',
            ),
            backgroundColor: const Color(0xFF0d9488),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _isDispatching = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Machine Inward / Config Methods
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _saveMachine() async {
    final name = _macNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Machine name is required')),
      );
      return;
    }
    try {
      await ref.read(boqRepositoryProvider).createMachine({
        'brand': _macBrandCtrl.text.trim(),
        'name': name,
        'unitCode': _macUnitCode,
        'size': _macSizeCtrl.text.trim(),
        'activityId': _macActivityId,
        'subtaskId': _macSubtaskId,
        'qtyOnHand': double.tryParse(_macQtyCtrl.text) ?? 0,
      });
      ref.invalidate(erpMachinesProvider);
      _macBrandCtrl.clear();
      _macNameCtrl.clear();
      _macSizeCtrl.clear();
      _macQtyCtrl.text = '0';
      setState(() {
        _macUnitCode = null;
        _macActivityId = null;
        _macSubtaskId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Machine saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _addMachineStock(String id) async {
    final qtyCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Machine Stock (Purchase)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarksCtrl,
              decoration: const InputDecoration(
                labelText: 'Remarks',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add Stock'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(boqRepositoryProvider).addMachineStock(id, {
        'quantity': double.tryParse(qtyCtrl.text) ?? 0,
        'logType': 'PURCHASE',
        'remarks': remarksCtrl.text.trim(),
      });
      ref.invalidate(erpMachinesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Machine stock updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Consumption & Stock Logs Bottom Sheet Modal
  // ──────────────────────────────────────────────────────────────────────────
  void _showMaterialLogsModal(BuildContext context, ErpMaterial material) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MaterialLogsSheet(material: material),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Machine Outward / Issue & Return Methods
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _issueMachineAction(List<ErpMachine> machines) async {
    if (_issueMachineId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a machine to issue')),
      );
      return;
    }
    if (_issueContractorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a contractor (Used by)')),
      );
      return;
    }
    final qty = double.tryParse(_issueQtyCtrl.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity greater than 0')),
      );
      return;
    }
    final selectedMac = machines.where((m) => m.id == _issueMachineId).firstOrNull;
    final avail = selectedMac?.qtyAvailable ?? 0;
    if (qty > avail) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot issue more than available machines ($avail ${selectedMac?.unitCode ?? ''})',
          ),
        ),
      );
      return;
    }
    setState(() => _isIssuingMachine = true);
    try {
      await ref.read(boqRepositoryProvider).issueMachine(
            _issueMachineId!,
            quantity: qty,
            contractorId: _issueContractorId!,
            issueDate: _issueDate,
            remarks: _issueRemarksCtrl.text.trim(),
          );
      ref.invalidate(erpMachinesProvider);
      ref.invalidate(activeMachineIssuesProvider);
      _issueQtyCtrl.clear();
      _issueRemarksCtrl.clear();
      setState(() {
        _issueMachineId = null;
        _issueContractorId = null;
        _issueDate = DateTime.now();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully issued $qty ${selectedMac?.unitCode ?? 'units'} of ${selectedMac?.name}',
            ),
            backgroundColor: const Color(0xFF0D9488),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _isIssuingMachine = false);
    }
  }

  Future<void> _showReturnDialog(ErpMachineIssue issue) async {
    final qtyCtrl = TextEditingController(
      text: issue.quantityInUse % 1 == 0
          ? issue.quantityInUse.toInt().toString()
          : issue.quantityInUse.toString(),
    );
    final remarksCtrl = TextEditingController();
    DateTime returnDate = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final entered = double.tryParse(qtyCtrl.text.trim()) ?? 0;
          final maxReturn = issue.quantityInUse;
          final isExceeding = entered > maxReturn;
          final isInvalid = entered <= 0 || isExceeding;

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.assignment_return_rounded, color: Color(0xFF7C3AED), size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Return Equipment: ${issue.machineName ?? 'Machine'}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Contractor: ${issue.contractorName ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Taken: ${issue.quantityTaken} ${issue.unitCode ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            Text('Returned: ${issue.quantityReturned} ${issue.unitCode ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.teal)),
                            Text('In Use: ${issue.quantityInUse} ${issue.unitCode ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setLocal(() {}),
                    decoration: InputDecoration(
                      labelText: 'Return Quantity *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.keyboard_return_rounded),
                      suffixIcon: TextButton(
                        onPressed: () {
                          qtyCtrl.text = maxReturn % 1 == 0 ? maxReturn.toInt().toString() : maxReturn.toString();
                          setLocal(() {});
                        },
                        child: const Text('Return All', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                      ),
                      errorText: isExceeding ? 'Cannot return more than quantity in use ($maxReturn)' : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: returnDate,
                        firstDate: issue.issueDate,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setLocal(() => returnDate = picked);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Return Date *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(_formatDateOnly(returnDate)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: remarksCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Remarks / Condition (optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: isInvalid ? null : () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Confirm Return'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    final returnQty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
    try {
      await ref.read(boqRepositoryProvider).returnMachine(
            issue.id,
            quantity: returnQty,
            returnDate: returnDate,
            remarks: remarksCtrl.text.trim(),
          );
      ref.invalidate(activeMachineIssuesProvider);
      ref.invalidate(erpMachinesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully recorded return of $returnQty ${issue.unitCode ?? 'units'}'),
            backgroundColor: const Color(0xFF0D9488),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _showMachineLogsModal(BuildContext context, ErpMachine machine) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MachineLogsSheet(machine: machine),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Store',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: const AppBackButton(fallbackLocation: '/erp/home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Store',
            onPressed: () {
              ref.invalidate(erpMaterialsProvider);
              ref.invalidate(erpMachinesProvider);
              ref.invalidate(erpContractorsProvider);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: isDark ? const Color(0xFF1A1816) : Colors.white,
            child: TabBar(
              controller: _storeTabController,
              indicatorColor: const Color(0xFF0D9488),
              indicatorWeight: 3,
              labelColor: const Color(0xFF0D9488),
              unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF64748B),
              tabs: const [
                Tab(
                  icon: Icon(Icons.inventory_2_outlined),
                  text: 'Material',
                ),
                Tab(
                  icon: Icon(Icons.precision_manufacturing_outlined),
                  text: 'Machine',
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _storeTabController,
        children: [
          _buildMaterialSection(isDark),
          _buildMachineSection(isDark),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MATERIAL SECTION: INWARD & OUTWARD TABS
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildMaterialSection(bool isDark) {
    return Column(
      children: [
        Container(
          color: isDark ? const Color(0xFF1F1D1B) : const Color(0xFFEEF2F6),
          child: TabBar(
            controller: _materialTabController,
            indicatorColor: const Color(0xFFC5A059),
            indicatorWeight: 2,
            labelColor: const Color(0xFFC5A059),
            unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF475569),
            tabs: const [
              Tab(
                icon: Icon(Icons.arrow_downward_rounded, size: 20),
                text: 'Inward',
              ),
              Tab(
                icon: Icon(Icons.arrow_upward_rounded, size: 20),
                text: 'Outward',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _materialTabController,
            children: [
              _buildMaterialInwardTab(isDark),
              _buildMaterialOutwardTab(isDark),
            ],
          ),
        ),
      ],
    );
  }

  // ── Material Inward Tab ──
  Widget _buildMaterialInwardTab(bool isDark) {
    final materialsAsync = ref.watch(erpMaterialsProvider);
    final activitiesAsync = ref.watch(erpActivitiesAdminProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add_box_outlined,
                        color: Color(0xFF0D9488),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Add Material (Inward)',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _matBrandCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Brand',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _matNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Material Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                lookupDropdown(
                  ref: ref,
                  category: kWoMeasurementUnit,
                  value: _matUnitCode,
                  label: 'Unit',
                  onChanged: (v) => setState(() => _matUnitCode = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _matSizeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Size / Spec',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _matQtyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Initial Qty on hand',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 10),
                activitiesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (acts) => DropdownButtonFormField<String>(
                    value: _matActivityId,
                    decoration: const InputDecoration(
                      labelText: 'Activity (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: acts
                        .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _matActivityId = v;
                      _matSubtaskId = null;
                    }),
                  ),
                ),
                if (_matActivityId != null)
                  activitiesAsync.maybeWhen(
                    data: (acts) {
                      final act = acts.where((a) => a.id == _matActivityId).firstOrNull;
                      if (act == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: DropdownButtonFormField<String>(
                          value: _matSubtaskId,
                          decoration: const InputDecoration(
                            labelText: 'Sub-activity (optional)',
                            border: OutlineInputBorder(),
                          ),
                          items: act.subtasks
                              .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                              .toList(),
                          onChanged: (v) => setState(() => _matSubtaskId = v),
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saveMaterial,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Save Material'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Stock Summary (Inward Inventory)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            Text(
              'Tap card for logs',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        materialsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(child: Text('Error loading materials: $e')),
          data: (items) {
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No materials found. Add one above.')),
              );
            }
            return Column(
              children: [
                for (final m in items)
                  Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _showMaterialLogsModal(context, m),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9488).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.inventory_2_rounded,
                                color: Color(0xFF0D9488),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${m.brand != null && m.brand!.isNotEmpty ? '${m.brand} ' : ''}${m.name}',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      Text(
                                        'Available: ${m.qtyAvailable} ${m.unitCode ?? ''}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0D9488),
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        'Total: ${m.qtyTotal}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                        ),
                                      ),
                                      Text(
                                        'Used: ${m.qtyUsed}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_shopping_cart_outlined),
                              tooltip: 'Add purchase stock',
                              color: const Color(0xFF0D9488),
                              onPressed: () => _addMaterialStock(m.id),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ── Material Outward Tab ──
  Widget _buildMaterialOutwardTab(bool isDark) {
    final materialsAsync = ref.watch(erpMaterialsProvider);
    final contractorsAsync = ref.watch(erpContractorsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Outward Issue Card
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.output_rounded,
                        color: Color(0xFFEA580C),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Issue Material (Outward)',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Record material issued from store to contractor. Total available quantity will automatically decrease.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),

                // 1. Material Dropdown
                materialsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Failed to load materials: $e'),
                  data: (materials) {
                    final activeMaterials = materials.where((m) => m.isActive).toList();
                    ErpMaterial? selectedMat;
                    if (_outwardMaterialId != null) {
                      selectedMat = activeMaterials
                          .where((m) => m.id == _outwardMaterialId)
                          .firstOrNull;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _outwardMaterialId,
                          decoration: const InputDecoration(
                            labelText: 'Which Material *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.inventory_2_outlined),
                          ),
                          items: activeMaterials.map((m) {
                            final label =
                                '${m.brand != null && m.brand!.isNotEmpty ? '${m.brand} - ' : ''}${m.name} (Avail: ${m.qtyAvailable} ${m.unitCode ?? ''})';
                            return DropdownMenuItem(
                              value: m.id,
                              child: Text(label, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _outwardMaterialId = v),
                        ),
                        if (selectedMat != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: selectedMat.qtyAvailable > 0
                                  ? const Color(0xFF0D9488).withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  selectedMat.qtyAvailable > 0
                                      ? Icons.check_circle_outline
                                      : Icons.warning_amber_rounded,
                                  size: 16,
                                  color: selectedMat.qtyAvailable > 0
                                      ? const Color(0xFF0D9488)
                                      : Colors.red,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Available in Store: ${selectedMat.qtyAvailable} ${selectedMat.unitCode ?? ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: selectedMat.qtyAvailable > 0
                                        ? const Color(0xFF0D9488)
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 2. Quantity
                materialsAsync.maybeWhen(
                  data: (materials) {
                    final selectedMat = materials.where((m) => m.id == _outwardMaterialId).firstOrNull;
                    final enteredQty = double.tryParse(_outwardQtyCtrl.text.trim()) ?? 0;
                    final avail = selectedMat?.qtyAvailable ?? 0;
                    final isExceeding = enteredQty > avail;
                    return TextField(
                      controller: _outwardQtyCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Quantity *',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.straighten_outlined),
                        suffixIcon: selectedMat != null && avail > 0
                            ? TextButton(
                                onPressed: () {
                                  _outwardQtyCtrl.text = avail % 1 == 0
                                      ? avail.toInt().toString()
                                      : avail.toString();
                                  setState(() {});
                                },
                                child: const Text(
                                  'Max',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFEA580C),
                                  ),
                                ),
                              )
                            : null,
                        errorText: isExceeding
                            ? 'Quantity cannot exceed available stock (${avail.toInt()} ${selectedMat?.unitCode ?? ''})'
                            : null,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    );
                  },
                  orElse: () => TextField(
                    controller: _outwardQtyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Quantity *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.straighten_outlined),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Used by (Contractors Dropdown)
                contractorsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Failed to load contractors: $e'),
                  data: (contractors) {
                    final activeContractors = contractors.where((c) => c.isActive).toList();
                    return DropdownButtonFormField<String>(
                      value: _outwardContractorId,
                      decoration: const InputDecoration(
                        labelText: 'Used by (Contractor) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.handshake_outlined),
                      ),
                      items: activeContractors.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _outwardContractorId = v),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 4. Remarks
                TextField(
                  controller: _outwardRemarksCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Remarks / Work Order / Purpose (optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 16),

                // Submit button
                materialsAsync.maybeWhen(
                  data: (materials) {
                    final selectedMat = materials.where((m) => m.id == _outwardMaterialId).firstOrNull;
                    final enteredQty = double.tryParse(_outwardQtyCtrl.text.trim()) ?? 0;
                    final avail = selectedMat?.qtyAvailable ?? 0;
                    final isInvalid = _outwardMaterialId == null ||
                        _outwardContractorId == null ||
                        enteredQty <= 0 ||
                        enteredQty > avail;
                    return FilledButton.icon(
                      onPressed: _isDispatching || isInvalid ? null : () => _dispatchOutward(materials),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      icon: _isDispatching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_isDispatching ? 'Dispatching…' : 'Dispatch Outward'),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Materials & Consumption Logs Overview
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Materials Stock & Logs',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            Text(
              'Click material to see consumption logs',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        materialsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (materials) {
            if (materials.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No materials found.')),
              );
            }
            return Column(
              children: [
                for (final m in materials)
                  Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _showMaterialLogsModal(context, m),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.history_rounded,
                                color: Color(0xFFEA580C),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${m.brand != null && m.brand!.isNotEmpty ? '${m.brand} ' : ''}${m.name}',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0D9488).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Available: ${m.qtyAvailable} ${m.unitCode ?? ''}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0D9488),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Used: ${m.qtyUsed}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showMaterialLogsModal(context, m),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: const Color(0xFFEA580C),
                                side: const BorderSide(color: Color(0xFFEA580C)),
                              ),
                              icon: const Icon(Icons.receipt_long_outlined, size: 16),
                              label: const Text('Logs'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MACHINE SECTION: INWARD & OUTWARD (ISSUE / RETURNS) TABS
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildMachineSection(bool isDark) {
    return Column(
      children: [
        Container(
          color: isDark ? const Color(0xFF1F1D1B) : const Color(0xFFEEF2F6),
          child: TabBar(
            controller: _machineTabController,
            indicatorColor: const Color(0xFF7C3AED),
            indicatorWeight: 2,
            labelColor: const Color(0xFF7C3AED),
            unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF475569),
            tabs: const [
              Tab(
                icon: Icon(Icons.arrow_downward_rounded, size: 20),
                text: 'Inward & Stock',
              ),
              Tab(
                icon: Icon(Icons.arrow_upward_rounded, size: 20),
                text: 'Issue & Returns',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _machineTabController,
            children: [
              _buildMachineInwardTab(isDark),
              _buildMachineIssueTab(isDark),
            ],
          ),
        ),
      ],
    );
  }

  // ── Machine Inward & Stock Tab ──
  Widget _buildMachineInwardTab(bool isDark) {
    final machinesAsync = ref.watch(erpMachinesProvider);
    final activitiesAsync = ref.watch(erpActivitiesAdminProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.precision_manufacturing_outlined,
                        color: Color(0xFF7C3AED),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Add Machine (Equipment)',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _macBrandCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Brand',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _macNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Machine Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                lookupDropdown(
                  ref: ref,
                  category: kWoMeasurementUnit,
                  value: _macUnitCode,
                  label: 'Unit',
                  onChanged: (v) => setState(() => _macUnitCode = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _macSizeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Capacity / Size',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _macQtyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Qty on hand',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 10),
                activitiesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (acts) => DropdownButtonFormField<String>(
                    value: _macActivityId,
                    decoration: const InputDecoration(
                      labelText: 'Activity (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: acts
                        .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _macActivityId = v;
                      _macSubtaskId = null;
                    }),
                  ),
                ),
                if (_macActivityId != null)
                  activitiesAsync.maybeWhen(
                    data: (acts) {
                      final act = acts.where((a) => a.id == _macActivityId).firstOrNull;
                      if (act == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: DropdownButtonFormField<String>(
                          value: _macSubtaskId,
                          decoration: const InputDecoration(
                            labelText: 'Sub-activity (optional)',
                            border: OutlineInputBorder(),
                          ),
                          items: act.subtasks
                              .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                              .toList(),
                          onChanged: (v) => setState(() => _macSubtaskId = v),
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saveMachine,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Save Machine'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Machine Stock Summary',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            Text(
              'Click machine to view logs',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        machinesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (items) {
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No machines found. Add one above.')),
              );
            }
            return Column(
              children: [
                for (final m in items)
                  Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _showMachineLogsModal(context, m),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.precision_manufacturing_rounded,
                                color: Color(0xFF7C3AED),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${m.brand != null && m.brand!.isNotEmpty ? '${m.brand} ' : ''}${m.name}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                                  if (m.size != null && m.size!.isNotEmpty)
                                    Text(
                                      'Capacity: ${m.size}',
                                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                                    ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Total: ${m.qtyTotal} ${m.unitCode ?? ''}',
                                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF7C3AED).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'In Use: ${m.qtyInUse} ${m.unitCode ?? ''}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0D9488).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Avail: ${m.qtyAvailable} ${m.unitCode ?? ''}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0D9488)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.add_shopping_cart_outlined),
                                  tooltip: 'Add purchase stock',
                                  color: const Color(0xFF7C3AED),
                                  onPressed: () => _addMachineStock(m.id),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _showMachineLogsModal(context, m),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: const Color(0xFF7C3AED),
                                    side: const BorderSide(color: Color(0xFF7C3AED)),
                                  ),
                                  icon: const Icon(Icons.receipt_long_outlined, size: 16),
                                  label: const Text('Logs'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ── Machine Issue & Returns (Outward) Tab ──
  Widget _buildMachineIssueTab(bool isDark) {
    final machinesAsync = ref.watch(erpMachinesProvider);
    final contractorsAsync = ref.watch(erpContractorsProvider);
    final activeIssuesAsync = ref.watch(activeMachineIssuesProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Issue / Checkout Card
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.output_rounded,
                        color: Color(0xFF7C3AED),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Issue Equipment (Outward)',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Record equipment checked out by a contractor. Available machines will decrease while in use. Partial or full returns will restore available machines.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),

                // 1. Machine Dropdown
                machinesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Failed to load machines: $e'),
                  data: (machines) {
                    final activeMachines = machines.where((m) => m.isActive).toList();
                    ErpMachine? selectedMac;
                    if (_issueMachineId != null) {
                      selectedMac = activeMachines
                          .where((m) => m.id == _issueMachineId)
                          .firstOrNull;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _issueMachineId,
                          decoration: const InputDecoration(
                            labelText: 'Which Machine / Equipment *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.precision_manufacturing_outlined),
                          ),
                          items: activeMachines.map((m) {
                            final label =
                                '${m.brand != null && m.brand!.isNotEmpty ? '${m.brand} - ' : ''}${m.name} (Avail: ${m.qtyAvailable} ${m.unitCode ?? ''})';
                            return DropdownMenuItem(
                              value: m.id,
                              child: Text(label, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _issueMachineId = v),
                        ),
                        if (selectedMac != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: selectedMac.qtyAvailable > 0
                                  ? const Color(0xFF7C3AED).withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  selectedMac.qtyAvailable > 0
                                      ? Icons.check_circle_outline
                                      : Icons.warning_amber_rounded,
                                  size: 16,
                                  color: selectedMac.qtyAvailable > 0
                                      ? const Color(0xFF7C3AED)
                                      : Colors.red,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Available in Store: ${selectedMac.qtyAvailable} ${selectedMac.unitCode ?? ''} (Total: ${selectedMac.qtyTotal}, In Use: ${selectedMac.qtyInUse})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: selectedMac.qtyAvailable > 0
                                        ? const Color(0xFF7C3AED)
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 2. Quantity with strict validation & Max button
                machinesAsync.maybeWhen(
                  data: (machines) {
                    final selectedMac = machines.where((m) => m.id == _issueMachineId).firstOrNull;
                    final enteredQty = double.tryParse(_issueQtyCtrl.text.trim()) ?? 0;
                    final avail = selectedMac?.qtyAvailable ?? 0;
                    final isExceeding = enteredQty > avail;

                    return TextField(
                      controller: _issueQtyCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Quantity to Take *',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.numbers_outlined),
                        suffixIcon: selectedMac != null && avail > 0
                            ? TextButton(
                                onPressed: () {
                                  _issueQtyCtrl.text = avail % 1 == 0
                                      ? avail.toInt().toString()
                                      : avail.toString();
                                  setState(() {});
                                },
                                child: const Text(
                                  'Max',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                              )
                            : null,
                        errorText: isExceeding
                            ? 'Quantity cannot exceed available stock ($avail ${selectedMac?.unitCode ?? ''})'
                            : null,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    );
                  },
                  orElse: () => TextField(
                    controller: _issueQtyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Quantity to Take *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers_outlined),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Used by (Contractors Dropdown)
                contractorsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Failed to load contractors: $e'),
                  data: (contractors) {
                    final activeContractors = contractors.where((c) => c.isActive).toList();
                    return DropdownButtonFormField<String>(
                      value: _issueContractorId,
                      decoration: const InputDecoration(
                        labelText: 'Used by (Contractor) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.handshake_outlined),
                      ),
                      items: activeContractors.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _issueContractorId = v),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 4. Taken Date
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _issueDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _issueDate = picked);
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Taken Date *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(_formatDateOnly(_issueDate)),
                  ),
                ),
                const SizedBox(height: 12),

                // 5. Remarks
                TextField(
                  controller: _issueRemarksCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Remarks / Purpose / Site location (optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 16),

                // Submit button
                machinesAsync.maybeWhen(
                  data: (machines) {
                    final selectedMac = machines.where((m) => m.id == _issueMachineId).firstOrNull;
                    final enteredQty = double.tryParse(_issueQtyCtrl.text.trim()) ?? 0;
                    final avail = selectedMac?.qtyAvailable ?? 0;
                    final isInvalid = _issueMachineId == null ||
                        _issueContractorId == null ||
                        enteredQty <= 0 ||
                        enteredQty > avail;

                    return FilledButton.icon(
                      onPressed: _isIssuingMachine || isInvalid
                          ? null
                          : () => _issueMachineAction(machines),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      icon: _isIssuingMachine
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_isIssuingMachine ? 'Issuing…' : 'Issue Equipment'),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Active In-Use Equipment Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Equipment Currently In-Use',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Text(
              'Tap Return when contractor returns items',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        activeIssuesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(child: Text('Error loading active issues: $e')),
          data: (issues) {
            if (issues.isEmpty) {
              return Card(
                elevation: 0,
                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No equipment is currently issued to contractors. All machines are available in store.'),
                  ),
                ),
              );
            }

            return Column(
              children: [
                for (final issue in issues)
                  Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.precision_manufacturing_rounded,
                                  color: Color(0xFF7C3AED),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${issue.machineBrand != null && issue.machineBrand!.isNotEmpty ? '${issue.machineBrand} ' : ''}${issue.machineName ?? 'Machine'}',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.handshake_outlined,
                                          size: 14,
                                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Used by: ${issue.contractorName ?? 'Contractor'}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () => _showReturnDialog(issue),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF7C3AED).withOpacity(0.15),
                                  foregroundColor: const Color(0xFF7C3AED),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.assignment_return_rounded, size: 16),
                                label: const Text('Return'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  'Taken: ${issue.quantityTaken} ${issue.unitCode ?? ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  'Currently in Use: ${issue.quantityInUse} ${issue.unitCode ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                              ),
                              if (issue.quantityReturned > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    'Returned: ${issue.quantityReturned} ${issue.unitCode ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  'Taken Date: ${_formatDateOnly(issue.issueDate)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (issue.remarks != null && issue.remarks!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Remarks: ${issue.remarks}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                          if (issue.returnLogs.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF262626) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Return History:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  for (final r in issue.returnLogs)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: Colors.teal),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Returned ${r.quantityReturned} ${issue.unitCode ?? ''} on ${_formatDateOnly(r.returnDate)}${r.remarks != null && r.remarks!.isNotEmpty ? ' (${r.remarks})' : ''}',
                                              style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// CONSUMPTION & STOCK LOGS MODAL SHEET
// ────────────────────────────────────────────────────────────────────────────
class _MaterialLogsSheet extends ConsumerStatefulWidget {
  const _MaterialLogsSheet({required this.material});

  final ErpMaterial material;

  @override
  ConsumerState<_MaterialLogsSheet> createState() => _MaterialLogsSheetState();
}

class _MaterialLogsSheetState extends ConsumerState<_MaterialLogsSheet> {
  bool _showConsumptionOnly = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logsAsync = ref.watch(materialStockLogsProvider(widget.material.id));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.material.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (widget.material.brand != null && widget.material.brand!.isNotEmpty)
                      Text(
                        'Brand: ${widget.material.brand}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Avail: ${widget.material.qtyAvailable} ${widget.material.unitCode ?? ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D9488),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filter bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Stock & Consumption Logs',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              FilterChip(
                label: const Text('Contractors Only', style: TextStyle(fontSize: 12)),
                selected: _showConsumptionOnly,
                onSelected: (v) => setState(() => _showConsumptionOnly = v),
                selectedColor: const Color(0xFFEA580C).withOpacity(0.2),
                checkmarkColor: const Color(0xFFEA580C),
              ),
            ],
          ),
          const Divider(),

          // Logs List
          Expanded(
            child: logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load logs: $e')),
              data: (logs) {
                final filtered = _showConsumptionOnly
                    ? logs.where((l) => l.logType == 'CONSUMPTION').toList()
                    : logs;

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _showConsumptionOnly
                            ? 'No consumption logs recorded by contractors yet.'
                            : 'No logs recorded for this material.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final log = filtered[i];
                    final isConsumption = log.logType == 'CONSUMPTION';
                    final isPurchase = log.logType == 'PURCHASE';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: isConsumption
                            ? const Color(0xFFEA580C).withOpacity(0.12)
                            : isPurchase
                                ? const Color(0xFF0D9488).withOpacity(0.12)
                                : Colors.blue.withOpacity(0.12),
                        child: Icon(
                          isConsumption
                              ? Icons.output_rounded
                              : isPurchase
                                  ? Icons.add_shopping_cart_rounded
                                  : Icons.info_outline,
                          size: 18,
                          color: isConsumption
                              ? const Color(0xFFEA580C)
                              : isPurchase
                                  ? const Color(0xFF0D9488)
                                  : Colors.blue,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            isConsumption ? 'Consumed by: ' : 'Log: ',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              isConsumption
                                  ? (log.contractorName ?? 'Contractor')
                                  : log.logType,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isConsumption ? const Color(0xFFEA580C) : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (log.remarks != null && log.remarks!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Remarks: ${log.remarks}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : const Color(0xFF334155),
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(log.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        '${isConsumption ? '-' : '+'}${log.quantity} ${widget.material.unitCode ?? ''}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isConsumption ? const Color(0xFFEA580C) : const Color(0xFF0D9488),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  final y = local.year;
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$d-$m-$y $h:$min';
}

String _formatDateOnly(DateTime dt) {
  final local = dt.toLocal();
  final y = local.year;
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$d-$m-$y';
}

// ────────────────────────────────────────────────────────────────────────────
// MACHINE LOGS MODAL SHEET (Issues, Returns & Stock Logs)
// ────────────────────────────────────────────────────────────────────────────
class _MachineLogsSheet extends ConsumerStatefulWidget {
  const _MachineLogsSheet({required this.machine});

  final ErpMachine machine;

  @override
  ConsumerState<_MachineLogsSheet> createState() => _MachineLogsSheetState();
}

class _MachineLogsSheetState extends ConsumerState<_MachineLogsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _logTabController;

  @override
  void initState() {
    super.initState();
    _logTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _logTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logsAsync = ref.watch(machineLogsProvider(widget.machine.id));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.machine.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (widget.machine.brand != null && widget.machine.brand!.isNotEmpty)
                      Text(
                        'Brand: ${widget.machine.brand}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'In Use: ${widget.machine.qtyInUse} ${widget.machine.unitCode ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Avail: ${widget.machine.qtyAvailable} ${widget.machine.unitCode ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          TabBar(
            controller: _logTabController,
            indicatorColor: const Color(0xFF7C3AED),
            indicatorWeight: 2,
            labelColor: const Color(0xFF7C3AED),
            unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF475569),
            tabs: const [
              Tab(text: 'Issues & Returns'),
              Tab(text: 'Stock Purchases'),
            ],
          ),
          const SizedBox(height: 10),

          Expanded(
            child: logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading logs: $e')),
              data: (data) {
                final issues = (data['issues'] as List<ErpMachineIssue>?) ?? [];
                final stockLogs = (data['stockLogs'] as List<ErpMachineStockLog>?) ?? [];

                return TabBarView(
                  controller: _logTabController,
                  children: [
                    // Tab 1: Issues & Returns
                    issues.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No issue or return history for this machine'),
                            ),
                          )
                        : ListView.separated(
                            itemCount: issues.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final issue = issues[i];
                              final isReturned = issue.status == 'RETURNED';
                              final isPartial = issue.status == 'PARTIALLY_RETURNED';

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.handshake_outlined,
                                              size: 16,
                                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              issue.contractorName ?? 'Contractor',
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isReturned
                                                ? Colors.green.withOpacity(0.12)
                                                : isPartial
                                                    ? Colors.orange.withOpacity(0.12)
                                                    : const Color(0xFF7C3AED).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isReturned
                                                ? 'Fully Returned'
                                                : isPartial
                                                    ? 'Partially Returned'
                                                    : 'Active In Use',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isReturned
                                                  ? Colors.green
                                                  : isPartial
                                                      ? Colors.orange
                                                      : const Color(0xFF7C3AED),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'Taken: ${issue.quantityTaken} ${widget.machine.unitCode ?? ''} on ${_formatDateOnly(issue.issueDate)}',
                                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF475569)),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'In use: ${issue.quantityInUse} ${widget.machine.unitCode ?? ''}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                        ),
                                      ],
                                    ),
                                    if (issue.remarks != null && issue.remarks!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Note: ${issue.remarks}',
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                                      ),
                                    ],
                                    // Return history logs breakdown
                                    if (issue.returnLogs.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF262626) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Return Logs:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                                            const SizedBox(height: 2),
                                            for (final r in issue.returnLogs)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: Colors.teal),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        'Returned ${r.quantityReturned} ${widget.machine.unitCode ?? ''} on ${_formatDateOnly(r.returnDate)}${r.remarks != null && r.remarks!.isNotEmpty ? ' (${r.remarks})' : ''}',
                                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),

                    // Tab 2: Stock Purchases / Logs
                    stockLogs.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No stock purchase logs found'),
                            ),
                          )
                        : ListView.separated(
                            itemCount: stockLogs.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final log = stockLogs[i];
                              final isPurchase = log.logType == 'PURCHASE' || log.logType == 'INITIAL';
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  isPurchase ? Icons.add_circle_outline : Icons.adjust_rounded,
                                  color: isPurchase ? const Color(0xFF0D9488) : Colors.blue,
                                ),
                                title: Text(
                                  log.logType,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (log.remarks != null && log.remarks!.isNotEmpty)
                                      Text(log.remarks!, style: const TextStyle(fontSize: 11)),
                                    Text(_formatDate(log.createdAt), style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
                                  ],
                                ),
                                trailing: Text(
                                  '+${log.quantity} ${widget.machine.unitCode ?? ''}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0D9488), fontSize: 13),
                                ),
                              );
                            },
                          ),
                  ],
                );
              },
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
