import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
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
            year: monthFilter.year,
            month: monthFilter.month,
            overview: overview,
          ),
        ),
      ],
    );
  }
}

class _MonthlyOverviewCard extends ConsumerStatefulWidget {
  const _MonthlyOverviewCard({
    required this.employeeId,
    required this.year,
    required this.month,
    required this.overview,
  });

  final int employeeId;
  final int year;
  final int month;
  final Map<String, dynamic> overview;

  @override
  ConsumerState<_MonthlyOverviewCard> createState() => _MonthlyOverviewCardState();
}

class _MonthlyOverviewCardState extends ConsumerState<_MonthlyOverviewCard> {
  bool _busy = false;
  Map<String, dynamic>? _preview;

  @override
  Widget build(BuildContext context) {
    final attendance = widget.overview['attendance'] as Map<String, dynamic>?;
    final salaryRecord = (_preview?['salaryRecord'] as Map<String, dynamic>?) ??
        (widget.overview['salaryRecord'] as Map<String, dynamic>?);
    final leaveApplications = (widget.overview['leaveApplications'] as List?) ?? [];
    final auth = ref.watch(authNotifierProvider);
    final canWrite = Permissions.canWriteSalary(auth.permissions);
    final computed = _preview?['computed'] as Map<String, dynamic>?;
    final breakdown = _preview?['breakdown'] as Map<String, dynamic>?;

    final trueAbsent = attendance?['absentDays'] ?? 0;
    final unpaidLeave = attendance?['unpaidLeaveDays'] ?? 0;
    final salaryAbsent = attendance?['salaryAbsentDays'] ??
        ((trueAbsent is num ? trueAbsent.toInt() : 0) +
            (unpaidLeave is num ? unpaidLeave.toInt() : 0));

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
                  _chip(context, 'Leave', '${attendance['leaveDays'] ?? attendance['leaveDaysInMonth'] ?? 0}'),
                  _chip(context, 'Holiday', '${attendance['holidayDays'] ?? 0}'),
                  _chip(context, 'Absent', '${attendance['absentDays'] ?? 0}'),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (leaveApplications.isNotEmpty) ...[
              Text('Leave details', style: _sectionStyle(context)),
              const SizedBox(height: 8),
              ...leaveApplications.map((raw) {
                final leave = Map<String, dynamic>.from(raw as Map);
                final leaveType = leave['leaveType'] as Map<String, dynamic>?;
                final name = leaveType?['name']?.toString() ?? 'Leave';
                final status = leave['status']?.toString() ?? '—';
                final totalDays = leave['totalDays']?.toString() ?? '0';
                final fromDate = leave['fromDate']?.toString();
                final toDate = leave['toDate']?.toString();
                final range = fromDate != null && toDate != null
                    ? '${_fmtDate(fromDate)} - ${_fmtDate(toDate)}'
                    : 'Date unavailable';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '$name • $totalDays day(s) • $status\n$range',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],
            Text('Salary', style: _sectionStyle(context)),
            const SizedBox(height: 8),
            if (salaryRecord != null) ...[
              Row(
                children: [
                  Text('Status', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  salaryStatusChip(
                    context,
                    salaryRecord['status']?.toString() ?? 'UNPAID',
                  ),
                  const Spacer(),
                  if (canWrite && salaryRecord['id'] != null)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _togglePaid(
                                salaryRecord['id'].toString(),
                                paid: (salaryRecord['status']?.toString() ?? '').toUpperCase() != 'PAID',
                              ),
                      child: Text(
                        (salaryRecord['status']?.toString() ?? '').toUpperCase() == 'PAID'
                            ? 'Mark unpaid'
                            : 'Mark paid',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tooltip(
                  message:
                      'Absent = $trueAbsent · Leave (salary cut) = $unpaidLeave',
                  child: _chip(context, 'Absent*', '$salaryAbsent'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (computed != null) ...[
              _salaryRow(context, 'Gross pay', formatInr(computed['grossPay']), bold: false),
              _salaryRow(context, 'Deductions', formatInr(computed['totalDeductions'])),
              _salaryRow(context, 'Net pay', formatInr(computed['netPay']), bold: true),
              if (breakdown != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Cut days: absent ${breakdown['trueAbsentDays'] ?? 0} + unpaid leave ${breakdown['unpaidLeaveDays'] ?? 0} '
                  '(of ${breakdown['daysInMonth'] ?? 0} days)'
                  '${breakdown['reimbursementTotal'] != null ? ' · Reimbursements ${formatInr(breakdown['reimbursementTotal'])}' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ] else if (salaryRecord == null)
              Text(
                'No salary record for this month yet (Not calculated).',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              )
            else ...[
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
                      '/profile/salary-slip/$recordId?employeeId=${widget.employeeId}',
                    );
                  },
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Download salary slip'),
                ),
              ],
            ],
            if (canWrite) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _onCalculate,
                      icon: const Icon(Icons.calculate_outlined, size: 18),
                      label: const Text('Calculate salary'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _onSave,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save (Unpaid)'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _togglePaid(String recordId, {required bool paid}) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(salaryRepositoryProvider);
      if (paid) {
        await repo.markRecordPaid(recordId);
      } else {
        await repo.markRecordUnpaid(recordId);
      }
      ref.invalidate(
        employeeSalaryMonthlyOverviewProvider((
          employeeId: widget.employeeId,
          year: widget.year,
          month: widget.month,
        )),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(paid ? 'Marked paid' : 'Marked unpaid')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onCalculate() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(salaryRepositoryProvider);
      final result = await repo.calculateEmployeeMonthlySalary(
        employeeId: widget.employeeId,
        year: widget.year,
        month: widget.month,
      );
      if (!mounted) return;
      setState(() => _preview = result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salary calculated (not saved yet)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onSave() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(salaryRepositoryProvider);
      final result = await repo.saveEmployeeMonthlySalary(
        employeeId: widget.employeeId,
        year: widget.year,
        month: widget.month,
      );
      if (!mounted) return;
      setState(() => _preview = result);
      ref.invalidate(
        employeeSalaryMonthlyOverviewProvider((
          employeeId: widget.employeeId,
          year: widget.year,
          month: widget.month,
        )),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salary saved as unpaid for this month')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

  String _fmtDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final d = dt.toUtc().add(const Duration(hours: 5, minutes: 30));
    return '${d.day.toString().padLeft(2, '0')} ${_monthLabels[d.month - 1]} ${d.year}';
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
