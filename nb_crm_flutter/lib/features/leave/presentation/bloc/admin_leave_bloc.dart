import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/leave_repository.dart';
import '../../domain/leave_models.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class AdminLeaveEvent extends Equatable {
  const AdminLeaveEvent();

  @override
  List<Object?> get props => [];
}

class AdminLeaveLoadRequested extends AdminLeaveEvent {
  const AdminLeaveLoadRequested();
}

class AdminLeaveRefreshRequested extends AdminLeaveEvent {
  const AdminLeaveRefreshRequested();
}

class AdminLeaveSearchChanged extends AdminLeaveEvent {
  const AdminLeaveSearchChanged(this.search);
  final String search;

  @override
  List<Object?> get props => [search];
}

class AdminLeaveStatusChanged extends AdminLeaveEvent {
  const AdminLeaveStatusChanged(this.status);
  final String status;

  @override
  List<Object?> get props => [status];
}

class AdminLeaveYearChanged extends AdminLeaveEvent {
  const AdminLeaveYearChanged(this.year);
  final int year;

  @override
  List<Object?> get props => [year];
}

class AdminLeavePageChanged extends AdminLeaveEvent {
  const AdminLeavePageChanged(this.page);
  final int page;

  @override
  List<Object?> get props => [page];
}

class AdminLeaveApplicationApproved extends AdminLeaveEvent {
  const AdminLeaveApplicationApproved(this.id, {this.notes});
  final String id;
  final String? notes;

  @override
  List<Object?> get props => [id, notes];
}

class AdminLeaveApplicationRejected extends AdminLeaveEvent {
  const AdminLeaveApplicationRejected(this.id, {required this.reason});
  final String id;
  final String reason;

