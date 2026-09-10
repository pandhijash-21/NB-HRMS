import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/bloc/load_status.dart';
import '../../../profile/domain/profile_models.dart';
import '../../data/admin_repository.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class AdminWorkforceEvent extends Equatable {
  const AdminWorkforceEvent();

  @override
  List<Object?> get props => [];
}

class AdminWorkforceLoadRequested extends AdminWorkforceEvent {
  const AdminWorkforceLoadRequested();
}

class AdminWorkforceRefreshRequested extends AdminWorkforceEvent {
  const AdminWorkforceRefreshRequested();
}

class AdminWorkforceSearchChanged extends AdminWorkforceEvent {
  const AdminWorkforceSearchChanged(this.search);
  final String search;

  @override
  List<Object?> get props => [search];
}

class AdminWorkforceStatusChanged extends AdminWorkforceEvent {
  const AdminWorkforceStatusChanged(this.status);
  final String status;

  @override
  List<Object?> get props => [status];
}

class AdminWorkforcePageChanged extends AdminWorkforceEvent {
  const AdminWorkforcePageChanged(this.page);
  final int page;

  @override
  List<Object?> get props => [page];
}

class AdminWorkforceEmployeeDeleted extends AdminWorkforceEvent {
  const AdminWorkforceEmployeeDeleted(this.employeeId);
  final int employeeId;

  @override
  List<Object?> get props => [employeeId];
}

class AdminWorkforceEmployeeCreated extends AdminWorkforceEvent {
  const AdminWorkforceEmployeeCreated({
    required this.data,
    required this.completer,
  });

  final Map<String, dynamic> data;
  final Completer<({EmployeeProfile profile, String? initialPassword})> completer;

  @override
  List<Object?> get props => [data];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class AdminWorkforceState extends Equatable {
  const AdminWorkforceState({
    this.status = LoadStatus.initial,
    this.employees = const [],
    this.total = 0,
    this.search = '',
    this.filterStatus = '',
    this.page = 0,
    this.limit = 10,
    this.isDeleting = false,
    this.errorMessage,
  });

  final LoadStatus status;
  final List<EmployeeProfile> employees;
  final int total;
  final String search;
  final String filterStatus;
  final int page;
  final int limit;
  final bool isDeleting;
  final String? errorMessage;

  AdminWorkforceState copyWith({
    LoadStatus? status,
    List<EmployeeProfile>? employees,
    int? total,
    String? search,
    String? filterStatus,
    int? page,
    int? limit,
    bool? isDeleting,
    String? errorMessage,
  }) {
    return AdminWorkforceState(
      status: status ?? this.status,
      employees: employees ?? this.employees,
      total: total ?? this.total,
      search: search ?? this.search,
      filterStatus: filterStatus ?? this.filterStatus,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      isDeleting: isDeleting ?? this.isDeleting,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        employees,
        total,
        search,
        filterStatus,
        page,
        limit,
        isDeleting,
        errorMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class AdminWorkforceBloc
    extends Bloc<AdminWorkforceEvent, AdminWorkforceState> {
  AdminWorkforceBloc({required AdminRepository adminRepository})
      : _adminRepository = adminRepository,
        super(const AdminWorkforceState()) {
    on<AdminWorkforceLoadRequested>(_onLoad);
    on<AdminWorkforceRefreshRequested>(_onRefresh);
    on<AdminWorkforceSearchChanged>(_onSearchChanged);
    on<AdminWorkforceStatusChanged>(_onStatusChanged);
    on<AdminWorkforcePageChanged>(_onPageChanged);
    on<AdminWorkforceEmployeeDeleted>(_onDeleteEmployee);
    on<AdminWorkforceEmployeeCreated>(_onCreateEmployee);
  }

  final AdminRepository _adminRepository;

  Future<void> _fetchData(
    Emitter<AdminWorkforceState> emit, {
    required int page,
    required String search,
    required String status,
  }) async {
    try {
      final res = await _adminRepository.listEmployees(
        limit: state.limit,
        offset: page * state.limit,
        search: search.isEmpty ? null : search,
        status: status.isEmpty ? null : status,
      );

      final items = (res['items'] as List? ?? []).cast<EmployeeProfile>();
      final total = res['total'] as int? ?? 0;

      emit(state.copyWith(
        status: LoadStatus.success,
        employees: items,
        total: total,
        page: page,
        search: search,
        filterStatus: status,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoad(
    AdminWorkforceLoadRequested event,
    Emitter<AdminWorkforceState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    await _fetchData(
      emit,
      page: state.page,
      search: state.search,
      status: state.filterStatus,
    );
  }

  Future<void> _onRefresh(
    AdminWorkforceRefreshRequested event,
    Emitter<AdminWorkforceState> emit,
  ) async {
    await _fetchData(
      emit,
      page: state.page,
      search: state.search,
      status: state.filterStatus,
    );
  }

  Future<void> _onSearchChanged(
    AdminWorkforceSearchChanged event,
    Emitter<AdminWorkforceState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, page: 0, search: event.search));
    await _fetchData(
      emit,
      page: 0,
      search: event.search,
      status: state.filterStatus,
    );
  }

  Future<void> _onStatusChanged(
    AdminWorkforceStatusChanged event,
    Emitter<AdminWorkforceState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, page: 0, filterStatus: event.status));
    await _fetchData(
      emit,
      page: 0,
      search: state.search,
      status: event.status,
    );
  }

  Future<void> _onPageChanged(
    AdminWorkforcePageChanged event,
    Emitter<AdminWorkforceState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, page: event.page));
    await _fetchData(
      emit,
      page: event.page,
      search: state.search,
      status: state.filterStatus,
    );
  }

  Future<void> _onDeleteEmployee(
    AdminWorkforceEmployeeDeleted event,
    Emitter<AdminWorkforceState> emit,
  ) async {
    emit(state.copyWith(isDeleting: true));
    try {
      await _adminRepository.deleteEmployee(event.employeeId);
      await _fetchData(
        emit,
        page: state.page,
        search: state.search,
        status: state.filterStatus,
      );
    } catch (e) {
      emit(state.copyWith(
        isDeleting: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onCreateEmployee(
    AdminWorkforceEmployeeCreated event,
    Emitter<AdminWorkforceState> emit,
  ) async {
    try {
      final created = await _adminRepository.createEmployee(event.data);
      event.completer.complete(created);
      emit(state.copyWith(search: '', page: 0));
      await _fetchData(
        emit,
        page: 0,
        search: '',
        status: state.filterStatus,
      );
    } catch (e) {
      event.completer.completeError(e);
    }
  }
}
