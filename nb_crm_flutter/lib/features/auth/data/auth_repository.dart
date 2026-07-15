import 'dart:convert';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../domain/auth_user.dart';

class AuthRepository {
  AuthRepository({
    required DioClient dioClient,
    required SecureStorageService storage,
  })  : _dio = dioClient,
        _storage = storage;

  final DioClient _dio;
  final SecureStorageService _storage;

  Future<LoginResult> login({
    required String identifier,
    required String password,
  }) {
    return _dio.postEnvelope<LoginResult>(
      'auth/login',
      data: {
        'identifier': identifier.trim(),
        'password': password,
      },
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid login payload');
        }
        return LoginResult.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  /// Backend: `POST auth/change-password` `{ currentPassword, newPassword }`.
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _dio.postEnvelope<String>(
      'auth/change-password',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
      parse: (raw) {
        if (raw is Map && raw['message'] is String) {
          return raw['message'] as String;
        }
        return 'Password changed. Please log in again.';
      },
    );
  }

  Future<void> logoutRemote() async {
    try {
      await _dio.postEnvelope<Map<String, dynamic>>(
        'auth/logout',
        parse: (raw) {
          if (raw is Map<String, dynamic>) return raw;
          if (raw is Map) return Map<String, dynamic>.from(raw);
          return <String, dynamic>{};
        },
      );
    } catch (_) {
      // Local clear still proceeds even if remote logout fails.
    }
  }

  Future<void> persistSession({
    required String token,
    required AuthUser user,
    required Map<String, List<String>> permissions,
    required bool isFirstLogin,
  }) async {
    await _storage.writeToken(token);
    await _storage.writeSessionJson(
      jsonEncode({
        'isFirstLogin': isFirstLogin,
        'permissions': permissions,
        'user': user.toJson(),
      }),
    );
  }

  Future<({String token, AuthUser user, Map<String, List<String>> permissions, bool isFirstLogin})?>
      restoreSession() async {
    final token = await _storage.readToken();
    final sessionJson = await _storage.readSessionJson();
    if (token == null || token.isEmpty || sessionJson == null) return null;

    try {
      final map = jsonDecode(sessionJson) as Map<String, dynamic>;
      final userRaw = map['user'];
      if (userRaw is! Map) return null;
      final permsRaw = map['permissions'];
      final permissions = <String, List<String>>{};
      if (permsRaw is Map) {
        permsRaw.forEach((key, value) {
          if (value is List) {
            permissions[key.toString()] =
                value.map((e) => e.toString()).toList();
          }
        });
      }
      return (
        token: token,
        user: AuthUser.fromJson(Map<String, dynamic>.from(userRaw)),
        permissions: permissions,
        isFirstLogin: map['isFirstLogin'] == true,
      );
    } catch (_) {
      await _storage.clearAuth();
      return null;
    }
  }

  Future<void> clearSession() => _storage.clearAuth();
}
