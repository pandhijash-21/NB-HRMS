import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/work_order_labels.dart';
import '../../domain/work_order_models.dart';
import '../work_order_providers.dart';
import '../widgets/work_order_info_dialogs.dart';

class WorkOrderDetailScreen extends ConsumerStatefulWidget {
  const WorkOrderDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<WorkOrderDetailScreen> createState() => _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState extends ConsumerState<WorkOrderDetailScreen> {
  bool _saving = false;

  Future<void> _setStatus(String status) async {
    setState(() => _saving = true);
    try {
      await ref.read(workOrderRepositoryProvider).updateStatus(widget.id, status);
      ref.invalidate(workOrderDetailProvider(widget.id));
      ref.invalidate(workOrdersListProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setApproval(String approval) async {
    setState(() => _saving = true);
    try {
      await ref.read(workOrderRepositoryProvider).updateApproval(widget.id, approval);
      ref.invalidate(workOrderDetailProvider(widget.id));
      ref.invalidate(workOrdersListProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final canWrite = Permissions.hasPermission(auth.permissions, 'WORK_ORDERS', 'WRITE');
    final canApprove = Permissions.hasPermission(auth.permissions, 'WORK_ORDERS', 'APPROVE');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(workOrderDetailProvider(widget.id));
    final dateFmt = _formatDate;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        title: const Text('Work Order', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: const AppBackButton(fallbackLocation: '/erp/work-orders'),
        actions: [
          if (canWrite)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.go('/erp/work-orders/${widget.id}/edit'),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (wo) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Basic Details', [
              _kv('Work Order ID', wo.workOrderId),
              _kv('Date', dateFmt.format(wo.orderDate)),
              if (wo.dueDate != null) _kv('Due Date', dateFmt.format(wo.dueDate!)),
              _kv('Project', wo.project?.name ?? '—'),
              _kv('Contractor', wo.contractor?.name ?? '—'),
              _kv('Total Amount', '₹ ${wo.totalAmount.toStringAsFixed(2)}'),
              _kv('WO Owner', wo.owner?.displayName ?? '—'),
              if (wo.tenderRef != null) _kv('Tender', wo.tenderRef!),
            ]),
            const SizedBox(height: 12),
            if (canWrite || canApprove)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Status & Approval', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      if (canWrite) ...[
                        Row(
                          children: [
                            const Text('Status: '),
                            WoStatusBadge(status: wo.status),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.info_outline, size: 18),
                              onPressed: () => showWorkOrderStatusInfo(context),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          children: WorkOrderLabels.statusOptions
                              .map(
                                (s) => ActionChip(
                                  label: Text(WorkOrderLabels.statusLabel(s)),
                                  onPressed: _saving || wo.status == s ? null : () => _setStatus(s),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (canApprove) ...[
                        Row(
                          children: [
                            const Text('Approval: '),
                            WoApprovalBadge(approvalStatus: wo.approvalStatus),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.info_outline, size: 18),
                              onPressed: () => showWorkOrderApprovalInfo(context),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          children: WorkOrderLabels.approvalOptions
                              .map(
                                (s) => ActionChip(
                                  label: Text(WorkOrderLabels.approvalLabel(s)),
                                  onPressed:
                                      _saving || wo.approvalStatus == s ? null : () => _setApproval(s),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _workDetailsSection(wo),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 140, child: Text(k, style: const TextStyle(color: Colors.grey))),
            Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );

  Widget _workDetailsSection(ErpWorkOrder wo) {
    if (wo.activities.isEmpty) {
      return _section('Work Details', [const Text('No work details added.')]);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Work Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('ACTIVITY')),
                  DataColumn(label: Text('WORK DETAIL')),
                  DataColumn(label: Text('BLOCK')),
                  DataColumn(label: Text('FLOOR')),
                  DataColumn(label: Text('UNIT')),
                  DataColumn(label: Text('QTY')),
                  DataColumn(label: Text('UNIT')),
                  DataColumn(label: Text('RATE')),
                  DataColumn(label: Text('AMOUNT')),
                ],
                rows: [
                  for (final g in wo.activities)
                    for (final line in g.lines)
                      DataRow(
                        cells: [
                          DataCell(Text(g.activityName)),
                          DataCell(Text(line.workDetail)),
                          DataCell(Text(
                            line.towerIds.isEmpty ? 'All Block' : '${line.towerIds.length} Block(s)',
                          )),
                          DataCell(Text(
                            line.floorNos.isEmpty ? 'All Floor' : line.floorNos.join(', '),
                          )),
                          DataCell(Text(
                            line.unitIds.isEmpty ? 'All Unit' : '${line.unitIds.length} Unit(s)',
                          )),
                          DataCell(Text(line.quantity?.toString() ?? '—')),
                          DataCell(Text(line.unitCode ?? '—')),
                          DataCell(Text(line.rate?.toStringAsFixed(2) ?? '—')),
                          DataCell(Text((line.amount ?? 0).toStringAsFixed(2))),
                        ],
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
}

