import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/leave_repository.dart';
import '../domain/leave_models.dart';

final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  return LeaveRepository(dioClient: ref.watch(dioClientProvider));
});

class LeaveYearFilter extends Notifier<int> {
  @override
  int build() => DateTime.now().year;

  void set(int year) => state = year;
}

final leaveYearFilterProvider =
    NotifierProvider<LeaveYearFilter, int>(LeaveYearFilter.new);

final leaveTypesProvider =
    FutureProvider.autoDispose<List<LeaveType>>((ref) async {
  return ref.watch(leaveRepositoryProvider).getLeaveTypes();
});

/// Merges leave types with balance rows so every active type shows (0 if missing).
final leaveBalancesProvider =
    FutureProvider.autoDispose<List<LeaveBalance>>((ref) async {
  final year = ref.watch(leaveYearFilterProvider);
  final repo = ref.watch(leaveRepositoryProvider);
  final types = await repo.getLeaveTypes();
  final balances = await repo.getMyBalances(year: year);
  final byType = {for (final b in balances) b.leaveTypeId: b};

  return types.where((t) => t.isActive).map((t) {
    final bal = byType[t.id];
    if (bal != null) {
      return LeaveBalance(
        id: bal.id,
        employeeId: bal.employeeId,
        leaveTypeId: t.id,
        year: bal.year,
        totalCredited: bal.totalCredited,
        carryForward: bal.carryForward,
        used: bal.used,
        pending: bal.pending,
        leaveType: t,
      );
    }
    return LeaveBalance(
      id: t.id,
      employeeId: 0,
      leaveTypeId: t.id,
      year: year,
      totalCredited: 0,
      carryForward: 0,
      used: 0,
      pending: 0,
      leaveType: t,
    );
  }).toList();
});

class MyApplicationsFilter {
  const MyApplicationsFilter({
    this.status = '',
    this.year,
    this.page = 0,
    this.limit = 20,
  });

  final String status;
  final int? year;
  final int page;
  final int limit;

  MyApplicationsFilter copyWith({
    String? status,
    int? year,
    int? page,
    int? limit,
  }) {
    return MyApplicationsFilter(
      status: status ?? this.status,
      year: year ?? this.year,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }
}

class MyApplicationsFilterNotifier extends Notifier<MyApplicationsFilter> {
  @override
  MyApplicationsFilter build() => const MyApplicationsFilter();

  void setStatus(String status) =>
      state = state.copyWith(status: status, page: 0);

  void setYear(int? year) => state = state.copyWith(year: year, page: 0);

  void setPage(int page) => state = state.copyWith(page: page);
}

final myApplicationsFilterProvider =
    NotifierProvider<MyApplicationsFilterNotifier, MyApplicationsFilter>(
  MyApplicationsFilterNotifier.new,
);

final myApplicationsProvider =
    FutureProvider.autoDispose<LeaveApplicationsPage>((ref) async {
  final filters = ref.watch(myApplicationsFilterProvider);
  return ref.watch(leaveRepositoryProvider).getMyApplications(
        status: filters.status.isEmpty ? null : filters.status,
        year: filters.year,
        page: filters.page,
        limit: filters.limit,
      );
});

final pendingApprovalsProvider =
    FutureProvider.autoDispose<List<LeaveApplication>>((ref) async {
  return ref.watch(leaveRepositoryProvider).getPendingApprovals();
});

class AdminApplicationsFilter {
  const AdminApplicationsFilter({
    this.status = '',
    this.year,
    this.search = '',
    this.page = 0,
    this.limit = 20,
  });

  final String status;
  final int? year;
  final String search;
  final int page;
  final int limit;

