import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/header_action_button.dart';
import '../../domain/attendance_models.dart';
import '../../../leave/presentation/widgets/leave_shared_widgets.dart';
import '../attendance_providers.dart';
import 'admin_attendance_screen.dart';

class AdminEmployeeAttendanceHistoryScreen extends ConsumerWidget {
  const AdminEmployeeAttendanceHistoryScreen({
    super.key,
    required this.employeeId,
  });

  final int employeeId;

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(adminEmployeeHistoryMonthProvider);
    final historyAsync = ref.watch(adminEmployeeHistoryProvider(employeeId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Employee Attendance',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF212F3D),
          ),
          onPressed: () => context.go('/admin/attendance'),
        ),
        actions: [
          HeaderActionButton(
            tooltip: 'Add punch',
            label: 'Add punch',
            icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFFC5A059)),
            onPressed: () => showAdminPunchDialog(
              context,
              ref,
              employeeId: employeeId,
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
            height: 1.5,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: isDark ? const Color(0xFF1A1816) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () =>
                      ref.read(adminEmployeeHistoryMonthProvider.notifier).previousMonth(),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    '${_monthNames[month.month - 1]} ${month.year}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      ref.read(adminEmployeeHistoryMonthProvider.notifier).nextMonth(),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFFC5A059)),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$e', style: const TextStyle(color: Colors.red)),
                    FilledButton(
                      onPressed: () =>
                          ref.invalidate(adminEmployeeHistoryProvider(employeeId)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (history) {
                final daysWithActivity = history.days.where((d) => d.punches.isNotEmpty).toList();
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  children: [
                    Text(
                      history.fullName,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (history.employeeCode != null) 'Code ${history.employeeCode}',
                        'ID ${history.employeeId}',
                        if (history.department != null) history.department!,
                      ].join(' • '),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (daysWithActivity.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            'No punches this month.',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : const Color(0xFF90A4AE),
                            ),
                          ),
                        ),
                      )
                    else
                      ...daysWithActivity.reversed.map(
                        (day) => _HistoryDayCard(
                          day: day,
                          employeeId: employeeId,
                          onEdit: (punch) => showAdminPunchDialog(
                            context,
                            ref,
                            employeeId: employeeId,
                            existing: punch,
                            dateYmd: day.date,
                          ),
                          onAdd: () => showAdminPunchDialog(
                            context,
                            ref,
                            employeeId: employeeId,
                            dateYmd: day.date,
                          ),
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

class _HistoryDayCard extends StatelessWidget {
  const _HistoryDayCard({
    required this.day,
    required this.employeeId,
    required this.onEdit,
    required this.onAdd,
  });

  final AdminAttendanceHistoryDay day;
  final int employeeId;
  final ValueChanged<AttendancePunch> onEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            day.date,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF212F3D),
            ),
          ),
          subtitle: Text(
            'In ${day.firstIn != null ? formatIsoTime(day.firstIn) : '—'}  ·  '
            'Out ${day.lastOut != null ? formatIsoTime(day.lastOut) : '—'}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : const Color(0xFF607D8B),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (day.isLate == true)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Text(
                    'LATE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.orange,
                    ),
                  ),
                ),
              Text(
                '${day.punches.length}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                ),
              ),
            ],
          ),
          children: [
            ...day.punches.map(
              (p) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.fingerprint_rounded,
                  color: (p.punchType?.toUpperCase() == 'OUT')
                      ? const Color(0xFFC5A059)
                      : Colors.green,
                ),
                title: Text(
                  formatIsoTime(p.punchAt),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('${p.punchType ?? '—'} · ${p.terminalId ?? '—'} · ${p.source ?? '—'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => onEdit(p),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add punch for this day'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
