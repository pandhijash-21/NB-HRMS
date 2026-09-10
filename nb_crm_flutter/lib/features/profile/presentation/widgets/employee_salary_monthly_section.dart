import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../salary/data/salary_repository.dart';
import '../../../salary/presentation/widgets/salary_shared_widgets.dart';

const _monthLabels = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class EmployeeSalaryMonthlySection extends StatefulWidget {
  const EmployeeSalaryMonthlySection({super.key, required this.employeeId});

  final int employeeId;

  @override
  State<EmployeeSalaryMonthlySection> createState() => _EmployeeSalaryMonthlySectionState();
}

class _EmployeeSalaryMonthlySectionState extends State<EmployeeSalaryMonthlySection> {
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _overview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOverview());
  }

  Future<void> _loadOverview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context.read<SalaryRepository>().getEmployeeMonthlyOverview(
        employeeId: widget.employeeId,
        year: _year,
        month: _month,
      );
      if (mounted) {
        setState(() {
          _overview = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MonthPicker(
          year: _year,
          month: _month,
          onYearChanged: (y) {
            setState(() => _year = y);
            _loadOverview();
          },
          onMonthChanged: (m) {
            setState(() => _month = m);
            _loadOverview();
          },
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error != null)
          Text('Could not load monthly summary: $_error')
        else if (_overview != null)
          _MonthlyOverviewCard(
            employeeId: widget.employeeId,
            year: _year,
            month: _month,
            overview: _overview!,
            onRefresh: _loadOverview,
          ),
      ],
    );
  }
}

class _MonthlyOverviewCard extends StatefulWidget {
  const _MonthlyOverviewCard({
    required this.employeeId,
    required this.year,
    required this.month,
    required this.overview,
    required this.onRefresh,
  });

  final int employeeId;
  final int year;
  final int month;
  final Map<String, dynamic> overview;
  final VoidCallback onRefresh;

  @override
  State<_MonthlyOverviewCard> createState() => _MonthlyOverviewCardState();
}

class _MonthlyOverviewCardState extends State<_MonthlyOverviewCard> {
  bool _busy = false;
  Map<String, dynamic>? _preview;

  @override
  Widget build(BuildContext context) {
    final attendance = widget.overview['attendance'] as Map<String, dynamic>?;
    final salaryRecord = (_preview?['salaryRecord'] as Map<String, dynamic>?) ??
        (widget.overview['salaryRecord'] as Map<String, dynamic>?);
    final leaveApplications = (widget.overview['leaveApplications'] as List?) ?? [];
    final auth = context.watch<AuthBloc>().state;
    final canWrite = Permissions.canWriteSalary(auth.permissions);
    final computed = _preview?['computed'] as Map<String, dynamic>?;
    final breakdown = _preview?['breakdown'] as Map<String, dynamic>?;

    final trueAbsent = attendance?['absentDays'] ?? 0;
    final unpaidLeave = attendance?['unpaidLeaveDays'] ?? 0;
    final salaryAbsent = attendance?['salaryAbsentDays'] ??
        ((trueAbsent is num ? trueAbsent.toInt() : 0) +
            (unpaidLeave is num ? unpaidLeave.toInt() : 0));
    final absentDates = <String>[
      ...((attendance?['absentDates'] as List?) ?? const []).map((e) => e.toString()),
      ...((breakdown?['absentDates'] as List?) ?? const []).map((e) => e.toString()),
      ...((widget.overview['days'] as List?) ?? const [])
          .where((d) => d is Map && (d['dayStatus']?.toString().toUpperCase() == 'ABSENT'))
          .map((d) => (d as Map)['date']?.toString() ?? '')
          .where((d) => d.isNotEmpty),
    ];
    final absentDatesUnique = absentDates.toSet().toList()..sort();
    final absentDatesLabel = absentDatesUnique.isEmpty
        ? 'none'
        : absentDatesUnique.join(', ');

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
                  const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
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
                      'Absent = $trueAbsent ($absentDatesLabel)\nLeave (salary cut) = $unpaidLeave',
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
                  'Cut days: absent ${breakdown['trueAbsentDays'] ?? 0}'
                  '${((breakdown['absentDates'] as List?)?.isNotEmpty ?? false) ? ' (${(breakdown['absentDates'] as List).join(', ')})' : ''}'
                  ' + unpaid leave ${breakdown['unpaidLeaveDays'] ?? 0} '
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
    final repo = context.read<SalaryRepository>();
    setState(() => _busy = true);
    try {
      if (paid) {
        await repo.markRecordPaid(recordId);
      } else {
        await repo.markRecordUnpaid(recordId);
      }
      widget.onRefresh();
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
    final repo = context.read<SalaryRepository>();
    setState(() => _busy = true);
    try {
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
    final repo = context.read<SalaryRepository>();
    setState(() => _busy = true);
    try {
      final result = await repo.saveEmployeeMonthlySalary(
        employeeId: widget.employeeId,
        year: widget.year,
        month: widget.month,
      );
      if (!mounted) return;
      setState(() => _preview = result);
      widget.onRefresh();
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
          color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF374151),
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