  AdminApplicationsFilter copyWith({
    String? status,
    int? year,
    String? search,
    int? page,
    int? limit,
  }) {
    return AdminApplicationsFilter(
      status: status ?? this.status,
      year: year ?? this.year,
      search: search ?? this.search,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }
}

class AdminApplicationsFilterNotifier
    extends Notifier<AdminApplicationsFilter> {
  @override
  AdminApplicationsFilter build() =>
      AdminApplicationsFilter(year: DateTime.now().year);

  void setStatus(String status) =>
      state = state.copyWith(status: status, page: 0);

  void setYear(int? year) => state = state.copyWith(year: year, page: 0);

  void setSearch(String search) =>
      state = state.copyWith(search: search, page: 0);

  void setPage(int page) => state = state.copyWith(page: page);
}

final adminApplicationsFilterProvider =
    NotifierProvider<AdminApplicationsFilterNotifier, AdminApplicationsFilter>(
  AdminApplicationsFilterNotifier.new,
);

final adminApplicationsProvider =
    FutureProvider.autoDispose<LeaveApplicationsPage>((ref) async {
  final filters = ref.watch(adminApplicationsFilterProvider);
  final page = await ref.watch(leaveRepositoryProvider).getAdminApplications(
        status: filters.status.isEmpty ? null : filters.status,
        year: filters.year,
        page: filters.page,
        limit: filters.limit,
      );
  final q = filters.search.trim().toLowerCase();
  if (q.isEmpty) return page;
  final filtered = page.items.where((a) {
    final name = a.employee?.fullName?.toLowerCase() ?? '';
    final code = a.employee?.employeeCode?.toLowerCase() ?? '';
    final no = a.applicationNo.toLowerCase();
    final type = a.leaveType?.name.toLowerCase() ?? '';
    return name.contains(q) ||
        code.contains(q) ||
        no.contains(q) ||
        type.contains(q) ||
        '${a.employee?.id ?? ''}'.contains(q);
  }).toList();
  return LeaveApplicationsPage(items: filtered, total: filtered.length);
});

final adminLeaveTypesProvider =
    FutureProvider.autoDispose<List<LeaveType>>((ref) async {
  return ref.watch(leaveRepositoryProvider).getAdminTypes();
});

final adminEmployeeBalancesProvider = FutureProvider.autoDispose
    .family<List<LeaveBalance>, ({int employeeId, int year})>((ref, args) async {
  final repo = ref.watch(leaveRepositoryProvider);
  final types = await repo.getAdminTypes();
  final balances =
      await repo.getAdminEmployeeBalances(args.employeeId, year: args.year);
  final byType = {for (final b in balances) b.leaveTypeId: b};
  return types.where((t) => t.isActive).map((t) {
    final bal = byType[t.id];
    if (bal != null) {
      return LeaveBalance(
        id: bal.id,
        employeeId: bal.employeeId,
        leaveTypeId: t.id,
        year: bal.year,
        totalCredited: bal.totalCredited,
        carryForward: bal.carryForward,
        used: bal.used,
        pending: bal.pending,
        leaveType: t,
      );
    }
    return LeaveBalance(
      id: t.id,
      employeeId: args.employeeId,
      leaveTypeId: t.id,
      year: args.year,
      totalCredited: 0,
      carryForward: 0,
      used: 0,
      pending: 0,
      leaveType: t,
    );
  }).toList();
});

final adminEmployeeApplicationsProvider = FutureProvider.autoDispose
    .family<LeaveApplicationsPage, ({int employeeId, int year, int page})>(
        (ref, args) async {
  return ref.watch(leaveRepositoryProvider).getAdminApplications(
        employeeId: args.employeeId,
        year: args.year,
        page: args.page,
        limit: 8,
      );
});

final adminLeaveSettingsProvider =
    FutureProvider.autoDispose<List<LeaveSetting>>((ref) async {
  return ref.watch(leaveRepositoryProvider).getAdminSettings();
});

class HolidaysYearFilter extends Notifier<int> {
  @override
  int build() => DateTime.now().year;

  void set(int year) => state = year;
}

final holidaysYearFilterProvider =
    NotifierProvider<HolidaysYearFilter, int>(HolidaysYearFilter.new);

final adminHolidaysProvider =
    FutureProvider.autoDispose<List<PublicHoliday>>((ref) async {
  final year = ref.watch(holidaysYearFilterProvider);
  return ref.watch(leaveRepositoryProvider).getAdminHolidays(year: year);
});

void invalidateLeaveSelfData(WidgetRef ref) {
  ref.invalidate(leaveBalancesProvider);
  ref.invalidate(myApplicationsProvider);
}

void invalidateLeaveApprovalData(WidgetRef ref) {
  ref.invalidate(pendingApprovalsProvider);
  ref.invalidate(adminApplicationsProvider);
}

void invalidateLeaveAdminData(WidgetRef ref) {
  ref.invalidate(adminApplicationsProvider);
  ref.invalidate(adminLeaveTypesProvider);
  ref.invalidate(adminLeaveSettingsProvider);
  ref.invalidate(adminHolidaysProvider);
  ref.invalidate(leaveBalancesProvider);
}
