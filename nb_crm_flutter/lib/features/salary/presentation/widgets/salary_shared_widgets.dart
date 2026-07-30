import '../../domain/salary_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


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
      loading: () => Center(
        child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$err', textAlign: TextAlign.center),
              if (onRetry != null) ...[
                SizedBox(height: 12),
                FilledButton(onPressed: onRetry, child: Text('Retry')),
              ],
            ],
          ),
        ),
      ),
      data: (data) {
        if (data is List && data.isEmpty) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 64,
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    emptyMessage,
                    style: TextStyle(
                      color: isDark ? Colors.white30 : const Color(0xFF607D8B).withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          );
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

Widget salaryStatusChip(BuildContext context, String status) {
  final v = status.toUpperCase();
  final paid = v == 'PAID' || v == 'FINALIZED';
  final notCalc = v == 'NOT_CALCULATED';
  final color = paid
      ? Colors.green
      : notCalc
          ? Colors.grey
          : Colors.orange;
  final label = payrollRowStatusLabel(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      border: Border.all(color: color, width: 1.2),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
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
      padding: EdgeInsets.all(16),
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
          SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}
