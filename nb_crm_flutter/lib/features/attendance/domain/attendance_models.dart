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
  });

  final int count;
  final String? firstIn;
  final String? lastOut;

  factory AttendanceCalendarDay.fromJson(Map<String, dynamic> json) {
    return AttendanceCalendarDay(
      count: _asInt(json['count']),
      firstIn: json['firstIn'] as String?,
      lastOut: json['lastOut'] as String?,
    );
  }
}

class AttendancePunch {
  const AttendancePunch({
    required this.id,
    required this.punchAt,
    this.terminalId,
    this.punchType,
    this.source,
    this.employeeId,
  });

  final String id;
  final String punchAt;
  final String? terminalId;
  final String? punchType;
  final String? source;
  final int? employeeId;

  factory AttendancePunch.fromJson(Map<String, dynamic> json) {
    return AttendancePunch(
      id: json['id']?.toString() ?? '',
      punchAt: json['punchAt']?.toString() ?? '',
      terminalId: json['terminalId'] as String?,
      punchType: json['punchType'] as String?,
      source: json['source'] as String?,
      employeeId: json['employeeId'] != null ? _asInt(json['employeeId']) : null,
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

class AttendanceMyDaySummary {
  const AttendanceMyDaySummary({
    this.firstIn,
    this.lastOut,
    this.totalMinutes = 0,
    this.policy,
    this.evaluation,
  });

  final String? firstIn;
  final String? lastOut;
  final int totalMinutes;
  final AttendancePolicy? policy;
  final AttendanceDayEvaluation? evaluation;

  factory AttendanceMyDaySummary.fromJson(Map<String, dynamic> json) {
    final policy = _asMap(json['policy']);
    final evaluation = _asMap(json['evaluation']);
    return AttendanceMyDaySummary(
      firstIn: json['firstIn'] as String?,
      lastOut: json['lastOut'] as String?,
      totalMinutes: _asInt(json['totalMinutes']),
      policy: policy != null ? AttendancePolicy.fromJson(policy) : null,
      evaluation:
          evaluation != null ? AttendanceDayEvaluation.fromJson(evaluation) : null,
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
