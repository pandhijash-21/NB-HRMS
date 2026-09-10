import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/bloc/load_status.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/attendance_repository.dart';
import '../../domain/attendance_models.dart';
import '../geofenced_punch_service.dart';
import '../web_attendance_gate.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class AttendanceEvent extends Equatable {
  const AttendanceEvent();

  @override
  List<Object?> get props => [];
}

class AttendanceLoadRequested extends AttendanceEvent {
  const AttendanceLoadRequested({this.employeeId});
  final int? employeeId;

  @override
  List<Object?> get props => [employeeId];
}

class AttendanceMonthChanged extends AttendanceEvent {
  const AttendanceMonthChanged({required this.year, required this.month});
  final int year;
  final int month;

  @override
  List<Object?> get props => [year, month];
}

class AttendancePreviousMonthRequested extends AttendanceEvent {
  const AttendancePreviousMonthRequested();
}

class AttendanceNextMonthRequested extends AttendanceEvent {
  const AttendanceNextMonthRequested();
}

class AttendanceDateSelected extends AttendanceEvent {
  const AttendanceDateSelected(this.date);
  final String date;

  @override
  List<Object?> get props => [date];
}

class AttendanceRefreshRequested extends AttendanceEvent {
  const AttendanceRefreshRequested({this.employeeId});
  final int? employeeId;

  @override
  List<Object?> get props => [employeeId];
}

class AttendanceSettingsReloadRequested extends AttendanceEvent {
  const AttendanceSettingsReloadRequested(this.employeeId);
  final int employeeId;

