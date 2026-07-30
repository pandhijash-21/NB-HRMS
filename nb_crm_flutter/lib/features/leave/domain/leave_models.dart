Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) return const [];
  return value.map(_asMap).whereType<Map<String, dynamic>>().toList();
}

double _asDouble(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

int _asInt(Object? value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

bool _asBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value == null) return fallback;
  final s = value.toString().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return fallback;
}

String? _dateOnly(Object? value) {
  if (value == null) return null;
  final s = value.toString();
  return s.length >= 10 ? s.substring(0, 10) : s;
}

class LeaveType {
  const LeaveType({
    required this.id,
    required this.code,
    required this.name,
    this.applicableTo,
    this.defaultDaysPerYear,
    this.isCarryForward = false,
    this.allowHalfDay = true,
    this.skipPublicHolidays = true,
    this.skipWeekends = true,
    this.requiresDocument = false,
    this.requiresReason = true,
    this.isActive = true,
    this.employeeCanApply = true,
    this.cutsSalary = false,
  });

  final String id;
  final String code;
  final String name;
  final String? applicableTo;
  final double? defaultDaysPerYear;
  final bool isCarryForward;
  final bool allowHalfDay;
  final bool skipPublicHolidays;
  final bool skipWeekends;
  final bool requiresDocument;
  final bool requiresReason;
  final bool isActive;
  final bool employeeCanApply;
  final bool cutsSalary;

  factory LeaveType.fromJson(Map<String, dynamic> json) {
    return LeaveType(
      id: json['id']?.toString() ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      applicableTo: json['applicableTo'] as String?,
      defaultDaysPerYear: json['defaultDaysPerYear'] != null
          ? _asDouble(json['defaultDaysPerYear'])
          : null,
      isCarryForward: json['isCarryForward'] as bool? ?? false,
      allowHalfDay: json['allowHalfDay'] as bool? ?? true,
      skipPublicHolidays: json['skipPublicHolidays'] as bool? ?? true,
      skipWeekends: json['skipWeekends'] as bool? ?? true,
      requiresDocument: json['requiresDocument'] as bool? ?? false,
      requiresReason: json['requiresReason'] as bool? ?? true,
      isActive: json['isActive'] as bool? ?? true,
      employeeCanApply: json['employeeCanApply'] as bool? ?? true,
      cutsSalary: json['cutsSalary'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        if (applicableTo != null) 'applicableTo': applicableTo,
        if (defaultDaysPerYear != null) 'defaultDaysPerYear': defaultDaysPerYear,
        'isCarryForward': isCarryForward,
        'allowHalfDay': allowHalfDay,
        'skipPublicHolidays': skipPublicHolidays,
        'skipWeekends': skipWeekends,
        'requiresDocument': requiresDocument,
        'requiresReason': requiresReason,
        'isActive': isActive,
        'employeeCanApply': employeeCanApply,
        'cutsSalary': cutsSalary,
      };
}

class LeaveBalance {
  const LeaveBalance({
    required this.id,
    required this.employeeId,
    required this.leaveTypeId,
    required this.year,
    required this.totalCredited,
    required this.carryForward,
    required this.used,
    required this.pending,
    this.leaveType,
  });

  final String id;
  final int employeeId;
  final String leaveTypeId;
  final int year;
  final double totalCredited;
  final double carryForward;
  final double used;
  final double pending;
  final LeaveType? leaveType;

  double get displayAvailable => totalCredited + carryForward - used;

  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    final lt = _asMap(json['leaveType']);
    return LeaveBalance(
      id: json['id']?.toString() ?? '',
      employeeId: _asInt(json['employeeId']),
      leaveTypeId: json['leaveTypeId']?.toString() ?? '',
      year: _asInt(json['year']),
      totalCredited: _asDouble(json['totalCredited']),
      carryForward: _asDouble(json['carryForward']),
      used: _asDouble(json['used']),
      pending: _asDouble(json['pending']),
      leaveType: lt != null ? LeaveType.fromJson(lt) : null,
    );
  }
}

class LeaveEmployeeInfo {
  const LeaveEmployeeInfo({
    required this.id,
    this.fullName,
    this.employeeCode,
    this.designation,
    this.department,
  });

  final int id;
  final String? fullName;
  final String? employeeCode;
  final String? designation;
  final String? department;

  factory LeaveEmployeeInfo.fromJson(Map<String, dynamic> json) {
    final general = _asMap(json['generalInfo']);
    return LeaveEmployeeInfo(
      id: _asInt(json['id']),
      fullName: general?['fullName'] as String?,
      employeeCode: general?['employeeCode'] as String?,
      designation: general?['designation'] as String?,
      department: general?['department'] as String?,
    );
  }
}

class LeaveApprovalStep {
  LeaveApprovalStep({
    required this.id,
    required this.stepNumber,
    this.approverRole,
    this.approverUserId,
    this.approverName,
    this.action,
    this.remarks,
    this.actionAt,
    bool? isSuperseded,
  }) : _isSuperseded = isSuperseded;

  final String id;
  final int stepNumber;
  final String? approverRole;
  final String? approverUserId;
  final String? approverName;
  final String? action;
  final String? remarks;
  final String? actionAt;
  final bool? _isSuperseded;

  /// Safe on web when legacy/cached JSON omitted this field (null at runtime).
  bool get isSuperseded => _isSuperseded == true;

