import '../../../core/network/dio_client.dart';
import '../domain/leave_models.dart';

class LeaveRepository {
  const LeaveRepository({required DioClient dioClient}) : _dio = dioClient;

  final DioClient _dio;

  Future<List<LeaveBalance>> getMyBalances({int? year}) async {
    return _dio.getEnvelope<List<LeaveBalance>>(
      'leave/my/balances',
      queryParameters: year != null ? {'year': year} : null,
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid balances response');
        }
        return raw
            .map((e) => LeaveBalance.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<List<LeaveType>> getLeaveTypes() async {
    return _dio.getEnvelope<List<LeaveType>>(
      'leave/types',
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid leave types response');
        }
        return raw
            .map((e) => LeaveType.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<LeaveApplicationsPage> getMyApplications({
    String? status,
    int? year,
    int page = 0,
    int limit = 20,
  }) async {
    return _dio.getEnvelope<LeaveApplicationsPage>(
      'leave/my/applications',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (year != null) 'year': year,
        'page': page,
        'limit': limit,
      },
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid applications response');
        }
        return LeaveApplicationsPage.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<List<LeaveApplication>> getPendingApprovals() async {
    return _dio.getEnvelope<List<LeaveApplication>>(
      'leave/my/pending-approvals',
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid pending approvals response');
        }
        return raw
            .map((e) =>
                LeaveApplication.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<LeaveApplication> applyLeave(Map<String, dynamic> body) async {
    return _dio.postEnvelope<LeaveApplication>(
      'leave/apply',
      data: body,
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid apply response');
        }
        return LeaveApplication.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<void> cancelApplication(String id) async {
    await _dio.postEnvelope<dynamic>(
      'leave/applications/$id/cancel',
      parse: (raw) => raw,
    );
  }

  Future<LeaveApplication> approveApplication(String id, {String? remarks}) async {
    return _dio.postEnvelope<LeaveApplication>(
      'leave/applications/$id/approve',
      data: {'remarks': remarks ?? ''},
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid approve response');
        }
        return LeaveApplication.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<LeaveApplication> rejectApplication(String id, {String? remarks}) async {
    return _dio.postEnvelope<LeaveApplication>(
      'leave/applications/$id/reject',
      data: {'remarks': remarks ?? ''},
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid reject response');
        }
        return LeaveApplication.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<LeaveApplicationsPage> getAdminApplications({
    int? employeeId,
    String? status,
    int? year,
    int page = 0,
    int limit = 20,
  }) async {
    return _dio.getEnvelope<LeaveApplicationsPage>(
      'leave/admin/applications',
      queryParameters: {
        if (employeeId != null) 'employeeId': employeeId,
        if (status != null && status.isNotEmpty) 'status': status,
        if (year != null) 'year': year,
        'page': page,
        'limit': limit,
      },
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid admin applications response');
        }
        return LeaveApplicationsPage.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<LeaveApplication> adminApplyLeave(Map<String, dynamic> body) async {
    return _dio.postEnvelope<LeaveApplication>(
      'leave/admin/apply',
      data: body,
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid admin apply response');
        }
        return LeaveApplication.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<List<LeaveType>> getAdminTypes() async {
    return _dio.getEnvelope<List<LeaveType>>(
      'leave/admin/types',
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid admin types response');
        }
        return raw
            .map((e) => LeaveType.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<List<LeaveBalance>> getAdminEmployeeBalances(
    int employeeId, {
    int? year,
  }) async {
    return _dio.getEnvelope<List<LeaveBalance>>(
      'leave/admin/balances/$employeeId',
      queryParameters: year != null ? {'year': year} : null,
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid admin balances response');
        }
        return raw
            .map((e) => LeaveBalance.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<LeaveType> upsertAdminType(Map<String, dynamic> body) async {
    return _dio.postEnvelope<LeaveType>(
      'leave/admin/types',
      data: body,
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid upsert type response');
        }
        return LeaveType.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<void> deleteAdminType(String code) async {
    await _dio.deleteEnvelope<dynamic>(
      'leave/admin/types/$code',
      parse: (raw) => raw,
    );
  }

  Future<List<LeaveSetting>> getAdminSettings() async {
    return _dio.getEnvelope<List<LeaveSetting>>(
      'leave/admin/settings',
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid settings response');
        }
        return raw
            .map((e) =>
                LeaveSetting.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<LeaveSetting> patchAdminSetting(String key, String value) async {
    return _dio.patchEnvelope<LeaveSetting>(
      'leave/admin/settings/$key',
      data: {'value': value},
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid setting patch response');
        }
        return LeaveSetting.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<Map<String, dynamic>> runYearEnd(int year) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'leave/admin/year-end',
      data: {'year': year},
      parse: (raw) {
        if (raw is Map) return Map<String, dynamic>.from(raw);
        return {'result': raw};
      },
    );
  }

  Future<List<PublicHoliday>> getAdminHolidays({int? year}) async {
    return _dio.getEnvelope<List<PublicHoliday>>(
      'leave/admin/holidays',
      queryParameters: year != null ? {'year': year} : null,
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid holidays response');
        }
        return raw
            .map((e) =>
                PublicHoliday.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<PublicHoliday> addAdminHoliday(Map<String, dynamic> body) async {
    return _dio.postEnvelope<PublicHoliday>(
      'leave/admin/holidays',
      data: body,
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid holiday create response');
        }
        return PublicHoliday.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<void> deleteAdminHoliday(String id) async {
    await _dio.deleteEnvelope<dynamic>(
      'leave/admin/holidays/$id',
      parse: (raw) => raw,
    );
  }
}
