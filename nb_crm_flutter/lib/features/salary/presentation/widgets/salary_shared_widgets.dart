import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';

class SalaryAsyncBody<T> extends StatelessWidget {
  const SalaryAsyncBody({
    super.key,
    required this.value,
    required this.builder,
    this.emptyMessage = 'Nothing here yet.',
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final String emptyMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.bronze),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$err', textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ],
          ),
        ),
      ),
      data: (data) {
        if (data is List && data.isEmpty) {
          return Center(child: Text(emptyMessage));
        }
        return builder(data);
      },
    );
  }
}

String formatInr(dynamic value) {
  final n = value is num ? value : num.tryParse(value?.toString() ?? '') ?? 0;
  final negative = n < 0;
  final abs = n.abs().toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < abs.length; i++) {
    if (i > 0 && (abs.length - i) % 3 == 0) buf.write(',');
    buf.write(abs[i]);
  }
  return '${negative ? '-' : ''}₹${buf.toString()}';
}

String slugCommissionCode(String name) {
  return name
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

String columnDisplayLabel(String identifier) {
  const labels = {
    'basic': 'Basic',
    'dearness_pay': 'Dearness Pay',
    'new_basic': 'New Basic',
    'dearness_allowance': 'Dearness Allowance',
    'house_rent_allowance': 'House Rent Allowance',
    'city_compensatory_allowance': 'City Compensatory Allowance',
    'medical_allowance': 'Medical Allowance',
    'travel_allowance': 'Travel Allowance',
    'academic_grade_pay': 'Academic Grade Pay',
    'special_allowance': 'Special Allowance',
    'other_allowance': 'Other Allowance',
    'gratuity': 'Gratuity',
    'provident_fund': 'Provident Fund',
    'professional_tax': 'Professional Tax',
    'tax_deducted_at_source': 'Tax Deducted at Source',
    'tax_deducted_at_source_against_proof': 'TDS Against Proof',
    'other_deductions': 'Other Deductions',
    'gross_pay': 'Gross Pay',
    'total_deductions': 'Total Deductions',
    'net_pay': 'Net Pay',
  };
  return labels[identifier] ?? identifier.replaceAll('_', ' ');
}

Widget salaryStatusChip(String status) {
  final finalized = status.toUpperCase() == 'FINALIZED';
  final color = finalized ? AppColors.success : AppColors.bronzeDark;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      status,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

Widget salarySectionCard({
  required String title,
  required Color titleColor,
  required Widget child,
}) {
  return Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}
