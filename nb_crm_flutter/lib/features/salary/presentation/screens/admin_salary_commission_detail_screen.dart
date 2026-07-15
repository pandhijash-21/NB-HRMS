import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/salary_models.dart';
import '../salary_providers.dart';
import '../widgets/salary_shared_widgets.dart';

class AdminSalaryCommissionDetailScreen extends ConsumerWidget {
  const AdminSalaryCommissionDetailScreen({super.key, required this.commissionId});

  final String commissionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final canWrite = Permissions.canWriteSalary(auth.permissions);
    final pcAsync = ref.watch(payCommissionProvider(commissionId));

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Commission Columns'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/salary/commissions'),
        ),
        actions: [
          if (canWrite)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddColumnDialog(context, ref, pcAsync.value),
            ),
        ],
      ),
      body: SalaryAsyncBody<PayCommission>(
        value: pcAsync,
        emptyMessage: 'Commission not found.',
        onRetry: () => ref.invalidate(payCommissionProvider(commissionId)),
        builder: (pc) {
          final earnings = pc.columnDefinitions
              .where((c) => c.category == SalaryColumnCategory.earning)
              .toList();
          final deductions = pc.columnDefinitions
              .where((c) => c.category == SalaryColumnCategory.deduction)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                pc.name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(pc.code)),
                  Chip(
                    label: Text(pc.ruleEditorEnabled ? 'Rule editor on' : 'Fixed amounts only'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                color: AppColors.mist,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Order controls calculation sequence — lower numbers run first. '
                    'Use gaps of 10 so you can insert columns without renumbering.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ColumnTable(
                title: 'Earnings',
                titleColor: AppColors.success,
                columns: earnings,
                canWrite: canWrite,
                onDelete: (col) => _deleteColumn(context, ref, col),
              ),
              const SizedBox(height: 16),
              _ColumnTable(
                title: 'Deductions',
                titleColor: AppColors.error,
                columns: deductions,
                canWrite: canWrite,
                onDelete: (col) => _deleteColumn(context, ref, col),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteColumn(
    BuildContext context,
    WidgetRef ref,
    PayCommissionColumn col,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove column?'),
        content: Text('Remove "${col.displayName}"? Rules using this column will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(salaryRepositoryProvider).deletePayCommissionColumn(col.id);
    invalidateSalaryCommission(ref, commissionId);
  }

  Future<void> _showAddColumnDialog(
    BuildContext context,
    WidgetRef ref,
    PayCommission? pc,
  ) async {
    final displayCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    final orderCtrl = TextEditingController(
      text: '${((pc?.columnDefinitions.length ?? 0) + 1) * 10}',
    );
    var category = SalaryColumnCategory.earning;
    var configurable = true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add salary column'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: displayCtrl,
                  decoration: const InputDecoration(labelText: 'Display name'),
                ),
                TextField(
                  controller: idCtrl,
                  decoration: const InputDecoration(labelText: 'Identifier (optional)'),
                ),
                DropdownButtonFormField<SalaryColumnCategory>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: SalaryColumnCategory.earning, child: Text('Earning')),
                    DropdownMenuItem(value: SalaryColumnCategory.deduction, child: Text('Deduction')),
                  ],
                  onChanged: (v) => setLocal(() => category = v ?? category),
                ),
                TextField(
                  controller: orderCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Order'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow rule configuration'),
                  value: configurable,
                  onChanged: (v) => setLocal(() => configurable = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final identifier = idCtrl.text.trim().isNotEmpty
                    ? idCtrl.text.trim()
                    : displayCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
                await ref.read(salaryRepositoryProvider).createPayCommissionColumn(
                  commissionId,
                  {
                    'columnIdentifier': identifier,
                    'displayName': displayCtrl.text.trim(),
                    'category': salaryColumnCategoryApi(category),
                    'evaluationOrder': int.tryParse(orderCtrl.text) ?? 100,
                    'isRuleConfigurable': configurable,
                  },
                );
                invalidateSalaryCommission(ref, commissionId);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColumnTable extends StatelessWidget {
  const _ColumnTable({
    required this.title,
    required this.titleColor,
    required this.columns,
    required this.canWrite,
    required this.onDelete,
  });

  final String title;
  final Color titleColor;
  final List<PayCommissionColumn> columns;
  final bool canWrite;
  final void Function(PayCommissionColumn col) onDelete;

  @override
  Widget build(BuildContext context) {
    return salarySectionCard(
      title: title,
      titleColor: titleColor,
      child: columns.isEmpty
          ? const Text('No columns yet.', style: TextStyle(color: AppColors.textSecondary))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Order')),
                  DataColumn(label: Text('Display name')),
                  DataColumn(label: Text('Identifier')),
                  DataColumn(label: Text('Configurable')),
                  DataColumn(label: Text('')),
                ],
                rows: columns
                    .map(
                      (col) => DataRow(cells: [
                        DataCell(Text('${col.evaluationOrder}')),
                        DataCell(Text(col.displayName)),
                        DataCell(Text(col.columnIdentifier, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                        DataCell(Text(col.isRuleConfigurable ? 'Yes' : 'Auto')),
                        DataCell(
                          canWrite
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                  onPressed: () => onDelete(col),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ]),
                    )
                    .toList(),
              ),
            ),
    );
  }
}
