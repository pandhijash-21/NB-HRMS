import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/salary_models.dart';
import '../salary_providers.dart';
import '../widgets/salary_shared_widgets.dart';

class AdminSalaryStructuresScreen extends ConsumerWidget {
  const AdminSalaryStructuresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(salaryStructureStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Salary Structures'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/salary/records'),
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/admin/salary/commissions'),
            child: const Text('Commissions', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => context.go('/admin/salary/entry'),
            child: const Text('Entry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SalaryAsyncBody<List<SalaryStructureStatus>>(
        value: statusAsync,
        emptyMessage: 'No designations found.',
        onRetry: () => ref.invalidate(salaryStructureStatusProvider),
        builder: (rows) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final row = rows[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.designation.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: row.commissions
                          .map(
                            (c) => Chip(
                              label: Text(
                                '${c.payCommission.name} ${c.configured ? 'Configured' : 'Not configured'}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: row.commissions
                          .map(
                            (c) => OutlinedButton(
                              onPressed: () => _goConfigure(context, ref, row, c),
                              child: Text('Configure ${c.payCommission.name}'),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _goConfigure(
    BuildContext context,
    WidgetRef ref,
    SalaryStructureStatus row,
    SalaryStructureCommissionStatus commission,
  ) async {
    var templateId = commission.templateId;
    if (templateId == null) {
      final created = await ref.read(salaryRepositoryProvider).createTemplate(
            designationId: row.designation.id,
            payCommissionCode: commission.payCommission.code,
          );
      templateId = created.id;
      invalidateSalaryStructures(ref);
    }
    if (!context.mounted) return;
    context.go(
      '/admin/salary/structures/${row.designation.id}/${commission.payCommission.code.toLowerCase()}?templateId=$templateId',
    );
  }
}
