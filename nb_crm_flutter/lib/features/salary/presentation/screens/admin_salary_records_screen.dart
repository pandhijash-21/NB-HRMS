import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/salary_models.dart';
import '../salary_providers.dart';
import '../widgets/salary_shared_widgets.dart';

class AdminSalaryRecordsScreen extends ConsumerWidget {
  const AdminSalaryRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(salaryRecordsFilterProvider);
    final recordsAsync = ref.watch(salaryRecordsProvider);

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Salary Records'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            tooltip: 'Salary entry',
            icon: const Icon(Icons.edit_note),
            onPressed: () => context.go('/admin/salary/entry'),
          ),
          IconButton(
            tooltip: 'Structures',
            icon: const Icon(Icons.account_tree_outlined),
            onPressed: () => context.go('/admin/salary/structures'),
          ),
          IconButton(
            tooltip: 'Commissions',
            icon: const Icon(Icons.layers_outlined),
            onPressed: () => context.go('/admin/salary/commissions'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Employee ID',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => ref
                        .read(salaryRecordsFilterProvider.notifier)
                        .setEmployeeId(int.tryParse(v)),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Month', isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => ref
                        .read(salaryRecordsFilterProvider.notifier)
                        .setMonth(int.tryParse(v)),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Year', isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => ref
                        .read(salaryRecordsFilterProvider.notifier)
                        .setYear(int.tryParse(v)),
                  ),
                ),
                DropdownButton<String>(
                  value: filters.status.isEmpty ? '' : filters.status,
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All statuses')),
                    DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                    DropdownMenuItem(value: 'FINALIZED', child: Text('Finalized')),
                  ],
                  onChanged: (v) => ref
                      .read(salaryRecordsFilterProvider.notifier)
                      .setStatus(v ?? ''),
                ),
              ],
            ),
          ),
          Expanded(
            child: SalaryAsyncBody<List<SalaryRecord>>(
              value: recordsAsync,
              emptyMessage: 'No salary records found.',
              onRetry: () => ref.invalidate(salaryRecordsProvider),
              builder: (records) => ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final r = records[i];
                  return Card(
                    child: ListTile(
                      title: Text(r.employee?.fullName ?? 'Employee #${r.employeeId}'),
                      subtitle: Text(
                        '${r.template?.designation?.name ?? '—'} · '
                        '${r.payCommissionCode} · ${r.salaryMonth}/${r.salaryYear}\n'
                        'Gross ${formatInr(r.grossPay)} · Net ${formatInr(r.netPay)}',
                      ),
                      isThreeLine: true,
                      trailing: salaryStatusChip(salaryRecordStatusApi(r.status)),
                      onTap: () => context.go('/admin/salary/records/${r.id}/slip'),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
