import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../data/boq_repository.dart';
import '../../data/project_repository.dart';
import '../../data/purchase_repository.dart';
import '../../data/work_order_repository.dart';
import '../../domain/contractor_lookup_keys.dart';
import '../../domain/project_models.dart';
import '../../domain/purchase_models.dart';
import '../../domain/resource_models.dart';
import '../../domain/store_models.dart';
import '../../domain/work_order_models.dart';
import '../../../earth/data/earth_repository.dart';
import '../../../earth/domain/earth_models.dart';

class PurchaseRequestListScreen extends StatefulWidget {
  const PurchaseRequestListScreen({super.key});

  @override
  State<PurchaseRequestListScreen> createState() => _PurchaseRequestListScreenState();
}

class _PurchaseRequestListScreenState extends State<PurchaseRequestListScreen> {
  List<ErpPurchaseRequest> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await context.read<PurchaseRepository>().listRequests();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Purchase Requests'),
        leading: const AppBackButton(fallbackLocation: '/erp/store'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/erp/store/purchase-requests/new');
          if (mounted) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('New PR'),
        backgroundColor: const Color(0xFFC5A059),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _items.isEmpty
                  ? const Center(child: Text('No purchase requests yet.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final pr = _items[i];
                        return Card(
                          child: ListTile(
                            title: Text(
                              '${pr.prNumber} · ${pr.status}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              [
                                DateFormat('dd/MM/yyyy').format(pr.prDate),
                                if (pr.projectName != null) pr.projectName!,
                                if (pr.vendorName != null) pr.vendorName!,
                                '${pr.lines.length} line(s)',
                              ].join(' · '),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await context.push('/erp/store/purchase-requests/${pr.id}');
                              if (mounted) _load();
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}

class PurchaseRequestFormScreen extends StatefulWidget {
  const PurchaseRequestFormScreen({super.key, this.id});

  final String? id;
  bool get isEdit => id != null && id!.isNotEmpty;

  @override
  State<PurchaseRequestFormScreen> createState() => _PurchaseRequestFormScreenState();
}

class _PrLineDraft {
  String? materialId;
  String? itemCode;
  String? categoryCode;
  String? brandCode;
  String? brand;
  String itemName = '';
  String? unitCode;
  String? sizeCode;
  String? size;
  final qtyCtrl = TextEditingController(text: '1');
  final remarkCtrl = TextEditingController();

  void dispose() {
    qtyCtrl.dispose();
    remarkCtrl.dispose();
  }

  Map<String, dynamic> toJson() => {
        'materialId': materialId,
        'itemCode': itemCode,
        'categoryCode': categoryCode,
        'brandCode': brandCode,
        'brand': brand,
        'itemName': itemName,
        'unitCode': unitCode,
        'sizeCode': sizeCode,
        'size': size,
        'qty': double.tryParse(qtyCtrl.text.trim()) ?? 0,
        'remark': remarkCtrl.text.trim().isEmpty ? null : remarkCtrl.text.trim(),
      };
}

class _PurchaseRequestFormScreenState extends State<PurchaseRequestFormScreen> {
  final _prNoCtrl = TextEditingController();
  DateTime _prDate = DateTime.now();
  DateTime? _requiredBy;
  String? _prTypeCode;
  String? _priorityCode;
  String? _projectId;
  String? _activityId;
  String? _vendorId;
  String? _storeId;
  String? _propertyId;
  String? _status;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<ErpProject> _projects = [];
  List<ErpActivity> _activities = [];
  List<ErpContractor> _vendors = [];
  List<ErpStoreMaster> _stores = [];
  List<EarthProperty> _properties = [];
  List<ErpMaterial> _inventory = [];
  final List<_PrLineDraft> _lines = [_PrLineDraft()];

  String get _requestedByLabel {
    final auth = context.read<AuthBloc>().state;
    return auth.user?.name ?? auth.user?.username ?? 'You';
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _prNoCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        context.read<ProjectRepository>().list(),
        context.read<WorkOrderRepository>().listActivities(),
        context.read<WorkOrderRepository>().listContractors(),
        context.read<BoqRepository>().listStores(),
        context.read<EarthRepository>().list(),
        context.read<BoqRepository>().listMaterials(),
      ]);
      _projects = results[0] as List<ErpProject>;
      _activities = results[1] as List<ErpActivity>;
      _vendors = results[2] as List<ErpContractor>;
      _stores = results[3] as List<ErpStoreMaster>;
      _properties = results[4] as List<EarthProperty>;
      _inventory = results[5] as List<ErpMaterial>;

      if (widget.isEdit) {
        final pr = await context.read<PurchaseRepository>().getRequest(widget.id!);
        _hydrate(pr);
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _hydrate(ErpPurchaseRequest pr) {
    _prNoCtrl.text = pr.prNumber;
    _prDate = pr.prDate;
    _requiredBy = pr.requiredByDate;
    _prTypeCode = pr.prTypeCode;
    _priorityCode = pr.priorityCode;
    _projectId = pr.projectId;
    _activityId = pr.activityId;
    _vendorId = pr.vendorId;
    _storeId = pr.storeId;
    _propertyId = pr.propertyId;
    _status = pr.status;
    for (final l in _lines) {
      l.dispose();
    }
    _lines.clear();
    if (pr.lines.isEmpty) {
      _lines.add(_PrLineDraft());
    } else {
      for (final line in pr.lines) {
        final d = _PrLineDraft()
          ..materialId = line.materialId
          ..itemCode = line.itemCode
          ..categoryCode = line.categoryCode
          ..brandCode = line.brandCode
          ..brand = line.brand
          ..itemName = line.itemName
          ..unitCode = line.unitCode
          ..sizeCode = line.sizeCode
          ..size = line.size;
        d.qtyCtrl.text = line.qty.toString();
        d.remarkCtrl.text = line.remark ?? '';
        _lines.add(d);
      }
    }
  }

  void _onPropertyChanged(String? propertyId) {
    setState(() {
      _propertyId = propertyId;
      if (propertyId == null) return;
      final linked = _stores.where((s) => s.propertyId == propertyId).toList();
      if (linked.length == 1) {
        _storeId = linked.first.id;
      } else if (linked.isNotEmpty && (_storeId == null || !linked.any((s) => s.id == _storeId))) {
        _storeId = linked.first.id;
      }
    });
  }

  void _applyMaterial(_PrLineDraft line, ErpMaterial? m) {
    setState(() {
      if (m == null) {
        line.materialId = null;
        return;
      }
      line.materialId = m.id;
      line.itemCode = m.itemCode;
      line.categoryCode = m.categoryCode;
      line.brandCode = m.brandCode ?? m.brand;
      line.brand = m.brand ?? m.brandCode;
      line.itemName = m.name;
      line.unitCode = m.unitCode;
      line.sizeCode = m.sizeCode ?? m.size;
      line.size = m.size ?? m.sizeCode;
    });
  }

  Future<void> _pickDate({required bool requiredBy}) async {
    final initial = requiredBy ? (_requiredBy ?? DateTime.now()) : _prDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() {
      if (requiredBy) {
        _requiredBy = picked;
      } else {
        _prDate = picked;
      }
    });
  }

  Future<void> _save({required bool submit}) async {
    final prNo = _prNoCtrl.text.trim();
    if (prNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PR No. is required')));
      return;
    }
    final lines = _lines.map((e) => e.toJson()).toList();
    for (final l in lines) {
      if ((l['itemName'] as String?)?.isEmpty ?? true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Each line needs an inventory item / name')),
        );
        return;
      }
      if ((l['qty'] as num) <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Each line needs quantity > 0')),
        );
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final body = {
        'prNumber': prNo,
        'prDate': DateFormat('yyyy-MM-dd').format(_prDate),
        'prTypeCode': _prTypeCode,
        'projectId': _projectId,
        'activityId': _activityId,
        'vendorId': _vendorId,
        'requiredByDate': _requiredBy != null ? DateFormat('yyyy-MM-dd').format(_requiredBy!) : null,
        'priorityCode': _priorityCode,
        'storeId': _storeId,
        'propertyId': _propertyId,
        'submit': submit && !widget.isEdit,
        'lines': lines,
      };
      final repo = context.read<PurchaseRepository>();
      if (widget.isEdit) {
        await repo.updateRequest(widget.id!, body);
        if (submit) await repo.submitRequest(widget.id!);
      } else {
        await repo.createRequest(body);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(submit ? 'Purchase request submitted for approval' : 'Purchase request saved')),
      );
      context.go('/erp/store/purchase-requests');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredStores = _propertyId == null
        ? _stores
        : _stores.where((s) => s.propertyId == null || s.propertyId == _propertyId).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Purchase Request' : 'New Purchase Request'),
        leading: const AppBackButton(fallbackLocation: '/erp/store/purchase-requests'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    if (_status != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('Status: $_status', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    TextField(
                      controller: _prNoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'PR No. *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => _pickDate(requiredBy: false),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'PR Date *', border: OutlineInputBorder()),
                        child: Text(DateFormat('dd/MM/yyyy').format(_prDate)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    lookupNullableDropdown(
                      category: kPrType,
                      label: 'PR Type',
                      value: _prTypeCode,
                      onChanged: (v) => setState(() => _prTypeCode = v),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _projectId,
                      decoration: const InputDecoration(labelText: 'Project', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Select project')),
                        ..._projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                      ],
                      onChanged: (v) => setState(() => _projectId = v),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _activityId,
                      decoration: const InputDecoration(labelText: 'Activity', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Select activity')),
                        ..._activities.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                      ],
                      onChanged: (v) => setState(() => _activityId = v),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _vendorId,
                      decoration: const InputDecoration(labelText: 'Name of Vendor', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Select vendor')),
                        ..._vendors.map((v) => DropdownMenuItem(value: v.id, child: Text(v.name))),
                      ],
                      onChanged: (v) => setState(() => _vendorId = v),
                    ),
                    const SizedBox(height: 10),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'Requested By', border: OutlineInputBorder()),
                      child: Text(_requestedByLabel),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => _pickDate(requiredBy: true),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Require by date', border: OutlineInputBorder()),
                        child: Text(
                          _requiredBy == null ? 'Select date' : DateFormat('dd/MM/yyyy').format(_requiredBy!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    lookupNullableDropdown(
                      category: kPrPriority,
                      label: 'Priority',
                      value: _priorityCode,
                      onChanged: (v) => setState(() => _priorityCode = v),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _propertyId,
                      decoration: const InputDecoration(labelText: 'Property', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Select property (optional)')),
                        ..._properties.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                      ],
                      onChanged: _onPropertyChanged,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _storeId,
                      decoration: const InputDecoration(labelText: 'Store', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Select store')),
                        ...filteredStores.map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text('${s.name} (${s.location})'),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _storeId = v),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Material Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => setState(() => _lines.add(_PrLineDraft())),
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _lines.length; i++) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Text('SR# ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const Spacer(),
                                  if (_lines.length > 1)
                                    IconButton(
                                      onPressed: () => setState(() {
                                        _lines[i].dispose();
                                        _lines.removeAt(i);
                                      }),
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    ),
                                ],
                              ),
                              DropdownButtonFormField<String>(
                                value: _lines[i].materialId,
                                decoration: const InputDecoration(
                                  labelText: 'Item Code / Material',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('Select from inventory')),
                                  ..._inventory.map(
                                    (m) => DropdownMenuItem(
                                      value: m.id,
                                      child: Text(
                                        [
                                          if (m.itemCode != null && m.itemCode!.isNotEmpty) m.itemCode!,
                                          m.name,
                                        ].join(' — '),
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (id) {
                                  ErpMaterial? m;
                                  for (final item in _inventory) {
                                    if (item.id == id) {
                                      m = item;
                                      break;
                                    }
                                  }
                                  _applyMaterial(_lines[i], m);
                                },
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  _chip('Category', _lines[i].categoryCode),
                                  _chip('Brand', _lines[i].brand ?? _lines[i].brandCode),
                                  _chip('Name', _lines[i].itemName),
                                  _chip('UoM', _lines[i].unitCode),
                                  _chip('Size', _lines[i].size ?? _lines[i].sizeCode),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _lines[i].qtyCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Quantity *',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _lines[i].remarkCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Remark',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : () => _save(submit: false),
                            child: const Text('Save Draft'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving ? null : () => _save(submit: true),
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Submit'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }

  Widget _chip(String label, String? value) {
    return Chip(
      label: Text('$label: ${value?.isNotEmpty == true ? value : '—'}', style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
    );
  }
}
