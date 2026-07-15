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
        positionsOnly: true,
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

final rolePermissionsProvider =
    FutureProvider.family.autoDispose<List<ModulePermission>, String>((ref, roleId) async {
  return ref.watch(rbacRepositoryProvider).getRolePermissions(roleId);
});
