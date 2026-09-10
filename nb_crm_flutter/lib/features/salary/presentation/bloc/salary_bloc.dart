import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/salary_repository.dart';
import '../../domain/salary_models.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class SalaryEvent extends Equatable {
  const SalaryEvent();

  @override
  List<Object?> get props => [];
}

class SalaryLoadRequested extends SalaryEvent {
  const SalaryLoadRequested();
}

class SalaryRefreshRequested extends SalaryEvent {
  const SalaryRefreshRequested();
}

class SalaryRecordsFilterChanged extends SalaryEvent {
  const SalaryRecordsFilterChanged({
    this.employeeId,
    this.salaryMonth,
    this.salaryYear,
    this.status,
  });

  final int? employeeId;
  final int? salaryMonth;
  final int? salaryYear;
  final String? status;

  @override
  List<Object?> get props => [employeeId, salaryMonth, salaryYear, status];
}

class SalaryRecordsEmployeeIdChanged extends SalaryEvent {
  const SalaryRecordsEmployeeIdChanged(this.employeeId);
  final int? employeeId;

  @override
  List<Object?> get props => [employeeId];
}

class SalaryRecordsMonthChanged extends SalaryEvent {
  const SalaryRecordsMonthChanged(this.month);
  final int? month;

  @override
  List<Object?> get props => [month];
}

class SalaryRecordsYearChanged extends SalaryEvent {
  const SalaryRecordsYearChanged(this.year);
  final int? year;

  @override
  List<Object?> get props => [year];
}

class SalaryRecordsStatusChanged extends SalaryEvent {
  const SalaryRecordsStatusChanged(this.status);
  final String status;

  @override
  List<Object?> get props => [status];
}

class PayrollMonthChanged extends SalaryEvent {
  const PayrollMonthChanged({required this.year, required this.month});
  final int year;
  final int month;

  @override
  List<Object?> get props => [year, month];
}

class SalaryRecordPaymentToggled extends SalaryEvent {
  const SalaryRecordPaymentToggled({
    required this.recordId,
    required this.markPaid,
  });

  final String recordId;
  final bool markPaid;