  @override
  List<Object?> get props => [employeeId];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class AttendanceState extends Equatable {
  const AttendanceState({
    this.status = LoadStatus.initial,
    this.year = 0,
    this.month = 0,
    this.selectedDate = '',
    this.calendar = const {},
    this.dayDetail,
    this.isDayLoading = false,
    this.settings,
    this.hasLocalToken = false,
    this.webGate,
    this.errorMessage,
  });

  final LoadStatus status;
  final int year;
  final int month;
  final String selectedDate;
  final Map<String, AttendanceCalendarDay> calendar;
  final AttendanceMyDay? dayDetail;
  final bool isDayLoading;
  final EmployeeAttendanceSettings? settings;
  final bool hasLocalToken;
  final WebAttendanceStatus? webGate;
  final String? errorMessage;

  AttendanceState copyWith({
    LoadStatus? status,
    int? year,
    int? month,
    String? selectedDate,
    Map<String, AttendanceCalendarDay>? calendar,
    AttendanceMyDay? dayDetail,
    bool? isDayLoading,
    EmployeeAttendanceSettings? settings,
    bool? hasLocalToken,
    WebAttendanceStatus? webGate,
    String? errorMessage,
  }) {
    return AttendanceState(
      status: status ?? this.status,
      year: year ?? this.year,
      month: month ?? this.month,
      selectedDate: selectedDate ?? this.selectedDate,
      calendar: calendar ?? this.calendar,
      dayDetail: dayDetail ?? this.dayDetail,
      isDayLoading: isDayLoading ?? this.isDayLoading,
      settings: settings ?? this.settings,
      hasLocalToken: hasLocalToken ?? this.hasLocalToken,
      webGate: webGate ?? this.webGate,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        year,
        month,
        selectedDate,
        calendar,
        dayDetail,
        isDayLoading,
        settings,
        hasLocalToken,
        webGate,
        errorMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  AttendanceBloc({
    required AttendanceRepository attendanceRepository,
    required DioClient dioClient,
  })  : _attendanceRepository = attendanceRepository,
        _dioClient = dioClient,
        super(_initialState()) {
    on<AttendanceLoadRequested>(_onLoad);
    on<AttendanceMonthChanged>(_onMonthChanged);
    on<AttendancePreviousMonthRequested>(_onPreviousMonth);
    on<AttendanceNextMonthRequested>(_onNextMonth);
    on<AttendanceDateSelected>(_onDateSelected);
    on<AttendanceRefreshRequested>(_onRefresh);
    on<AttendanceSettingsReloadRequested>(_onSettingsReload);
  }

  final AttendanceRepository _attendanceRepository;
  final DioClient _dioClient;

  static AttendanceState _initialState() {
    final now = DateTime.now();
    return AttendanceState(
      year: now.year,
      month: now.month,
      selectedDate: _formatDate(now),
    );
  }

  Future<void> _fetchCalendar(
    Emitter<AttendanceState> emit, {
    required int year,
    required int month,
    required String selectedDate,
    int? employeeId,
  }) async {
    try {
      final from = DateTime(year, month, 1);
      final to = DateTime(year, month + 1, 0);

      final calFuture = _attendanceRepository.getMyCalendar(
        from: _formatDate(from),
        to: _formatDate(to),
      );
      final dayFuture = _attendanceRepository.getMyDay(date: selectedDate).catchError((_) => null);

      final cal = await calFuture;
      AttendanceMyDay? dayDetail;
      try {
        dayDetail = await dayFuture;
      } catch (_) {}

      EmployeeAttendanceSettings? settings = state.settings;
      bool hasLocal = state.hasLocalToken;
      WebAttendanceStatus? webGate = state.webGate;

      if (employeeId != null && employeeId > 0) {
        try {
          settings = await _attendanceRepository.getEmployeeSettings(employeeId);
        } catch (_) {}
        try {
          final svc = GeofencedPunchService(_dioClient);
          hasLocal = await svc.hasLocalToken(employeeId);
        } catch (_) {}
      }

      if (kIsWeb) {
        try {
          webGate = await WebAttendanceGate.evaluate();
        } catch (_) {}
      }

      emit(state.copyWith(
        status: LoadStatus.success,
        year: year,
        month: month,
        selectedDate: selectedDate,
        calendar: cal,
        dayDetail: dayDetail,
        isDayLoading: false,
        settings: settings,
        hasLocalToken: hasLocal,
        webGate: webGate,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoad(
    AttendanceLoadRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    await _fetchCalendar(
      emit,
      year: state.year,
      month: state.month,
      selectedDate: state.selectedDate,
      employeeId: event.employeeId,
    );
  }

  Future<void> _onRefresh(
    AttendanceRefreshRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    await _fetchCalendar(
      emit,
      year: state.year,
      month: state.month,
      selectedDate: state.selectedDate,
      employeeId: event.employeeId,
    );
  }

  Future<void> _onSettingsReload(
    AttendanceSettingsReloadRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    try {
      final s = await _attendanceRepository.getEmployeeSettings(event.employeeId);
      final svc = GeofencedPunchService(_dioClient);
      final hasLocal = await svc.hasLocalToken(event.employeeId);
      WebAttendanceStatus? gate;
      if (kIsWeb) {
        WebAttendanceGate.reevaluate();
        gate = await WebAttendanceGate.evaluate();
      }
      emit(state.copyWith(settings: s, hasLocalToken: hasLocal, webGate: gate));
    } catch (_) {}
  }

  Future<void> _onMonthChanged(
    AttendanceMonthChanged event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    await _fetchCalendar(
      emit,
      year: event.year,
      month: event.month,
      selectedDate: state.selectedDate,
    );
  }

  Future<void> _onPreviousMonth(
    AttendancePreviousMonthRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    int y = state.year;
    int m = state.month - 1;
    if (m < 1) {
      y -= 1;
      m = 12;
    }
    emit(state.copyWith(status: LoadStatus.loading));
    await _fetchCalendar(emit, year: y, month: m, selectedDate: state.selectedDate);
  }

  Future<void> _onNextMonth(
    AttendanceNextMonthRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    int y = state.year;
    int m = state.month + 1;
    if (m > 12) {
      y += 1;
      m = 1;
    }
    emit(state.copyWith(status: LoadStatus.loading));
    await _fetchCalendar(emit, year: y, month: m, selectedDate: state.selectedDate);
  }

  Future<void> _onDateSelected(
    AttendanceDateSelected event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(state.copyWith(selectedDate: event.date, isDayLoading: true));
    try {
      final day = await _attendanceRepository.getMyDay(date: event.date);
      emit(state.copyWith(dayDetail: day, isDayLoading: false));
    } catch (e) {
      emit(state.copyWith(isDayLoading: false, errorMessage: e.toString()));
    }
  }
}
