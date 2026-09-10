import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/leave_repository.dart';
import '../../domain/leave_models.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class LeaveEvent extends Equatable {
  const LeaveEvent();

  @override
  List<Object?> get props => [];
}

class LeaveLoadRequested extends LeaveEvent {
  const LeaveLoadRequested();
}

class LeaveRefreshRequested extends LeaveEvent {
  const LeaveRefreshRequested();
}

class LeaveYearChanged extends LeaveEvent {
  const LeaveYearChanged(this.year);
  final int year;

  @override
  List<Object?> get props => [year];
}

class LeaveStatusFilterChanged extends LeaveEvent {
  const LeaveStatusFilterChanged(this.status);
  final String status;

  @override
  List<Object?> get props => [status];
}

class LeavePageChanged extends LeaveEvent {
  const LeavePageChanged(this.page);
  final int page;

  @override
  List<Object?> get props => [page];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class LeaveState extends Equatable {
  const LeaveState({
    this.status = LoadStatus.initial,
    this.year = 0,
    this.leaveTypes = const [],
    this.balances = const [],
    this.applications = const [],
    this.totalApplications = 0,
    this.filterStatus = '',
    this.page = 0,
    this.limit = 20,
    this.errorMessage,
  });

  final LoadStatus status;
  final int year;
  final List<LeaveType> leaveTypes;
  final List<LeaveBalance> balances;
  final List<LeaveApplication> applications;
  final int totalApplications;
  final String filterStatus;
  final int page;
  final int limit;
  final String? errorMessage;

  LeaveState copyWith({
    LoadStatus? status,
    int? year,
    List<LeaveType>? leaveTypes,
    List<LeaveBalance>? balances,
    List<LeaveApplication>? applications,
    int? totalApplications,
    String? filterStatus,
    int? page,
    int? limit,
    String? errorMessage,
  }) {
    return LeaveState(
      status: status ?? this.status,
      year: year ?? this.year,
      leaveTypes: leaveTypes ?? this.leaveTypes,
      balances: balances ?? this.balances,
      applications: applications ?? this.applications,
      totalApplications: totalApplications ?? this.totalApplications,
      filterStatus: filterStatus ?? this.filterStatus,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        year,
        leaveTypes,
        balances,
        applications,
        totalApplications,
        filterStatus,
        page,
        limit,
        errorMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class LeaveBloc extends Bloc<LeaveEvent, LeaveState> {
  LeaveBloc({required LeaveRepository leaveRepository})
      : _leaveRepository = leaveRepository,
        super(LeaveState(year: DateTime.now().year)) {
    on<LeaveLoadRequested>(_onLoad);
    on<LeaveRefreshRequested>(_onRefresh);
    on<LeaveYearChanged>(_onYearChanged);
    on<LeaveStatusFilterChanged>(_onStatusFilterChanged);
    on<LeavePageChanged>(_onPageChanged);
  }

  final LeaveRepository _leaveRepository;

  Future<void> _fetchData(
    Emitter<LeaveState> emit, {
    required int year,
    required String filterStatus,
    required int page,
  }) async {
    try {
      final results = await Future.wait([
        _leaveRepository.getLeaveTypes(),
        _leaveRepository.getMyBalances(year: year),
        _leaveRepository.getMyApplications(
          status: filterStatus.isEmpty ? null : filterStatus,
          year: year,
          page: page,
          limit: state.limit,
        ),
      ]);

      final types = results[0] as List<LeaveType>;
      final rawBalances = results[1] as List<LeaveBalance>;
      final appsPage = results[2] as LeaveApplicationsPage;

      final byType = {for (final b in rawBalances) b.leaveTypeId: b};
      final mergedBalances = types.where((t) => t.isActive).map((t) {
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

      emit(state.copyWith(
        status: LoadStatus.success,
        year: year,
        filterStatus: filterStatus,
        page: page,
        leaveTypes: types,
        balances: mergedBalances,
        applications: appsPage.items,
        totalApplications: appsPage.total,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoad(
    LeaveLoadRequested event,
    Emitter<LeaveState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    await _fetchData(
      emit,
      year: state.year,
      filterStatus: state.filterStatus,
      page: state.page,
    );
  }

  Future<void> _onRefresh(
    LeaveRefreshRequested event,
    Emitter<LeaveState> emit,
  ) async {
    await _fetchData(
      emit,
      year: state.year,
      filterStatus: state.filterStatus,
      page: state.page,
    );
  }

  Future<void> _onYearChanged(
    LeaveYearChanged event,
    Emitter<LeaveState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, year: event.year, page: 0));
    await _fetchData(
      emit,
      year: event.year,
      filterStatus: state.filterStatus,
      page: 0,
    );
  }

  Future<void> _onStatusFilterChanged(
    LeaveStatusFilterChanged event,
    Emitter<LeaveState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, filterStatus: event.status, page: 0));
    await _fetchData(
      emit,
      year: state.year,
      filterStatus: event.status,
      page: 0,
    );
  }

  Future<void> _onPageChanged(
    LeavePageChanged event,
    Emitter<LeaveState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, page: event.page));
    await _fetchData(
      emit,
      year: state.year,
      filterStatus: state.filterStatus,
      page: event.page,
    );
  }
}
