import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../domain/profile_models.dart';
import '../domain/experience_models.dart';

class ProfileRepository {
  final DioClient _dio;

  const ProfileRepository({required DioClient dioClient}) : _dio = dioClient;

  /// Fetch full employee aggregate via GET `employees/{id}`.
  Future<EmployeeProfile> getProfile(int employeeId) async {
    final emp = await _dio.getEnvelope<EmployeeProfile>(
      'employees/$employeeId',
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid employee profile data');
        }
        return EmployeeProfile.fromJson(Map<String, dynamic>.from(raw));
      },
    );

    // Fetch salary profile from salary microservice endpoint
    try {
      final salaryData = await _dio.getEnvelope<Map<String, dynamic>?>(
        'salary/employees/$employeeId/profile',
        parse: (raw) {
          if (raw is Map) {
            return Map<String, dynamic>.from(raw);
          }
          return null;
        },
      );
      if (salaryData != null && salaryData['profile'] != null) {
        final profileMap = Map<String, dynamic>.from(
          salaryData['profile'] as Map,
        );
        final salaryInfo = SalaryInfo.fromJson(profileMap);
        return EmployeeProfile(
          id: emp.id,
          abbreviation: emp.abbreviation,
          status: emp.status,
          photoUrl: emp.photoUrl,
          signatureUrl: emp.signatureUrl,
          position: emp.position,
          generalInfo: emp.generalInfo,
          personalInfo: emp.personalInfo,
          addresses: emp.addresses,
          otherInfo: emp.otherInfo,
          familyMembers: emp.familyMembers,
          academicQuals: emp.academicQuals,
          salaryInfo: salaryInfo,
          bankInfo: emp.bankInfo,
        );
      }
    } catch (_) {
      // Return basic profile if salary endpoint fails/is unconfigured/forbidden
    }

    return emp;
  }

  /// Submit a profile change request via `POST /approvals` (for Personal / Address self-edits).
  Future<void> submitChangeRequest({
    required String module,
    required Map<String, dynamic> newData,
  }) async {
    await _dio.postEnvelope<dynamic>(
      'approvals',
      data: {'module': module, 'newData': newData},
      parse: (raw) => raw,
    );
  }

  /// Get pending change-request for self-service employee via `GET /approvals/pending?module={module}`.
  Future<Map<String, dynamic>?> getPendingChangeRequest(String module) {
    return _dio.getEnvelope<Map<String, dynamic>?>(
      'approvals/pending?module=$module',
      parse: (raw) {
        if (raw is Map) {
          return Map<String, dynamic>.from(raw);
        }
        return null;
      },
    );
  }

  Future<List<EmployeeExperience>> listExperiences(int employeeId) {
    return _dio.getEnvelope<List<EmployeeExperience>>(
      'employees/$employeeId/experience',
      parse: (raw) {
        if (raw is! List)
          throw const FormatException('Invalid experience list');
        return raw
            .map(
              (e) => EmployeeExperience.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      },
    );
  }

  Future<EmployeeExperience> addExperience(
    int employeeId,
    Map<String, dynamic> data,
  ) {
    return _dio.postEnvelope<EmployeeExperience>(
      'employees/$employeeId/experience',
      data: data,
      parse: (raw) =>
          EmployeeExperience.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<EmployeeExperience> updateExperience(
    int employeeId,
    String experienceId,
    Map<String, dynamic> data,
  ) {
    return _dio.patchEnvelope<EmployeeExperience>(
      'employees/$employeeId/experience/$experienceId',
      data: data,
      parse: (raw) =>
          EmployeeExperience.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> deleteExperience(int employeeId, String experienceId) {
    return _dio.deleteEnvelope<void>(
      'employees/$employeeId/experience/$experienceId',
      parse: (_) {},
    );
  }

  /// Direct write (admin/privileged update) update employee bank info via `PATCH employees/{id}/bank`.
  Future<void> updateBankInfo(int employeeId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.dio.patch<Map<String, dynamic>>(
        'employees/$employeeId/bank',
        data: data,
      );
      _unwrapResponse(response);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Direct write (admin/privileged update) update employee other info via `PATCH employees/{id}/other`.
  Future<void> updateOtherInfo(
    int employeeId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.dio.patch<Map<String, dynamic>>(
        'employees/$employeeId/other',
        data: data,
      );
      _unwrapResponse(response);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Save employee general info directly via `PATCH employees/{id}/general`.
  Future<void> updateGeneralInfo(
    int employeeId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.dio.patch<Map<String, dynamic>>(
        'employees/$employeeId/general',
        data: data,
      );
      _unwrapResponse(response);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Update core employee row (abbreviation, photo, signature) via `PATCH employees/{id}`.
  Future<void> updateEmployeeCore(
    int employeeId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.dio.patch<Map<String, dynamic>>(
        'employees/$employeeId',
        data: data,
      );
      _unwrapResponse(response);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Direct update employee personal info directly via `PATCH employees/{id}/personal`.
  Future<void> updatePersonalInfoDirect(
    int employeeId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.dio.patch<Map<String, dynamic>>(
        'employees/$employeeId/personal',
        data: data,
      );
      _unwrapResponse(response);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Direct update employee address info directly via `PATCH employees/{id}/address/{type}`.
  Future<void> updateAddressInfoDirect(
    int employeeId,
    String type,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.dio.patch<Map<String, dynamic>>(
        'employees/$employeeId/address/$type',
        data: data,
      );
      _unwrapResponse(response);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Add family member info via `POST employees/{id}/family`.
  /// Returns the created member id when present.
  Future<String?> addFamilyMember(
    int employeeId,
    Map<String, dynamic> data,
  ) async {
    final created = await _dio.postEnvelope<Map<String, dynamic>?>(
      'employees/$employeeId/family',
      data: data,
      parse: (raw) {
        if (raw is Map<String, dynamic>) return raw;
        if (raw is Map) return Map<String, dynamic>.from(raw);
        return null;
      },
    );
    return created?['id']?.toString();
  }

  /// Update family member info via `PATCH employees/{id}/family/{memberId}`.
  Future<void> updateFamilyMember(
    int employeeId,
    String memberId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.dio.patch<Map<String, dynamic>>(
        'employees/$employeeId/family/$memberId',
        data: data,
      );
      _unwrapResponse(response);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Delete family member info via `DELETE employees/{id}/family/{memberId}`.
  Future<void> deleteFamilyMember(int employeeId, String memberId) async {
    try {
      final response = await _dio.dio.delete<Map<String, dynamic>>(
        'employees/$employeeId/family/$memberId',
      );
      _unwrapResponse(response);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Add academic qualification via `POST employees/{id}/academic`.
  Future<void> addAcademicQualification(
    int employeeId,
    Map<String, dynamic> data,
  ) async {
    await _dio.postEnvelope<dynamic>(
      'employees/$employeeId/academic',
      data: data,
      parse: (raw) => raw,
    );
  }

  /// Update academic qualification via `PATCH employees/{id}/academic/{qualId}`.
  Future<void> updateAcademicQualification(
    int employeeId,
    String qualId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.dio.patch<Map<String, dynamic>>(
        'employees/$employeeId/academic/$qualId',
        data: data,
      );
      _unwrapResponse(response);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Delete academic qualification via `DELETE employees/{id}/academic/{qualId}`.
  Future<void> deleteAcademicQualification(
    int employeeId,
    String qualId,
  ) async {
    try {
      final response = await _dio.dio.delete<Map<String, dynamic>>(
        'employees/$employeeId/academic/$qualId',
      );
      _unwrapResponse(response);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<String> resolveViewableUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    if (!trimmed.contains('res.cloudinary.com')) return trimmed;
    try {
      return await _dio.getEnvelope<String>(
        'upload/view-url',
        queryParameters: {'url': trimmed},
        parse: (raw) {
          if (raw is Map && raw['url'] is String) return raw['url'] as String;
          throw const FormatException('Invalid view-url response');
        },
      );
    } catch (_) {
      return trimmed;
    }
  }

  /// Upload file multipart helper: `POST upload/{kebab-type}`.
  /// kebabType: photo, signature, aadhaar-card, pan-card, passport, other-document, aadhaar-family, marksheet, certificate
  Future<String> uploadFile({
    required int employeeId,
    required String kebabType,
    File? file,
    Uint8List? bytes,
    String? filename,
    String? qualId,
    int? sem,
    String? memberId,
    String? experienceId,
  }) async {
    final MultipartFile multipart;
    if (file != null) {
      final name = filename ?? file.path.split(Platform.pathSeparator).last;
      multipart = await MultipartFile.fromFile(file.path, filename: name);
    } else if (bytes != null) {
      multipart = MultipartFile.fromBytes(
        bytes,
        filename: filename ?? 'upload.bin',
      );
    } else {
      throw ArgumentError('Either file or bytes must be provided');
    }

    final Map<String, dynamic> formDataMap = {
      'employeeId': employeeId,
      'file': multipart,
    };
    if (qualId != null) formDataMap['qualId'] = qualId;
    if (sem != null) formDataMap['sem'] = sem.toString();
    if (memberId != null) formDataMap['memberId'] = memberId;
    if (experienceId != null) formDataMap['experienceId'] = experienceId;

    try {
      final response = await _dio.dio.post<Map<String, dynamic>>(
        'upload/$kebabType',
        data: FormData.fromMap(formDataMap),
      );
      final body = response.data;
      if (body == null || body['success'] != true) {
        throw Exception(body?['error'] ?? 'File upload failed');
      }
      final data = body['data'];
      if (data is Map && data['url'] is String) {
        return data['url'] as String;
      }
      throw const FormatException('Upload response missing URL');
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  void _unwrapResponse(Response<Map<String, dynamic>> response) {
    final body = response.data;
    if (body == null) {
      throw Exception('Empty response from server');
    }
    if (body['success'] != true) {
      throw Exception(body['error'] ?? 'Request failed');
    }
  }

  Exception _mapDioException(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is String && error.isNotEmpty) {
        return Exception(error);
      }
      final message = data['message'];
      if (message is String && message.isNotEmpty) {
        return Exception(message);
      }
    }
    return Exception(e.message ?? 'Network request failed');
  }
}
