import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/bloc/load_status.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../../core/utils/open_url.dart';
import '../../data/dpr_repository.dart';
import '../../domain/dpr_models.dart';
import '../bloc/erp_dpr_bloc.dart';

/// Trade columns matching the legacy September DPR Excel layout.
const _manpowerTrades = <String>[
  'Mason',
  'Labour',
  'Reinforcement',
  'Threading',
  'Shuttering',
  'Carpenter',
  'Plumber',
  'Polish',
  'Flooring',
  'Helper',
  'Fabrication',
  'Gypsum plaster',
  'Painter',
  'Water Proofing',
  'Electrician',
  'Aluminium',
];

final _tradeAliases = <RegExp, String>{
  RegExp(r'mason|mistry|brick', caseSensitive: false): 'Mason',
  RegExp(r'reinforc|steel\s*bind|re[- ]?bar|bar\s*bend|steel', caseSensitive: false):
      'Reinforcement',
  RegExp(r'thread', caseSensitive: false): 'Threading',
  RegExp(r'shutter|form\s*work|centering', caseSensitive: false): 'Shuttering',
  RegExp(r'carpent|furniture', caseSensitive: false): 'Carpenter',
  RegExp(r'plumb|pipe\s*fit', caseSensitive: false): 'Plumber',
  RegExp(r'polish', caseSensitive: false): 'Polish',
  RegExp(r'floor|tiling|tile', caseSensitive: false): 'Flooring',
  RegExp(r'helper|unskilled|naka', caseSensitive: false): 'Helper',
  RegExp(r'fabricat|welding', caseSensitive: false): 'Fabrication',
  RegExp(r'gypsum|ceiling|false\s*ceil', caseSensitive: false): 'Gypsum plaster',
  RegExp(r'paint|colour|color', caseSensitive: false): 'Painter',
  RegExp(r'water\s*proof|waterproof', caseSensitive: false): 'Water Proofing',
  RegExp(r'electric|wiring', caseSensitive: false): 'Electrician',
  RegExp(r'alumini|alu[- ]?work|glazing', caseSensitive: false): 'Aluminium',
  RegExp(r'labour|labor|skilled|manpower|worker', caseSensitive: false): 'Labour',
};

String _mapLabourTrade(String name) {
  final n = name.trim();
  if (n.isEmpty) return 'Labour';
  for (final e in _tradeAliases.entries) {
    if (e.key.hasMatch(n)) return e.value;
  }
  return 'Labour';
}

class DprDetailScreen extends StatelessWidget {
  const DprDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ErpDprBloc(dprRepository: ctx.read<DprRepository>())
        ..add(ErpDprDetailRequested(id)),
      child: _DprDetailView(id: id),
    );
  }
}

class _DprDetailView extends StatefulWidget {
  const _DprDetailView({required this.id});

  final String id;

  @override
  State<_DprDetailView> createState() => _DprDetailViewState();
}

class _DprDetailViewState extends State<_DprDetailView> {
  bool _exporting = false;

  Future<void> _exportExcel(ErpDpr dpr) async {
    setState(() => _exporting = true);
    try {
      final bytes = await context.read<DprRepository>().exportExcel(dpr.id);
      if (!mounted) return;
      final tag = DateFormat('yyyyMMdd').format(dpr.reportDate.toLocal());
      final project = (dpr.project?.name ?? 'Project')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final name = 'DPR_${project}_${tag}_${dpr.dprNo}.xlsx';
      await downloadBytes(
        bytes,
        name,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded $name'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ErpDprBloc>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dpr = state.selectedDpr;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(dpr == null ? 'DPR Detail' : 'Daily Report · ${dpr.dprNo}'),
        leading: const AppBackButton(fallbackLocation: '/erp/dpr'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<ErpDprBloc>().add(ErpDprDetailRequested(widget.id)),
          ),
          if (dpr != null)
            IconButton(
              tooltip: 'Download Excel (site DPR format)',
              onPressed: _exporting ? null : () => _exportExcel(dpr),
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
            ),
        ],
      ),
      floatingActionButton: dpr == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _exporting ? null : () => _exportExcel(dpr),
              icon: const Icon(Icons.print_outlined),
              label: Text(_exporting ? 'Preparing…' : 'Print / Excel'),
            ),
      body: Builder(
        builder: (context) {
          if (state.status == LoadStatus.loading && dpr == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == LoadStatus.failure && dpr == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.errorMessage ?? 'Failed to load DPR details'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => context
                        .read<ErpDprBloc>()
                        .add(ErpDprDetailRequested(widget.id)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (dpr == null) {
            return const Center(child: Text('DPR not found'));
          }
          return _DprReportPreview(dpr: dpr);
        },
      ),
    );
  }
}

