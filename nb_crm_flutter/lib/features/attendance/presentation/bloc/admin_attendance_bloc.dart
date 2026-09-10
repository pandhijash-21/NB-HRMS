import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/attendance_repository.dart';
import '../../domain/attendance_models.dart';

String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class AdminAttendanceEvent extends Equatable {
  const AdminAttendanceEvent();

  @override
  List<Object?> get props => [];
}

class AdminAttendanceLoadRequested extends AdminAttendanceEvent {
  const AdminAttendanceLoadRequested();
}

class AdminAttendanceDateChanged extends AdminAttendanceEvent {
  const AdminAttendanceDateChanged(this.date);
  final String date;

  @override
  List<Object?> get props => [date];
}

class AdminAttendanceRefreshRequested extends AdminAttendanceEvent {
  const AdminAttendanceRefreshRequested();
}

class AdminAttendancePunchAdded extends AdminAttendanceEvent {
  const AdminAttendancePunchAdded({
    required this.employeeId,
    required this.punchAt,
    this.punchType,
    this.terminalId,
  });

  final int employeeId;
  final String punchAt;
  final String? punchType;
  final String? terminalId;

  @override
  List<Object?> get props => [employeeId, punchAt, punchType, terminalId];
}

class AdminAttendancePunchUpdated extends AdminAttendanceEvent {
  const AdminAttendancePunchUpdated({
    required this.punchId,
    required this.punchAt,
    this.punchType,
    this.terminalId,
  });

  final String punchId;
  final String punchAt;
  final String? punchType;
  final String? terminalId;

  @override
  List<Object?> get props => [punchId, punchAt, punchType, terminalId];
}

class AdminAttendancePolicyUpdated extends AdminAttendanceEvent {
  const AdminAttendancePolicyUpdated(this.body);
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [body];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class AdminAttendanceState extends Equatable {
  const AdminAttendanceState({
    this.status = LoadStatus.initial,
    this.date = '',
    this.rows = const [],
    this.policy,
    this.isActing = false,
    this.errorMessage,
    this.actionMessage,
  });

  final LoadStatus status;
  final String date;
  final List<AdminAttendanceEmployeeRow> rows;
  final AttendancePolicy? policy;
  final bool isActing;
  final String? errorMessage;
  final String? actionMessage;

  AdminAttendanceState copyWith({
    LoadStatus? status,
    String? date,
    List<AdminAttendanceEmployeeRow>? rows,
    AttendancePolicy? policy,
    bool? isActing,
    String? errorMessage,
    String? actionMessage,
  }) {
    return AdminAttendanceState(
      status: status ?? this.status,
      date: date ?? this.date,
      rows: rows ?? this.rows,
      policy: policy ?? this.policy,
      isActing: isActing ?? this.isActing,
      errorMessage: errorMessage,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        date,
        rows,
        policy,
        isActing,
        errorMessage,
        actionMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class AdminAttendanceBloc
    extends Bloc<AdminAttendanceEvent, AdminAttendanceState> {
  AdminAttendanceBloc({required AttendanceRepository attendanceRepository})
      : _attendanceRepository = attendanceRepository,
        super(AdminAttendanceState(date: _formatDate(DateTime.now()))) {
    on<AdminAttendanceLoadRequested>(_onLoad);
    on<AdminAttendanceDateChanged>(_onDateChanged);
    on<AdminAttendanceRefreshRequested>(_onRefresh);
    on<AdminAttendancePunchAdded>(_onPunchAdded);
    on<AdminAttendancePunchUpdated>(_onPunchUpdated);
    on<AdminAttendancePolicyUpdated>(_onPolicyUpdated);
  }

  final AttendanceRepository _attendanceRepository;

  Future<void> _fetchData(
    Emitter<AdminAttendanceState> emit, {
    required String date,
  }) async {
    try {
      final results = await Future.wait([
        _attendanceRepository.getAdminDay(date: date),
        _attendanceRepository.getAdminPolicy(),
      ]);

      emit(state.copyWith(
        status: LoadStatus.success,
        date: date,
        rows: results[0] as List<AdminAttendanceEmployeeRow>,
        policy: results[1] as AttendancePolicy,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoad(
    AdminAttendanceLoadRequested event,
    Emitter<AdminAttendanceState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    await _fetchData(emit, date: state.date);
  }

  Future<void> _onDateChanged(
    AdminAttendanceDateChanged event,
    Emitter<AdminAttendanceState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, date: event.date));
    await _fetchData(emit, date: event.date);
  }

  Future<void> _onRefresh(
    AdminAttendanceRefreshRequested event,
    Emitter<AdminAttendanceState> emit,
  ) async {
    await _fetchData(emit, date: state.date);
  }

  Future<void> _onPunchAdded(
    AdminAttendancePunchAdded event,
    Emitter<AdminAttendanceState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _attendanceRepository.adminAddPunch(
        employeeId: event.employeeId,
        punchAt: event.punchAt,
        punchType: event.punchType,
        terminalId: event.terminalId,
      );
      emit(state.copyWith(
        isActing: false,
        actionMessage: 'Punch added successfully',
      ));
      await _fetchData(emit, date: state.date);
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onPunchUpdated(
    AdminAttendancePunchUpdated event,
    Emitter<AdminAttendanceState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _attendanceRepository.adminUpdatePunch(
        punchId: event.punchId,
        punchAt: event.punchAt,
        punchType: event.punchType,
        terminalId: event.terminalId,
      );
      emit(state.copyWith(
        isActing: false,
        actionMessage: 'Punch updated successfully',
      ));
      await _fetchData(emit, date: state.date);
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onPolicyUpdated(
    AdminAttendancePolicyUpdated event,
    Emitter<AdminAttendanceState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _attendanceRepository.updateAdminPolicy(event.body);
      emit(state.copyWith(
        isActing: false,
        actionMessage: 'Policy saved successfully',
      ));
      await _fetchData(emit, date: state.date);
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }
}
