import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/rbac_repository.dart';
import '../../domain/rbac_models.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class AdminRolesEvent extends Equatable {
  const AdminRolesEvent();

  @override
  List<Object?> get props => [];
}

class AdminRolesLoadRequested extends AdminRolesEvent {
  const AdminRolesLoadRequested();
}

class AdminRolesFiltersChanged extends AdminRolesEvent {
  const AdminRolesFiltersChanged({
    this.search,
    this.positionsOnly,
  });

  final String? search;
  final bool? positionsOnly;

  @override
  List<Object?> get props => [search, positionsOnly];
}

class AdminRoleCreated extends AdminRolesEvent {
  const AdminRoleCreated(this.data);
  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [data];
}

class AdminRoleUpdated extends AdminRolesEvent {
  const AdminRoleUpdated({required this.id, required this.data});
  final String id;
  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [id, data];
}

class AdminRoleDeleted extends AdminRolesEvent {
  const AdminRoleDeleted(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class AdminRolesState extends Equatable {
  const AdminRolesState({
    this.status = LoadStatus.initial,
    this.roles = const [],
    this.search = '',
    this.positionsOnly = false,
    this.isActing = false,
    this.errorMessage,
    this.actionMessage,
  });

  final LoadStatus status;
  final List<RoleSummary> roles;
  final String search;
  final bool positionsOnly;
  final bool isActing;
  final String? errorMessage;
  final String? actionMessage;

  AdminRolesState copyWith({
    LoadStatus? status,
    List<RoleSummary>? roles,
    String? search,
    bool? positionsOnly,
    bool? isActing,
    String? errorMessage,
    String? actionMessage,
  }) {
    return AdminRolesState(
      status: status ?? this.status,
      roles: roles ?? this.roles,
      search: search ?? this.search,
      positionsOnly: positionsOnly ?? this.positionsOnly,
      isActing: isActing ?? this.isActing,
      errorMessage: errorMessage,
      actionMessage: actionMessage,
    );
  }

  List<RoleSummary> get filteredRoles {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return roles;
    return roles.where((r) {
      return r.name.toLowerCase().contains(q) ||
          (r.description ?? '').toLowerCase().contains(q) ||
          (r.positionName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  List<Object?> get props => [
        status,
        roles,
        search,
        positionsOnly,
        isActing,
        errorMessage,
        actionMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class AdminRolesBloc extends Bloc<AdminRolesEvent, AdminRolesState> {
  AdminRolesBloc({required RbacRepository rbacRepository})
      : _rbacRepository = rbacRepository,
        super(const AdminRolesState()) {
    on<AdminRolesLoadRequested>(_onLoadRequested);
    on<AdminRolesFiltersChanged>(_onFiltersChanged);
    on<AdminRoleCreated>(_onRoleCreated);
    on<AdminRoleUpdated>(_onRoleUpdated);
    on<AdminRoleDeleted>(_onRoleDeleted);
  }

  final RbacRepository _rbacRepository;

  Future<void> _fetchRoles(Emitter<AdminRolesState> emit, {required bool positionsOnly}) async {
    final roles = await _rbacRepository.listRoles(positionsOnly: positionsOnly);
    emit(state.copyWith(
      status: LoadStatus.success,
      roles: roles,
    ));
  }

  Future<void> _onLoadRequested(
    AdminRolesLoadRequested event,
    Emitter<AdminRolesState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, errorMessage: null));
    try {
      await _fetchRoles(emit, positionsOnly: state.positionsOnly);
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onFiltersChanged(
    AdminRolesFiltersChanged event,
    Emitter<AdminRolesState> emit,
  ) async {
    final nextSearch = event.search ?? state.search;
    final nextPositionsOnly = event.positionsOnly ?? state.positionsOnly;

    emit(state.copyWith(
      status: LoadStatus.loading,
      search: nextSearch,
      positionsOnly: nextPositionsOnly,
      errorMessage: null,
    ));

    try {
      await _fetchRoles(emit, positionsOnly: nextPositionsOnly);
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRoleCreated(
    AdminRoleCreated event,
    Emitter<AdminRolesState> emit,
  ) async {
    emit(state.copyWith(isActing: true, errorMessage: null, actionMessage: null));
    try {
      await _rbacRepository.createRole(event.data);
      emit(state.copyWith(isActing: false, actionMessage: 'Role created successfully'));
      await _fetchRoles(emit, positionsOnly: state.positionsOnly);
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onRoleUpdated(
    AdminRoleUpdated event,
    Emitter<AdminRolesState> emit,
  ) async {
    emit(state.copyWith(isActing: true, errorMessage: null, actionMessage: null));
    try {
      await _rbacRepository.updateRole(event.id, event.data);
      emit(state.copyWith(isActing: false, actionMessage: 'Role updated successfully'));
      await _fetchRoles(emit, positionsOnly: state.positionsOnly);
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onRoleDeleted(
    AdminRoleDeleted event,
    Emitter<AdminRolesState> emit,
  ) async {
    emit(state.copyWith(isActing: true, errorMessage: null, actionMessage: null));
    try {
      await _rbacRepository.deleteRole(event.id);
      emit(state.copyWith(isActing: false, actionMessage: 'Role deleted successfully'));
      await _fetchRoles(emit, positionsOnly: state.positionsOnly);
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }
}
