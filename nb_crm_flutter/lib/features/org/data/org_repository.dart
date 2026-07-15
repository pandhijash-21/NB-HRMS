import '../../../core/network/dio_client.dart';
import '../domain/org_models.dart';

class OrgRepository {
  const OrgRepository({required DioClient dioClient}) : _dio = dioClient;

  final DioClient _dio;

  Future<List<Institute>> listInstitutes({bool includeInactive = true}) async {
    return _dio.getEnvelope<List<Institute>>(
      'admin/institutes',
      queryParameters: includeInactive ? {'includeInactive': 'true'} : null,
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid institutes response');
        }
        return raw
            .map((e) => Institute.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<Institute> createInstitute({
    required String code,
    required String name,
    int? sortOrder,
  }) async {
    return _dio.postEnvelope<Institute>(
      'admin/institutes',
      data: {
        'code': code,
        'name': name,
        if (sortOrder != null) 'sortOrder': sortOrder,
      },
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid institute create response');
        }
        return Institute.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<Institute> updateInstitute(
    String id, {
    String? code,
    String? name,
    bool? isActive,
    int? sortOrder,
  }) async {
    return _dio.patchEnvelope<Institute>(
      'admin/institutes/$id',
      data: {
        if (code != null) 'code': code,
        if (name != null) 'name': name,
        if (isActive != null) 'isActive': isActive,
        if (sortOrder != null) 'sortOrder': sortOrder,
      },
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid institute update response');
        }
        return Institute.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<InstituteMembersPayload> getInstituteMembers(String id) async {
    return _dio.getEnvelope<InstituteMembersPayload>(
      'admin/institutes/$id/members',
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid institute members response');
        }
        return InstituteMembersPayload.fromJson(
          Map<String, dynamic>.from(raw),
        );
      },
    );
  }

  Future<List<Designation>> listDesignations({
    bool? isAlias,
    bool includeInactive = false,
  }) async {
    final params = <String, dynamic>{};
    if (isAlias != null) params['isAlias'] = isAlias.toString();
    if (includeInactive) params['includeInactive'] = 'true';

    return _dio.getEnvelope<List<Designation>>(
      'admin/designations',
      queryParameters: params.isEmpty ? null : params,
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid designations response');
        }
        return raw
            .map((e) =>
                Designation.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<Designation> createDesignation({
    required String name,
    bool isAlias = false,
    String? linkedRoleId,
  }) async {
    return _dio.postEnvelope<Designation>(
      'admin/designations',
      data: {
        'name': name,
        if (isAlias) 'isAlias': isAlias,
        if (linkedRoleId != null) 'linkedRoleId': linkedRoleId,
      },
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid designation create response');
        }
        return Designation.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<Designation> updateDesignation(
    String id, {
    String? name,
    bool? isActive,
    String? linkedRoleId,
  }) async {
    return _dio.patchEnvelope<Designation>(
      'admin/designations/$id',
      data: {
        if (name != null) 'name': name,
        if (isActive != null) 'isActive': isActive,
        if (linkedRoleId != null) 'linkedRoleId': linkedRoleId,
      },
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid designation update response');
        }
        return Designation.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<List<Position>> listPositions() async {
    return _dio.getEnvelope<List<Position>>(
      'admin/positions',
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid positions response');
        }
        return raw
            .map((e) => Position.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<CreatePositionResult> createPosition({
    required String displayName,
    required String roleName,
    String? description,
  }) async {
    return _dio.postEnvelope<CreatePositionResult>(
      'admin/positions',
      data: {
        'displayName': displayName,
        'roleName': roleName,
        if (description != null && description.isNotEmpty) 'description': description,
      },
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid position create response');
        }
        return CreatePositionResult.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<List<PositionSlot>> listPositionSlots() async {
    return _dio.getEnvelope<List<PositionSlot>>(
      'admin/position-slots',
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid position slots response');
        }
        return raw
            .map((e) =>
                PositionSlot.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<CreatePositionSlotResult> createPositionSlot({
    required String code,
    required String name,
    required String designationId,
    String? linkedRoleId,
    String? instituteId,
    String? subOrganization,
    required String password,
    bool grantUniversityAccess = false,
  }) async {
    return _dio.postEnvelope<CreatePositionSlotResult>(
      'admin/position-slots',
      data: {
        'code': code,
        'name': name,
        'designationId': designationId,
        if (linkedRoleId != null) 'linkedRoleId': linkedRoleId,
        if (instituteId != null) 'instituteId': instituteId,
        if (subOrganization != null) 'subOrganization': subOrganization,
        'password': password,
        if (grantUniversityAccess) 'grantUniversityAccess': true,
      },
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid position slot create response');
        }
        return CreatePositionSlotResult.fromJson(
          Map<String, dynamic>.from(raw),
        );
      },
    );
  }

  Future<dynamic> assignPositionSlot({
    required String slotId,
    required int holderEmployeeId,
    required String effectiveFrom,
  }) async {
    return _dio.postEnvelope<dynamic>(
      'admin/position-slots/$slotId/assign',
      data: {
        'holderEmployeeId': holderEmployeeId,
        'effectiveFrom': effectiveFrom,
      },
      parse: (raw) => raw,
    );
  }
}
