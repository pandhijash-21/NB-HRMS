import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/attendance_models.dart';
import '../../../leave/presentation/widgets/leave_shared_widgets.dart';
import '../attendance_providers.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthFilter = ref.watch(attendanceMonthFilterProvider);
    final calendarAsync = ref.watch(myAttendanceCalendarProvider);
    final selectedDate = ref.watch(selectedAttendanceDayProvider);
    final dayAsync = ref.watch(myAttendanceDayProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = ref.watch(authNotifierProvider);
    final canAdmin = Permissions.canAdminAttendance(
      auth.permissions,
      auth.user?.role ?? '',
    );

    final daysInMonth =
        DateTime(monthFilter.year, monthFilter.month + 1, 0).day;
    final firstWeekday =
        DateTime(monthFilter.year, monthFilter.month, 1).weekday;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Attendance',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF212F3D),
          ),
          onPressed: () => context.go('/home'),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
            height: 1.5,
          ),
        ),
      ),
      body: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0.0, 35.0 * (1.0 - value)),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          children: [
            if (canAdmin) ...[
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC5A059),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Attendance Workspace',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _AttendanceWorkspaceTile(
                icon: Icons.admin_panel_settings_rounded,
                title: 'Manage Attendance',
                subtitle: 'Policy, manual punches & all employees',
                color: const Color(0xFF16a34a),
                onTap: () => context.go('/admin/attendance'),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC5A059),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'My Attendance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            // Month Navigator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () =>
                        ref.read(attendanceMonthFilterProvider.notifier).previousMonth(),
                    icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFFC5A059)),
                  ),
                  Text(
                    '${_monthName(monthFilter.month)} ${monthFilter.year}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                      letterSpacing: -0.3,
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        ref.read(attendanceMonthFilterProvider.notifier).nextMonth(),
                    icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFFC5A059)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            calendarAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: Color(0xFFC5A059)),
                ),
              ),
              error: (e, _) => Column(
                children: [
                  Text(
                    '$e',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => ref.invalidate(myAttendanceCalendarProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
              data: (calendar) => _CalendarGrid(
                daysInMonth: daysInMonth,
                firstWeekday: firstWeekday,
                monthFilter: monthFilter,
                calendar: calendar,
                selectedDate: selectedDate,
                onSelect: (date) =>
                    ref.read(selectedAttendanceDayProvider.notifier).set(date),
              ),
            ),
            const SizedBox(height: 36),
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC5A059),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Day Detail · ${selectedDate ?? '—'}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            dayAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: Color(0xFFC5A059)),
                ),
              ),
              error: (e, _) => Column(
                children: [
                  Text(
                    '$e',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => ref.invalidate(myAttendanceDayProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
              data: (day) => _DayDetail(day: day),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[month - 1];
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.daysInMonth,
    required this.firstWeekday,
    required this.monthFilter,
    required this.calendar,
    required this.selectedDate,
    required this.onSelect,
  });

  final int daysInMonth;
  final int firstWeekday;
  final AttendanceMonthFilter monthFilter;
  final Map<String, AttendanceCalendarDay> calendar;
  final String? selectedDate;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    const headers = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cells = <Widget>[
      for (final h in headers)
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              h,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: isDark ? Colors.white60 : const Color(0xFF607D8B),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
    ];

    for (var i = 1; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }

    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(monthFilter.year, monthFilter.month, day);
      final key = formatDateYmd(date);
      final summary = calendar[key];
      final selected = key == selectedDate;
      final hasPunches = summary != null && summary.count > 0;

      Widget cellContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: selected
                  ? (isDark ? const Color(0xFF1A1816) : Colors.white)
                  : (isDark ? Colors.white : const Color(0xFF212F3D)),
            ),
          ),
          if (hasPunches) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: selected
                    ? (isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.2))
                    : (isDark ? const Color(0xFF2B2722) : const Color(0xFFECEFF1)),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : (isDark ? const Color(0xFFC5A059).withOpacity(0.3) : const Color(0xFFCFD8DC)),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fingerprint_rounded,
                    size: 9,
                    color: selected
                        ? (isDark ? const Color(0xFF1A1816) : Colors.white)
                        : const Color(0xFFC5A059),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${summary.count}',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? (isDark ? const Color(0xFF1A1816) : Colors.white)
                          : (isDark ? Colors.white70 : const Color(0xFF263238)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );

      cells.add(
        Padding(
          padding: const EdgeInsets.all(3),
          child: InkWell(
            onTap: () => onSelect(key),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: selected
                    ? (isDark ? const Color(0xFFC5A059) : const Color(0xFF263238))
                    : (hasPunches
                        ? (isDark ? const Color(0xFF1E1B18) : Colors.white)
                        : (isDark ? const Color(0xFF151311) : const Color(0xFFF1F5F9))),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? (isDark ? const Color(0xFFC5A059) : const Color(0xFF263238))
                      : (hasPunches
                          ? (isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC))
                          : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03))),
                  width: selected ? 2.0 : 1.2,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: (isDark ? const Color(0xFFC5A059) : const Color(0xFF263238)).withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: cellContent,
            ),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final gridWidth = screenWidth > 800 ? 800.0 : (screenWidth - 48).clamp(0.0, double.infinity);
    final cellWidth = gridWidth / 7;
    final targetHeight = cellWidth < 65.0 ? cellWidth : 65.0;
    final aspectRatio = cellWidth > 0 && targetHeight > 0 ? (cellWidth / targetHeight) : 1.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: aspectRatio,
          children: cells,
        ),
      ),
    );
  }
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.day});

  final AttendanceMyDay day;

  @override
  Widget build(BuildContext context) {
    final summary = day.summary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Convert total minutes to hours & minutes format
    final int hours = summary.totalMinutes ~/ 60;
    final int minutes = summary.totalMinutes % 60;
    final durationStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    // Compliance evaluation status flags
    final isLate = summary.evaluation?.isLate ?? false;
    final isHalfDay = summary.evaluation?.isHalfDay ?? false;
    final meetsPunchOut = summary.evaluation?.meetsPunchOut ?? false;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First In & Last Out split grid
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151311) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.login_rounded, size: 14, color: isLate ? Colors.orange : Colors.green),
                            const SizedBox(width: 6),
                            const Text(
                              'FIRST IN',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          summary.firstIn != null ? formatIsoTime(summary.firstIn) : '—',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF212F3D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151311) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.logout_rounded, size: 14, color: meetsPunchOut ? const Color(0xFFC5A059) : Colors.orange),
                            const SizedBox(width: 6),
                            const Text(
                              'LAST OUT',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          summary.lastOut != null ? formatIsoTime(summary.lastOut) : '—',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF212F3D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Duration metrics row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Working Duration',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                  ),
                ),
                Text(
                  '$durationStr (${summary.totalMinutes} mins)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 16),
            // Evaluation Status Pill tags
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Late Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLate ? Colors.red.withOpacity(0.12) : Colors.green.withOpacity(0.12),
                    border: Border.all(color: isLate ? Colors.red : Colors.green, width: 1.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    isLate ? 'LATE IN' : 'ON TIME',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isLate ? Colors.red : Colors.green,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // Half Day Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHalfDay ? Colors.orange.withOpacity(0.12) : Colors.green.withOpacity(0.12),
                    border: Border.all(color: isHalfDay ? Colors.orange : Colors.green, width: 1.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    isHalfDay ? 'HALF DAY' : 'FULL DAY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isHalfDay ? Colors.orange : Colors.green,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // meetsPunchOut Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: meetsPunchOut ? Colors.green.withOpacity(0.12) : Colors.amber.withOpacity(0.12),
                    border: Border.all(color: meetsPunchOut ? Colors.green : Colors.amber, width: 1.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    meetsPunchOut ? 'OUT PUNCH COMPLIANT' : 'MISSING OUT PUNCH',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: meetsPunchOut ? Colors.green : Colors.amber,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'PUNCH HISTORY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            if (day.punches.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No punches recorded for this day.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white30 : const Color(0xFF607D8B).withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              ...day.punches.map(
                (p) {
                  final type = p.punchType?.toUpperCase() ?? 'IN';
                  final isOut = type == 'OUT';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151311) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border(
                        left: BorderSide(
                          color: isOut ? const Color(0xFFC5A059) : Colors.green,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.fingerprint_rounded,
                          color: isOut ? const Color(0xFFC5A059) : Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatIsoTime(p.punchAt),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                [p.punchType, p.terminalId, p.source]
                                    .whereType<String>()
                                    .where((s) => s.isNotEmpty)
                                    .join(' · '),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white30 : const Color(0xFF607D8B).withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceWorkspaceTile extends StatelessWidget {
  const _AttendanceWorkspaceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1B18) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? const Color(0xFFC5A059).withOpacity(0.15)
                  : const Color(0xFFCFD8DC),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white38 : const Color(0xFF90A4AE),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
