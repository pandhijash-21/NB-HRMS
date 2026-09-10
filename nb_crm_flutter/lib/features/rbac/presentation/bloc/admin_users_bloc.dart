import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/rbac_repository.dart';
import '../../domain/rbac_models.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class AdminUsersEvent extends Equatable {
  const AdminUsersEvent();

  @override
  List<Object?> get props => [];
}

class AdminUsersLoadRequested extends AdminUsersEvent {
  const AdminUsersLoadRequested();
}

class AdminUsersFiltersChanged extends AdminUsersEvent {
  const AdminUsersFiltersChanged({
    this.search,
    this.status,
    this.roleId,
    this.lockedOnly,
  });

  final String? search;
  final String? status;
  final String? roleId;
  final bool? lockedOnly;

  @override
  List<Object?> get props => [search, status, roleId, lockedOnly];
}

class AdminUserCreated extends AdminUsersEvent {
  const AdminUserCreated(this.data);
  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [data];
}

class AdminUserUpdated extends AdminUsersEvent {
  const AdminUserUpdated({required this.id, required this.data});
  final String id;
  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [id, data];
}

class AdminUserDeleted extends AdminUsersEvent {
  const AdminUserDeleted(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class AdminUserUnblocked extends AdminUsersEvent {
  const AdminUserUnblocked(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class AdminUsersState extends Equatable {
  const AdminUsersState({
    this.status = LoadStatus.initial,
    this.users = const [],
    this.roles = const [],
    this.search = '',
    this.statusFilter = 'all',
    this.roleIdFilter = 'all',
    this.lockedOnly = false,
    this.isActing = false,
    this.errorMessage,
    this.actionMessage,
  });

  final LoadStatus status;
  final List<UserAccount> users;
  final List<RoleSummary> roles;
  final String search;
  final String statusFilter;
  final String roleIdFilter;
  final bool lockedOnly;
  final bool isActing;
  final String? errorMessage;
  final String? actionMessage;

  AdminUsersState copyWith({
    LoadStatus? status,
    List<UserAccount>? users,
    List<RoleSummary>? roles,
    String? search,
    String? statusFilter,
    String? roleIdFilter,
    bool? lockedOnly,
    bool? isActing,
    String? errorMessage,
    String? actionMessage,
  }) {
    return AdminUsersState(
      status: status ?? this.status,
      users: users ?? this.users,
      roles: roles ?? this.roles,
      search: search ?? this.search,
      statusFilter: statusFilter ?? this.statusFilter,
      roleIdFilter: roleIdFilter ?? this.roleIdFilter,
      lockedOnly: lockedOnly ?? this.lockedOnly,
      isActing: isActing ?? this.isActing,
      errorMessage: errorMessage,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        users,
        roles,
        search,
        statusFilter,
        roleIdFilter,
        lockedOnly,
        isActing,
        errorMessage,
        actionMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class AdminUsersBloc extends Bloc<AdminUsersEvent, AdminUsersState> {
  AdminUsersBloc({required RbacRepository rbacRepository})
      : _rbacRepository = rbacRepository,
        super(const AdminUsersState()) {
    on<AdminUsersLoadRequested>(_onLoadRequested);
    on<AdminUsersFiltersChanged>(_onFiltersChanged);
    on<AdminUserCreated>(_onUserCreated);
    on<AdminUserUpdated>(_onUserUpdated);
    on<AdminUserDeleted>(_onUserDeleted);
    on<AdminUserUnblocked>(_onUserUnblocked);
  }

  final RbacRepository _rbacRepository;

  Future<void> _fetchData(Emitter<AdminUsersState> emit, {required String search, required String status, required String roleId}) async {
    final results = await Future.wait([
      _rbacRepository.listUsers(
        search: search.isEmpty ? null : search,
        status: status == 'all' ? null : status,
        roleId: roleId == 'all' ? null : roleId,
      ),
      _rbacRepository.listRoles(),
    ]);

    emit(state.copyWith(
      status: LoadStatus.success,
      users: results[0] as List<UserAccount>,
      roles: results[1] as List<RoleSummary>,
    ));
  }

  Future<void> _onLoadRequested(
    AdminUsersLoadRequested event,
    Emitter<AdminUsersState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, errorMessage: null));
    try {
      await _fetchData(emit, search: state.search, status: state.statusFilter, roleId: state.roleIdFilter);
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onFiltersChanged(
    AdminUsersFiltersChanged event,
    Emitter<AdminUsersState> emit,
  ) async {
    final nextSearch = event.search ?? state.search;
    final nextStatus = event.status ?? state.statusFilter;
    final nextRole = event.roleId ?? state.roleIdFilter;
    final nextLocked = event.lockedOnly ?? state.lockedOnly;

    emit(state.copyWith(
      status: LoadStatus.loading,
      search: nextSearch,
      statusFilter: nextStatus,
      roleIdFilter: nextRole,
      lockedOnly: nextLocked,
      errorMessage: null,
    ));

    try {
      final users = await _rbacRepository.listUsers(
        search: nextSearch.isEmpty ? null : nextSearch,
        status: nextStatus == 'all' ? null : nextStatus,
        roleId: nextRole == 'all' ? null : nextRole,
      );
      emit(state.copyWith(
        status: LoadStatus.success,
        users: users,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onUserCreated(
    AdminUserCreated event,
    Emitter<AdminUsersState> emit,
  ) async {
    emit(state.copyWith(isActing: true, errorMessage: null, actionMessage: null));
    try {
      await _rbacRepository.createUser(event.data);
      emit(state.copyWith(isActing: false, actionMessage: 'User created successfully'));
      await _fetchData(emit, search: state.search, status: state.statusFilter, roleId: state.roleIdFilter);
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onUserUpdated(
    AdminUserUpdated event,
    Emitter<AdminUsersState> emit,
  ) async {
    emit(state.copyWith(isActing: true, errorMessage: null, actionMessage: null));
    try {
      await _rbacRepository.updateUser(event.id, event.data);
      emit(state.copyWith(isActing: false, actionMessage: 'User updated successfully'));
      await _fetchData(emit, search: state.search, status: state.statusFilter, roleId: state.roleIdFilter);
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onUserDeleted(
    AdminUserDeleted event,
    Emitter<AdminUsersState> emit,
  ) async {
    emit(state.copyWith(isActing: true, errorMessage: null, actionMessage: null));
    try {
      await _rbacRepository.deleteUser(event.id);
      emit(state.copyWith(isActing: false, actionMessage: 'User deleted successfully'));
      await _fetchData(emit, search: state.search, status: state.statusFilter, roleId: state.roleIdFilter);
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onUserUnblocked(
    AdminUserUnblocked event,
    Emitter<AdminUsersState> emit,
  ) async {
    emit(state.copyWith(isActing: true, errorMessage: null, actionMessage: null));
    try {
      await _rbacRepository.unblockLogin(event.id);
      emit(state.copyWith(isActing: false, actionMessage: 'User unblocked successfully'));
      await _fetchData(emit, search: state.search, status: state.statusFilter, roleId: state.roleIdFilter);
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }
}
