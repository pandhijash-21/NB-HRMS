import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/utils/open_url.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../data/purchase_repository.dart';
import '../../data/work_order_repository.dart';
import '../../domain/contractor_lookup_keys.dart';
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
      final poId = po is Map ? po['id']?.toString() : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(poNo != null ? 'Final PO created: $poNo' : 'Quotation selected'),
          backgroundColor: Colors.green.shade700,
          action: poId == null
              ? null
              : SnackBarAction(
                  label: 'Print PO',
                  textColor: Colors.white,
                  onPressed: () => _printPo(poId),
                ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  Future<void> _printCs() async {
    try {
      final bytes =
          await context.read<PurchaseRepository>().exportComparisonExcel(widget.purchaseRequestId);
      final prNo = _sheet?.purchaseRequest.prNumber ?? 'PR';
      await downloadBytes(
        bytes,
        'CS_${prNo.replaceAll(RegExp(r'[^\w.-]+'), '_')}.xlsx',
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comparison Sheet downloaded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _printPo(String purchaseOrderId) async {
    try {
      final bytes =
          await context.read<PurchaseRepository>().exportPurchaseOrderExcel(purchaseOrderId);
      ErpPurchaseQuotation? matched;
      for (final x in _sheet?.quotations ?? const <ErpPurchaseQuotation>[]) {
        if (x.purchaseOrderId == purchaseOrderId) {
          matched = x;
          break;
        }
      }
      final poNo = matched?.purchaseOrderNo ?? purchaseOrderId;
      await downloadBytes(
        bytes,
        'PO_${poNo.replaceAll(RegExp(r'[^\w.-]+'), '_')}.xlsx',
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase Order downloaded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _editPoTerms(String purchaseOrderId) async {
    final repo = context.read<PurchaseRepository>();
    try {
      final po = await repo.getPurchaseOrder(purchaseOrderId);
      if (!mounted) return;
      final ctrl = TextEditingController(text: po.termsAndConditions.join('\n'));
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Terms & Conditions · ${po.poNumber}'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'One term per line. These print on the Purchase Order.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                    labelText: 'Terms & Conditions',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      );
      if (saved != true || !mounted) return;
      final terms = ctrl.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      await repo.updatePurchaseOrder(purchaseOrderId, termsAndConditions: terms);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terms & Conditions saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pr = _sheet?.purchaseRequest;
    final quotes = _sheet?.quotations ?? const <ErpPurchaseQuotation>[];
    final hasSelected = quotes.any((q) => q.status == 'SELECTED');
    ErpPurchaseQuotation? selected;
    for (final q in quotes) {
      if (q.status == 'SELECTED') {
        selected = q;
        break;
      }
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(pr != null ? 'Quotations · ${pr.prNumber}' : 'Quotations'),
        leading: const AppBackButton(fallbackLocation: '/erp/purchase'),
        actions: [
          if (quotes.isNotEmpty)
            IconButton(
              tooltip: 'Print Comparison Sheet',
              icon: const Icon(Icons.print_outlined),
              onPressed: _printCs,
            ),
          if (selected?.purchaseOrderId != null) ...[
            IconButton(
              tooltip: 'Edit PO Terms & Conditions',
              icon: const Icon(Icons.article_outlined),
              onPressed: () => _editPoTerms(selected!.purchaseOrderId!),
            ),
            IconButton(
              tooltip: 'Print Purchase Order',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () => _printPo(selected!.purchaseOrderId!),
            ),
          ],
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
                    Column(
                      children: [
                        _VendorPortalInviteCard(purchaseRequestId: widget.purchaseRequestId),
                        Expanded(
                          child: _QuotationsTab(
                            quotes: quotes,
                            hasSelected: hasSelected,
                            onAdd: () => _addOrEditQuotation(),
                            onEdit: (q) => _addOrEditQuotation(existing: q),
                            onSubmit: _submit,
                            onDelete: _delete,
                            onSelect: hasSelected || _selecting ? null : _selectWinner,
                            onPrintPo: (q) {
                              if (q.purchaseOrderId != null) _printPo(q.purchaseOrderId!);
                            },
                            onEditTerms: (q) {
                              if (q.purchaseOrderId != null) _editPoTerms(q.purchaseOrderId!);
                            },
                          ),
                        ),
                      ],
                    ),
                    _ComparisonTab(
                      sheet: _sheet!,
                      selecting: _selecting,
                      onSelect: hasSelected || _selecting ? null : _selectWinner,
                      onPrintCs: _printCs,
                      onPrintPo: selected?.purchaseOrderId == null
                          ? null
                          : () => _printPo(selected!.purchaseOrderId!),
                      onEditTerms: selected?.purchaseOrderId == null
                          ? null
                          : () => _editPoTerms(selected!.purchaseOrderId!),
                    ),
                  ],
                ),
    );
  }
}

class _VendorPortalInviteCard extends StatefulWidget {
  const _VendorPortalInviteCard({required this.purchaseRequestId});

  final String purchaseRequestId;

  @override
  State<_VendorPortalInviteCard> createState() => _VendorPortalInviteCardState();
}

class _VendorPortalInviteCardState extends State<_VendorPortalInviteCard> {
  Map<String, dynamic>? _invite;
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
      final data =
          await context.read<PurchaseRepository>().getVendorPortalInvite(widget.purchaseRequestId);
      if (!mounted) return;
      setState(() {
        _invite = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _ensure() async {
    try {
      final data =
          await context.read<PurchaseRepository>().ensureVendorPortalInvite(widget.purchaseRequestId);
      if (!mounted) return;
      setState(() => _invite = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _rotate() async {
    try {
      final data =
          await context.read<PurchaseRepository>().rotateVendorPortalInvite(widget.purchaseRequestId);
      if (!mounted) return;
      setState(() => _invite = data);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite link regenerated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _email() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Email invite link'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Vendor emails',
            hintText: 'a@x.com, b@y.com',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final emails = ctrl.text
        .split(RegExp(r'[,;\s]+'))
        .map((e) => e.trim())
        .where((e) => e.contains('@'))
        .toList();
    if (emails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one email')),
      );
      return;
    }
    try {
      final res = await context.read<PurchaseRepository>().emailVendorPortalInvite(
            widget.purchaseRequestId,
            emails: emails,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent to ${res['sent']} recipient(s)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LinearProgressIndicator(minHeight: 2);
    }
    final enabled = _invite?['vendorPortalEnabled'] == true;
    final link = _invite?['link']?.toString();
    return Material(
      color: enabled ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.link,
                  size: 18,
                  color: enabled ? const Color(0xFF1e3a5f) : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    enabled
                        ? 'Vendor quotation link (unique for this PR)'
                        : 'Vendor portal disabled — enable in Purchase → Settings',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                if (enabled)
                  TextButton(onPressed: _ensure, child: const Text('Generate')),
              ],
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            if (enabled && link != null && link.isNotEmpty) ...[
              const SizedBox(height: 6),
              SelectableText(link, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: link));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                  ),
                  if (_invite?['vendorPortalAutoEmail'] == true)
                    OutlinedButton.icon(
                      onPressed: _email,
                      icon: const Icon(Icons.mail_outline, size: 16),
                      label: const Text('Email vendors'),
                    ),
                  TextButton(onPressed: _rotate, child: const Text('Rotate link')),
                ],
              ),
            ],
          ],
        ),
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
    this.onPrintPo,
    this.onEditTerms,
  });

  final List<ErpPurchaseQuotation> quotes;
  final bool hasSelected;
  final VoidCallback onAdd;
  final ValueChanged<ErpPurchaseQuotation> onEdit;
  final ValueChanged<ErpPurchaseQuotation> onSubmit;
  final ValueChanged<ErpPurchaseQuotation> onDelete;
  final ValueChanged<ErpPurchaseQuotation>? onSelect;
  final ValueChanged<ErpPurchaseQuotation>? onPrintPo;
  final ValueChanged<ErpPurchaseQuotation>? onEditTerms;

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
        final hasPo = q.purchaseOrderId != null;
        return Card(
          child: ListTile(
            title: Text(
              '${q.quotationNo} · ${q.vendorName}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              [
                q.status,
                money.format(q.displayFinal),
                if (q.gstMode == 'EXCLUSIVE') 'GST excl.',
                if (q.freightMode == 'EXCLUSIVE') 'Freight excl.',
                if (q.deliveryDays != null) '${q.deliveryDays}d',
                if (q.rating != null) '★ ${q.rating}',
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
                if (hasPo) ...[
                  IconButton(
                    tooltip: 'Edit TnC',
                    icon: const Icon(Icons.article_outlined),
                    onPressed: onEditTerms == null ? null : () => onEditTerms!(q),
                  ),
                  IconButton(
                    tooltip: 'Print PO',
                    icon: const Icon(Icons.print_outlined),
                    onPressed: onPrintPo == null ? null : () => onPrintPo!(q),
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
    this.onPrintCs,
    this.onPrintPo,
    this.onEditTerms,
  });

  final ErpPurchaseComparisonSheet sheet;
  final bool selecting;
  final ValueChanged<ErpPurchaseQuotation>? onSelect;
  final VoidCallback? onPrintCs;
  final VoidCallback? onPrintPo;
  final VoidCallback? onEditTerms;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onPrintCs,
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Print CS'),
              ),
              if (onPrintPo != null)
                FilledButton.icon(
                  onPressed: onPrintPo,
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Print PO'),
                ),
              if (onEditTerms != null)
                OutlinedButton.icon(
                  onPressed: onEditTerms,
                  icon: const Icon(Icons.article_outlined, size: 18),
                  label: const Text('Edit TnC'),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
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
                    Text('${q.status} · ${money.format(q.displayFinal)}',
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
                const DataCell(Text('Subtotal')),
                for (final q in quotes) DataCell(Text(money.format(q.totalAmount))),
              ],
            ),
            DataRow(
              cells: [
                const DataCell(Text('GST')),
                for (final q in quotes)
                  DataCell(Text(() {
                    if (q.gstMode != 'EXCLUSIVE') return 'Inclusive';
                    if (q.gstTaxType == 'IGST') {
                      return 'IGST ${q.igstRate ?? 0}% = ${money.format(q.igstAmount)}';
                    }
                    return 'CGST ${q.cgstRate ?? 0}% (${money.format(q.cgstAmount)}) + '
                        'SGST ${q.sgstRate ?? 0}% (${money.format(q.sgstAmount)})';
                  }())),
              ],
            ),
            DataRow(
              cells: [
                const DataCell(Text('Freight')),
                for (final q in quotes)
                  DataCell(Text(
                    q.freightMode == 'EXCLUSIVE'
                        ? 'Extra ${money.format(q.freightAmount)}'
                        : 'Inclusive',
                  )),
              ],
            ),
            DataRow(
              cells: [
                const DataCell(Text('Final amount', style: TextStyle(fontWeight: FontWeight.w800))),
                for (final q in quotes)
                  DataCell(
                    Text(
                      money.format(q.displayFinal),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
            DataRow(
              cells: [
                const DataCell(Text('Payment terms')),
                for (final q in quotes) DataCell(Text(q.paymentTerms ?? '—')),
              ],
            ),
            DataRow(
              cells: [
                const DataCell(Text('Delivery (days)')),
                for (final q in quotes)
                  DataCell(Text(q.deliveryDays?.toString() ?? '—')),
              ],
            ),
            DataRow(
              cells: [
                const DataCell(Text('Rating')),
                for (final q in quotes)
                  DataCell(Text(q.rating != null ? q.rating!.toStringAsFixed(1) : '—')),
              ],
            ),
          ],
              ),
            ),
          ),
        ),
      ],
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
  late TextEditingController _cgstRateCtrl;
  late TextEditingController _sgstRateCtrl;
  late TextEditingController _igstRateCtrl;
  late TextEditingController _freightAmtCtrl;
  late TextEditingController _deliveryCtrl;
  late TextEditingController _ratingCtrl;
  String? _vendorId;
  String? _vendorStateCode;
  String _gstMode = 'INCLUSIVE';
  String _gstTaxType = 'CGST_SGST'; // CGST_SGST | IGST
  String _freightMode = 'INCLUSIVE';
  String? _paymentTerms;
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
    _gstMode = e?.gstMode ?? 'INCLUSIVE';
    _gstTaxType = e?.gstTaxType == 'IGST' ? 'IGST' : 'CGST_SGST';
    _vendorStateCode = e?.vendorStateCode;
    _freightMode = e?.freightMode ?? 'INCLUSIVE';
    _paymentTerms = e?.paymentTerms;
    _cgstRateCtrl = TextEditingController(
      text: e?.cgstRate != null && e!.cgstRate! > 0 ? e.cgstRate!.toString() : '2.5',
    );
    _sgstRateCtrl = TextEditingController(
      text: e?.sgstRate != null && e!.sgstRate! > 0 ? e.sgstRate!.toString() : '2.5',
    );
    _igstRateCtrl = TextEditingController(
      text: e?.igstRate != null && e!.igstRate! > 0 ? e.igstRate!.toString() : '5',
    );
    _freightAmtCtrl = TextEditingController(
      text: e != null && e.freightAmount > 0 ? e.freightAmount.toString() : '',
    );
    _deliveryCtrl = TextEditingController(
      text: e?.deliveryDays != null ? e!.deliveryDays!.toString() : '',
    );
    _ratingCtrl = TextEditingController(
      text: e?.rating != null ? e!.rating!.toString() : '',
    );
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
    _cgstRateCtrl.dispose();
    _sgstRateCtrl.dispose();
    _igstRateCtrl.dispose();
    _freightAmtCtrl.dispose();
    _deliveryCtrl.dispose();
    _ratingCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _lines.fold(0.0, (s, l) => s + l.amount);

  double get _cgstRate => double.tryParse(_cgstRateCtrl.text.trim()) ?? 0;
  double get _sgstRate => double.tryParse(_sgstRateCtrl.text.trim()) ?? 0;
  double get _igstRate => double.tryParse(_igstRateCtrl.text.trim()) ?? 0;
  double get _freightAmt => double.tryParse(_freightAmtCtrl.text.trim()) ?? 0;

  double get _cgstAmount =>
      _gstMode == 'EXCLUSIVE' && _gstTaxType == 'CGST_SGST'
          ? double.parse(((_subtotal * _cgstRate) / 100).toStringAsFixed(2))
          : 0;
  double get _sgstAmount =>
      _gstMode == 'EXCLUSIVE' && _gstTaxType == 'CGST_SGST'
          ? double.parse(((_subtotal * _sgstRate) / 100).toStringAsFixed(2))
          : 0;
  double get _igstAmount =>
      _gstMode == 'EXCLUSIVE' && _gstTaxType == 'IGST'
          ? double.parse(((_subtotal * _igstRate) / 100).toStringAsFixed(2))
          : 0;
  double get _freightAdd => _freightMode == 'EXCLUSIVE' ? _freightAmt : 0;
  double get _finalAmount =>
      double.parse((_subtotal + _cgstAmount + _sgstAmount + _igstAmount + _freightAdd)
          .toStringAsFixed(2));

  void _setTaxTypeFromState(String? stateCode) {
    final state = (stateCode ?? '').trim().toUpperCase();
    if (state.isEmpty) return;
    _vendorStateCode = state;
    _gstTaxType = state == 'GUJARAT' ? 'CGST_SGST' : 'IGST';
  }

  Future<void> _onVendorPicked(String? id) async {
    setState(() => _vendorId = id);
    if (id == null) return;
    final v = _vendors.where((c) => c.id == id).firstOrNull;
    if (v == null) return;
    _nameCtrl.text = v.name;
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
          _setTaxTypeFromState(loc.stateCode);
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
    if (_gstMode == 'EXCLUSIVE' &&
        _gstTaxType == 'CGST_SGST' &&
        _cgstRate <= 0 &&
        _sgstRate <= 0) {
      setState(() => _error = 'Enter CGST and/or SGST % for exclusive GST');
      return;
    }
    if (_gstMode == 'EXCLUSIVE' && _gstTaxType == 'IGST' && _igstRate <= 0) {
      setState(() => _error = 'Enter IGST % for exclusive GST');
      return;
    }
    if (_freightMode == 'EXCLUSIVE' && _freightAmt < 0) {
      setState(() => _error = 'Freight amount cannot be negative');
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
        'gstMode': _gstMode,
        'gstTaxType': _gstMode == 'EXCLUSIVE' ? _gstTaxType : null,
        'vendorStateCode': _vendorStateCode,
        'cgstRate': _gstMode == 'EXCLUSIVE' && _gstTaxType == 'CGST_SGST' ? _cgstRate : null,
        'sgstRate': _gstMode == 'EXCLUSIVE' && _gstTaxType == 'CGST_SGST' ? _sgstRate : null,
        'igstRate': _gstMode == 'EXCLUSIVE' && _gstTaxType == 'IGST' ? _igstRate : null,
        'freightMode': _freightMode,
        'freightAmount': _freightAmt,
        'paymentTerms': _paymentTerms,
        'deliveryDays':
            _deliveryCtrl.text.trim().isEmpty ? null : int.tryParse(_deliveryCtrl.text.trim()),
        'rating':
            _ratingCtrl.text.trim().isEmpty ? null : double.tryParse(_ratingCtrl.text.trim()),
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

  Widget _modeToggle({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Inclusive'),
            selected: value == 'INCLUSIVE',
            onSelected: (_) => onChanged('INCLUSIVE'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Exclusive'),
            selected: value == 'EXCLUSIVE',
            onSelected: (_) => onChanged('EXCLUSIVE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add quotation' : 'Edit quotation'),
      content: SizedBox(
        width: 680,
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
                          labelText: 'GST No.',
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
                    'Subtotal: ${money.format(_subtotal)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('GST', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _modeToggle(
                  label: 'GST (Inclusive / Exclusive)',
                  value: _gstMode,
                  onChanged: (v) => setState(() => _gstMode = v),
                ),
                if (_gstMode == 'EXCLUSIVE') ...[
                  const SizedBox(height: 10),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tax type',
                      border: OutlineInputBorder(),
                      helperText:
                          'Gujarat vendor → CGST + SGST; outside Gujarat → IGST (auto from vendor state)',
                    ),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('CGST'),
                          selected: _gstTaxType == 'CGST_SGST',
                          onSelected: (_) => setState(() => _gstTaxType = 'CGST_SGST'),
                        ),
                        ChoiceChip(
                          label: const Text('SGST'),
                          selected: _gstTaxType == 'CGST_SGST',
                          onSelected: (_) => setState(() => _gstTaxType = 'CGST_SGST'),
                        ),
                        ChoiceChip(
                          label: const Text('IGST'),
                          selected: _gstTaxType == 'IGST',
                          onSelected: (_) => setState(() => _gstTaxType = 'IGST'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_gstTaxType == 'CGST_SGST')
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cgstRateCtrl,
                            decoration: InputDecoration(
                              labelText: 'CGST %',
                              border: const OutlineInputBorder(),
                              helperText: 'Amt: ${money.format(_cgstAmount)}',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            ],
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _sgstRateCtrl,
                            decoration: InputDecoration(
                              labelText: 'SGST %',
                              border: const OutlineInputBorder(),
                              helperText: 'Amt: ${money.format(_sgstAmount)}',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            ],
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    )
                  else
                    TextFormField(
                      controller: _igstRateCtrl,
                      decoration: InputDecoration(
                        labelText: 'IGST %',
                        border: const OutlineInputBorder(),
                        helperText: 'Amt: ${money.format(_igstAmount)}',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      onChanged: (_) => setState(() {}),
                    ),
                ],
                const SizedBox(height: 16),
                const Text('Freight', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _modeToggle(
                  label: 'Freight (Inclusive / Exclusive)',
                  value: _freightMode,
                  onChanged: (v) => setState(() => _freightMode = v),
                ),
                if (_freightMode == 'EXCLUSIVE') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _freightAmtCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Freight amount',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const SizedBox(height: 16),
                lookupDropdown(
                  context: context,
                  category: kPaymentTerms,
                  value: _paymentTerms,
                  label: 'Payment terms',
                  onChanged: (v) => setState(() => _paymentTerms = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _deliveryCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Delivery time (days)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _ratingCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Rating (optional)',
                          hintText: '0 – 5',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Subtotal: ${money.format(_subtotal)}'),
                      if (_gstMode == 'EXCLUSIVE' && _gstTaxType == 'CGST_SGST') ...[
                        Text('CGST: ${money.format(_cgstAmount)}'),
                        Text('SGST: ${money.format(_sgstAmount)}'),
                      ],
                      if (_gstMode == 'EXCLUSIVE' && _gstTaxType == 'IGST')
                        Text('IGST: ${money.format(_igstAmount)}'),
                      if (_freightMode == 'EXCLUSIVE')
                        Text('Freight: ${money.format(_freightAdd)}'),
                      const SizedBox(height: 4),
                      Text(
                        'Final amount: ${money.format(_finalAmount)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ],
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
