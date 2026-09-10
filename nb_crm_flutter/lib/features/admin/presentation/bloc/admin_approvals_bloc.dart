import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/admin_repository.dart';
import '../../domain/admin_models.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class AdminApprovalsEvent extends Equatable {
  const AdminApprovalsEvent();

  @override
  List<Object?> get props => [];
}

class AdminApprovalsLoadRequested extends AdminApprovalsEvent {
  const AdminApprovalsLoadRequested();
}

class AdminApprovalsRefreshRequested extends AdminApprovalsEvent {
  const AdminApprovalsRefreshRequested();
}

class AdminApprovalsFilterChanged extends AdminApprovalsEvent {
  const AdminApprovalsFilterChanged(this.status);
  final String status;

  @override
  List<Object?> get props => [status];
}

class AdminApprovalsApproveRequested extends AdminApprovalsEvent {
  const AdminApprovalsApproveRequested(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class AdminApprovalsRejectRequested extends AdminApprovalsEvent {
  const AdminApprovalsRejectRequested(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class AdminApprovalsState extends Equatable {
  const AdminApprovalsState({
    this.status = LoadStatus.initial,
    this.requests = const [],
    this.approverNames = const [],
    this.filterStatus = 'PENDING',
    this.isActing = false,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  final LoadStatus status;
  final List<ChangeRequest> requests;
  final List<EmployeeNameOption> approverNames;
  final String filterStatus;
  final bool isActing;
  final String? errorMessage;
  final String? actionSuccessMessage;

  AdminApprovalsState copyWith({
    LoadStatus? status,
    List<ChangeRequest>? requests,
    List<EmployeeNameOption>? approverNames,
    String? filterStatus,
    bool? isActing,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return AdminApprovalsState(
      status: status ?? this.status,
      requests: requests ?? this.requests,
      approverNames: approverNames ?? this.approverNames,
      filterStatus: filterStatus ?? this.filterStatus,
      isActing: isActing ?? this.isActing,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        requests,
        approverNames,
        filterStatus,
        isActing,
        errorMessage,
        actionSuccessMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class AdminApprovalsBloc
    extends Bloc<AdminApprovalsEvent, AdminApprovalsState> {
  AdminApprovalsBloc({required AdminRepository adminRepository})
      : _adminRepository = adminRepository,
        super(const AdminApprovalsState()) {
    on<AdminApprovalsLoadRequested>(_onLoad);
    on<AdminApprovalsRefreshRequested>(_onRefresh);
    on<AdminApprovalsFilterChanged>(_onFilterChanged);
    on<AdminApprovalsApproveRequested>(_onApprove);
    on<AdminApprovalsRejectRequested>(_onReject);
  }

  final AdminRepository _adminRepository;

  Future<void> _fetchQueue(
    Emitter<AdminApprovalsState> emit, {
    required String filterStatus,
  }) async {
    try {
      final actualStatus = filterStatus == 'ALL' ? null : filterStatus;
      final results = await Future.wait([
        _adminRepository.listApprovals(status: actualStatus),
        _adminRepository.listEmployeeNames(),
      ]);

      emit(state.copyWith(
        status: LoadStatus.success,
        requests: results[0] as List<ChangeRequest>,
        approverNames: results[1] as List<EmployeeNameOption>,
        filterStatus: filterStatus,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoad(
    AdminApprovalsLoadRequested event,
    Emitter<AdminApprovalsState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    await _fetchQueue(emit, filterStatus: state.filterStatus);
  }

  Future<void> _onRefresh(
    AdminApprovalsRefreshRequested event,
    Emitter<AdminApprovalsState> emit,
  ) async {
    await _fetchQueue(emit, filterStatus: state.filterStatus);
  }

  Future<void> _onFilterChanged(
    AdminApprovalsFilterChanged event,
    Emitter<AdminApprovalsState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, filterStatus: event.status));
    await _fetchQueue(emit, filterStatus: event.status);
  }

  Future<void> _onApprove(
    AdminApprovalsApproveRequested event,
    Emitter<AdminApprovalsState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _adminRepository.approveRequest(event.id);
      emit(state.copyWith(
        isActing: false,
        actionSuccessMessage: 'Request approved successfully',
      ));
      await _fetchQueue(emit, filterStatus: state.filterStatus);
    } catch (e) {
      emit(state.copyWith(
        isActing: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onReject(
    AdminApprovalsRejectRequested event,
    Emitter<AdminApprovalsState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _adminRepository.rejectRequest(event.id);
      emit(state.copyWith(
        isActing: false,
        actionSuccessMessage: 'Request rejected',
      ));
      await _fetchQueue(emit, filterStatus: state.filterStatus);
    } catch (e) {
      emit(state.copyWith(
        isActing: false,
        errorMessage: e.toString(),
      ));
    }
  }
}