  bool get isDone => action == 'RECOMMENDED' || action == 'APPROVED';
  bool get isRejected => action == 'REJECTED';
  bool get isPending => action == null && !isSuperseded;

  String get roleLabel {
    switch (approverRole) {
      case 'FIRST_REPORTING':
        return '1st Reporting';
      case 'SECOND_REPORTING':
        return '2nd Reporting';
      case 'THIRD_REPORTING':
        return '3rd Reporting';
      default:
        return approverRole?.replaceAll('_', ' ') ?? 'Approver';
    }
  }

  String get statusLabel {
    if (isSuperseded && action == null) return 'Skipped';
    if (action == 'RECOMMENDED') return 'Approved';
    if (action == 'APPROVED') return 'Approved';
    if (action == 'REJECTED') return 'Rejected';
    return 'Pending';
  }

  factory LeaveApprovalStep.fromJson(Map<String, dynamic> json) {
    return LeaveApprovalStep(
      id: json['id']?.toString() ?? '',
      stepNumber: _asInt(json['stepNumber']),
      approverRole: json['approverRole'] as String?,
      approverUserId: json['approverUserId']?.toString(),
      approverName: json['approverName'] as String?,
      action: json['action'] as String?,
      remarks: json['remarks'] as String?,
      actionAt: json['actionAt']?.toString(),
      isSuperseded: _asBool(json['isSuperseded']),
    );
  }
}

class LeaveApplication {
  const LeaveApplication({
    required this.id,
    required this.applicationNo,
    required this.employeeId,
    required this.leaveTypeId,
    required this.fromDate,
    required this.toDate,
    required this.isHalfDay,
    this.halfDaySession,
    required this.totalDays,
    required this.reason,
    this.documentUrl,
    required this.status,
    this.appliedAt,
    this.isAppliedByAdmin = false,
    this.leaveType,
    this.employee,
    this.approvalSteps = const [],
  });

  final String id;
  final String applicationNo;
  final int employeeId;
  final String leaveTypeId;
  final String fromDate;
  final String toDate;
  final bool isHalfDay;
  final String? halfDaySession;
  final double totalDays;
  final String reason;
  final String? documentUrl;
  final String status;
  final String? appliedAt;
  final bool isAppliedByAdmin;
  final LeaveType? leaveType;
  final LeaveEmployeeInfo? employee;
  final List<LeaveApprovalStep> approvalSteps;

  factory LeaveApplication.fromJson(Map<String, dynamic> json) {
    final lt = _asMap(json['leaveType']);
    final emp = _asMap(json['employee']);
    return LeaveApplication(
      id: json['id']?.toString() ?? '',
      applicationNo: json['applicationNo'] as String? ?? '',
      employeeId: _asInt(json['employeeId']),
      leaveTypeId: json['leaveTypeId']?.toString() ?? '',
      fromDate: _dateOnly(json['fromDate']) ?? '',
      toDate: _dateOnly(json['toDate']) ?? '',
      isHalfDay: _asBool(json['isHalfDay']),
      halfDaySession: json['halfDaySession'] as String?,
      totalDays: _asDouble(json['totalDays']),
      reason: json['reason'] as String? ?? '',
      documentUrl: json['documentUrl'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      appliedAt: json['appliedAt']?.toString(),
      isAppliedByAdmin: _asBool(json['isAppliedByAdmin']),
      leaveType: lt != null ? LeaveType.fromJson(lt) : null,
      employee: emp != null ? LeaveEmployeeInfo.fromJson(emp) : null,
      approvalSteps: _asMapList(json['approvalSteps'])
          .map(LeaveApprovalStep.fromJson)
          .toList(),
    );
  }
}

class LeaveApplicationsPage {
  const LeaveApplicationsPage({required this.items, required this.total});

  final List<LeaveApplication> items;
  final int total;

  factory LeaveApplicationsPage.fromJson(Map<String, dynamic> json) {
    return LeaveApplicationsPage(
      items: _asMapList(json['items']).map(LeaveApplication.fromJson).toList(),
      total: _asInt(json['total']),
    );
  }
}

class LeaveSetting {
  const LeaveSetting({
    required this.id,
    required this.key,
    required this.value,
    required this.description,
    this.updatedBy,
    this.updatedAt,
  });

  final String id;
  final String key;
  final String value;
  final String description;
  final String? updatedBy;
  final String? updatedAt;

  factory LeaveSetting.fromJson(Map<String, dynamic> json) {
    return LeaveSetting(
      id: json['id']?.toString() ?? '',
      key: json['key'] as String? ?? '',
      value: json['value'] as String? ?? '',
      description: json['description'] as String? ?? '',
      updatedBy: json['updatedBy'] as String?,
      updatedAt: json['updatedAt']?.toString(),
    );
  }
}

class PublicHoliday {
  const PublicHoliday({
    required this.id,
    required this.name,
    required this.date,
    required this.year,
    this.isOptional = false,
  });

  final String id;
  final String name;
  final String date;
  final int year;
  final bool isOptional;

  factory PublicHoliday.fromJson(Map<String, dynamic> json) {
    return PublicHoliday(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      date: _dateOnly(json['date']) ?? '',
      year: _asInt(json['year']),
      isOptional: json['isOptional'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'date': date,
        'year': year,
        'isOptional': isOptional,
      };
}
