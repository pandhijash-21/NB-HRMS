import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/platform_file_picker.dart';
import '../../data/boq_repository.dart';
import '../../domain/resource_models.dart';
import '../../domain/store_models.dart';
import '../widgets/quick_create_masters.dart';

/// Sentinel for inward without a PO — stock is taken now; PO can be linked later.
const String kNaPurchaseOrder = '__NA__';

/// PO-based goods inward form embedded in Material / Machine Inward tabs.
class StorePoInwardPanel extends StatefulWidget {
  const StorePoInwardPanel({
    super.key,
    required this.isDark,
    this.resourceKind = StoreInwardKind.material,
    this.compact = false,
  });

  final bool isDark;
  final StoreInwardKind resourceKind;
  /// When true, omit the outer ListView (parent already scrolls).
  final bool compact;

  @override
  State<StorePoInwardPanel> createState() => _StorePoInwardPanelState();
}

enum StoreInwardKind { material, machine }

class _InwardLineDraft {
  String? poItemId;
  String? resourceId; // materialId or machineId when NA
  final qtyCtrl = TextEditingController();
  final rejectCtrl = TextEditingController(text: '0');

  void dispose() {
    qtyCtrl.dispose();
    rejectCtrl.dispose();
  }
}

class _StorePoInwardPanelState extends State<StorePoInwardPanel> {
  List<ErpPurchaseOrder> _pos = [];
  List<ErpStoreMaster> _stores = [];
  List<ErpStoreInward> _recent = [];
  List<ErpMaterial> _materials = [];
  List<ErpMachine> _machines = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  String? _poId;
  ErpPurchaseOrder? _selectedPo;
  String? _storeId;
  DateTime _date = DateTime.now();
  final _truckCtrl = TextEditingController();
  final _challanCtrl = TextEditingController();
  final _vendorCtrl = TextEditingController();
  String? _challanImageUrl;
  bool _uploading = false;
  String _qc = 'PASSED';
  final _headerRejectCtrl = TextEditingController();
  DateTime? _returnDate;
  final _remarksCtrl = TextEditingController();

  final List<_InwardLineDraft> _lines = [_InwardLineDraft()];

