class EmployeeNameOption {
  final String type;
  final String userId;
  final String fullName;
  final String? employeeCode;
  final String? designationName;
  final int? employeeId;

  const EmployeeNameOption({
    required this.type,
    required this.userId,
    required this.fullName,
    this.employeeCode,
    this.designationName,
    this.employeeId,
  });

  factory EmployeeNameOption.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    int? employeeId;
    if (json['type'] == 'EMPLOYEE' || json['type'] == null) {
      if (rawId is int) {
        employeeId = rawId;
      } else if (rawId != null) {
        employeeId = int.tryParse(rawId.toString());
      }
    }
    return EmployeeNameOption(
      type: json['type'] as String? ?? 'EMPLOYEE',
      userId: json['userId']?.toString() ?? '',
      fullName: json['fullName'] as String? ?? '',
      employeeCode: json['employeeCode'] as String?,
      designationName: json['designationName'] as String?,
      employeeId: employeeId,
    );
  }

  String get displayLabel {
    final code = employeeCode;
    final designation = designationName;
    final parts = <String>[fullName];
    if (code != null && code.isNotEmpty) parts.add(code);
    if (designation != null && designation.isNotEmpty) parts.add(designation);
    return parts.join(' • ');
  }
}

class ChangeRequestGeneralInfo {
  final String fullName;
  final String? employeeCode;
  final String? designation;

  ChangeRequestGeneralInfo({
    required this.fullName,
    this.employeeCode,
    this.designation,
  });

  factory ChangeRequestGeneralInfo.fromJson(Map<String, dynamic> json) {
    return ChangeRequestGeneralInfo(
      fullName: json['fullName'] as String? ?? '',
      employeeCode: json['employeeCode'] as String?,
      designation: json['designation'] as String?,
    );
  }
}

class ChangeRequestEmployee {
  final int id;
  final ChangeRequestGeneralInfo? generalInfo;

  ChangeRequestEmployee({
    required this.id,
    this.generalInfo,
  });

  factory ChangeRequestEmployee.fromJson(Map<String, dynamic> json) {
    return ChangeRequestEmployee(
      id: json['id'] as int? ?? 0,
      generalInfo: json['generalInfo'] != null
          ? ChangeRequestGeneralInfo.fromJson(Map<String, dynamic>.from(json['generalInfo'] as Map))
          : null,
    );
  }
}

class ChangeRequest {
  final String id;
  final int employeeId;
  final String module;
  final Map<String, dynamic> oldData;
  final Map<String, dynamic> newData;
  final String status;
  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final ChangeRequestEmployee employee;

  ChangeRequest({
    required this.id,
    required this.employeeId,
    required this.module,
    required this.oldData,
    required this.newData,
    required this.status,
    required this.requestedAt,
    this.reviewedAt,
    required this.employee,
  });

  factory ChangeRequest.fromJson(Map<String, dynamic> json) {
    return ChangeRequest(
      id: json['id'] as String? ?? '',
      employeeId: json['employeeId'] as int? ?? 0,
      module: json['module'] as String? ?? '',
      oldData: json['oldData'] != null ? Map<String, dynamic>.from(json['oldData'] as Map) : {},
      newData: json['newData'] != null ? Map<String, dynamic>.from(json['newData'] as Map) : {},
      status: json['status'] as String? ?? 'PENDING',
      requestedAt: json['requestedAt'] != null
          ? DateTime.parse(json['requestedAt'].toString())
          : DateTime.now(),
      reviewedAt: json['reviewedAt'] != null ? DateTime.parse(json['reviewedAt'].toString()) : null,
      employee: ChangeRequestEmployee.fromJson(
        Map<String, dynamic>.from(json['employee'] as Map? ?? {}),
      ),
    );
  }
}

class EmployeeAssignment {
  final String id;
  final int employeeId;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final String? organization;
  final String? instituteId;
  final String? subOrganization;
  final String? department;
  final String designation;
  final String? designationId;
  final String? shift;
  final String? reason;
  final String changedBy;
  final DateTime createdAt;

  EmployeeAssignment({
    required this.id,
    required this.employeeId,
    required this.effectiveFrom,
    this.effectiveTo,
    this.organization,
    this.instituteId,
    this.subOrganization,
    this.department,
    required this.designation,
    this.designationId,
    this.shift,
    this.reason,
    required this.changedBy,
    required this.createdAt,
  });

  factory EmployeeAssignment.fromJson(Map<String, dynamic> json) {
    return EmployeeAssignment(
      id: json['id'] as String? ?? '',
      employeeId: json['employeeId'] as int? ?? 0,
      effectiveFrom: json['effectiveFrom'] != null
          ? DateTime.parse(json['effectiveFrom'].toString())
          : DateTime.now(),
      effectiveTo: json['effectiveTo'] != null ? DateTime.parse(json['effectiveTo'].toString()) : null,
      organization: json['organization'] as String?,
      instituteId: json['instituteId'] as String?,
      subOrganization: json['subOrganization'] as String?,
      department: json['department'] as String?,
      designation: json['designation'] as String? ?? '',
      designationId: json['designationId'] as String?,
      shift: json['shift'] as String?,
      reason: json['reason'] as String?,
      changedBy: json['changedBy'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
    );
  }
}
