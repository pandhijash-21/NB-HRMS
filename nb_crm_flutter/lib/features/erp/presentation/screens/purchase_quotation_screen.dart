import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_back_button.dart';
import '../../data/purchase_repository.dart';
import '../../data/work_order_repository.dart';
import '../../domain/purchase_models.dart';
import '../../domain/work_order_models.dart';
import '../widgets/quick_create_vendor_dialog.dart';

/// Quotations + Comparison Sheet for one approved Purchase Request.
class PurchaseQuotationScreen extends StatefulWidget {
  const PurchaseQuotationScreen({super.key, required this.purchaseRequestId});

  final String purchaseRequestId;

  @override
  State<PurchaseQuotationScreen> createState() => _PurchaseQuotationScreenState();
}

class _PurchaseQuotationScreenState extends State<PurchaseQuotationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  ErpPurchaseComparisonSheet? _sheet;
  bool _loading = true;
  String? _error;
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sheet =
          await context.read<PurchaseRepository>().getComparison(widget.purchaseRequestId);
      if (!mounted) return;
      setState(() {
        _sheet = sheet;
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

  Future<void> _addOrEditQuotation({ErpPurchaseQuotation? existing}) async {
    final sheet = _sheet;
    if (sheet == null) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _QuotationEditorDialog(
        purchaseRequest: sheet.purchaseRequest,
        existing: existing,
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _submit(ErpPurchaseQuotation q) async {
    try {
      await context.read<PurchaseRepository>().submitQuotation(q.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _delete(ErpPurchaseQuotation q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete quotation?'),
        content: Text(q.quotationNo),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<PurchaseRepository>().deleteQuotation(q.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _selectWinner(ErpPurchaseQuotation q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Comparison Sheet'),
        content: Text(
          'Select ${q.vendorName} (${q.quotationNo}) as the winning quotation?\n\n'
          'This creates the final Purchase Order and rejects other quotations.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve & create PO')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _selecting = true);
    try {
      final result = await context.read<PurchaseRepository>().selectQuotation(q.id);
      await _load();
      if (!mounted) return;
      final po = result['purchaseOrder'];
      final poNo = po is Map ? po['poNumber']?.toString() : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(poNo != null ? 'Final PO created: $poNo' : 'Quotation selected'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pr = _sheet?.purchaseRequest;
    final quotes = _sheet?.quotations ?? const <ErpPurchaseQuotation>[];
    final hasSelected = quotes.any((q) => q.status == 'SELECTED');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(pr != null ? 'Quotations · ${pr.prNumber}' : 'Quotations'),
        leading: const AppBackButton(fallbackLocation: '/erp/purchase'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          if (pr != null && !hasSelected)
            IconButton(
              tooltip: 'Add quotation',
              icon: const Icon(Icons.add),
              onPressed: () => _addOrEditQuotation(),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Quotations'),
            Tab(text: 'Comparison Sheet'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _QuotationsTab(
                      quotes: quotes,
                      hasSelected: hasSelected,
                      onAdd: () => _addOrEditQuotation(),
                      onEdit: (q) => _addOrEditQuotation(existing: q),
                      onSubmit: _submit,
                      onDelete: _delete,
                      onSelect: hasSelected || _selecting ? null : _selectWinner,
                    ),
                    _ComparisonTab(
                      sheet: _sheet!,
                      selecting: _selecting,
                      onSelect: hasSelected || _selecting ? null : _selectWinner,
                    ),
                  ],
                ),
    );
  }
}

class _QuotationsTab extends StatelessWidget {
  const _QuotationsTab({
    required this.quotes,
    required this.hasSelected,
    required this.onAdd,
    required this.onEdit,
    required this.onSubmit,
    required this.onDelete,
    required this.onSelect,
  });

  final List<ErpPurchaseQuotation> quotes;
  final bool hasSelected;
  final VoidCallback onAdd;
  final ValueChanged<ErpPurchaseQuotation> onEdit;
  final ValueChanged<ErpPurchaseQuotation> onSubmit;
  final ValueChanged<ErpPurchaseQuotation> onDelete;
  final ValueChanged<ErpPurchaseQuotation>? onSelect;

  @override
  Widget build(BuildContext context) {
    if (quotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No quotations yet. Add vendor quotes against this PR.'),
            const SizedBox(height: 12),
            if (!hasSelected)
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add quotation'),
              ),
          ],
        ),
      );
    }
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: quotes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final q = quotes[i];
        final editable = q.status == 'DRAFT';
        return Card(
          child: ListTile(
            title: Text(
              '${q.quotationNo} · ${q.vendorName}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              [
                q.status,
                money.format(q.totalAmount),
                if (q.gstNo != null && q.gstNo!.isNotEmpty) 'GST ${q.gstNo}',
                if (q.purchaseOrderNo != null) 'PO ${q.purchaseOrderNo}',
              ].join(' · '),
            ),
            isThreeLine: true,
            trailing: Wrap(
              spacing: 4,
              children: [
                if (editable) ...[
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => onEdit(q),
                  ),
                  TextButton(onPressed: () => onSubmit(q), child: const Text('Submit')),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => onDelete(q),
                  ),
                ],
                if (!hasSelected && (q.status == 'DRAFT' || q.status == 'SUBMITTED'))
                  FilledButton(
                    onPressed: onSelect == null ? null : () => onSelect!(q),
                    child: const Text('Select'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ComparisonTab extends StatelessWidget {
  const _ComparisonTab({
    required this.sheet,
    required this.selecting,
    required this.onSelect,
  });

  final ErpPurchaseComparisonSheet sheet;
  final bool selecting;
  final ValueChanged<ErpPurchaseQuotation>? onSelect;

  @override
  Widget build(BuildContext context) {
    final quotes = sheet.quotations;
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    if (quotes.isEmpty) {
      return const Center(child: Text('Add quotations to build the comparison sheet.'));
    }

    // Collect unique PR line keys for rows
    final lineKeys = <String>[];
    final lineLabels = <String, String>{};
    for (final q in quotes) {
      for (final l in q.lines) {
        final key = l.purchaseRequestLineId ?? '${l.itemName}|${l.materialId ?? ''}';
        if (!lineKeys.contains(key)) {
          lineKeys.add(key);
          lineLabels[key] =
              '${l.itemName}${l.unitCode != null ? ' (${l.unitCode})' : ''} · Qty ${l.qty}';
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowHeight: 56,
          columns: [
            const DataColumn(label: Text('Item / Qty', style: TextStyle(fontWeight: FontWeight.w800))),
            for (final q in quotes)
              DataColumn(
                label: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(q.vendorName, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${q.status} · ${money.format(q.totalAmount)}',
                        style: const TextStyle(fontSize: 11)),
                    if (onSelect != null &&
                        (q.status == 'DRAFT' || q.status == 'SUBMITTED'))
                      TextButton(
                        onPressed: selecting ? null : () => onSelect!(q),
                        child: const Text('Select as winner'),
                      ),
                  ],
                ),
              ),
          ],
          rows: [
            for (final key in lineKeys)
              DataRow(
                cells: [
                  DataCell(SizedBox(width: 220, child: Text(lineLabels[key] ?? key))),
                  for (final q in quotes)
                    DataCell(() {
                      ErpPurchaseQuotationLine? line;
                      for (final l in q.lines) {
                        final k = l.purchaseRequestLineId ??
                            '${l.itemName}|${l.materialId ?? ''}';
                        if (k == key) {
                          line = l;
                          break;
                        }
                      }
                      if (line == null) return const Text('—');
                      return Text(
                        '${money.format(line.rate)}\n= ${money.format(line.amount)}',
                      );
                    }()),
                ],
              ),
            DataRow(
              cells: [
                const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w800))),
                for (final q in quotes)
                  DataCell(
                    Text(
                      money.format(q.totalAmount),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuotationEditorDialog extends StatefulWidget {
  const _QuotationEditorDialog({
    required this.purchaseRequest,
    this.existing,
  });

  final ErpPurchaseRequest purchaseRequest;
  final ErpPurchaseQuotation? existing;

  @override
  State<_QuotationEditorDialog> createState() => _QuotationEditorDialogState();
}

class _QuotationEditorDialogState extends State<_QuotationEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _gstCtrl;
  late TextEditingController _panCtrl;
  late TextEditingController _remarksCtrl;
  String? _vendorId;
  List<ErpContractor> _vendors = [];
  late List<ErpPurchaseQuotationLine> _lines;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.vendorName ?? '');
    _addressCtrl = TextEditingController(text: e?.address ?? '');
    _gstCtrl = TextEditingController(text: e?.gstNo ?? '');
    _panCtrl = TextEditingController(text: e?.panNo ?? '');
    _remarksCtrl = TextEditingController(text: e?.remarks ?? '');
    _vendorId = e?.vendorId;
    if (e != null && e.lines.isNotEmpty) {
      _lines = List.of(e.lines);
    } else {
      _lines = widget.purchaseRequest.lines
          .map(
            (l) => ErpPurchaseQuotationLine(
              purchaseRequestLineId: l.id,
              materialId: l.materialId,
              itemCode: l.itemCode,
              brand: l.brand,
              itemName: l.itemName,
              unitCode: l.unitCode,
              size: l.size,
              qty: l.qty,
              rate: 0,
              amount: 0,
            ),
          )
          .toList();
    }
    _loadVendors();
  }

  Future<void> _loadVendors() async {
    try {
      final list = await context.read<WorkOrderRepository>().listContractors();
      if (mounted) setState(() => _vendors = list);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _gstCtrl.dispose();
    _panCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  double get _total => _lines.fold(0.0, (s, l) => s + l.amount);

  Future<void> _onVendorPicked(String? id) async {
    setState(() => _vendorId = id);
    if (id == null) return;
    final v = _vendors.where((c) => c.id == id).firstOrNull;
    if (v == null) return;
    _nameCtrl.text = v.name;
    // Prefer first location for GST/PAN/address if present on model
    try {
      final detail = await context.read<WorkOrderRepository>().getContractor(id);
      if (!mounted) return;
      final loc = detail.locations.isNotEmpty ? detail.locations.first : null;
      setState(() {
        if (loc != null) {
          _gstCtrl.text = loc.gstNo ?? _gstCtrl.text;
          _panCtrl.text = loc.panNo ?? _panCtrl.text;
          final addr = [
            loc.address1,
            loc.address2,
            loc.cityCode,
            loc.stateCode,
          ].where((x) => x != null && x.trim().isNotEmpty).join(', ');
          if (addr.isNotEmpty) _addressCtrl.text = addr;
        }
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Company / vendor name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final body = {
        'vendorId': _vendorId,
        'vendorName': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'gstNo': _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
        'panNo': _panCtrl.text.trim().isEmpty ? null : _panCtrl.text.trim(),
        'remarks': _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
        'lines': _lines.map((l) => l.toJson()).toList(),
      };
      final repo = context.read<PurchaseRepository>();
      if (widget.existing == null) {
        await repo.createQuotation(widget.purchaseRequest.id, body);
      } else {
        await repo.updateQuotation(widget.existing!.id, body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add quotation' : 'Edit quotation'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'PR ${widget.purchaseRequest.prNumber} — items & qty from request; enter rates.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                VendorDropdownWithCreate(
                  value: _vendorId,
                  vendors: _vendors,
                  includeNullOption: true,
                  nullLabel: 'Select vendor (optional)',
                  decoration: const InputDecoration(
                    labelText: 'Vendor (from master)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _onVendorPicked,
                  onVendorCreated: (created) {
                    setState(() {
                      _vendors = [..._vendors, created];
                      _vendorId = created.id;
                      _nameCtrl.text = created.name;
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Company name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _gstCtrl,
                        decoration: const InputDecoration(
                          labelText: 'GST',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _panCtrl,
                        decoration: const InputDecoration(
                          labelText: 'PAN',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Lines', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                for (var i = 0; i < _lines.length; i++) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _lines[i].itemName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Qty ${_lines[i].qty}${_lines[i].unitCode != null ? ' ${_lines[i].unitCode}' : ''}'
                            '${_lines[i].brand != null ? ' · ${_lines[i].brand}' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: _lines[i].rate == 0 ? '' : _lines[i].rate.toString(),
                            decoration: InputDecoration(
                              labelText: 'Rate *',
                              border: const OutlineInputBorder(),
                              helperText: 'Amount: ${money.format(_lines[i].amount)}',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            ],
                            onChanged: (v) {
                              final rate = double.tryParse(v) ?? 0;
                              setState(() => _lines[i] = _lines[i].copyWith(rate: rate));
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total: ${money.format(_total)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _remarksCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Remarks',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
