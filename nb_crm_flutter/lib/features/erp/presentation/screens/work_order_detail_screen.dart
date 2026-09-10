import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/bloc/load_status.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/work_order_labels.dart';
import '../../domain/work_order_models.dart';
import '../bloc/erp_work_orders_bloc.dart';
import '../widgets/work_order_info_dialogs.dart';

class WorkOrderDetailScreen extends StatefulWidget {
  const WorkOrderDetailScreen({super.key, required this.id});

  final String id;

  @override
  State<WorkOrderDetailScreen> createState() => _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState extends State<WorkOrderDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ErpWorkOrdersBloc>().add(ErpWorkOrderDetailRequested(widget.id));
  }

  void _setStatus(String status) {
    context.read<ErpWorkOrdersBloc>().add(
          ErpWorkOrderStatusUpdated(id: widget.id, status: status),
        );
  }

  void _setApproval(String approval) {
    context.read<ErpWorkOrdersBloc>().add(
          ErpWorkOrderApprovalUpdated(id: widget.id, approvalStatus: approval),
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final canWrite = Permissions.canWriteWorkOrders(auth.permissions, auth.user?.role);
    final canApprove = Permissions.canApproveWorkOrders(auth.permissions, auth.user?.role);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const dateFmt = _formatDate;

    return BlocConsumer<ErpWorkOrdersBloc, ErpWorkOrdersState>(
      listener: (context, state) {
        if (state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.actionMessage!)),
          );
        } else if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
      },
      builder: (context, state) {
        final wo = state.selectedWorkOrder;
        final isSaving = state.isActing;

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
          body: () {
            if (state.status == LoadStatus.loading && wo == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (wo == null) {
              return Center(child: Text(state.errorMessage ?? 'Work order not found.'));
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('Basic Details', [
                  _kv('Work Order ID', wo.workOrderId),
                  _kv('Date', dateFmt(wo.orderDate)),
                  if (wo.dueDate != null) _kv('Due Date', dateFmt(wo.dueDate!)),
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
                                      onPressed: isSaving || wo.status == s ? null : () => _setStatus(s),
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
                                          isSaving || wo.approvalStatus == s ? null : () => _setApproval(s),
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
            );
          }(),
        );
      },
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

