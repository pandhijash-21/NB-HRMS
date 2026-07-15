import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../profile/domain/profile_models.dart';
import '../data/admin_repository.dart';
import '../domain/admin_models.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(dioClient: ref.watch(dioClientProvider));
});

class WorkforceFilterState {
  final String search;
  final String status;
  final int page;
  final int limit;

  const WorkforceFilterState({
    required this.search,
    required this.status,
    required this.page,
    required this.limit,
  });

  WorkforceFilterState copyWith({
    String? search,
    String? status,
    int? page,
    int? limit,
  }) {
    return WorkforceFilterState(
      search: search ?? this.search,
      status: status ?? this.status,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }
}

class WorkforceFilterNotifier extends Notifier<WorkforceFilterState> {
  @override
  WorkforceFilterState build() => const WorkforceFilterState(
        search: '',
        status: '',
        page: 0,
        limit: 10,
      );

  void setSearch(String search) {
    state = state.copyWith(search: search, page: 0);
  }

  void setStatus(String status) {
    state = state.copyWith(status: status, page: 0);
  }

  void setPage(int page) {
    state = state.copyWith(page: page);
  }
}

final workforceFilterProvider = NotifierProvider<WorkforceFilterNotifier, WorkforceFilterState>(
  WorkforceFilterNotifier.new,
);

class WorkforceListNotifier extends AsyncNotifier<Map<String, dynamic>> {
  @override
  FutureOr<Map<String, dynamic>> build() {
    final filters = ref.watch(workforceFilterProvider);
    return ref.read(adminRepositoryProvider).listEmployees(
          limit: filters.limit,
          offset: filters.page * filters.limit,
          search: filters.search,
          status: filters.status,
        );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      final filters = ref.read(workforceFilterProvider);
      return ref.read(adminRepositoryProvider).listEmployees(
            limit: filters.limit,
            offset: filters.page * filters.limit,
            search: filters.search,
            status: filters.status,
          );
    });
  }

  Future<void> deleteEmployee(int employeeId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(adminRepositoryProvider).deleteEmployee(employeeId);
      final filters = ref.read(workforceFilterProvider);
      return ref.read(adminRepositoryProvider).listEmployees(
            limit: filters.limit,
            offset: filters.page * filters.limit,
            search: filters.search,
            status: filters.status,
          );
    });
  }

  Future<EmployeeProfile> createEmployee(Map<String, dynamic> data) async {
    final created = await ref.read(adminRepositoryProvider).createEmployee(data);
    final name = created.generalInfo?.fullName.trim() ?? '';
    ref.read(workforceFilterProvider.notifier).setSearch(name);
    return created;
  }
}

final workforceListProvider = AsyncNotifierProvider<WorkforceListNotifier, Map<String, dynamic>>(
  WorkforceListNotifier.new,
);

/// Fetch assignment history of an employee.
final employeeAssignmentsProvider = FutureProvider.family.autoDispose<List<EmployeeAssignment>, int>((ref, employeeId) async {
  return ref.watch(adminRepositoryProvider).listAssignments(employeeId);
});

/// Holds active status filter for change requests queue.
class ApprovalsFilter extends Notifier<String> {
  @override
  String build() => 'PENDING';

  void set(String status) => state = status;
}

final approvalsFilterProvider = NotifierProvider<ApprovalsFilter, String>(ApprovalsFilter.new);

/// List approvals queue.
final approvalsQueueProvider = FutureProvider.autoDispose<List<ChangeRequest>>((ref) async {
  final status = ref.watch(approvalsFilterProvider);
  final actualStatus = status == 'ALL' ? null : status;
  return ref.watch(adminRepositoryProvider).listApprovals(status: actualStatus);
});
