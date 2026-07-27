import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../salary/presentation/salary_providers.dart';
import '../../../salary/presentation/widgets/salary_shared_widgets.dart';

const _monthLabels = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class EmployeeSalaryMonthlySection extends ConsumerWidget {
  const EmployeeSalaryMonthlySection({super.key, required this.employeeId});

  final int employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthFilter = ref.watch(profileSalaryMonthProvider);
    final overviewAsync = ref.watch(
      employeeSalaryMonthlyOverviewProvider((
        employeeId: employeeId,
        year: monthFilter.year,
        month: monthFilter.month,
      )),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MonthPicker(
          year: monthFilter.year,
          month: monthFilter.month,
          onYearChanged: (y) => ref
              .read(profileSalaryMonthProvider.notifier)
              .setMonth(y, monthFilter.month),
          onMonthChanged: (m) => ref
              .read(profileSalaryMonthProvider.notifier)
              .setMonth(monthFilter.year, m),
        ),
        const SizedBox(height: 12),
        overviewAsync.when(
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          )),
          error: (e, _) => Text('Could not load monthly summary: $e'),
          data: (overview) => _MonthlyOverviewCard(
            employeeId: employeeId,
            overview: overview,
          ),
        ),
      ],
    );
  }
}

class _MonthlyOverviewCard extends StatelessWidget {
  const _MonthlyOverviewCard({
    required this.employeeId,
    required this.overview,
  });

  final int employeeId;
  final Map<String, dynamic> overview;

  @override
  Widget build(BuildContext context) {
    final attendance = overview['attendance'] as Map<String, dynamic>?;
    final salaryRecord = overview['salaryRecord'] as Map<String, dynamic>?;
    final leaveBalances = (overview['leaveBalances'] as List?) ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (attendance != null) ...[
              Text('Attendance', style: _sectionStyle(context)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(context, 'Present', '${attendance['presentDays'] ?? 0} days'),
                  _chip(context, 'Working hours', '${attendance['totalWorkingHours'] ?? 0}h'),
                  _chip(context, 'Late', '${attendance['lateDays'] ?? 0}'),
                  _chip(context, 'Leave', '${attendance['leaveDaysInMonth'] ?? 0}'),
                  _chip(context, 'Absent*', '${attendance['absentDays'] ?? 0}'),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (leaveBalances.isNotEmpty) ...[
              Text('Leave balances', style: _sectionStyle(context)),
              const SizedBox(height: 8),
              ...leaveBalances.map((raw) {
                final b = Map<String, dynamic>.from(raw as Map);
                final leaveType = b['leaveType'] as Map<String, dynamic>?;
                final name = leaveType?['name']?.toString() ?? 'Leave';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '$name: ${b['closingBalance'] ?? 0} remaining',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],
            Text('Salary', style: _sectionStyle(context)),
            const SizedBox(height: 8),
            if (salaryRecord == null)
              Text(
                'No salary record for this month yet.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              )
            else ...[
              _salaryRow(context, 'Status', salaryRecord['status']?.toString() ?? '—'),
              _salaryRow(context, 'Gross pay', formatInr(salaryRecord['grossPay'])),
              _salaryRow(context, 'Deductions', formatInr(salaryRecord['totalDeductions'])),
              _salaryRow(context, 'Net pay', formatInr(salaryRecord['netPay']), bold: true),
              if (salaryRecord['canDownloadSlip'] == true) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    final recordId = salaryRecord['id']?.toString();
                    if (recordId == null) return;
                    context.push(
                      '/profile/salary-slip/$recordId?employeeId=$employeeId',
                    );
                  },
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Download salary slip'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  TextStyle? _sectionStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700);
  }

  Widget _chip(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Chip(
      label: Text(
        '$label: $value',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF374151),
        ),
      ),
      backgroundColor: isDark 
          ? const Color(0xFF2E2E2E)
          : const Color(0xFFF3F4F6),
      side: BorderSide(
        color: isDark 
            ? const Color(0xFF3E3E3E)
            : const Color(0xFFE5E7EB),
        width: 1,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _salaryRow(BuildContext context, String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({
    required this.year,
    required this.month,
    required this.onYearChanged,
    required this.onMonthChanged,
  });

  final int year;
  final int month;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Monthly records',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => onYearChanged(year - 1),
              icon: const Icon(Icons.chevron_left),
            ),
            Text('$year', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            IconButton(
              onPressed: year >= now.year ? null : () => onYearChanged(year + 1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(12, (i) {
            final m = i + 1;
            final selected = m == month;
            final isFuture = year > now.year || (year == now.year && m > now.month);
            return ChoiceChip(
              label: Text(
                _monthLabels[i],
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              selected: selected,
              selectedColor: isDark ? const Color(0xFFC5A059) : Colors.black,
              checkmarkColor: Colors.white,
              onSelected: isFuture ? null : (_) => onMonthChanged(m),
            );
          }),
        ),
      ],
    );
  }
}
