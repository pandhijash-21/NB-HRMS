import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
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

    final daysInMonth =
        DateTime(monthFilter.year, monthFilter.month + 1, 0).day;
    final firstWeekday =
        DateTime(monthFilter.year, monthFilter.month, 1).weekday;

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Attendance'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () =>
                    ref.read(attendanceMonthFilterProvider.notifier).previousMonth(),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                '${_monthName(monthFilter.month)} ${monthFilter.year}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.midnight,
                ),
              ),
              IconButton(
                onPressed: () =>
                    ref.read(attendanceMonthFilterProvider.notifier).nextMonth(),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 12),
          calendarAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.bronze),
              ),
            ),
            error: (e, _) => Column(
              children: [
                Text('$e'),
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
          const SizedBox(height: 24),
          Text(
            'Day detail · ${selectedDate ?? '—'}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          dayAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.bronze)),
            error: (e, _) => Column(
              children: [
                Text('$e'),
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
    final cells = <Widget>[
      for (final h in headers)
        Center(
          child: Text(
            h,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
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
      cells.add(
        InkWell(
          onTap: () => onSelect(key),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.bronze.withValues(alpha: 0.25)
                  : (summary != null && summary.count > 0
                      ? AppColors.successSoft
                      : AppColors.surface),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$day', style: const TextStyle(fontWeight: FontWeight.w600)),
                if (summary != null && summary.count > 0)
                  Text(
                    '${summary.count} punch',
                    style: const TextStyle(fontSize: 10, color: AppColors.success),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: cells,
    );
  }
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.day});

  final AttendanceMyDay day;

  @override
  Widget build(BuildContext context) {
    final summary = day.summary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'First in: ${formatIsoTime(summary.firstIn)} · Last out: ${formatIsoTime(summary.lastOut)}',
            ),
            Text('Total: ${summary.totalMinutes} minutes'),
            if (summary.evaluation != null) ...[
              const SizedBox(height: 8),
              Text(
                'Late: ${summary.evaluation!.isLate ?? false} · '
                'Half day: ${summary.evaluation!.isHalfDay ?? false} · '
                'Meets punch-out: ${summary.evaluation!.meetsPunchOut ?? false}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            if (day.punches.isEmpty)
              const Text('No punches recorded.')
            else
              ...day.punches.map(
                (p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.fingerprint, color: AppColors.bronze),
                  title: Text(formatIsoTime(p.punchAt)),
                  subtitle: Text(
                    [p.punchType, p.terminalId, p.source]
                        .whereType<String>()
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
