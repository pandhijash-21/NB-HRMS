Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) return const [];
  return value.map(_asMap).whereType<Map<String, dynamic>>().toList();
}

int _asInt(Object? value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

class AttendanceCalendarDay {
  const AttendanceCalendarDay({
    required this.count,
    this.firstIn,
    this.lastOut,
    this.dayStatus,
  });

  final int count;
  final String? firstIn;
  final String? lastOut;
  final String? dayStatus;

  factory AttendanceCalendarDay.fromJson(Map<String, dynamic> json) {
    return AttendanceCalendarDay(
      count: _asInt(json['count']),
      firstIn: json['firstIn'] as String?,
      lastOut: json['lastOut'] as String?,
      dayStatus: json['dayStatus'] as String?,
    );
  }

  bool get isLeave => (dayStatus ?? '').toUpperCase() == 'LEAVE';
}

class AttendancePunch {
  const AttendancePunch({
    required this.id,
    required this.punchAt,
    this.terminalId,
    this.punchType,
    this.source,
    this.employeeId,
    this.latitude,
    this.longitude,
    this.locationId,
    this.location,
    this.deviceInfo,
    this.reason,
  });

  final String id;
  final String punchAt;
  final String? terminalId;
  final String? punchType;
  final String? source;
  final int? employeeId;
  final double? latitude;
  final double? longitude;
  final String? locationId;
  final Map<String, dynamic>? location;
  final Map<String, dynamic>? deviceInfo;
  final String? reason;

  factory AttendancePunch.fromJson(Map<String, dynamic> json) {
    return AttendancePunch(
      id: json['id']?.toString() ?? '',
      punchAt: json['punchAt']?.toString() ?? '',
      terminalId: json['terminalId'] as String?,
      punchType: json['punchType'] as String?,
      source: json['source'] as String?,
      employeeId: json['employeeId'] as int?,
      latitude: json['latitude'] is num ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] is num ? (json['longitude'] as num).toDouble() : null,
      locationId: json['locationId'] as String?,
      location: json['location'] != null ? Map<String, dynamic>.from(json['location'] as Map) : null,
      deviceInfo: json['deviceInfo'] != null ? Map<String, dynamic>.from(json['deviceInfo'] as Map) : null,
      reason: json['reason'] as String?,
    );
  }
}

