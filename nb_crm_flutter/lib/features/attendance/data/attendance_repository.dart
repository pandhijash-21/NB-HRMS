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
}
