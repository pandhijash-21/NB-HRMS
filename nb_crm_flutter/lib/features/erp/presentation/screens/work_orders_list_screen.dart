import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/widgets/header_action_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/work_order_models.dart';
import '../work_order_providers.dart';
import '../widgets/work_order_info_dialogs.dart';

class WorkOrdersListScreen extends ConsumerWidget {
  const WorkOrdersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final canWrite = Permissions.canWriteWorkOrders(auth.permissions, auth.user?.role);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(workOrdersListProvider);
    final dateFmt = _formatDate;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        title: const Text('Work Orders', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: const AppBackButton(fallbackLocation: '/erp/home'),
        actions: [
          HeaderActionButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            label: 'Refresh',
            onPressed: () => ref.invalidate(workOrdersListProvider),
          ),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/erp/work-orders/new'),
              icon: const Icon(Icons.add),
              label: const Text('Add Work Order'),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No work orders yet.'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            child: Card(
              elevation: 0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFE8F4FC)),
                  columns: [
                    const DataColumn(label: Text('SR#')),
                    const DataColumn(label: Text('WORK ORDER ID')),
                    const DataColumn(label: Text('DATE')),
                    const DataColumn(label: Text('PROJECT')),
                    const DataColumn(label: Text('CONTRACTOR')),
                    const DataColumn(label: Text('TOTAL AMOUNT(₹)')),
                    const DataColumn(label: Text('WO OWNER')),
                    DataColumn(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('STATUS'),
                          IconButton(
                            icon: const Icon(Icons.info_outline, size: 18),
                            onPressed: () => showWorkOrderStatusInfo(context),
                          ),
                        ],
                      ),
                    ),
                    DataColumn(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('APPROVAL'),
                          IconButton(
                            icon: const Icon(Icons.info_outline, size: 18),
                            onPressed: () => showWorkOrderApprovalInfo(context),
                          ),
                        ],
                      ),
                    ),
                    const DataColumn(label: Text('ACTION')),
                  ],
                  rows: [
                    for (var i = 0; i < items.length; i++)
                      _row(context, items[i], i + 1, dateFmt),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  DataRow _row(BuildContext context, ErpWorkOrder wo, int sr, String Function(DateTime) fmt) {
    return DataRow(
      cells: [
        DataCell(Text('$sr')),
        DataCell(Text(wo.workOrderId)),
        DataCell(Text(fmt(wo.orderDate))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (wo.project?.imageUrl != null)
                CircleAvatar(
                  radius: 14,
                  backgroundImage: NetworkImage(wo.project!.imageUrl!),
                )
              else
                const CircleAvatar(radius: 14, child: Icon(Icons.apartment, size: 14)),
              const SizedBox(width: 8),
              Text(wo.project?.name ?? '—'),
            ],
          ),
        ),
        DataCell(Text(wo.contractor?.name ?? '—')),
        DataCell(Text(wo.totalAmount.toStringAsFixed(2))),
        DataCell(
          CircleAvatar(
            radius: 14,
            backgroundImage: wo.owner?.photoUrl != null ? NetworkImage(wo.owner!.photoUrl!) : null,
            child: wo.owner?.photoUrl == null ? const Icon(Icons.person, size: 14) : null,
          ),
        ),
        DataCell(WoStatusBadge(status: wo.status)),
        DataCell(WoApprovalBadge(approvalStatus: wo.approvalStatus)),
        DataCell(
          IconButton(
            icon: const Icon(Icons.visibility_outlined),
            onPressed: () => context.go('/erp/work-orders/${wo.id}'),
          ),
        ),
      ],
    );
  }
}

String _formatDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
}

