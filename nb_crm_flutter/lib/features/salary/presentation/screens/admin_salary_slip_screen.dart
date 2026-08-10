import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/salary_models.dart';
import '../salary_providers.dart';
import '../widgets/salary_shared_widgets.dart';

class AdminSalarySlipScreen extends ConsumerWidget {
  const AdminSalarySlipScreen({super.key, required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slipAsync = ref.watch(salarySlipProvider(recordId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Salary Slip'),
        leading: const AppBackButton(fallbackLocation: '/admin/salary/records'),
      ),
      body: SalaryAsyncBody<SalarySlip>(
        value: slipAsync,
        emptyMessage: 'Slip not found.',
        onRetry: () => ref.invalidate(salarySlipProvider(recordId)),
        builder: (slip) => SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        slip.institutionName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Salary Slip — ${slip.monthYear}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                      ),
                      const Divider(height: 32),
                      _InfoRow(label: 'Employee', value: slip.employee.name),
                      _InfoRow(label: 'Employee ID', value: '${slip.employee.id}'),
                      _InfoRow(label: 'Designation', value: slip.employee.designation),
                      _InfoRow(label: 'Department', value: slip.employee.department),
                      SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _SlipColumn(title: 'Earnings', lines: slip.earnings, color: AppColors.success)),
                          SizedBox(width: 16),
                          Expanded(child: _SlipColumn(title: 'Deductions', lines: slip.deductions, color: AppColors.error)),
                        ],
                      ),
                      const Divider(height: 32),
                      _SummaryRow(label: 'Gross Pay', value: formatInr(slip.grossPay)),
                      _SummaryRow(label: 'Total Deductions', value: formatInr(slip.totalDeductions)),
                      _SummaryRow(
                        label: 'Net Pay',
                        value: formatInr(slip.netPay),
                        bold: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _SlipColumn extends StatelessWidget {
  const _SlipColumn({
    required this.title,
    required this.lines,
    required this.color,
  });

  final String title;
  final List<SalarySlipLine> lines;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        SizedBox(height: 8),
        ...lines.map(
          (line) => Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(columnDisplayLabel(line.columnIdentifier), style: const TextStyle(fontSize: 13)),
                ),
                Text(formatInr(line.effectiveValue), style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
        ],
      ),
    );
  }
}
