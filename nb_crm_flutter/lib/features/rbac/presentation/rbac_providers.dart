import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/rbac_repository.dart';
import '../domain/rbac_models.dart';

final rbacRepositoryProvider = Provider<RbacRepository>((ref) {
  return RbacRepository(dioClient: ref.watch(dioClientProvider));
});

class UsersFilterState {
  const UsersFilterState({
    required this.search,
    required this.status,
    required this.roleId,
  });

  final String search;
  final String status;
  final String roleId;

  UsersFilterState copyWith({
    String? search,
    String? status,
    String? roleId,
  }) {
    return UsersFilterState(
      search: search ?? this.search,
      status: status ?? this.status,
      roleId: roleId ?? this.roleId,
    );
  }
}

class UsersFilterNotifier extends Notifier<UsersFilterState> {
  @override
  UsersFilterState build() => const UsersFilterState(
        search: '',
        status: 'all',
        roleId: 'all',
      );

  void setSearch(String search) => state = state.copyWith(search: search);
  void setStatus(String status) => state = state.copyWith(status: status);
  void setRoleId(String roleId) => state = state.copyWith(roleId: roleId);
}

final usersFilterProvider =
    NotifierProvider<UsersFilterNotifier, UsersFilterState>(UsersFilterNotifier.new);

class UsersListNotifier extends AsyncNotifier<List<UserAccount>> {
  @override
  FutureOr<List<UserAccount>> build() {
    final filters = ref.watch(usersFilterProvider);
    return ref.read(rbacRepositoryProvider).listUsers(
          search: filters.search.isEmpty ? null : filters.search,
          status: filters.status == 'all' ? null : filters.status,
          roleId: filters.roleId == 'all' ? null : filters.roleId,
        );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final filters = ref.read(usersFilterProvider);
      return ref.read(rbacRepositoryProvider).listUsers(
            search: filters.search.isEmpty ? null : filters.search,
            status: filters.status == 'all' ? null : filters.status,
            roleId: filters.roleId == 'all' ? null : filters.roleId,
          );
    });
  }

  Future<void> deleteUser(String id) async {
    await ref.read(rbacRepositoryProvider).deleteUser(id);
    ref.invalidateSelf();
  }

  Future<UserAccount> createUser(Map<String, dynamic> data) async {
    final created = await ref.read(rbacRepositoryProvider).createUser(data);
    ref.invalidateSelf();
    return created;
  }

  Future<UserAccount> updateUser(String id, Map<String, dynamic> data) async {
    final updated = await ref.read(rbacRepositoryProvider).updateUser(id, data);
    ref.invalidateSelf();
    return updated;
  }
}

final usersListProvider =
    AsyncNotifierProvider<UsersListNotifier, List<UserAccount>>(UsersListNotifier.new);

/// All roles (for user filters / assignment).
final allRolesProvider = FutureProvider.autoDispose<List<RoleSummary>>((ref) async {
  return ref.watch(rbacRepositoryProvider).listRoles();
});

class RolesFilterState {
  const RolesFilterState({required this.search, required this.positionsOnly});

  final String search;
  final bool positionsOnly;

  RolesFilterState copyWith({String? search, bool? positionsOnly}) {
    return RolesFilterState(
      search: search ?? this.search,
      positionsOnly: positionsOnly ?? this.positionsOnly,
    );
  }
}

class RolesFilterNotifier extends Notifier<RolesFilterState> {
  @override
  RolesFilterState build() => const RolesFilterState(
        search: '',
        positionsOnly: false,
      );

  void setSearch(String search) => state = state.copyWith(search: search);
}

final rolesFilterProvider =
    NotifierProvider<RolesFilterNotifier, RolesFilterState>(RolesFilterNotifier.new);

class RolesListNotifier extends AsyncNotifier<List<RoleSummary>> {
  @override
  FutureOr<List<RoleSummary>> build() {
    final filters = ref.watch(rolesFilterProvider);
    return ref.read(rbacRepositoryProvider).listRoles(
          positionsOnly: filters.positionsOnly,
        );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final filters = ref.read(rolesFilterProvider);
      return ref.read(rbacRepositoryProvider).listRoles(
            positionsOnly: filters.positionsOnly,
          );
    });
  }

  Future<void> deleteRole(String id) async {
    await ref.read(rbacRepositoryProvider).deleteRole(id);
    ref.invalidateSelf();
  }

  Future<RoleSummary> createRole(Map<String, dynamic> data) async {
    final created = await ref.read(rbacRepositoryProvider).createRole(data);
    ref.invalidateSelf();
    return created;
  }
}

final rolesListProvider =
    AsyncNotifierProvider<RolesListNotifier, List<RoleSummary>>(RolesListNotifier.new);

final roleDetailProvider =
    FutureProvider.family.autoDispose<RoleSummary, String>((ref, roleId) async {
  return ref.watch(rbacRepositoryProvider).getRole(roleId);
});

final systemModulesProvider = FutureProvider.autoDispose<List<SystemModule>>((ref) async {
  return ref.watch(rbacRepositoryProvider).listModules();
});

class RolePermissionsNotifier extends AsyncNotifier<List<ModulePermission>> {
  RolePermissionsNotifier(this.roleId);

  final String roleId;

  @override
  FutureOr<List<ModulePermission>> build() {
    return ref.watch(rbacRepositoryProvider).getRolePermissions(roleId);
  }

  Future<void> refresh() async {
    final next = await ref.read(rbacRepositoryProvider).getRolePermissions(roleId);
    state = AsyncData(next);
  }

  /// Optimistically flip a flag (or scope), then sync from the server response.
  Future<void> patch(String moduleKey, Map<String, dynamic> data) async {
    final previous = state.asData?.value;
    if (previous != null) {
      state = AsyncData(
        previous.map((p) {
          if (p.moduleKey != moduleKey) return p;
          return p.copyWith(
            canRead: data.containsKey('canRead') ? data['canRead'] as bool : null,
            canWrite: data.containsKey('canWrite') ? data['canWrite'] as bool : null,
            canApprove:
                data.containsKey('canApprove') ? data['canApprove'] as bool : null,
            canDelete:
                data.containsKey('canDelete') ? data['canDelete'] as bool : null,
            canExport:
                data.containsKey('canExport') ? data['canExport'] as bool : null,
            employeeViewScope: data.containsKey('employeeViewScope')
                ? employeeViewScopeFromJson(data['employeeViewScope']?.toString())
                : null,
          );
        }).toList(),
      );
    }

    try {
      final updated = await ref.read(rbacRepositoryProvider).patchRolePermission(
            roleId,
            moduleKey,
            data,
          );
      state = AsyncData(updated);
    } catch (e) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }
}

final rolePermissionsProvider = AsyncNotifierProvider.autoDispose
    .family<RolePermissionsNotifier, List<ModulePermission>, String>(
  RolePermissionsNotifier.new,
);
