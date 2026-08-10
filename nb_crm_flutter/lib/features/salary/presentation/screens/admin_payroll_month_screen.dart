import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/widgets/header_action_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../salary_providers.dart';
import '../widgets/salary_shared_widgets.dart';

const _monthLabels = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class AdminPayrollMonthScreen extends ConsumerWidget {
  const AdminPayrollMonthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(payrollMonthFilterProvider);
    final payrollAsync = ref.watch(payrollMonthProvider(filter));
    final auth = ref.watch(authNotifierProvider);
    final canWrite = Permissions.canWriteSalary(auth.permissions);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        title: Text(
          'Payroll',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
          ),
        ),
        leading: const AppBackButton(),
        actions: [
          HeaderActionButton(
            tooltip: 'Salary Entry',
            label: 'Entry',
            icon: Icon(
              Icons.edit_document,
              size: 18,
              color: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
            ),
            onPressed: () => context.go('/admin/salary/entry'),
          ),
          HeaderActionButton(
            tooltip: 'Structures',
            label: 'Structures',
            icon: Icon(
              Icons.account_tree_outlined,
              size: 18,
              color: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
            ),
            onPressed: () => context.go('/admin/salary/structures'),
          ),
          HeaderActionButton(
            tooltip: 'Records',
            label: 'Records',
            icon: Icon(
              Icons.receipt_long_outlined,
              size: 18,
              color: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
            ),
            onPressed: () => context.go('/admin/salary/records'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _MonthBar(
            year: filter.year,
            month: filter.month,
            onYearChanged: (y) =>
                ref.read(payrollMonthFilterProvider.notifier).setMonth(y, filter.month),
            onMonthChanged: (m) =>
                ref.read(payrollMonthFilterProvider.notifier).setMonth(filter.year, m),
          ),
          Expanded(
            child: SalaryAsyncBody<Map<String, dynamic>>(
              value: payrollAsync,
              emptyMessage: 'No employees found.',
              onRetry: () => ref.invalidate(payrollMonthProvider(filter)),
              builder: (data) {
                final kpis = Map<String, dynamic>.from(
                  (data['kpis'] as Map?) ?? const {},
                );
                final employees = (data['employees'] as List? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _KpiRow(kpis: kpis),
                    const SizedBox(height: 16),
                    Text(
                      'Employees · ${_monthLabels[filter.month - 1]} ${filter.year}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...employees.map(
                      (row) => _EmployeePayrollTile(
                        row: row,
                        canWrite: canWrite,
                        year: filter.year,
                        month: filter.month,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: isDark ? const Color(0xFF1A1816) : Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => onYearChanged(year - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                '$year',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                ),
              ),
              IconButton(
                onPressed: () => onYearChanged(year + 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(12, (i) {
                final m = i + 1;
                final selected = m == month;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(_monthLabels[i]),
                    selected: selected,
                    onSelected: (_) => onMonthChanged(m),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.kpis});

  final Map<String, dynamic> kpis;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _kpi(context, 'Employees', '${kpis['totalEmployees'] ?? 0}'),
        _kpi(context, 'Calculated', '${kpis['calculatedCount'] ?? 0}'),
        _kpi(context, 'Not calculated', '${kpis['notCalculatedCount'] ?? 0}'),
        _kpi(context, 'Unpaid', '${kpis['unpaidCount'] ?? 0}'),
        _kpi(context, 'Paid', '${kpis['paidCount'] ?? 0}'),
        _kpi(context, 'Paid amount', formatInr(kpis['paidAmount'])),
        _kpi(context, 'Remaining', formatInr(kpis['remainingAmount'])),
        _kpi(context, 'Total net', formatInr(kpis['totalNetPay'])),
      ],
    );
  }

  Widget _kpi(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : const Color(0xFF607D8B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF212F3D),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeePayrollTile extends ConsumerStatefulWidget {
  const _EmployeePayrollTile({
    required this.row,
    required this.canWrite,
    required this.year,
    required this.month,
  });

  final Map<String, dynamic> row;
  final bool canWrite;
  final int year;
  final int month;

  @override
  ConsumerState<_EmployeePayrollTile> createState() => _EmployeePayrollTileState();
}

class _EmployeePayrollTileState extends ConsumerState<_EmployeePayrollTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = widget.row['status']?.toString() ?? 'NOT_CALCULATED';
    final recordId = widget.row['recordId']?.toString();
    final net = widget.row['netPay'];
    final name = widget.row['fullName']?.toString() ?? 'Employee';
    final code = widget.row['employeeCode']?.toString();
    final dept = widget.row['department']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [
            if (code != null && code.isNotEmpty) code,
            if (dept != null && dept.isNotEmpty) dept,
            if (net != null) 'Net ${formatInr(net)}',
          ].join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            salaryStatusChip(context, status),
            if (widget.canWrite && recordId != null) ...[
              const SizedBox(width: 8),
              if (status.toUpperCase() == 'UNPAID')
                IconButton(
                  tooltip: 'Mark paid',
                  onPressed: _busy ? null : () => _togglePaid(recordId, paid: true),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.payments_outlined, color: isDark ? const Color(0xFFC5A059) : Colors.green),
                )
              else if (status.toUpperCase() == 'PAID')
                IconButton(
                  tooltip: 'Mark unpaid',
                  onPressed: _busy ? null : () => _togglePaid(recordId, paid: false),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.undo_rounded, color: Colors.orange),
                ),
            ],
            IconButton(
              tooltip: 'Open profile salary',
              onPressed: () => context.push('/admin/employees/${widget.row['employeeId']}'),
              icon: const Icon(Icons.open_in_new, size: 18),
            ),
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
      ref.invalidate(payrollMonthProvider(PayrollMonthFilter(year: widget.year, month: widget.month)));
      invalidateSalaryRecords(ref);
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
}
