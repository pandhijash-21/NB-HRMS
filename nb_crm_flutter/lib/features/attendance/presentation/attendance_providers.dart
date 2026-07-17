import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/attendance_repository.dart';
import '../domain/attendance_models.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(dioClient: ref.watch(dioClientProvider));
});

class AttendanceMonthFilter {
  const AttendanceMonthFilter({required this.year, required this.month});

  final int year;
  final int month;

  AttendanceMonthFilter copyWith({int? year, int? month}) {
    return AttendanceMonthFilter(
      year: year ?? this.year,
      month: month ?? this.month,
    );
  }
}

class AttendanceMonthFilterNotifier extends Notifier<AttendanceMonthFilter> {
  @override
  AttendanceMonthFilter build() {
    final now = DateTime.now();
    return AttendanceMonthFilter(year: now.year, month: now.month);
  }

  void setMonth(int year, int month) =>
      state = AttendanceMonthFilter(year: year, month: month);

  void previousMonth() {
    if (state.month == 1) {
      state = AttendanceMonthFilter(year: state.year - 1, month: 12);
    } else {
      state = state.copyWith(month: state.month - 1);
    }
  }

  void nextMonth() {
    if (state.month == 12) {
      state = AttendanceMonthFilter(year: state.year + 1, month: 1);
    } else {
      state = state.copyWith(month: state.month + 1);
    }
  }
}

final attendanceMonthFilterProvider =
    NotifierProvider<AttendanceMonthFilterNotifier, AttendanceMonthFilter>(
  AttendanceMonthFilterNotifier.new,
);

String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final myAttendanceCalendarProvider =
    FutureProvider.autoDispose<Map<String, AttendanceCalendarDay>>((ref) async {
  final filter = ref.watch(attendanceMonthFilterProvider);
  final from = DateTime(filter.year, filter.month, 1);
  final to = DateTime(filter.year, filter.month + 1, 0);
  return ref.watch(attendanceRepositoryProvider).getMyCalendar(
        from: _formatDate(from),
        to: _formatDate(to),
      );
});

class SelectedAttendanceDay extends Notifier<String?> {
  @override
  String? build() => _formatDate(DateTime.now());

  void set(String date) => state = date;
}

final selectedAttendanceDayProvider =
    NotifierProvider<SelectedAttendanceDay, String?>(SelectedAttendanceDay.new);

final myAttendanceDayProvider =
    FutureProvider.autoDispose<AttendanceMyDay>((ref) async {
  final date = ref.watch(selectedAttendanceDayProvider);
  if (date == null) {
    throw StateError('No date selected');
  }
  return ref.watch(attendanceRepositoryProvider).getMyDay(date: date);
});

class AdminAttendanceDateFilter extends Notifier<String> {
  @override
  String build() => _formatDate(DateTime.now());

  void set(String date) => state = date;
}

final adminAttendanceDateProvider =
    NotifierProvider<AdminAttendanceDateFilter, String>(
  AdminAttendanceDateFilter.new,
);

final adminAttendanceDayProvider =
    FutureProvider.autoDispose<List<AdminAttendanceEmployeeRow>>((ref) async {
  final date = ref.watch(adminAttendanceDateProvider);
  return ref.watch(attendanceRepositoryProvider).getAdminDay(date: date);
});

final adminAttendancePolicyProvider =
    FutureProvider.autoDispose<AttendancePolicy>((ref) async {
  return ref.watch(attendanceRepositoryProvider).getAdminPolicy();
});

class AdminEmployeeHistoryMonthFilter extends Notifier<AttendanceMonthFilter> {
  @override
  AttendanceMonthFilter build() {
    final now = DateTime.now();
    return AttendanceMonthFilter(year: now.year, month: now.month);
  }

  void setMonth(int year, int month) =>
      state = AttendanceMonthFilter(year: year, month: month);

  void previousMonth() {
    if (state.month == 1) {
      state = AttendanceMonthFilter(year: state.year - 1, month: 12);
    } else {
      state = AttendanceMonthFilter(year: state.year, month: state.month - 1);
    }
  }

  void nextMonth() {
    if (state.month == 12) {
      state = AttendanceMonthFilter(year: state.year + 1, month: 1);
    } else {
      state = AttendanceMonthFilter(year: state.year, month: state.month + 1);
    }
  }
}

final adminEmployeeHistoryMonthProvider =
    NotifierProvider<AdminEmployeeHistoryMonthFilter, AttendanceMonthFilter>(
  AdminEmployeeHistoryMonthFilter.new,
);

final adminEmployeeHistoryProvider = FutureProvider.autoDispose
    .family<AdminAttendanceEmployeeHistory, int>((ref, employeeId) async {
  final filter = ref.watch(adminEmployeeHistoryMonthProvider);
  final from = DateTime(filter.year, filter.month, 1);
  final to = DateTime(filter.year, filter.month + 1, 0);
  return ref.watch(attendanceRepositoryProvider).getAdminEmployeeHistory(
        employeeId: employeeId,
        from: _formatDate(from),
        to: _formatDate(to),
      );
});

void invalidateAttendanceSelfData(WidgetRef ref) {
  ref.invalidate(myAttendanceCalendarProvider);
  ref.invalidate(myAttendanceDayProvider);
}

void invalidateAttendanceAdminData(WidgetRef ref) {
  ref.invalidate(adminAttendanceDayProvider);
  ref.invalidate(adminAttendancePolicyProvider);
  ref.invalidate(adminEmployeeHistoryProvider);
}
