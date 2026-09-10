import '../../../core/network/dio_client.dart';
import '../domain/platform_models.dart';

class PlatformRepository {
  final DioClient _dio;

  const PlatformRepository({required DioClient dioClient}) : _dio = dioClient;

  Future<PlatformStats> getStats() async {
    return _dio.getEnvelope<PlatformStats>(
      'platform/stats',
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid platform stats response');
        return PlatformStats.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<List<ClientCompany>> listCompanies() async {
    return _dio.getEnvelope<List<ClientCompany>>(
      'platform/companies',
      parse: (raw) {
        if (raw is! List) throw const FormatException('Expected list of companies');
        return raw
            .whereType<Map>()
            .map((m) => ClientCompany.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      },
    );
  }

  Future<Map<String, dynamic>> onboardCompany(Map<String, dynamic> data) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'platform/companies',
      data: data,
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid onboard response');
        return Map<String, dynamic>.from(raw);
      },
    );
  }

  Future<Map<String, dynamic>> updateCompany(String id, Map<String, dynamic> data) async {
    return _dio.patchEnvelope<Map<String, dynamic>>(
      'platform/companies/$id',
      data: data,
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid update response');
        return Map<String, dynamic>.from(raw);
      },
    );
  }

  Future<List<PlatformAdminUser>> listAdmins() async {
    return _dio.getEnvelope<List<PlatformAdminUser>>(
      'platform/admins',
      parse: (raw) {
        if (raw is! List) throw const FormatException('Expected list of admins');
        return raw
            .whereType<Map>()
            .map((m) => PlatformAdminUser.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      },
    );
  }

  Future<void> resetAdminPassword(String userId, String newPassword) async {
    await _dio.postEnvelope<void>(
      'platform/admins/$userId/reset-password',
      data: {'newPassword': newPassword},
      parse: (_) {},
    );
  }

  Future<void> unlockAdminAccount(String userId) async {
    await _dio.postEnvelope<void>(
      'platform/admins/$userId/unlock',
      data: const {},
      parse: (_) {},
    );
  }

  Future<void> trashCompany(String id, {String? superadminPassword}) async {
    await _dio.deleteEnvelope<void>(
      'platform/companies/$id',
      data: superadminPassword != null ? {'superadminPassword': superadminPassword} : null,
      parse: (_) {},
    );
  }

  Future<void> restoreCompany(String id) async {
    await _dio.postEnvelope<void>(
      'platform/companies/$id/restore',
      data: const {},
      parse: (_) {},
    );
  }

  Future<void> purgeCompany(String id, {String? superadminPassword}) async {
    await _dio.deleteEnvelope<void>(
      'platform/companies/$id/permanent',
      data: superadminPassword != null ? {'superadminPassword': superadminPassword} : null,
      parse: (_) {},
    );
  }

  Future<void> trashAdmin(String id, {String? superadminPassword}) async {
    await _dio.deleteEnvelope<void>(
      'platform/admins/$id',
      data: superadminPassword != null ? {'superadminPassword': superadminPassword} : null,
      parse: (_) {},
    );
  }

  Future<void> restoreAdmin(String id) async {
    await _dio.postEnvelope<void>(
      'platform/admins/$id/restore',
      data: const {},
      parse: (_) {},
    );
  }

  Future<void> purgeAdmin(String id, {String? superadminPassword}) async {
    await _dio.deleteEnvelope<void>(
      'platform/admins/$id/permanent',
      data: superadminPassword != null ? {'superadminPassword': superadminPassword} : null,
      parse: (_) {},
    );
  }

  Future<PlatformTrashData> getTrash() async {
    return _dio.getEnvelope<PlatformTrashData>(
      'platform/trash',
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Expected trash data map');
        return PlatformTrashData.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<void> emptyTrash({String? superadminPassword}) async {
    await _dio.deleteEnvelope<void>(
      'platform/trash/empty',
      data: superadminPassword != null ? {'superadminPassword': superadminPassword} : null,
      parse: (_) {},
    );
  }
}