class AttendancePolicy {
  const AttendancePolicy({
    required this.id,
    required this.defaultPunchInTime,
    required this.defaultPunchOutTime,
    required this.punchInBufferMinutes,
    required this.punchOutBufferMinutes,
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String defaultPunchInTime;
  final String defaultPunchOutTime;
  final int punchInBufferMinutes;
  final int punchOutBufferMinutes;
  final String? updatedAt;
  final String? updatedBy;

  factory AttendancePolicy.fromJson(Map<String, dynamic> json) {
    return AttendancePolicy(
      id: json['id'] as String? ?? 'default',
      defaultPunchInTime: json['defaultPunchInTime'] as String? ?? '09:00',
      defaultPunchOutTime: json['defaultPunchOutTime'] as String? ?? '15:30',
      punchInBufferMinutes: _asInt(json['punchInBufferMinutes']),
      punchOutBufferMinutes: _asInt(json['punchOutBufferMinutes']),
      updatedAt: json['updatedAt']?.toString(),
      updatedBy: json['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'defaultPunchInTime': defaultPunchInTime,
        'defaultPunchOutTime': defaultPunchOutTime,
        'punchInBufferMinutes': punchInBufferMinutes,
        'punchOutBufferMinutes': punchOutBufferMinutes,
      };
}

class AttendanceDayEvaluation {
  const AttendanceDayEvaluation({
    this.isLate,
    this.isHalfDay,
    this.meetsPunchOut,
  });

  final bool? isLate;
  final bool? isHalfDay;
  final bool? meetsPunchOut;

  factory AttendanceDayEvaluation.fromJson(Map<String, dynamic> json) {
    return AttendanceDayEvaluation(
      isLate: json['isLate'] as bool?,
      isHalfDay: json['isHalfDay'] as bool?,
      meetsPunchOut: json['meetsPunchOut'] as bool?,
    );
  }
}

class AttendanceDayLeaveInfo {
  const AttendanceDayLeaveInfo({
    this.applicationNo,
    this.leaveTypeName,
    this.leaveTypeCode,
    this.fromDate,
    this.toDate,
    this.isHalfDay,
  });

  final String? applicationNo;
  final String? leaveTypeName;
  final String? leaveTypeCode;
  final String? fromDate;
  final String? toDate;
  final bool? isHalfDay;

  factory AttendanceDayLeaveInfo.fromJson(Map<String, dynamic> json) {
    return AttendanceDayLeaveInfo(
      applicationNo: json['applicationNo'] as String?,
      leaveTypeName: json['leaveTypeName'] as String?,
      leaveTypeCode: json['leaveTypeCode'] as String?,
      fromDate: json['fromDate']?.toString(),
      toDate: json['toDate']?.toString(),
      isHalfDay: json['isHalfDay'] as bool?,
    );
  }
}

class AttendanceMyDaySummary {
  const AttendanceMyDaySummary({
    this.firstIn,
    this.lastOut,
    this.totalMinutes = 0,
    this.policy,
    this.evaluation,
    this.dayStatus,
    this.leave,
  });

  final String? firstIn;
  final String? lastOut;
  final int totalMinutes;
  final AttendancePolicy? policy;
  final AttendanceDayEvaluation? evaluation;
  final String? dayStatus;
  final AttendanceDayLeaveInfo? leave;

  bool get isLeave => (dayStatus ?? '').toUpperCase() == 'LEAVE';
  bool get isAbsent => (dayStatus ?? '').toUpperCase() == 'ABSENT';

  factory AttendanceMyDaySummary.fromJson(Map<String, dynamic> json) {
    final policy = _asMap(json['policy']);
    final evaluation = _asMap(json['evaluation']);
    final leave = _asMap(json['leave']);
    return AttendanceMyDaySummary(
      firstIn: json['firstIn'] as String?,
      lastOut: json['lastOut'] as String?,
      totalMinutes: _asInt(json['totalMinutes']),
      policy: policy != null ? AttendancePolicy.fromJson(policy) : null,
      evaluation:
          evaluation != null ? AttendanceDayEvaluation.fromJson(evaluation) : null,
      dayStatus: json['dayStatus'] as String?,
      leave: leave != null ? AttendanceDayLeaveInfo.fromJson(leave) : null,
    );
  }
}

class AttendanceMyDay {
  const AttendanceMyDay({
    required this.punches,
    required this.summary,
  });

  final List<AttendancePunch> punches;
  final AttendanceMyDaySummary summary;

  factory AttendanceMyDay.fromJson(Map<String, dynamic> json) {
    final summary = _asMap(json['summary']);
    return AttendanceMyDay(
      punches: _asMapList(json['punches']).map(AttendancePunch.fromJson).toList(),
      summary: summary != null
          ? AttendanceMyDaySummary.fromJson(summary)
          : const AttendanceMyDaySummary(),
    );
  }
}

class AdminAttendanceEmployeeRow {
  const AdminAttendanceEmployeeRow({
    required this.employeeId,
    required this.fullName,
    this.employeeCode,
    this.designation,
    this.department,
    required this.punches,
  });

  final int employeeId;
  final String fullName;
  final String? employeeCode;
  final String? designation;
  final String? department;
  final List<AttendancePunch> punches;

  String? get firstIn => punches.isEmpty ? null : punches.first.punchAt;
  String? get lastOut => punches.isEmpty ? null : punches.last.punchAt;

  factory AdminAttendanceEmployeeRow.fromJson(Map<String, dynamic> json) {
    return AdminAttendanceEmployeeRow(
      employeeId: _asInt(json['employeeId']),
      fullName: json['fullName'] as String? ?? '',
      employeeCode: json['employeeCode'] as String?,
      designation: json['designation'] as String?,
      department: json['department'] as String?,
      punches: _asMapList(json['punches']).map(AttendancePunch.fromJson).toList(),
    );
  }
}

class AdminAttendanceHistoryDay {
  const AdminAttendanceHistoryDay({
    required this.date,
    this.firstIn,
    this.lastOut,
    this.totalMinutes = 0,
    required this.punches,
    this.isLate,
    this.isHalfDay,
    this.meetsPunchOut,
    this.dayStatus,
  });

  final String date;
  final String? firstIn;
  final String? lastOut;
  final int totalMinutes;
  final List<AttendancePunch> punches;
  final bool? isLate;
  final bool? isHalfDay;
  final bool? meetsPunchOut;
  final String? dayStatus;

  factory AdminAttendanceHistoryDay.fromJson(Map<String, dynamic> json) {
    return AdminAttendanceHistoryDay(
      date: json['date']?.toString() ?? '',
      firstIn: json['firstIn'] as String?,
      lastOut: json['lastOut'] as String?,
      totalMinutes: _asInt(json['totalMinutes']),
      punches: _asMapList(json['punches']).map(AttendancePunch.fromJson).toList(),
      isLate: json['isLate'] as bool?,
      isHalfDay: json['isHalfDay'] as bool?,
      meetsPunchOut: json['meetsPunchOut'] as bool?,
      dayStatus: json['dayStatus'] as String?,
    );
  }
}

class AdminAttendanceEmployeeHistory {
  const AdminAttendanceEmployeeHistory({
    required this.employeeId,
    required this.fullName,
    this.employeeCode,
    this.designation,
    this.department,
    required this.from,
    required this.to,
    this.policy,
    required this.days,
  });

  final int employeeId;
  final String fullName;
  final String? employeeCode;
  final String? designation;
  final String? department;
  final String from;
  final String to;
  final AttendancePolicy? policy;
  final List<AdminAttendanceHistoryDay> days;

  factory AdminAttendanceEmployeeHistory.fromJson(Map<String, dynamic> json) {
    final employee = _asMap(json['employee']) ?? {};
    final policy = _asMap(json['policy']);
    return AdminAttendanceEmployeeHistory(
      employeeId: _asInt(employee['employeeId'] ?? json['employeeId']),
      fullName: employee['fullName'] as String? ?? '',
      employeeCode: employee['employeeCode'] as String?,
      designation: employee['designation'] as String?,
      department: employee['department'] as String?,
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      policy: policy != null ? AttendancePolicy.fromJson(policy) : null,
      days: _asMapList(json['days']).map(AdminAttendanceHistoryDay.fromJson).toList(),
    );
  }
}

class EmployeeAttendanceSettings {
  const EmployeeAttendanceSettings({
    required this.employeeId,
    required this.useGlobalPolicy,
    this.punchInTime,
    this.punchOutTime,
    this.punchInBufferMinutes,
    this.punchOutBufferMinutes,
    this.biometricToken,
    required this.effective,
    this.globalPolicy,
  });

  final int employeeId;
  final bool useGlobalPolicy;
  final String? punchInTime;
  final String? punchOutTime;
  final int? punchInBufferMinutes;
  final int? punchOutBufferMinutes;
  final String? biometricToken;
  final Map<String, dynamic> effective;
  final AttendancePolicy? globalPolicy;

  factory EmployeeAttendanceSettings.fromJson(Map<String, dynamic> json) {
    final effective = _asMap(json['effective']) ?? {};
    final global = _asMap(json['globalPolicy']);
    return EmployeeAttendanceSettings(
      employeeId: _asInt(json['employeeId']),
      useGlobalPolicy: json['useGlobalPolicy'] as bool? ?? true,
      punchInTime: json['punchInTime'] as String?,
      punchOutTime: json['punchOutTime'] as String?,
      punchInBufferMinutes: json['punchInBufferMinutes'] as int?,
      punchOutBufferMinutes: json['punchOutBufferMinutes'] as int?,
      biometricToken: json['biometricToken'] as String?,
      effective: effective,
      globalPolicy: global != null ? AttendancePolicy.fromJson(global) : null,
    );
  }
}

class AttendanceMonthlyStats {
  const AttendanceMonthlyStats({
    required this.presentDays,
    required this.lateDays,
    required this.halfDays,
    required this.absentDays,
    required this.totalWorkingMinutes,
    required this.totalWorkingHours,
    required this.leaveApplications,
    required this.leaveDaysInMonth,
    this.leaveDays = 0,
  });

  final int presentDays;
  final int lateDays;
  final int halfDays;
  final int absentDays;
  final int totalWorkingMinutes;
  final double totalWorkingHours;
  final int leaveApplications;
  final double leaveDaysInMonth;
  final int leaveDays;

  factory AttendanceMonthlyStats.fromJson(Map<String, dynamic> json) {
    return AttendanceMonthlyStats(
      presentDays: _asInt(json['presentDays']),
      lateDays: _asInt(json['lateDays']),
      halfDays: _asInt(json['halfDays']),
      absentDays: _asInt(json['absentDays']),
      totalWorkingMinutes: _asInt(json['totalWorkingMinutes']),
      totalWorkingHours: (json['totalWorkingHours'] as num?)?.toDouble() ?? 0,
      leaveApplications: _asInt(json['leaveApplications']),
      leaveDaysInMonth: (json['leaveDaysInMonth'] as num?)?.toDouble() ?? 0,
      leaveDays: _asInt(json['leaveDays']),
    );
  }
}

class AttendanceMonthlySummary {
  const AttendanceMonthlySummary({
    required this.year,
    required this.month,
    required this.from,
    required this.to,
    required this.stats,
    required this.days,
    required this.leaveApplications,
  });

  final int year;
  final int month;
  final String from;
  final String to;
  final AttendanceMonthlyStats stats;
  final List<AdminAttendanceHistoryDay> days;
  final List<Map<String, dynamic>> leaveApplications;

  factory AttendanceMonthlySummary.fromJson(Map<String, dynamic> json) {
    return AttendanceMonthlySummary(
      year: _asInt(json['year']),
      month: _asInt(json['month']),
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      stats: AttendanceMonthlyStats.fromJson(
        _asMap(json['stats']) ?? const {},
      ),
      days: _asMapList(json['days']).map(AdminAttendanceHistoryDay.fromJson).toList(),
      leaveApplications: _asMapList(json['leaveApplications']),
    );
  }
}

class DeviceSyncSourceStatus {
  const DeviceSyncSourceStatus({
    required this.configured,
    this.lastSyncedAt,
    this.cursor,
    this.note,
  });

  final bool configured;
  final String? lastSyncedAt;
  final String? cursor;
  final String? note;

  factory DeviceSyncSourceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceSyncSourceStatus(
      configured: json['configured'] == true,
      lastSyncedAt: json['lastSyncedAt'] as String?,
      cursor: json['cursor'] as String?,
      note: json['note'] as String?,
    );
  }
}

class DeviceAttendanceStatus {
  const DeviceAttendanceStatus({
    required this.etimeoffice,
    required this.esslMssql,
    required this.employeesWithPunchId,
  });

  final DeviceSyncSourceStatus etimeoffice;
  final DeviceSyncSourceStatus esslMssql;
  final int employeesWithPunchId;

  factory DeviceAttendanceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceAttendanceStatus(
      etimeoffice: DeviceSyncSourceStatus.fromJson(
        Map<String, dynamic>.from(json['etimeoffice'] as Map? ?? const {}),
      ),
      esslMssql: DeviceSyncSourceStatus.fromJson(
        Map<String, dynamic>.from(json['esslMssql'] as Map? ?? const {}),
      ),
      employeesWithPunchId: (json['employeesWithPunchId'] as num?)?.toInt() ?? 0,
    );
  }
}

class DevicePunchPreviewRow {
  const DevicePunchPreviewRow({
    this.name,
    required this.empcode,
    required this.punchDate,
    this.mcid,
    this.mFlag,
    this.matchedEmployeeId,
  });

  final String? name;
  final String empcode;
  final String punchDate;
  final String? mcid;
  final String? mFlag;
  final int? matchedEmployeeId;

  factory DevicePunchPreviewRow.fromJson(Map<String, dynamic> json) {
    return DevicePunchPreviewRow(
      name: json['name'] as String? ?? json['Name'] as String?,
      empcode: (json['empcode'] ?? json['Empcode'] ?? '').toString(),
      punchDate: (json['punchDate'] ?? json['PunchDate'] ?? '').toString(),
      mcid: json['mcid']?.toString() ?? json['MCID']?.toString(),
      mFlag: json['mFlag']?.toString() ?? json['M_Flag']?.toString(),
      matchedEmployeeId: json['matchedEmployeeId'] is int
          ? json['matchedEmployeeId'] as int
          : int.tryParse('${json['matchedEmployeeId'] ?? ''}'),
    );
  }
}

class DeviceSyncResult {
  const DeviceSyncResult({
    required this.source,
    required this.fetched,
    required this.inserted,
    required this.skippedUnmatched,
    required this.unmatchedCodes,
  });

  final String source;
  final int fetched;
  final int inserted;
  final int skippedUnmatched;
  final List<String> unmatchedCodes;

  factory DeviceSyncResult.fromJson(Map<String, dynamic> json) {
    final codes = json['unmatchedCodes'];
    return DeviceSyncResult(
      source: (json['source'] ?? '').toString(),
      fetched: (json['fetched'] as num?)?.toInt() ?? 0,
      inserted: (json['inserted'] as num?)?.toInt() ?? 0,
      skippedUnmatched: (json['skippedUnmatched'] as num?)?.toInt() ?? 0,
      unmatchedCodes: codes is List
          ? codes.map((e) => e.toString()).toList()
          : const [],
    );
  }
}
