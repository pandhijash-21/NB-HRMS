import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../profile/domain/profile_models.dart';
import '../domain/admin_models.dart';

class AdminRepository {
  final DioClient _dio;

  const AdminRepository({required DioClient dioClient}) : _dio = dioClient;

  /// Fetch workforce listing via GET `employees`.
  Future<Map<String, dynamic>> listEmployees({
    required int limit,
    required int offset,
    String? search,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    return _dio.getEnvelope<Map<String, dynamic>>(
      'employees',
      queryParameters: queryParams,
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid response format for employee list');
        }
        final list = (raw['items'] as List? ?? [])
            .map((e) => EmployeeProfile.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        final total = raw['total'] as int? ?? 0;
        return {
          'items': list,
          'total': total,
        };
      },
    );
  }

  /// Create an employee directly via POST `employees/full`.
  Future<EmployeeProfile> createEmployee(Map<String, dynamic> data) async {
    return _dio.postEnvelope<EmployeeProfile>(
      'employees/full',
      data: data,
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid response format for employee creation');
        }
        return EmployeeProfile.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  /// Soft-delete/deactivate an employee via DELETE `employees/{id}`.
  Future<void> deleteEmployee(int employeeId) async {
    try {
      final response = await _dio.dio.delete<Map<String, dynamic>>(
        'employees/$employeeId',
      );
      final body = response.data;
      if (body == null || body['success'] != true) {
        throw Exception(body?['error'] ?? 'Deactivation failed');
      }
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Fetch assignment history of an employee via GET `employees/{id}/assignments`.
  Future<List<EmployeeAssignment>> listAssignments(int employeeId) async {
    return _dio.getEnvelope<List<EmployeeAssignment>>(
      'employees/$employeeId/assignments',
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid assignment list format');
        }
        return raw
            .map((e) => EmployeeAssignment.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  /// Assign position to employee via PATCH `employees/{id}/position`.
  Future<void> assignPosition(int employeeId, String? positionDesignationId) async {
    try {
      final response = await _dio.dio.patch<Map<String, dynamic>>(
        'employees/$employeeId/position',
        data: {'positionDesignationId': positionDesignationId},
      );
      final body = response.data;
      if (body == null || body['success'] != true) {
        throw Exception(body?['error'] ?? 'Assign position failed');
      }
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Transfer employee to another institute via POST `employees/{id}/institute-transfer`.
  Future<void> instituteTransfer(int employeeId, Map<String, dynamic> data) async {
    await _dio.postEnvelope<dynamic>(
      'employees/$employeeId/institute-transfer',
      data: data,
      parse: (raw) => raw,
    );
  }

  /// Upgrade employee designation via POST `employees/{id}/designation-upgrade`.
  Future<void> designationUpgrade(int employeeId, Map<String, dynamic> data) async {
    await _dio.postEnvelope<dynamic>(
      'employees/$employeeId/designation-upgrade',
      data: data,
      parse: (raw) => raw,
    );
  }

  /// List profile change requests via GET `approvals`.
  Future<List<ChangeRequest>> listApprovals({String? status, int? employeeId}) async {
    final queryParams = <String, dynamic>{};
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (employeeId != null) queryParams['employeeId'] = employeeId;

    return _dio.getEnvelope<List<ChangeRequest>>(
      'approvals',
      queryParameters: queryParams,
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid approvals list format');
        }
        return raw
            .map((e) => ChangeRequest.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  /// Approve change request via POST `approvals/{id}/approve`.
  Future<void> approveRequest(String id) async {
    await _dio.postEnvelope<dynamic>(
      'approvals/$id/approve',
      parse: (raw) => raw,
    );
  }

  /// Reject change request via POST `approvals/{id}/reject`.
  Future<void> rejectRequest(String id) async {
    await _dio.postEnvelope<dynamic>(
      'approvals/$id/reject',
      parse: (raw) => raw,
    );
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
