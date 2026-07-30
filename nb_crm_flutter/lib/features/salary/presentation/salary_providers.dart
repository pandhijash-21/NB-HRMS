import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attendance/presentation/attendance_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/salary_repository.dart';
import '../domain/salary_models.dart';

final salaryRepositoryProvider = Provider<SalaryRepository>((ref) {
  return SalaryRepository(dioClient: ref.watch(dioClientProvider));
});

final payCommissionsProvider =
    FutureProvider.autoDispose<List<PayCommission>>((ref) async {
  return ref.watch(salaryRepositoryProvider).listPayCommissions();
});

final payCommissionProvider = FutureProvider.autoDispose
    .family<PayCommission, String>((ref, id) async {
  return ref.watch(salaryRepositoryProvider).getPayCommission(id);
});

final salaryStructureStatusProvider =
    FutureProvider.autoDispose<List<SalaryStructureStatus>>((ref) async {
  return ref.watch(salaryRepositoryProvider).getStructureStatus();
});

typedef SalaryTemplateKey = ({String designationId, String commissionCode});

final salaryTemplateProvider = FutureProvider.autoDispose
    .family<SalaryTemplateBundle, SalaryTemplateKey>((ref, key) async {
  return ref.watch(salaryRepositoryProvider).getTemplateByDesignation(
        key.designationId,
        key.commissionCode,
      );
});

final salaryTemplateRulesProvider =
    FutureProvider.autoDispose.family<List<SalaryRule>, String>((ref, templateId) async {
  return ref.watch(salaryRepositoryProvider).getTemplateRules(templateId);
});

class SalaryRecordsFilter {
  const SalaryRecordsFilter({
    this.employeeId,
    this.salaryMonth,
    this.salaryYear,
    this.status = '',
  });

  final int? employeeId;
  final int? salaryMonth;
  final int? salaryYear;
  final String status;

  SalaryRecordsFilter copyWith({
    int? employeeId,
    int? salaryMonth,
    int? salaryYear,
    String? status,
    bool clearEmployeeId = false,
    bool clearMonth = false,
    bool clearYear = false,
  }) {
    return SalaryRecordsFilter(
      employeeId: clearEmployeeId ? null : (employeeId ?? this.employeeId),
      salaryMonth: clearMonth ? null : (salaryMonth ?? this.salaryMonth),
      salaryYear: clearYear ? null : (salaryYear ?? this.salaryYear),
      status: status ?? this.status,
    );
  }
}

class SalaryRecordsFilterNotifier extends Notifier<SalaryRecordsFilter> {
  @override
  SalaryRecordsFilter build() => const SalaryRecordsFilter();

  void setEmployeeId(int? id) =>
      state = state.copyWith(employeeId: id, clearEmployeeId: id == null);

  void setMonth(int? month) =>
      state = state.copyWith(salaryMonth: month, clearMonth: month == null);

  void setYear(int? year) =>
      state = state.copyWith(salaryYear: year, clearYear: year == null);

  void setStatus(String status) => state = state.copyWith(status: status);
}

final salaryRecordsFilterProvider =
    NotifierProvider<SalaryRecordsFilterNotifier, SalaryRecordsFilter>(
  SalaryRecordsFilterNotifier.new,
);

final salaryRecordsProvider =
    FutureProvider.autoDispose<List<SalaryRecord>>((ref) async {
  final filters = ref.watch(salaryRecordsFilterProvider);
  return ref.watch(salaryRepositoryProvider).listRecords(
        employeeId: filters.employeeId,
        salaryMonth: filters.salaryMonth,
        salaryYear: filters.salaryYear,
        status: filters.status.isEmpty ? null : filters.status,
      );
});

final salarySlipProvider =
    FutureProvider.autoDispose.family<SalarySlip, String>((ref, recordId) async {
  return ref.watch(salaryRepositoryProvider).getSlip(recordId);
});

final salaryEmployeesProvider =
    FutureProvider.autoDispose<List<SalaryEmployeeOption>>((ref) async {
  return ref.watch(salaryRepositoryProvider).listEmployeesForEntry();
});

