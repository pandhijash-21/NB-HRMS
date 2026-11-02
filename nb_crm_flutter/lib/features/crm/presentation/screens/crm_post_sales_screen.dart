import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/widgets/mobile_input_formatter.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/crm_repository.dart';
import '../../domain/crm_models.dart';
import '../widgets/crm_scope_selector.dart';

class CrmPostSalesScreen extends StatefulWidget {
  const CrmPostSalesScreen({super.key});

  @override
  State<CrmPostSalesScreen> createState() => _CrmPostSalesScreenState();
}

class _CrmPostSalesScreenState extends State<CrmPostSalesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<CrmLead> _bookings = [];
  bool _loading = true;
  String? _error;
  CrmLead? _selected;

  @override
  void initState() {
    super.initState();
    CrmRepository.crmScopeNotifier.addListener(_onScopeChanged);
    _load();
  }

  @override
  void dispose() {
    CrmRepository.crmScopeNotifier.removeListener(_onScopeChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onScopeChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<CrmRepository>();
      final leads = await repo.getLeads(status: 'BOOKING_CONFIRMED', limit: 500);
      if (!mounted) return;
      setState(() {
        _bookings = leads;
        _loading = false;
        if (_selected != null) {
          _selected = leads.where((l) => l.id == _selected!.id).firstOrNull ?? _selected;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<CrmLead> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _bookings;
    return _bookings.where((l) {
      final snap = l.customFields['bookedProposalSnapshot'];
      final unit = snap is Map ? (snap['unitNo']?.toString() ?? '') : '';
      final project = snap is Map ? (snap['projectName']?.toString() ?? '') : '';
      return l.name.toLowerCase().contains(q) ||
          l.phone.contains(q) ||
          unit.toLowerCase().contains(q) ||
          project.toLowerCase().contains(q) ||
          (l.assignedToName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final borderColor = isDark ? const Color(0xFF3E3830) : const Color(0xFFE2E8F0);
    final textMuted = isDark ? const Color(0xFFB3ADA0) : const Color(0xFF64748B);
    const primary = Color(0xFF16A34A);
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final canWrite = Permissions.canWriteCrmPostSales(
      context.watch<AuthBloc>().state.permissions,
      context.watch<AuthBloc>().state.user?.role,
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141210) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Post-Sales · Bookings & Ledger'),
        leading: const AppBackButton(fallbackLocation: '/crm/dashboard'),
        actions: [
          const CrmScopeSelectorWidget(),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 380,
                              child: _buildList(cardBg, borderColor, textMuted, primary),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _selected == null
                                  ? _emptyDetail(cardBg, borderColor, textMuted)
                                  : _BookingDetailPanel(
                                      lead: _selected!,
                                      canWrite: canWrite,
                                      cardBg: cardBg,
                                      borderColor: borderColor,
                                      textMuted: textMuted,
                                      onChanged: () async {
                                        await _load();
                                      },
                                    ),
                            ),
                          ],
                        )
                      : _selected == null
                          ? _buildList(cardBg, borderColor, textMuted, primary)
                          : Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    icon: const Icon(Icons.arrow_back),
                                    label: const Text('Back to list'),
                                    onPressed: () => setState(() => _selected = null),
                                  ),
                                ),
                                Expanded(
                                  child: _BookingDetailPanel(
                                    lead: _selected!,
                                    canWrite: canWrite,
                                    cardBg: cardBg,
                                    borderColor: borderColor,
                                    textMuted: textMuted,
                                    onChanged: () async {
                                      await _load();
                                    },
                                  ),
                                ),
                              ],
                            ),
                ),
    );
  }

  Widget _emptyDetail(Color cardBg, Color borderColor, Color textMuted) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Center(
        child: Text(
          'Select a finalized booking to view quotation, payment plan, reminders & ledger.',
          style: TextStyle(color: textMuted),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildList(Color cardBg, Color borderColor, Color textMuted, Color primary) {
    final items = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search name, phone, unit, project…',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
            filled: true,
            fillColor: cardBg,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${items.length} finalized booking${items.length == 1 ? '' : 's'}',
          style: TextStyle(fontSize: 12, color: textMuted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: items.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Text(
                      'No BOOKING_CONFIRMED deals yet.\nFinalize a quotation with payment terms in Sales.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textMuted),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final lead = items[i];
                    final selected = _selected?.id == lead.id;
                    final snap = lead.customFields['bookedProposalSnapshot'];
                    final unit = snap is Map ? snap['unitNo']?.toString() : null;
                    final project = snap is Map ? snap['projectName']?.toString() : null;
                    final term = lead.customFields['selectedPaymentTermName']?.toString();
                    final dueSoon = _nextDueLabel(lead);
                    return Material(
                      color: selected ? primary.withValues(alpha: 0.08) : cardBg,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _selected = lead),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? primary : borderColor,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lead.name.isNotEmpty ? lead.name : 'Unnamed',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayCrmPhone(lead.phone, showFull: true),
                                style: TextStyle(fontSize: 12, color: textMuted),
                              ),
                              if (unit != null || project != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  [if (project != null) project, if (unit != null) 'Unit $unit']
                                      .join(' · '),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                              if (term != null && term.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('Plan: $term', style: TextStyle(fontSize: 11, color: textMuted)),
                              ],
                              if (dueSoon != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    dueSoon,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFC2410C),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                'Sales: ${lead.assignedToName ?? '—'} · TC: ${lead.telecallerName ?? '—'}',
                                style: TextStyle(fontSize: 11, color: textMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String? _nextDueLabel(CrmLead lead) {
    final schedule = lead.customFields['paymentSchedule'];
    if (schedule is! List) return null;
    final today = DateTime.now();
    final todayYmd =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    for (final raw in schedule) {
      if (raw is! Map) continue;
      final status = (raw['status']?.toString() ?? 'PENDING').toUpperCase();
      if (status == 'PAID') continue;
      final due = raw['dueDate']?.toString().slice0(10);
      if (due == null || due.isEmpty) continue;
      if (due == todayYmd) return 'Due today: ${raw['name']}';
      final dueDt = DateTime.tryParse(due);
      if (dueDt != null) {
        final diff = DateTime(dueDt.year, dueDt.month, dueDt.day)
            .difference(DateTime(today.year, today.month, today.day))
            .inDays;
        if (diff == 1) return 'Due tomorrow: ${raw['name']}';
        if (diff < 0) return 'Overdue: ${raw['name']}';
      }
    }
    return null;
  }
}

extension on String {
  String slice0(int end) => length <= end ? this : substring(0, end);
}

class _BookingDetailPanel extends StatefulWidget {
  const _BookingDetailPanel({
    required this.lead,
    required this.canWrite,
    required this.cardBg,
    required this.borderColor,
    required this.textMuted,
    required this.onChanged,
  });

  final CrmLead lead;
  final bool canWrite;
  final Color cardBg;
  final Color borderColor;
  final Color textMuted;
  final Future<void> Function() onChanged;

  @override
  State<_BookingDetailPanel> createState() => _BookingDetailPanelState();
}

class _BookingDetailPanelState extends State<_BookingDetailPanel> {
  final _currency = NumberFormat('#,##,###.##');

  Map<String, dynamic>? get _snap {
    final s = widget.lead.customFields['bookedProposalSnapshot'];
    return s is Map ? Map<String, dynamic>.from(s) : null;
  }

  List<Map<String, dynamic>> get _schedule {
    final raw = widget.lead.customFields['paymentSchedule'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  List<Map<String, dynamic>> get _ledger {
    final raw = widget.lead.customFields['paymentLedger'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  double get _grandTotal {
    final g = _snap?['grandTotal'];
    if (g is num) return g.toDouble();
    return _schedule.fold<double>(0, (s, r) => s + ((r['amount'] as num?)?.toDouble() ?? 0));
  }

  double get _collected =>
      _ledger.fold<double>(0, (s, r) => s + ((r['amount'] as num?)?.toDouble() ?? 0));

  @override
  Widget build(BuildContext context) {
    final snap = _snap;
    final termName = widget.lead.customFields['selectedPaymentTermName']?.toString() ?? '—';
    final bookingAt = widget.lead.customFields['bookingConfirmedAt']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.borderColor),
      ),
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.lead.name.isNotEmpty ? widget.lead.name : 'Client',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              if (widget.canWrite)
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_card_rounded, size: 18),
                  label: const Text('Record Payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _schedule.isEmpty ? null : () => _showRecordPayment(),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${displayCrmPhone(widget.lead.phone, showFull: true)} · Telecaller: ${widget.lead.telecallerName ?? '—'} · Sales: ${widget.lead.assignedToName ?? '—'}',
            style: TextStyle(fontSize: 13, color: widget.textMuted),
          ),
          if (bookingAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Finalized: ${DateTime.tryParse(bookingAt)?.toLocal().toString().split('.').first ?? bookingAt}',
              style: TextStyle(fontSize: 12, color: widget.textMuted),
            ),
          ],
          const SizedBox(height: 16),
          _sectionTitle('Final Deal / Quotation'),
          const SizedBox(height: 8),
          _infoGrid([
            ('Project', snap?['projectName']?.toString() ?? '—'),
            ('Tower', snap?['towerName']?.toString() ?? '—'),
            ('Unit', snap?['unitNo']?.toString() ?? '—'),
            ('Type', snap?['unitType']?.toString() ?? '—'),
            ('Carpet', '${snap?['carpetArea'] ?? '—'} ${snap?['areaUnit'] ?? ''}'),
            ('Payment Plan', termName),
            ('Grand Total', '₹ ${_currency.format(_grandTotal)}'),
            ('Collected', '₹ ${_currency.format(_collected)}'),
            ('Balance', '₹ ${_currency.format((_grandTotal - _collected).clamp(0, double.infinity))}'),
          ]),
          const SizedBox(height: 20),
          _sectionTitle('Payment Plan & Due Dates'),
          const SizedBox(height: 8),
          if (_schedule.isEmpty)
            Text('No payment schedule on this booking.', style: TextStyle(color: widget.textMuted))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 48,
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Installment')),
                  DataColumn(label: Text('%')),
                  DataColumn(label: Text('Due')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Paid')),
                  DataColumn(label: Text('Balance')),
                  DataColumn(label: Text('Status')),
                ],
                rows: _schedule.map((r) {
                  final status = (r['status']?.toString() ?? 'PENDING').toUpperCase();
                  return DataRow(cells: [
                    DataCell(Text('${r['seq'] ?? ''}')),
                    DataCell(Text(r['name']?.toString() ?? '')),
                    DataCell(Text('${r['percentage'] ?? ''}%')),
                    DataCell(Text(r['dueDate']?.toString() ?? r['timing']?.toString() ?? '')),
                    DataCell(Text('₹ ${_currency.format((r['amount'] as num?)?.toDouble() ?? 0)}')),
                    DataCell(Text('₹ ${_currency.format((r['paidAmount'] as num?)?.toDouble() ?? 0)}')),
                    DataCell(Text('₹ ${_currency.format((r['balance'] as num?)?.toDouble() ?? ((r['amount'] as num?)?.toDouble() ?? 0))}')),
                    DataCell(Text(status, style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: status == 'PAID'
                          ? const Color(0xFF16A34A)
                          : status == 'PARTIAL'
                              ? const Color(0xFFD97706)
                              : const Color(0xFFDC2626),
                    ))),
                  ]);
                }).toList(),
              ),
            ),
          const SizedBox(height: 22),
          _sectionTitle('Payment Ledger'),
          const SizedBox(height: 4),
          Text(
            'Running book for this booking — each collection against an installment.',
            style: TextStyle(fontSize: 12, color: widget.textMuted),
          ),
          const SizedBox(height: 8),
          if (_ledger.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: widget.borderColor),
              ),
              child: Text('No collections yet. Record the first payment to start the ledger.', style: TextStyle(color: widget.textMuted)),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 56,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Against')),
                  DataColumn(label: Text('Mode')),
                  DataColumn(label: Text('Reference')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Balance After')),
                  DataColumn(label: Text('By')),
                  DataColumn(label: Text('Proof')),
                ],
                rows: _ledger.reversed.map((e) {
                  final paidAt = e['paidAt']?.toString() ?? e['recordedAt']?.toString() ?? '';
                  final proof = e['proofUrl']?.toString();
                  return DataRow(cells: [
                    DataCell(Text(paidAt.length > 16 ? paidAt.substring(0, 16).replaceFirst('T', ' ') : paidAt)),
                    DataCell(Text(e['installmentName']?.toString() ?? '#${e['installmentSeq']}')),
                    DataCell(Text(e['mode']?.toString() ?? '')),
                    DataCell(Text(e['reference']?.toString().isNotEmpty == true ? e['reference'].toString() : '—')),
                    DataCell(Text('₹ ${_currency.format((e['amount'] as num?)?.toDouble() ?? 0)}', style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text('₹ ${_currency.format((e['runningBalanceAfter'] as num?)?.toDouble() ?? 0)}')),
                    DataCell(Text(e['recordedByName']?.toString() ?? '—')),
                    DataCell(
                      proof != null && proof.isNotEmpty
                          ? const Icon(Icons.attach_file, size: 16, color: Color(0xFF2563EB))
                          : const Text('—'),
                    ),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
        t,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F766E)),
      );

  Widget _infoGrid(List<(String, String)> rows) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: rows
          .map(
            (r) => SizedBox(
              width: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.$1, style: TextStyle(fontSize: 11, color: widget.textMuted)),
                  Text(r.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _showRecordPayment() async {
    final pending = _schedule.where((r) => (r['status']?.toString() ?? '').toUpperCase() != 'PAID').toList();
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All installments are already paid.')),
      );
      return;
    }

    var selectedSeq = (pending.first['seq'] as num?)?.toInt() ?? 1;
    final amountCtrl = TextEditingController(
      text: ((pending.first['balance'] as num?)?.toDouble() ?? (pending.first['amount'] as num?)?.toDouble() ?? 0)
          .toStringAsFixed(2),
    );
    var mode = 'UPI';
    final refCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? proofUrl;
    String? proofName;
    var uploading = false;

    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          Map<String, dynamic> current() =>
              pending.firstWhere((r) => (r['seq'] as num?)?.toInt() == selectedSeq, orElse: () => pending.first);

          String refLabel() {
            switch (mode) {
              case 'CHEQUE':
                return 'Cheque number';
              case 'DD':
                return 'DD number';
              case 'CASH':
                return 'Cash receipt / note (optional)';
              case 'UPI':
                return 'UPI / UTR reference';
              case 'NEFT':
              case 'RTGS':
                return 'Bank reference / UTR';
              default:
                return 'Reference number';
            }
          }

          return AlertDialog(
            title: const Text('Record Payment (Ledger)'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Client: ${widget.lead.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedSeq,
                      decoration: const InputDecoration(
                        labelText: 'Against installment *',
                        border: OutlineInputBorder(),
                      ),
                      items: pending
                          .map(
                            (r) => DropdownMenuItem(
                              value: (r['seq'] as num?)?.toInt() ?? 0,
                              child: Text(
                                '#${r['seq']} ${r['name']} — bal ₹ ${_currency.format((r['balance'] as num?)?.toDouble() ?? (r['amount'] as num?)?.toDouble() ?? 0)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setDlg(() {
                          selectedSeq = v;
                          final bal = (current()['balance'] as num?)?.toDouble() ??
                              (current()['amount'] as num?)?.toDouble() ??
                              0;
                          amountCtrl.text = bal.toStringAsFixed(2);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      decoration: const InputDecoration(
                        labelText: 'Amount received *',
                        border: OutlineInputBorder(),
                        prefixText: '₹ ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: mode,
                      decoration: const InputDecoration(
                        labelText: 'Payment mode *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                        DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                        DropdownMenuItem(value: 'DD', child: Text('Demand Draft (DD)')),
                        DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                        DropdownMenuItem(value: 'NEFT', child: Text('NEFT')),
                        DropdownMenuItem(value: 'RTGS', child: Text('RTGS')),
                        DropdownMenuItem(value: 'CARD', child: Text('Card')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                      ],
                      onChanged: (v) => setDlg(() => mode = v ?? mode),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: refCtrl,
                      decoration: InputDecoration(
                        labelText: refLabel(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_rounded),
                      label: Text(proofName ?? 'Upload payment proof'),
                      onPressed: uploading
                          ? null
                          : () async {
                              final picked = await FilePicker.pickFiles(withData: true);
                              if (picked == null || picked.files.isEmpty) return;
                              final f = picked.files.first;
                              if (f.bytes == null) return;
                              setDlg(() => uploading = true);
                              try {
                                final res = await context.read<CrmRepository>().uploadLeadDoc(
                                      widget.lead.id,
                                      docTypeId: 'payment_proof',
                                      docName: 'Payment Proof — ${current()['name']}',
                                      bytes: f.bytes!,
                                      filename: f.name,
                                    );
                                final doc = res['document'];
                                setDlg(() {
                                  proofUrl = doc is Map ? doc['fileUrl']?.toString() : null;
                                  proofName = f.name;
                                  uploading = false;
                                });
                              } catch (e) {
                                setDlg(() => uploading = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Proof upload failed: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                  if (amt <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a valid amount'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  if ((mode == 'CHEQUE' || mode == 'DD') && refCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${mode == 'CHEQUE' ? 'Cheque' : 'DD'} number is required'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  try {
                    await context.read<CrmRepository>().recordPaymentEntry(
                          widget.lead.id,
                          installmentSeq: selectedSeq,
                          amount: amt,
                          mode: mode,
                          reference: refCtrl.text.trim(),
                          note: noteCtrl.text.trim(),
                          proofUrl: proofUrl,
                          proofFileName: proofName,
                        );
                    if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                    await widget.onChanged();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Payment recorded in ledger'),
                          backgroundColor: Color(0xFF16A34A),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: const Text('Post to Ledger'),
              ),
            ],
          );
        },
      ),
    );
  }
}
