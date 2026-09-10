import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/rbac_repository.dart';
import '../../domain/rbac_models.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class AdminRoleDetailEvent extends Equatable {
  const AdminRoleDetailEvent();

  @override
  List<Object?> get props => [];
}

class RoleDetailLoadRequested extends AdminRoleDetailEvent {
  const RoleDetailLoadRequested(this.roleId);
  final String roleId;

  @override
  List<Object?> get props => [roleId];
}

class RolePermissionPatched extends AdminRoleDetailEvent {
  const RolePermissionPatched({
    required this.roleId,
    required this.moduleKey,
    required this.data,
  });

  final String roleId;
  final String moduleKey;
  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [roleId, moduleKey, data];
}

class CustomModuleCreated extends AdminRoleDetailEvent {
  const CustomModuleCreated({
    required this.roleId,
    required this.data,
  });

  final String roleId;
  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [roleId, data];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class AdminRoleDetailState extends Equatable {
  const AdminRoleDetailState({
    this.status = LoadStatus.initial,
    this.role,
    this.permissions = const [],
    this.modules = const [],
    this.isActing = false,
    this.errorMessage,
    this.actionMessage,
  });

  final LoadStatus status;
  final RoleSummary? role;
  final List<ModulePermission> permissions;
  final List<SystemModule> modules;
  final bool isActing;
  final String? errorMessage;
  final String? actionMessage;

  AdminRoleDetailState copyWith({
    LoadStatus? status,
    RoleSummary? role,
    List<ModulePermission>? permissions,
    List<SystemModule>? modules,
    bool? isActing,
    String? errorMessage,
    String? actionMessage,
  }) {
    return AdminRoleDetailState(
      status: status ?? this.status,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      modules: modules ?? this.modules,
      isActing: isActing ?? this.isActing,
      errorMessage: errorMessage,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        role,
        permissions,
        modules,
        isActing,
        errorMessage,
        actionMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class AdminRoleDetailBloc extends Bloc<AdminRoleDetailEvent, AdminRoleDetailState> {
  AdminRoleDetailBloc({required RbacRepository rbacRepository})
      : _rbacRepository = rbacRepository,
        super(const AdminRoleDetailState()) {
    on<RoleDetailLoadRequested>(_onLoadRequested);
    on<RolePermissionPatched>(_onPermissionPatched);
    on<CustomModuleCreated>(_onCustomModuleCreated);
  }

  final RbacRepository _rbacRepository;

  Future<void> _fetchRoleData(Emitter<AdminRoleDetailState> emit, String roleId) async {
    final results = await Future.wait([
      _rbacRepository.getRole(roleId),
      _rbacRepository.getRolePermissions(roleId),
      _rbacRepository.listModules(),
    ]);

    emit(state.copyWith(
      status: LoadStatus.success,
      role: results[0] as RoleSummary,
      permissions: results[1] as List<ModulePermission>,
      modules: results[2] as List<SystemModule>,
    ));
  }

  Future<void> _onLoadRequested(
    RoleDetailLoadRequested event,
    Emitter<AdminRoleDetailState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, errorMessage: null));
    try {
      await _fetchRoleData(emit, event.roleId);
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onPermissionPatched(
    RolePermissionPatched event,
    Emitter<AdminRoleDetailState> emit,
  ) async {
    // Optimistic update
    final previous = state.permissions;
    final updatedList = previous.map((p) {
      if (p.moduleKey != event.moduleKey) return p;
      return p.copyWith(
        canRead: event.data.containsKey('canRead') ? event.data['canRead'] == true : null,
        canWrite: event.data.containsKey('canWrite') ? event.data['canWrite'] == true : null,
        canApprove: event.data.containsKey('canApprove') ? event.data['canApprove'] == true : null,
        canDelete: event.data.containsKey('canDelete') ? event.data['canDelete'] == true : null,
        canExport: event.data.containsKey('canExport') ? event.data['canExport'] == true : null,
        employeeViewScope: event.data.containsKey('employeeViewScope')
            ? employeeViewScopeFromJson(event.data['employeeViewScope']?.toString())
            : null,
      );
    }).toList();

    emit(state.copyWith(permissions: updatedList));

    try {
      final updated = await _rbacRepository.patchRolePermission(
        event.roleId,
        event.moduleKey,
        event.data,
      );
      emit(state.copyWith(permissions: updated));
    } catch (e) {
      emit(state.copyWith(
        permissions: previous,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onCustomModuleCreated(
    CustomModuleCreated event,
    Emitter<AdminRoleDetailState> emit,
  ) async {
    emit(state.copyWith(isActing: true, errorMessage: null, actionMessage: null));
    try {
      await _rbacRepository.createModule(event.data);
      emit(state.copyWith(isActing: false, actionMessage: 'Module registered successfully'));
      await _fetchRoleData(emit, event.roleId);
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }
}
