import '../../../core/network/dio_client.dart';
import '../domain/attendance_models.dart';

class AttendanceRepository {
  const AttendanceRepository({required DioClient dioClient}) : _dio = dioClient;

  final DioClient _dio;

  Future<Map<String, AttendanceCalendarDay>> getMyCalendar({
    required String from,
    required String to,
  }) async {
    return _dio.getEnvelope<Map<String, AttendanceCalendarDay>>(
      'attendance/my/calendar',
      queryParameters: {'from': from, 'to': to},
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid calendar response');
        }
        final result = <String, AttendanceCalendarDay>{};
        raw.forEach((key, value) {
          if (value is Map) {
            result[key.toString()] = AttendanceCalendarDay.fromJson(
              Map<String, dynamic>.from(value),
            );
          }
        });
        return result;
      },
    );
  }

  Future<AttendanceMyDay> getMyDay({required String date}) async {
    return _dio.getEnvelope<AttendanceMyDay>(
      'attendance/my/day',
      queryParameters: {'date': date},
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid day response');
        }
        return AttendanceMyDay.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<List<AdminAttendanceEmployeeRow>> getAdminDay({
    required String date,
  }) async {
    return _dio.getEnvelope<List<AdminAttendanceEmployeeRow>>(
      'attendance/admin/day',
      queryParameters: {'date': date},
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid admin day response');
        }
        return raw
            .map((e) => AdminAttendanceEmployeeRow.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList();
      },
    );
  }

  Future<AttendancePunch> createAdminPunch(Map<String, dynamic> body) async {
    return _dio.postEnvelope<AttendancePunch>(
      'attendance/admin/punch',
      data: body,
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid punch create response');
        }
        return AttendancePunch.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<AttendancePunch> updateAdminPunch(
    String id,
    Map<String, dynamic> body,
  ) async {
    return _dio.patchEnvelope<AttendancePunch>(
      'attendance/admin/punch/$id',
      data: body,
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid punch update response');
        }
        return AttendancePunch.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<AttendancePolicy> getAdminPolicy() async {
    return _dio.getEnvelope<AttendancePolicy>(
      'attendance/admin/policy',
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid policy response');
        }
        return AttendancePolicy.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<AttendancePolicy> updateAdminPolicy(Map<String, dynamic> body) async {
    return _dio.patchEnvelope<AttendancePolicy>(
      'attendance/admin/policy',
      data: body,
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid policy update response');
        }
        return AttendancePolicy.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<AdminAttendanceEmployeeHistory> getAdminEmployeeHistory({
    required int employeeId,
    required String from,
    required String to,
  }) async {
    return _dio.getEnvelope<AdminAttendanceEmployeeHistory>(
      'attendance/admin/employee/$employeeId/history',
      queryParameters: {'from': from, 'to': to},
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid employee history response');
        }
        return AdminAttendanceEmployeeHistory.fromJson(
          Map<String, dynamic>.from(raw),
        );
      },
    );
  }

  Future<EmployeeAttendanceSettings> getEmployeeSettings(int employeeId) async {
    return _dio.getEnvelope<EmployeeAttendanceSettings>(
      'attendance/employee/$employeeId/settings',
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid settings response');
        return EmployeeAttendanceSettings.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<EmployeeAttendanceSettings> updateEmployeeSettings(
    int employeeId,
    Map<String, dynamic> body,
  ) async {
    return _dio.patchEnvelope<EmployeeAttendanceSettings>(
      'attendance/employee/$employeeId/settings',
      data: body,
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid settings update response');
        return EmployeeAttendanceSettings.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<AttendanceMonthlySummary> getEmployeeMonthlySummary({
    required int employeeId,
    required int year,
    required int month,
  }) async {
    return _dio.getEnvelope<AttendanceMonthlySummary>(
      'attendance/employee/$employeeId/monthly-summary',
      queryParameters: {'year': year, 'month': month},
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid monthly summary response');
        return AttendanceMonthlySummary.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<DeviceAttendanceStatus> getDeviceStatus() async {
    return _dio.getEnvelope<DeviceAttendanceStatus>(
      'attendance/admin/device/status',
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid device status response');
        }
        return DeviceAttendanceStatus.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<DevicePaytimeMeta> getDeviceMeta() async {
    return _dio.getEnvelope<DevicePaytimeMeta>(
      'attendance/admin/device/meta',
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid device meta response');
        }
        return DevicePaytimeMeta.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<List<DevicePunchPreviewRow>> getDevicePreview({
    required String from,
    required String to,
    String? empcode,
    String mode = 'raw',
  }) async {
    return _dio.getEnvelope<List<DevicePunchPreviewRow>>(
      'attendance/admin/device/preview',
      queryParameters: {
        'from': from,
        'to': to,
        'source': 'paytime',
        'mode': mode,
        if (empcode != null && empcode.isNotEmpty) 'empcode': empcode,
      },
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid device preview response');
        }
        return raw
            .map(
              (e) => DevicePunchPreviewRow.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      },
    );
  }

  Future<DeviceSyncResult> syncDeviceNow() async {
    return _dio.postEnvelope<DeviceSyncResult>(
      'attendance/admin/device/sync',
      data: const {},
      receiveTimeout: const Duration(minutes: 2),
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid device sync response');
        }
        return DeviceSyncResult.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<DeviceSyncResult> backfillDevice({
    required String from,
    required String to,
    String? empcode,
  }) async {
    return _dio.postEnvelope<DeviceSyncResult>(
      'attendance/admin/device/backfill',
      data: {
        'from': from,
        'to': to,
        if (empcode != null && empcode.isNotEmpty) 'empcode': empcode,
      },
      receiveTimeout: const Duration(minutes: 3),
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid device backfill response');
        }
        return DeviceSyncResult.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<void> resetEmployeeBiometrics(int employeeId) async {
    await _dio.postEnvelope<void>(
      'attendance/admin/reset-biometrics/$employeeId',
      data: const {},
      parse: (raw) => null,
    );
  }

  Future<void> adminAddPunch({
    required int employeeId,
    required String punchAt,
    String? punchType,
    String? terminalId,
  }) async {
    await _dio.postEnvelope<void>(
      'attendance/admin/punch',
      data: {
        'employeeId': employeeId,
        'punchAt': punchAt,
        if (punchType != null) 'punchType': punchType,
        if (terminalId != null) 'terminalId': terminalId,
      },
      parse: (raw) => null,
    );
  }

  Future<void> adminUpdatePunch({
    required String punchId,
    required String punchAt,
    String? punchType,
    String? terminalId,
  }) async {
    await _dio.patchEnvelope<void>(
      'attendance/admin/punch/$punchId',
      data: {
        'punchAt': punchAt,
        if (punchType != null) 'punchType': punchType,
        if (terminalId != null) 'terminalId': terminalId,
      },
      parse: (raw) => null,
    );
  }
}
