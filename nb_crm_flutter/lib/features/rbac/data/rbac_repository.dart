import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../domain/rbac_models.dart';

class RbacRepository {
  final DioClient _dio;

  const RbacRepository({required DioClient dioClient}) : _dio = dioClient;

  Future<List<UserAccount>> listUsers({
    String? search,
    String? status,
    String? roleId,
  }) async {
    final query = <String, dynamic>{};
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (roleId != null && roleId.isNotEmpty) query['roleId'] = roleId;
    if (status != null && status.isNotEmpty && status != 'all') {
      // Backend expects `isActive`; frontend audit names it `status`.
      query['isActive'] = status;
    }

    return _dio.getEnvelope<List<UserAccount>>(
      'admin/users',
      queryParameters: query.isEmpty ? null : query,
      parse: _parseUserList,
    );
  }

  Future<UserAccount> createUser(Map<String, dynamic> data) async {
    return _dio.postEnvelope<UserAccount>(
      'admin/users',
      data: data,
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid create user response');
        }
        return UserAccount.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<UserAccount> updateUser(String id, Map<String, dynamic> data) async {
    return _dio.patchEnvelope<UserAccount>(
      'admin/users/$id',
      data: data,
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid update user response');
        }
        return UserAccount.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<void> deleteUser(String id) async {
    await _dio.deleteEnvelope<void>(
      'admin/users/$id',
      parse: (_) {},
    );
  }

  Future<AccountCredentials> getUserCredentials(String userId) async {
    return _dio.getEnvelope<AccountCredentials>(
      'admin/users/$userId/credentials',
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid credentials response');
        }
        return AccountCredentials.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<PasswordResetResult> resetPassword(
    String userId, {
    String? password,
  }) async {
    return _dio.postEnvelope<PasswordResetResult>(
      'auth/reset-password/$userId',
      data: password != null && password.isNotEmpty ? {'password': password} : {},
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid reset password response');
        }
        return PasswordResetResult.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<List<RoleSummary>> listRoles({bool positionsOnly = false}) async {
    return _dio.getEnvelope<List<RoleSummary>>(
      'admin/roles',
      queryParameters: positionsOnly ? {'positionsOnly': 'true'} : null,
      parse: _parseRoleList,
    );
  }

  Future<RoleSummary> getRole(String id) async {
    return _dio.getEnvelope<RoleSummary>(
      'admin/roles/$id',
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid role response');
        }
        return RoleSummary.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<RoleSummary> createRole(Map<String, dynamic> data) async {
    return _dio.postEnvelope<RoleSummary>(
      'admin/roles',
      data: data,
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid create role response');
        }
        return RoleSummary.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<RoleSummary> updateRole(String id, Map<String, dynamic> data) async {
    return _dio.patchEnvelope<RoleSummary>(
      'admin/roles/$id',
      data: data,
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid update role response');
        }
        return RoleSummary.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<void> deleteRole(String id) async {
    await _dio.deleteEnvelope<void>(
      'admin/roles/$id',
      parse: (_) {},
    );
  }

  Future<List<ModulePermission>> getRolePermissions(String roleId) async {
    return _dio.getEnvelope<List<ModulePermission>>(
      'admin/roles/$roleId/permissions',
      parse: _parsePermissionList,
    );
  }

  Future<List<ModulePermission>> patchRolePermission(
    String roleId,
    String moduleKey,
    Map<String, dynamic> data,
  ) async {
    return _dio.patchEnvelope<List<ModulePermission>>(
      'admin/roles/$roleId/permissions/$moduleKey',
      data: data,
      parse: _parsePermissionList,
    );
  }

  Future<List<SystemModule>> listModules() async {
    return _dio.getEnvelope<List<SystemModule>>(
      'admin/modules',
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid modules list response');
        }
        return raw
            .map((e) => SystemModule.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  List<UserAccount> _parseUserList(Object? raw) {
    if (raw is! List) {
      throw const FormatException('Invalid users list response');
    }
    return raw
        .map((e) => UserAccount.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  List<RoleSummary> _parseRoleList(Object? raw) {
    if (raw is! List) {
      throw const FormatException('Invalid roles list response');
    }
    return raw
        .map((e) => RoleSummary.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  List<ModulePermission> _parsePermissionList(Object? raw) {
    if (raw is! List) {
      throw const FormatException('Invalid permissions list response');
    }
    return raw
        .map((e) => ModulePermission.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Exception mapError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final msg = data['error'] ?? data['message'];
        if (msg is String && msg.isNotEmpty) return Exception(msg);
      }
      return Exception(error.message ?? 'Network request failed');
    }
    if (error is Exception) return error;
    return Exception(error.toString());
  }
}