  @override
  List<Object?> get props => [id, reason];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class AdminLeaveState extends Equatable {
  const AdminLeaveState({
    this.status = LoadStatus.initial,
    this.year = 0,
    this.search = '',
    this.filterStatus = '',
    this.page = 0,
    this.limit = 20,
    this.applications = const [],
    this.totalApplications = 0,
    this.pendingApprovals = const [],
    this.leaveTypes = const [],
    this.settings = const [],
    this.holidays = const [],
    this.isActing = false,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  final LoadStatus status;
  final int year;
  final String search;
  final String filterStatus;
  final int page;
  final int limit;
  final List<LeaveApplication> applications;
  final int totalApplications;
  final List<LeaveApplication> pendingApprovals;
  final List<LeaveType> leaveTypes;
  final List<LeaveSetting> settings;
  final List<PublicHoliday> holidays;
  final bool isActing;
  final String? errorMessage;
  final String? actionSuccessMessage;

  AdminLeaveState copyWith({
    LoadStatus? status,
    int? year,
    String? search,
    String? filterStatus,
    int? page,
    int? limit,
    List<LeaveApplication>? applications,
    int? totalApplications,
    List<LeaveApplication>? pendingApprovals,
    List<LeaveType>? leaveTypes,
    List<LeaveSetting>? settings,
    List<PublicHoliday>? holidays,
    bool? isActing,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return AdminLeaveState(
      status: status ?? this.status,
      year: year ?? this.year,
      search: search ?? this.search,
      filterStatus: filterStatus ?? this.filterStatus,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      applications: applications ?? this.applications,
      totalApplications: totalApplications ?? this.totalApplications,
      pendingApprovals: pendingApprovals ?? this.pendingApprovals,
      leaveTypes: leaveTypes ?? this.leaveTypes,
      settings: settings ?? this.settings,
      holidays: holidays ?? this.holidays,
      isActing: isActing ?? this.isActing,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        year,
        search,
        filterStatus,
        page,
        limit,
        applications,
        totalApplications,
        pendingApprovals,
        leaveTypes,
        settings,
        holidays,
        isActing,
        errorMessage,
        actionSuccessMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class AdminLeaveBloc extends Bloc<AdminLeaveEvent, AdminLeaveState> {
  AdminLeaveBloc({required LeaveRepository leaveRepository})
      : _leaveRepository = leaveRepository,
        super(AdminLeaveState(year: DateTime.now().year)) {
    on<AdminLeaveLoadRequested>(_onLoad);
    on<AdminLeaveRefreshRequested>(_onRefresh);
    on<AdminLeaveSearchChanged>(_onSearchChanged);
    on<AdminLeaveStatusChanged>(_onStatusChanged);
    on<AdminLeaveYearChanged>(_onYearChanged);
    on<AdminLeavePageChanged>(_onPageChanged);
    on<AdminLeaveApplicationApproved>(_onApprove);
    on<AdminLeaveApplicationRejected>(_onReject);
  }

  final LeaveRepository _leaveRepository;

  Future<void> _fetchData(
    Emitter<AdminLeaveState> emit, {
    required int year,
    required String search,
    required String status,
    required int page,
  }) async {
    try {
      final results = await Future.wait([
        _leaveRepository.getAdminApplications(
          status: status.isEmpty ? null : status,
          year: year,
          page: page,
          limit: state.limit,
        ),
        _leaveRepository.getPendingApprovals(),
        _leaveRepository.getAdminTypes(),
        _leaveRepository.getAdminSettings(),
        _leaveRepository.getAdminHolidays(year: year),
      ]);

      final appsPage = results[0] as LeaveApplicationsPage;
      final pending = results[1] as List<LeaveApplication>;
      final types = results[2] as List<LeaveType>;
      final settings = results[3] as List<LeaveSetting>;
      final holidays = results[4] as List<PublicHoliday>;

      var filteredItems = appsPage.items;
      final q = search.trim().toLowerCase();
      if (q.isNotEmpty) {
        filteredItems = filteredItems.where((a) {
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
      }

      emit(state.copyWith(
        status: LoadStatus.success,
        year: year,
        search: search,
        filterStatus: status,
        page: page,
        applications: filteredItems,
        totalApplications: q.isNotEmpty ? filteredItems.length : appsPage.total,
        pendingApprovals: pending,
        leaveTypes: types,
        settings: settings,
        holidays: holidays,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoad(
    AdminLeaveLoadRequested event,
    Emitter<AdminLeaveState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    await _fetchData(
      emit,
      year: state.year,
      search: state.search,
      status: state.filterStatus,
      page: state.page,
    );
  }

  Future<void> _onRefresh(
    AdminLeaveRefreshRequested event,
    Emitter<AdminLeaveState> emit,
  ) async {
    await _fetchData(
      emit,
      year: state.year,
      search: state.search,
      status: state.filterStatus,
      page: state.page,
    );
  }

  Future<void> _onSearchChanged(
    AdminLeaveSearchChanged event,
    Emitter<AdminLeaveState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, search: event.search, page: 0));
    await _fetchData(
      emit,
      year: state.year,
      search: event.search,
      status: state.filterStatus,
      page: 0,
    );
  }

  Future<void> _onStatusChanged(
    AdminLeaveStatusChanged event,
    Emitter<AdminLeaveState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, filterStatus: event.status, page: 0));
    await _fetchData(
      emit,
      year: state.year,
      search: state.search,
      status: event.status,
      page: 0,
    );
  }

  Future<void> _onYearChanged(
    AdminLeaveYearChanged event,
    Emitter<AdminLeaveState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, year: event.year, page: 0));
    await _fetchData(
      emit,
      year: event.year,
      search: state.search,
      status: state.filterStatus,
      page: 0,
    );
  }

  Future<void> _onPageChanged(
    AdminLeavePageChanged event,
    Emitter<AdminLeaveState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, page: event.page));
    await _fetchData(
      emit,
      year: state.year,
      search: state.search,
      status: state.filterStatus,
      page: event.page,
    );
  }

  Future<void> _onApprove(
    AdminLeaveApplicationApproved event,
    Emitter<AdminLeaveState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _leaveRepository.approveApplication(event.id, remarks: event.notes);
      emit(state.copyWith(
        isActing: false,
        actionSuccessMessage: 'Application approved',
      ));
      await _fetchData(
        emit,
        year: state.year,
        search: state.search,
        status: state.filterStatus,
        page: state.page,
      );
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onReject(
    AdminLeaveApplicationRejected event,
    Emitter<AdminLeaveState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _leaveRepository.rejectApplication(event.id, remarks: event.reason);
      emit(state.copyWith(
        isActing: false,
        actionSuccessMessage: 'Application rejected',
      ));
      await _fetchData(
        emit,
        year: state.year,
        search: state.search,
        status: state.filterStatus,
        page: state.page,
      );
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }
}
