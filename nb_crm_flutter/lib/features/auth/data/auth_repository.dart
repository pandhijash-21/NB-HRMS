import 'dart:convert';

import '../../../core/network/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/logging/app_logger.dart';
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
    String? portal,
  }) {
    return _dio.postEnvelope<LoginResult>(
      'auth/login',
      data: {
        'identifier': identifier.trim(),
        'password': password,
        if (portal != null) 'portal': portal,
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

  Future<({bool needsEmailVerification, List<PendingEmail> emails})>
      fetchEmailVerificationStatus() {
    return _dio.getEnvelope(
      'otp/status',
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid OTP status payload');
        }
        final map = Map<String, dynamic>.from(raw);
        final list = <PendingEmail>[];
        final emailsRaw = map['emails'];
        if (emailsRaw is List) {
          for (final item in emailsRaw) {
            if (item is Map) {
              list.add(PendingEmail.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
        return (
          needsEmailVerification: map['needsEmailVerification'] == true,
          emails: list,
        );
      },
    );
  }

  Future<int> sendEmailOtp(String email) {
    return _dio.postEnvelope<int>(
      'otp/send',
      data: {'email': email},
      parse: (raw) {
        if (raw is Map && raw['cooldownSeconds'] is int) {
          return raw['cooldownSeconds'] as int;
        }
        return 120;
      },
    );
  }

  Future<({bool needsEmailVerification})> verifyEmailOtp({
    required String email,
    required String otp,
  }) {
    return _dio.postEnvelope(
      'otp/verify',
      data: {'email': email, 'otp': otp},
      parse: (raw) {
        if (raw is! Map) {
          return (needsEmailVerification: false);
        }
        final map = Map<String, dynamic>.from(raw);
        return (
          needsEmailVerification: map['needsEmailVerification'] == true,
        );
      },
    );
  }

  Future<void> logoutRemote() async {
    await _dio.postEnvelope<Map<String, dynamic>>(
      'auth/logout',
      parse: (raw) {
        if (raw is Map<String, dynamic>) return raw;
        if (raw is Map) return Map<String, dynamic>.from(raw);
        return <String, dynamic>{};
      },
    );
  }

  Future<void> persistSession({
    required String token,
    required AuthUser user,
    required Map<String, List<String>> permissions,
    required bool isFirstLogin,
    required bool needsEmailVerification,
    bool needsEmergencyContact = false,
  }) async {
    await _storage.writeToken(token);
    await _storage.writeSessionJson(
      jsonEncode({
        'apiBaseUrl': AppConfig.apiBaseUrl,
        'isFirstLogin': isFirstLogin,
        'needsEmailVerification': needsEmailVerification,
        'needsEmergencyContact': needsEmergencyContact,
        'permissions': permissions,
        'user': user.toJson(),
      }),
    );
  }

  Future<
      ({
        String token,
        AuthUser user,
        Map<String, List<String>> permissions,
        bool isFirstLogin,
        bool needsEmailVerification,
        bool needsEmergencyContact,
      })?> restoreSession() async {
    final token = await _storage.readToken();
    final sessionJson = await _storage.readSessionJson();
    if (token == null || token.isEmpty || sessionJson == null) return null;

    try {
      final map = jsonDecode(sessionJson) as Map<String, dynamic>;
      final savedApi = map['apiBaseUrl']?.toString();
      if (savedApi != null && savedApi.isNotEmpty) {
        if (AppConfig.isLocalUrl(savedApi) != AppConfig.isUsingLocalBackend) {
          await clearSession();
          return null;
        }
      } else if (AppConfig.isUsingLocalBackend) {
        await clearSession();
        return null;
      }
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
        needsEmailVerification: map['needsEmailVerification'] == true,
        needsEmergencyContact: map['needsEmergencyContact'] == true,
      );
    } catch (e, st) {
      AppLogger.auth.e('Error restoring session from storage: $e', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> clearSession() => _storage.clearAuth();

  Future<bool> readRememberMe() => _storage.readRememberMe();

  Future<({String identifier, String password})?>
      readRememberedCredentials() => _storage.readRememberedCredentials();

  Future<void> saveRememberedCredentials({
    required String identifier,
    required String password,
  }) =>
      _storage.writeRememberedCredentials(
        identifier: identifier,
        password: password,
      );

  Future<void> clearRememberedCredentials() =>
      _storage.clearRememberedCredentials();

  /// Marks Mr NB software tour as completed for the signed-in account (server).
  Future<void> markSoftwareTourSeen() {
    return _dio.postEnvelope<void>(
      'auth/software-tour/seen',
      parse: (_) {},
    );
  }

  /// Live server flag — used so restored sessions without the field don't flash welcome.
  Future<bool> fetchSoftwareTourSeen() {
    return _dio.getEnvelope<bool>(
      'auth/me',
      parse: (raw) {
        if (raw is Map) return raw['softwareTourSeen'] == true;
        return false;
      },
    );
  }
}