  bool get _isNa => _poId == kNaPurchaseOrder;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _truckCtrl.dispose();
    _challanCtrl.dispose();
    _vendorCtrl.dispose();
    _headerRejectCtrl.dispose();
    _remarksCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<BoqRepository>();
      final isMachine = widget.resourceKind == StoreInwardKind.machine;
      final res = await Future.wait([
        repo.listPurchaseOrders(openOnly: true),
        repo.listStores(),
        repo.listInwards(),
        if (isMachine) repo.listMachines() else repo.listMaterials(),
      ]);
      if (!mounted) return;
      setState(() {
        _pos = res[0] as List<ErpPurchaseOrder>;
        _stores = res[1] as List<ErpStoreMaster>;
        _recent = (res[2] as List<ErpStoreInward>).take(20).toList();
        if (isMachine) {
          _machines = res[3] as List<ErpMachine>;
        } else {
          _materials = res[3] as List<ErpMaterial>;
        }
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

  Future<void> _createSamplePo() async {
    try {
      final materials = await context.read<BoqRepository>().listMaterials();
      final items = materials.take(3).map((m) {
        return {
          'materialId': m.id,
          'itemName': m.name,
          'brand': m.brand,
          'unitCode': m.unitCode,
          'size': m.size,
          'orderedQty': 100,
        };
      }).toList();
      if (items.isEmpty) {
        items.add({
          'itemName': 'Cement',
          'brand': 'Sample',
          'unitCode': 'BAG',
          'orderedQty': 100,
        });
      }
      final po = await context.read<BoqRepository>().createPurchaseOrder({
        'vendorName': 'Sample Vendor',
        'items': items,
        'remarks': 'Temporary sample PO — replace via Purchase menu later',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created ${po.poNumber}')),
      );
      await _reload();
      await _onPoChanged(po.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _onPoChanged(String? id) async {
    setState(() {
      _poId = id;
      _selectedPo = null;
      for (final l in _lines) {
        l.poItemId = null;
        l.resourceId = null;
        l.qtyCtrl.clear();
        l.rejectCtrl.text = '0';
      }
    });
    if (id == null || id == kNaPurchaseOrder) return;
    try {
      final po = await context.read<BoqRepository>().getPurchaseOrder(id);
      if (!mounted) return;
      setState(() => _selectedPo = po);
      await _maybeShowRemainingAlert(po);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load PO: $e')),
      );
    }
  }

  Future<void> _maybeShowRemainingAlert(ErpPurchaseOrder po) async {
    final pending = po.items.where((i) => i.remainingQty > 0).toList();
    final partial = pending.where((i) => i.receivedQty > 0).toList();
    if (partial.isEmpty) return;
    if (!mounted) return;
    final lines = partial
        .map(
          (i) =>
              '• ${i.itemName}: ${i.remainingQty.toStringAsFixed(2)} still remaining '
              '(ordered ${i.orderedQty.toStringAsFixed(0)}, received ${i.receivedQty.toStringAsFixed(0)})',
        )
        .join('\n');
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${po.poNumber} — pending arrivals'),
        content: SingleChildScrollView(
          child: Text(
            'Some materials from this PO are still not fully received:\n\n$lines\n\n'
            'What would you like to do?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'keep'),
            child: const Text('Keep pending'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'new'),
            child: const Text('Create new PO'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel remaining'),
          ),
        ],
      ),
    );
    if (!mounted || action == null || action == 'keep') return;
    if (action == 'new') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a new PO from Purchase → Quotations / CS for the remaining qty.'),
        ),
      );
      return;
    }
    if (action == 'cancel') {
      try {
        await context.read<BoqRepository>().cancelPurchaseOrder(
              po.id,
              reason: 'Remaining qty cancelled from store inward',
            );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${po.poNumber} cancelled (remaining closed)')),
        );
        await _reload();
        setState(() {
          _poId = null;
          _selectedPo = null;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  List<ErpPurchaseOrderItem> get _availableItems {
    final po = _selectedPo;
    if (po == null) return const [];
    return po.items.where((i) => i.remainingQty > 0).toList();
  }

  ErpPurchaseOrderItem? _itemById(String? id) {
    if (id == null || _selectedPo == null) return null;
    for (final i in _selectedPo!.items) {
      if (i.id == id) return i;
    }
    return null;
  }

  Future<void> _pickChallan() async {
    final picked = await pickFileFromDevice(imagesOnly: true);
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final uploaded = await context.read<BoqRepository>().uploadStoreFile(
            bytes: picked.bytes,
            filename: picked.name,
          );
      if (!mounted) return;
      setState(() {
        _challanImageUrl = uploaded.url;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  Future<void> _pickDate({required bool returnDate}) async {
    final initial = returnDate ? (_returnDate ?? DateTime.now()) : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (returnDate) {
        _returnDate = picked;
      } else {
        _date = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_poId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a purchase order or NA')),
      );
      return;
    }
    if (_storeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a store')),
      );
      return;
    }
    if (_qc == 'PARTIAL_PASS' || _qc == 'FAIL') {
      if (_returnDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Return date is required for this QC status')),
        );
        return;
      }
    }

    final linesPayload = <Map<String, dynamic>>[];
    for (final line in _lines) {
      final qty = double.tryParse(line.qtyCtrl.text.trim()) ?? 0;
      if (qty <= 0) continue;
      final reject = double.tryParse(line.rejectCtrl.text.trim()) ?? 0;

      if (_isNa) {
        if (line.resourceId == null) continue;
        if (widget.resourceKind == StoreInwardKind.machine) {
          linesPayload.add({
            'machineId': line.resourceId,
            'quantityReceived': qty,
            if (_qc == 'PARTIAL_PASS') 'quantityRejected': reject,
          });
        } else {
          linesPayload.add({
            'materialId': line.resourceId,
            'quantityReceived': qty,
            if (_qc == 'PARTIAL_PASS') 'quantityRejected': reject,
          });
        }
      } else {
        if (line.poItemId == null) continue;
        final item = _itemById(line.poItemId);
        if (item != null && qty > item.remainingQty + 1e-9) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Qty for ${item.itemName} exceeds remaining ${item.remainingQty}',
              ),
            ),
          );
          return;
        }
        linesPayload.add({
          'purchaseOrderItemId': line.poItemId,
          'quantityReceived': qty,
          if (_qc == 'PARTIAL_PASS') 'quantityRejected': reject,
        });
      }
    }
    if (linesPayload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isNa
                ? 'Add at least one ${widget.resourceKind == StoreInwardKind.machine ? 'machine' : 'material'} with quantity'
                : 'Add at least one item with quantity',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<BoqRepository>().createInward({
        if (_isNa) 'na': true else 'purchaseOrderId': _poId,
        'storeId': _storeId,
        'resourceType':
            widget.resourceKind == StoreInwardKind.machine ? 'MACHINE' : 'MATERIAL',
        'inwardDate': DateFormat('yyyy-MM-dd').format(_date),
        'truckNumber': _truckCtrl.text.trim().isEmpty ? null : _truckCtrl.text.trim(),
        'challanNumber':
            _challanCtrl.text.trim().isEmpty ? null : _challanCtrl.text.trim(),
        'challanImageUrl': _challanImageUrl,
        'qcStatus': _qc,
        if (_isNa && _vendorCtrl.text.trim().isNotEmpty) 'vendorName': _vendorCtrl.text.trim(),
        if (_qc == 'PARTIAL_PASS' && _headerRejectCtrl.text.trim().isNotEmpty)
          'quantityRejected': double.tryParse(_headerRejectCtrl.text.trim()),
        if (_returnDate != null)
          'returnDate': DateFormat('yyyy-MM-dd').format(_returnDate!),
        'remarks': _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
        'lines': linesPayload,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isNa
                ? 'Inward saved as NA — you can link a PO later from Recent inwards'
                : 'Goods inward saved',
          ),
        ),
      );
      _truckCtrl.clear();
      _challanCtrl.clear();
      _vendorCtrl.clear();
      _headerRejectCtrl.clear();
      _remarksCtrl.clear();
      _challanImageUrl = null;
      _returnDate = null;
      _qc = 'PASSED';
      for (final l in _lines) {
        l.dispose();
      }
      _lines
        ..clear()
        ..add(_InwardLineDraft());
      await _onPoChanged(_poId);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _linkInwardToPo(ErpStoreInward inv) async {
    if (_pos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No open POs available to link')),
      );
      return;
    }
    String? selectedPoId = _pos.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Link Purchase Order'),
        content: StatefulBuilder(
          builder: (ctx, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Attach a PO to this NA inward. Lines are matched by item name when possible.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedPoId,
                decoration: const InputDecoration(
                  labelText: 'Purchase Order *',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final po in _pos)
                    DropdownMenuItem(
                      value: po.id,
                      child: Text(
                        '${po.poNumber} — ${po.vendorName}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setLocal(() => selectedPoId = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Link')),
        ],
      ),
    );
    if (ok != true || selectedPoId == null || !mounted) return;
    try {
      await context.read<BoqRepository>().linkInwardToPo(
            inv.id,
            purchaseOrderId: selectedPoId!,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PO linked to inward')),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final border = Border.all(
      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
    );

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _pos.isEmpty && _stores.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _reload, child: const Text('Retry')),
          ],
        ),
      );
    }

    final children = <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: border,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.resourceKind == StoreInwardKind.machine
                    ? 'Machine Inward'
                    : 'Material Inward',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isNa
                    ? 'NA mode: take stock now without a PO. You can link the PO later from Recent inwards.'
                    : 'Select PO or NA. With a PO, qty cannot exceed remaining.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              if (_pos.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: _createSamplePo,
                    icon: const Icon(Icons.add_shopping_cart_outlined),
                    label: const Text('No POs yet — create sample PO (optional)'),
                  ),
                ),
              DropdownButtonFormField<String>(
                value: _poId,
                decoration: const InputDecoration(
                  labelText: 'Purchase Order *',
                  border: OutlineInputBorder(),
                  helperText: 'Choose NA if PO is not created yet',
                ),
                items: [
                  const DropdownMenuItem(
                    value: kNaPurchaseOrder,
                    child: Text('NA — no PO (link later)'),
                  ),
                  for (final po in _pos)
                    DropdownMenuItem(
                      value: po.id,
                      child: Text(
                        '${po.poNumber} — ${po.vendorName} (rem ${po.totalRemaining.toStringAsFixed(0)})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _onPoChanged,
              ),
              if (_isNa) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _vendorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Vendor (optional)',
                    border: OutlineInputBorder(),
                    helperText: 'Record who supplied — update when PO is linked',
                  ),
                ),
              ],
              if (_selectedPo != null) ...[
                const SizedBox(height: 12),
                _PoDetailsCard(po: _selectedPo!, isDark: isDark),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(returnDate: false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date *',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(DateFormat('dd MMM yyyy').format(_date)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StoreDropdownWithCreate(
                      value: _storeId,
                      stores: _stores,
                      required: true,
                      decoration: const InputDecoration(
                        labelText: 'Store *',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _storeId = v),
                      onStoreCreated: (created) => setState(() {
                        _stores = [..._stores, created];
                        _storeId = created.id;
                      }),
                    ),
                  ),
                ],
              ),
              if (_stores.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'No stores configured. Add them under ERP → Configurations → Stores.',
                    style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _truckCtrl,
                decoration: const InputDecoration(
                  labelText: 'Truck Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _challanCtrl,
                decoration: const InputDecoration(
                  labelText: 'Challan Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _pickChallan,
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image_outlined),
                label: Text(
                  _challanImageUrl == null ? 'Upload Challan Image' : 'Challan image attached',
                ),
              ),
              if (_challanImageUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _challanImageUrl!,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Text('Image preview unavailable'),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _qc,
                decoration: const InputDecoration(
                  labelText: 'QC *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'PASSED', child: Text('Passed')),
                  DropdownMenuItem(value: 'PARTIAL_PASS', child: Text('Partial pass')),
                  DropdownMenuItem(value: 'FAIL', child: Text('Fail')),
                ],
                onChanged: (v) => setState(() {
                  _qc = v ?? 'PASSED';
                  if (_qc == 'PASSED') _returnDate = null;
                }),
              ),
              if (_qc == 'PARTIAL_PASS') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _headerRejectCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Quantity rejected *',
                    border: OutlineInputBorder(),
                    helperText: 'Or set rejected qty per line below',
                  ),
                ),
              ],
              if (_qc == 'PARTIAL_PASS' || _qc == 'FAIL') ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _pickDate(returnDate: true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Return date *',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _returnDate == null
                          ? 'Select return date'
                          : DateFormat('dd MMM yyyy').format(_returnDate!),
                    ),
                  ),
                ),
                if (_qc == 'FAIL')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Fail: entire receipt is rejected — nothing is added to stock.',
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Items',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: (_selectedPo == null && !_isNa)
                        ? null
                        : () => setState(() => _lines.add(_InwardLineDraft())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add line'),
                  ),
                ],
              ),
              for (var i = 0; i < _lines.length; i++)
                _buildLineCard(i, isDark),
              const SizedBox(height: 12),
              TextFormField(
                controller: _remarksCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Remarks',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: widget.resourceKind == StoreInwardKind.machine
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFF0D9488),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        widget.resourceKind == StoreInwardKind.machine
                            ? 'Save Machine Inward'
                            : 'Save Material Inward',
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Recent inwards',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        if (_recent.isEmpty)
          Text(
            'No inwards yet.',
            style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
          ),
        for (final inv in _recent)
          Card(
            child: ListTile(
              title: Text(
                '${inv.isNaPo ? 'NA (no PO)' : (inv.poNumber ?? inv.purchaseOrderId)}'
                '${inv.storeName != null && inv.storeName!.isNotEmpty ? ' · ${inv.storeName}' : ''}',
              ),
              subtitle: Text(
                [
                  DateFormat('dd MMM yyyy').format(inv.inwardDate),
                  'QC ${inv.qcStatus}',
                  if (inv.vendorName != null && inv.vendorName!.isNotEmpty) inv.vendorName!,
                  if (inv.challanNumber != null) 'Challan ${inv.challanNumber}',
                ].join(' · '),
              ),
              trailing: inv.isNaPo
                  ? TextButton(
                      onPressed: () => _linkInwardToPo(inv),
                      child: const Text('Link PO'),
                    )
                  : Text('${inv.lines.length} items'),
            ),
          ),
      ];

    if (widget.compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }

  Widget _buildLineCard(int index, bool isDark) {
    final line = _lines[index];
    final item = _itemById(line.poItemId);
    final items = _availableItems;
    final dropdownItems = [
      ...items,
      if (item != null && !items.any((e) => e.id == item.id)) item,
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Line ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_lines.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => setState(() {
                      _lines.removeAt(index).dispose();
                    }),
                  ),
              ],
            ),
            if (_isNa) ...[
              if (widget.resourceKind == StoreInwardKind.machine)
                MachineDropdownWithCreate(
                  value: line.resourceId,
                  machines: _machines,
                  required: true,
                  decoration: const InputDecoration(
                    labelText: 'Machine *',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => line.resourceId = v),
                  onMachineCreated: (created) => setState(() {
                    _machines = [..._machines, created];
                    line.resourceId = created.id;
                  }),
                )
              else
                MaterialDropdownWithCreate(
                  value: line.resourceId,
                  materials: _materials,
                  required: true,
                  decoration: const InputDecoration(
                    labelText: 'Material *',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => line.resourceId = v),
                  onMaterialCreated: (created) => setState(() {
                    _materials = [..._materials, created];
                    line.resourceId = created.id;
                  }),
                ),
            ] else ...[
              DropdownButtonFormField<String>(
                value: line.poItemId,
                decoration: const InputDecoration(
                  labelText: 'Item (from PO) *',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final it in dropdownItems)
                    DropdownMenuItem(
                      value: it.id,
                      child: Text(
                        '${it.itemName} · rem ${it.remainingQty.toStringAsFixed(0)}'
                        '${it.unitCode != null ? ' ${it.unitCode}' : ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) {
                  setState(() {
                    line.poItemId = v;
                    final sel = _itemById(v);
                    if (sel != null) {
                      line.qtyCtrl.text = sel.remainingQty.toStringAsFixed(
                        sel.remainingQty == sel.remainingQty.roundToDouble() ? 0 : 2,
                      );
                    }
                  });
                },
              ),
              if (item != null) ...[
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: item.itemName,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: widget.resourceKind == StoreInwardKind.machine
                        ? 'Machine Name'
                        : 'Material Name',
                    border: const OutlineInputBorder(),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: item.brand ?? '',
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Brand',
                          border: OutlineInputBorder(),
                          filled: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: item.unitCode ?? '',
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                          filled: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: item.size ?? '',
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: widget.resourceKind == StoreInwardKind.machine
                        ? 'Capacity / Size'
                        : 'Size / Spec',
                    border: const OutlineInputBorder(),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ordered: ${item.orderedQty} · Already received: ${item.receivedQty} · Remaining: ${item.remainingQty}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: line.qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Qty received *',
                      border: const OutlineInputBorder(),
                      helperText: item == null
                          ? null
                          : 'Max ${item.remainingQty.toStringAsFixed(2)}',
                    ),
                  ),
                ),
                if (_qc == 'PARTIAL_PASS') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: line.rejectCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Qty rejected',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PoDetailsCard extends StatelessWidget {
  const _PoDetailsCard({required this.po, required this.isDark});

  final ErpPurchaseOrder po;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final v = po.vendor;
    final phone = v?.mobileNo?.isNotEmpty == true
        ? v!.mobileNo
        : (v?.phone?.isNotEmpty == true ? v!.phone : null);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PO: ${po.poNumber} · Status: ${po.status}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text('Date: ${DateFormat('dd MMM yyyy').format(po.orderDate)}'),
          const SizedBox(height: 8),
          Text(
            'Vendor details',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
          Text('Name: ${v?.name ?? po.vendorName}'),
          if (v?.contactPerson != null && v!.contactPerson!.isNotEmpty)
            Text('Contact: ${v.contactPerson}'),
          if (phone != null) Text('Phone: $phone'),
          if (v?.email != null && v!.email!.isNotEmpty) Text('Email: ${v.email}'),
          if (v?.contractorTypeCode != null && v!.contractorTypeCode!.isNotEmpty)
            Text('Type: ${v.contractorTypeCode}'),
          const SizedBox(height: 8),
          Text(
            'Items · Remaining ${po.totalRemaining.toStringAsFixed(2)} / ${po.totalOrdered.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          for (final it in po.items)
            Text(
              '• ${it.itemName}'
              '${it.brand != null && it.brand!.isNotEmpty ? ' (${it.brand})' : ''}'
              '${it.unitCode != null ? ' · ${it.unitCode}' : ''}'
              '${it.size != null && it.size!.isNotEmpty ? ' · ${it.size}' : ''}'
              ' — ordered ${it.orderedQty}, rem ${it.remainingQty}',
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
    );
  }
}