final employeeSalaryProfileProvider = FutureProvider.autoDispose
    .family<EmployeeSalaryProfileResponse, int>((ref, employeeId) async {
  return ref.watch(salaryRepositoryProvider).getEmployeeProfile(employeeId);
});

final employeeSalaryMonthlyOverviewProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({int employeeId, int year, int month})>(
        (ref, params) async {
  return ref.watch(salaryRepositoryProvider).getEmployeeMonthlyOverview(
        employeeId: params.employeeId,
        year: params.year,
        month: params.month,
      );
});

typedef EmployeeSalarySlipParams = ({int employeeId, String recordId});

final employeeSalarySlipProvider = FutureProvider.autoDispose
    .family<SalarySlip, EmployeeSalarySlipParams>((ref, params) async {
  return ref.watch(salaryRepositoryProvider).getEmployeeSlip(
        employeeId: params.employeeId,
        recordId: params.recordId,
      );
});

class ProfileSalaryMonthFilter extends Notifier<AttendanceMonthFilter> {
  @override
  AttendanceMonthFilter build() {
    final now = DateTime.now();
    return AttendanceMonthFilter(year: now.year, month: now.month);
  }

  void setMonth(int year, int month) =>
      state = AttendanceMonthFilter(year: year, month: month);
}

final profileSalaryMonthProvider =
    NotifierProvider<ProfileSalaryMonthFilter, AttendanceMonthFilter>(
  ProfileSalaryMonthFilter.new,
);

final employeeSalaryPreviewProvider = FutureProvider.autoDispose
    .family<EmployeeSalaryPreview, int>((ref, employeeId) async {
  return ref.watch(salaryRepositoryProvider).getEmployeeSalaryPreview(employeeId);
});

typedef SalaryEntryPeriod = ({int employeeId, int month, int year});

final salaryEntryRecordsProvider = FutureProvider.autoDispose
    .family<List<SalaryRecord>, SalaryEntryPeriod>((ref, period) async {
  return ref.watch(salaryRepositoryProvider).listRecords(
        employeeId: period.employeeId,
        salaryMonth: period.month,
        salaryYear: period.year,
      );
});

void invalidateSalaryCommissions(WidgetRef ref) {
  ref.invalidate(payCommissionsProvider);
}

void invalidateSalaryCommission(WidgetRef ref, String id) {
  ref.invalidate(payCommissionProvider(id));
  ref.invalidate(payCommissionsProvider);
}

void invalidateSalaryStructures(WidgetRef ref) {
  ref.invalidate(salaryStructureStatusProvider);
}

void invalidateSalaryTemplate(WidgetRef ref, SalaryTemplateKey key) {
  ref.invalidate(salaryTemplateProvider(key));
  final templateId = ref.read(salaryTemplateProvider(key)).value?.template?.id;
  if (templateId != null) {
    ref.invalidate(salaryTemplateRulesProvider(templateId));
  }
  ref.invalidate(salaryStructureStatusProvider);
}

void invalidateSalaryRecords(WidgetRef ref) {
  ref.invalidate(salaryRecordsProvider);
}

class PayrollMonthFilter {
  const PayrollMonthFilter({required this.year, required this.month});
  final int year;
  final int month;

  @override
  bool operator ==(Object other) =>
      other is PayrollMonthFilter && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

class PayrollMonthFilterNotifier extends Notifier<PayrollMonthFilter> {
  @override
  PayrollMonthFilter build() {
    final now = DateTime.now();
    return PayrollMonthFilter(year: now.year, month: now.month);
  }

  void setMonth(int year, int month) => state = PayrollMonthFilter(year: year, month: month);
}

final payrollMonthFilterProvider =
    NotifierProvider<PayrollMonthFilterNotifier, PayrollMonthFilter>(
  PayrollMonthFilterNotifier.new,
);

final payrollMonthProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, PayrollMonthFilter>((ref, filter) async {
  return ref.watch(salaryRepositoryProvider).getMonthPayroll(
        year: filter.year,
        month: filter.month,
      );
});

void invalidateSalaryAll(WidgetRef ref) {
  invalidateSalaryCommissions(ref);
  invalidateSalaryStructures(ref);
  invalidateSalaryRecords(ref);
  ref.invalidate(payrollMonthProvider);
}