class _DprReportPreview extends StatelessWidget {
  const _DprReportPreview({required this.dpr});

  final ErpDpr dpr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('dd MMM yyyy');
    final projectName = dpr.project?.name ?? 'Project';

    final lineTrades = <Map<String, double>>[];
    final totals = {for (final t in _manpowerTrades) t: 0.0};

    for (final line in dpr.lines) {
      final trades = {for (final t in _manpowerTrades) t: 0.0};
      for (final lb in line.labour) {
        if (lb.consumedQty <= 0) continue;
        final trade = _mapLabourTrade(lb.name);
        trades[trade] = (trades[trade] ?? 0) + lb.consumedQty;
        totals[trade] = (totals[trade] ?? 0) + lb.consumedQty;
      }
      lineTrades.add(trades);
    }

    final staff = (dpr.createdByName != null && dpr.createdByName!.trim().isNotEmpty) ? 1.0 : 0.0;
    final totalManpower =
        totals.values.fold<double>(0, (s, n) => s + n) + staff;

    // Material consumption = DPR-logged usage only (Store inward stays in Material Report)
    final mats = <String, _AggMat>{};
    final macs = <String, _AggMac>{};
    for (final line in dpr.lines) {
      for (final m in line.materials) {
        final key = m.itemName.trim().toLowerCase();
        if (key.isEmpty) continue;
        final existing = mats[key];
        final desc = [m.brand, m.size].whereType<String>().where((s) => s.isNotEmpty).join(' / ');
        if (existing == null) {
          mats[key] = _AggMat(
            name: m.itemName,
            description: desc,
            unit: m.unitCode ?? '',
            consumed: m.consumedQty,
            remarks: m.remarks ?? '',
          );
        } else {
          existing.consumed += m.consumedQty;
          if (existing.description.isEmpty && desc.isNotEmpty) existing.description = desc;
          if (existing.unit.isEmpty && (m.unitCode ?? '').isNotEmpty) {
            existing.unit = m.unitCode!;
          }
        }
      }
      for (final m in line.machines) {
        final key = m.itemName.trim().toLowerCase();
        if (key.isEmpty) continue;
        final existing = macs[key];
        if (existing == null) {
          macs[key] = _AggMac(
            name: m.itemName,
            unit: m.unitCode ?? 'Hour',
            hours: m.consumedQty,
            remarks: [m.brand, m.size, m.remarks]
                .whereType<String>()
                .where((s) => s.isNotEmpty)
                .join(' / '),
          );
        } else {
          existing.hours += m.consumedQty;
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  projectName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'DAILY REPORT',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${df.format(dpr.reportDate.toLocal())}  ·  ${dpr.dprNo}'
                  '${dpr.createdByName != null ? '  ·  By ${dpr.createdByName}' : ''}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _sectionTitle(context, 'Work & Manpower'),
        const SizedBox(height: 8),
        _scrollTable(
          context,
          minWidth: 1100,
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 40,
            dataRowMaxHeight: 120,
            columnSpacing: 10,
            columns: [
              const DataColumn(label: Text('Block No.')),
              const DataColumn(label: Text('Contractor')),
              const DataColumn(label: Text('Activity')),
              const DataColumn(label: Text('Work Detail')),
              for (final t in _manpowerTrades)
                DataColumn(label: Text(t, style: const TextStyle(fontSize: 11))),
            ],
            rows: [
              for (var i = 0; i < dpr.lines.length; i++)
                DataRow(
                  cells: [
                    DataCell(Text(_blockLabel(dpr.lines[i]))),
                    DataCell(Text(dpr.lines[i].contractorName ?? '—')),
                    DataCell(Text(dpr.lines[i].activityName ?? '—')),
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Text(
                          _workDetail(dpr.lines[i]),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    for (final t in _manpowerTrades)
                      DataCell(Text(_qtyCell(lineTrades[i][t] ?? 0))),
                  ],
                ),
              DataRow(
                color: WidgetStatePropertyAll(
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                ),
                cells: [
                  DataCell(
                    Text(
                      '${projectName.toUpperCase()} STAFF',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const DataCell(Text('')),
                  DataCell(Text(staff > 0 ? staff.toStringAsFixed(0) : '')),
                  DataCell(
                    Text(
                      'Total Manpower  $totalManpower',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  for (final t in _manpowerTrades)
                    DataCell(
                      Text(
                        _qtyCell(totals[t] ?? 0),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle(context, 'Material Consumption'),
        const SizedBox(height: 8),
        _scrollTable(
          context,
          minWidth: 720,
          child: DataTable(
            headingRowHeight: 40,
            columns: const [
              DataColumn(label: Text('Material')),
              DataColumn(label: Text('Description')),
              DataColumn(label: Text('Opening')),
              DataColumn(label: Text('Receive')),
              DataColumn(label: Text('Daily Consumption'), numeric: true),
              DataColumn(label: Text('Closing')),
              DataColumn(label: Text('Unit')),
              DataColumn(label: Text('Remarks')),
            ],
            rows: mats.isEmpty
                ? [
                    const DataRow(
                      cells: [
                        DataCell(Text('—')),
                        DataCell(Text('No materials logged on this DPR')),
                        DataCell(Text('')),
                        DataCell(Text('')),
                        DataCell(Text('')),
                        DataCell(Text('')),
                        DataCell(Text('')),
                        DataCell(Text('')),
                      ],
                    ),
                  ]
                : [
                    for (final m in mats.values)
                      DataRow(
                        cells: [
                          DataCell(Text(m.name)),
                          DataCell(Text(m.description)),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          DataCell(Text(_qtyCell(m.consumed))),
                          const DataCell(Text('')),
                          DataCell(Text(m.unit)),
                          DataCell(Text(m.remarks)),
                        ],
                      ),
                  ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle(
          context,
          'Material Report (Store inwards / challans)'
          '${dpr.materialReport.inwardCount > 0 ? ' · ${dpr.materialReport.inwardCount} GRN(s)' : ''}',
        ),
        const SizedBox(height: 8),
        _scrollTable(
          context,
          minWidth: 900,
          child: DataTable(
            headingRowHeight: 40,
            columns: const [
              DataColumn(label: Text('Sr')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Site')),
              DataColumn(label: Text('Supplier')),
              DataColumn(label: Text('Challan')),
              DataColumn(label: Text('Material')),
              DataColumn(label: Text('Detail / Grade')),
              DataColumn(label: Text('Vehicle')),
              DataColumn(label: Text('Time')),
              DataColumn(label: Text('Qty'), numeric: true),
              DataColumn(label: Text('Unit')),
            ],
            rows: dpr.materialReport.rows.isEmpty
                ? const [
                    DataRow(
                      cells: [
                        DataCell(Text('—')),
                        DataCell(Text('')),
                        DataCell(Text('')),
                        DataCell(Text('No store inwards for this project on this date')),
                        DataCell(Text('')),
                        DataCell(Text('')),
                        DataCell(Text('')),
                        DataCell(Text('')),
                        DataCell(Text('')),
                        DataCell(Text('')),
                        DataCell(Text('')),
                      ],
                    ),
                  ]
                : [
                    for (final r in dpr.materialReport.rows)
                      DataRow(
                        cells: [
                          DataCell(Text('${r.srNo}')),
                          DataCell(Text(r.date)),
                          DataCell(Text(r.site)),
                          DataCell(Text(r.supplierName)),
                          DataCell(Text(r.challanNumber ?? '—')),
                          DataCell(Text(r.material)),
                          DataCell(Text(r.detailGrade ?? '')),
                          DataCell(Text(r.vehicleNo ?? '')),
                          DataCell(Text(r.time ?? '')),
                          DataCell(Text(_qtyCell(r.qtyAccepted > 0 ? r.qtyAccepted : r.qtyReceived))),
                          DataCell(Text(r.unitCode ?? '')),
                        ],
                      ),
                  ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle(context, 'Machinery'),
        const SizedBox(height: 8),
        _scrollTable(
          context,
          minWidth: 520,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Machine')),
              DataColumn(label: Text('Detail')),
              DataColumn(label: Text('Hours / Qty'), numeric: true),
              DataColumn(label: Text('Unit')),
            ],
            rows: macs.isEmpty
                ? const [
                    DataRow(
                      cells: [
                        DataCell(Text('—')),
                        DataCell(Text('No machinery logged')),
                        DataCell(Text('')),
                        DataCell(Text('Hour')),
                      ],
                    ),
                  ]
                : [
                    for (final m in macs.values)
                      DataRow(
                        cells: [
                          DataCell(Text(m.name)),
                          DataCell(Text(m.remarks)),
                          DataCell(Text(_qtyCell(m.hours))),
                          DataCell(Text(m.unit)),
                        ],
                      ),
                  ],
          ),
        ),
        if ((dpr.remarks ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionTitle(context, 'Remarks'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(dpr.remarks!),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _signLine(context, 'STORE INCHARGE')),
            const SizedBox(width: 16),
            Expanded(child: _signLine(context, 'ENGINEER (E)')),
            const SizedBox(width: 16),
            Expanded(child: _signLine(context, 'ENGINEER (E)')),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Open Print / Excel to download the site Daily Report workbook '
          '(same layout as September DPR).',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  static Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
    );
  }

  static Widget _scrollTable(BuildContext context, {required double minWidth, required Widget child}) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minWidth),
          child: child,
        ),
      ),
    );
  }

  static Widget _signLine(BuildContext context, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 28),
        const Divider(thickness: 1),
      ],
    );
  }

  static String _blockLabel(ErpDprLine line) {
    final parts = <String>[
      if ((line.towerName ?? '').isNotEmpty) line.towerName!,
      if (line.floorNo != null) 'Floor ${line.floorNo}',
      if ((line.unitLabel ?? '').isNotEmpty) line.unitLabel!,
    ];
    return parts.isEmpty ? 'Site' : parts.join(' / ');
  }

  static String _workDetail(ErpDprLine line) {
    final bits = <String>[
      if ((line.taskName ?? '').isNotEmpty) line.taskName!,
      if ((line.remarks ?? '').isNotEmpty) line.remarks!,
      'Qty ${line.consumedQty}${line.unitCode != null ? ' ${line.unitCode}' : ''}',
      if (line.completionPct != null) 'Completion ${line.completionPct}%',
      if ((line.gradeCode ?? '').isNotEmpty) 'Grade ${line.gradeCode}',
      if ((line.statusCode ?? '').isNotEmpty) line.statusCode!,
    ];
    return bits.join('\n');
  }

  static String _qtyCell(double n) {
    if (n == 0) return '';
    if (n == n.roundToDouble()) return n.toStringAsFixed(0);
    return n.toStringAsFixed(2);
  }
}

class _AggMat {
  _AggMat({
    required this.name,
    required this.description,
    required this.unit,
    required this.consumed,
    required this.remarks,
  });
  final String name;
  String description;
  String unit;
  double consumed;
  String remarks;
}

class _AggMac {
  _AggMac({
    required this.name,
    required this.unit,
    required this.hours,
    required this.remarks,
  });
  final String name;
  final String unit;
  double hours;
  final String remarks;
}