  @override
  List<Object?> get props => [recordId, markPaid];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class SalaryState extends Equatable {
  const SalaryState({
    this.status = LoadStatus.initial,
    this.commissions = const [],
    this.structureStatuses = const [],
    this.records = const [],
    this.filterEmployeeId,
    this.filterMonth,
    this.filterYear,
    this.filterStatus = '',
    this.payrollYear = 0,
    this.payrollMonth = 0,
    this.payrollData,
    this.isActing = false,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  final LoadStatus status;
  final List<PayCommission> commissions;
  final List<SalaryStructureStatus> structureStatuses;
  final List<SalaryRecord> records;
  final int? filterEmployeeId;
  final int? filterMonth;
  final int? filterYear;
  final String filterStatus;
  final int payrollYear;
  final int payrollMonth;
  final Map<String, dynamic>? payrollData;
  final bool isActing;
  final String? errorMessage;
  final String? actionSuccessMessage;

  SalaryState copyWith({
    LoadStatus? status,
    List<PayCommission>? commissions,
    List<SalaryStructureStatus>? structureStatuses,
    List<SalaryRecord>? records,
    int? filterEmployeeId,
    bool clearEmployeeId = false,
    int? filterMonth,
    bool clearMonth = false,
    int? filterYear,
    bool clearYear = false,
    String? filterStatus,
    int? payrollYear,
    int? payrollMonth,
    Map<String, dynamic>? payrollData,
    bool? isActing,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return SalaryState(
      status: status ?? this.status,
      commissions: commissions ?? this.commissions,
      structureStatuses: structureStatuses ?? this.structureStatuses,
      records: records ?? this.records,
      filterEmployeeId: clearEmployeeId ? null : (filterEmployeeId ?? this.filterEmployeeId),
      filterMonth: clearMonth ? null : (filterMonth ?? this.filterMonth),
      filterYear: clearYear ? null : (filterYear ?? this.filterYear),
      filterStatus: filterStatus ?? this.filterStatus,
      payrollYear: payrollYear ?? this.payrollYear,
      payrollMonth: payrollMonth ?? this.payrollMonth,
      payrollData: payrollData ?? this.payrollData,
      isActing: isActing ?? this.isActing,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        commissions,
        structureStatuses,
        records,
        filterEmployeeId,
        filterMonth,
        filterYear,
        filterStatus,
        payrollYear,
        payrollMonth,
        payrollData,
        isActing,
        errorMessage,
        actionSuccessMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class SalaryBloc extends Bloc<SalaryEvent, SalaryState> {
  SalaryBloc({required SalaryRepository salaryRepository})
      : _salaryRepository = salaryRepository,
        super(_initialState()) {
    on<SalaryLoadRequested>(_onLoad);
    on<SalaryRefreshRequested>(_onRefresh);
    on<SalaryRecordsFilterChanged>(_onFilterChanged);
    on<SalaryRecordsEmployeeIdChanged>(_onEmployeeIdChanged);
    on<SalaryRecordsMonthChanged>(_onMonthChanged);
    on<SalaryRecordsYearChanged>(_onYearChanged);
    on<SalaryRecordsStatusChanged>(_onStatusChanged);
    on<PayrollMonthChanged>(_onPayrollMonthChanged);
    on<SalaryRecordPaymentToggled>(_onPaymentToggled);
  }

  final SalaryRepository _salaryRepository;

  static SalaryState _initialState() {
    final now = DateTime.now();
    return SalaryState(
      payrollYear: now.year,
      payrollMonth: now.month,
      filterYear: now.year,
      filterMonth: now.month,
    );
  }

  Future<void> _fetchData(Emitter<SalaryState> emit) async {
    try {
      final results = await Future.wait([
        _salaryRepository.listPayCommissions(),
        _salaryRepository.getStructureStatus(),
        _salaryRepository.listRecords(
          employeeId: state.filterEmployeeId,
          salaryMonth: state.filterMonth,
          salaryYear: state.filterYear,
          status: state.filterStatus.isEmpty ? null : state.filterStatus,
        ),
        _salaryRepository.getMonthPayroll(
          year: state.payrollYear,
          month: state.payrollMonth,
        ),
      ]);

      emit(state.copyWith(
        status: LoadStatus.success,
        commissions: results[0] as List<PayCommission>,
        structureStatuses: results[1] as List<SalaryStructureStatus>,
        records: results[2] as List<SalaryRecord>,
        payrollData: results[3] as Map<String, dynamic>,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoad(
    SalaryLoadRequested event,
    Emitter<SalaryState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    await _fetchData(emit);
  }

  Future<void> _onRefresh(
    SalaryRefreshRequested event,
    Emitter<SalaryState> emit,
  ) async {
    await _fetchData(emit);
  }

  Future<void> _reloadRecords(
    Emitter<SalaryState> emit, {
    int? employeeId,
    bool clearEmployeeId = false,
    int? month,
    bool clearMonth = false,
    int? year,
    bool clearYear = false,
    String? status,
  }) async {
    final newEmpId = clearEmployeeId ? null : (employeeId ?? state.filterEmployeeId);
    final newMonth = clearMonth ? null : (month ?? state.filterMonth);
    final newYear = clearYear ? null : (year ?? state.filterYear);
    final newStatus = status ?? state.filterStatus;

    emit(state.copyWith(
      status: LoadStatus.loading,
      filterEmployeeId: newEmpId,
      clearEmployeeId: clearEmployeeId,
      filterMonth: newMonth,
      clearMonth: clearMonth,
      filterYear: newYear,
      clearYear: clearYear,
      filterStatus: newStatus,
    ));

    try {
      final recs = await _salaryRepository.listRecords(
        employeeId: newEmpId,
        salaryMonth: newMonth,
        salaryYear: newYear,
        status: newStatus.isEmpty ? null : newStatus,
      );
      emit(state.copyWith(status: LoadStatus.success, records: recs));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onFilterChanged(
    SalaryRecordsFilterChanged event,
    Emitter<SalaryState> emit,
  ) async {
    await _reloadRecords(
      emit,
      employeeId: event.employeeId,
      clearEmployeeId: event.employeeId == null,
      month: event.salaryMonth,
      clearMonth: event.salaryMonth == null,
      year: event.salaryYear,
      clearYear: event.salaryYear == null,
      status: event.status,
    );
  }

  Future<void> _onEmployeeIdChanged(
    SalaryRecordsEmployeeIdChanged event,
    Emitter<SalaryState> emit,
  ) async {
    await _reloadRecords(
      emit,
      employeeId: event.employeeId,
      clearEmployeeId: event.employeeId == null,
    );
  }

  Future<void> _onMonthChanged(
    SalaryRecordsMonthChanged event,
    Emitter<SalaryState> emit,
  ) async {
    await _reloadRecords(
      emit,
      month: event.month,
      clearMonth: event.month == null,
    );
  }

  Future<void> _onYearChanged(
    SalaryRecordsYearChanged event,
    Emitter<SalaryState> emit,
  ) async {
    await _reloadRecords(
      emit,
      year: event.year,
      clearYear: event.year == null,
    );
  }

  Future<void> _onStatusChanged(
    SalaryRecordsStatusChanged event,
    Emitter<SalaryState> emit,
  ) async {
    await _reloadRecords(emit, status: event.status);
  }

  Future<void> _onPayrollMonthChanged(
    PayrollMonthChanged event,
    Emitter<SalaryState> emit,
  ) async {
    emit(state.copyWith(
      status: LoadStatus.loading,
      payrollYear: event.year,
      payrollMonth: event.month,
    ));
    try {
      final data = await _salaryRepository.getMonthPayroll(
        year: event.year,
        month: event.month,
      );
      emit(state.copyWith(status: LoadStatus.success, payrollData: data));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onPaymentToggled(
    SalaryRecordPaymentToggled event,
    Emitter<SalaryState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      if (event.markPaid) {
        await _salaryRepository.markRecordPaid(event.recordId);
      } else {
        await _salaryRepository.markRecordUnpaid(event.recordId);
      }
      emit(state.copyWith(
        isActing: false,
        actionSuccessMessage: event.markPaid ? 'Marked paid' : 'Marked unpaid',
      ));
      // Refresh payroll month data & records
      final results = await Future.wait([
        _salaryRepository.listRecords(
          employeeId: state.filterEmployeeId,
          salaryMonth: state.filterMonth,
          salaryYear: state.filterYear,
          status: state.filterStatus.isEmpty ? null : state.filterStatus,
        ),
        _salaryRepository.getMonthPayroll(
          year: state.payrollYear,
          month: state.payrollMonth,
        ),
      ]);
      emit(state.copyWith(
        records: results[0] as List<SalaryRecord>,
        payrollData: results[1] as Map<String, dynamic>,
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }
}
