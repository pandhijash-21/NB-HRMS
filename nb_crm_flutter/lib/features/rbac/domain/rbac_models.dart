// RBAC domain models for user accounts, roles, and permission matrix.
enum EmployeeViewScope { none, self, institute, university }

EmployeeViewScope employeeViewScopeFromJson(String? raw) {
  switch (raw?.toUpperCase()) {
    case 'SELF':
      return EmployeeViewScope.self;
    case 'INSTITUTE':
      return EmployeeViewScope.institute;
    case 'UNIVERSITY':
      return EmployeeViewScope.university;
    default:
      return EmployeeViewScope.none;
  }
}

String employeeViewScopeToJson(EmployeeViewScope scope) {
  switch (scope) {
    case EmployeeViewScope.self:
      return 'SELF';
    case EmployeeViewScope.institute:
      return 'INSTITUTE';
    case EmployeeViewScope.university:
      return 'UNIVERSITY';
    case EmployeeViewScope.none:
      return 'NONE';
  }
}

class RoleRef {
  const RoleRef({required this.id, required this.name});

  final String id;
  final String name;

  factory RoleRef.fromJson(Map<String, dynamic> json) {
    return RoleRef(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class UserEmployeeInfo {
  const UserEmployeeInfo({
    this.employeeCode,
    this.fullName,
    this.photoUrl,
    this.designation,
    this.department,
    this.generalInfo,
  });

  final String? employeeCode;
  final String? fullName;
  final String? photoUrl;
  final String? designation;
  final String? department;
  final Map<String, dynamic>? generalInfo;

  factory UserEmployeeInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserEmployeeInfo();
    final gi = json['generalInfo'];
    return UserEmployeeInfo(
      employeeCode: json['employeeCode']?.toString() ??
          (gi is Map ? gi['employeeCode']?.toString() : null),
      fullName: json['fullName']?.toString() ??
          (gi is Map ? gi['fullName']?.toString() : null),
      photoUrl: json['photoUrl']?.toString(),
      designation: json['designation']?.toString() ??
          (gi is Map ? gi['designation']?.toString() : null),
      department: json['department']?.toString() ??
          (gi is Map ? gi['department']?.toString() : null),
      generalInfo: gi is Map ? Map<String, dynamic>.from(gi) : null,
    );
  }
}

class PositionSlotInfo {
  const PositionSlotInfo({
    required this.code,
    required this.name,
    this.designationName,
  });

  final String code;
  final String name;
  final String? designationName;

  factory PositionSlotInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const PositionSlotInfo(code: '', name: '');
    }
    final des = json['designation'];
    return PositionSlotInfo(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      designationName: des is Map ? des['name']?.toString() : null,
    );
  }
}

class UserAccount {
  const UserAccount({
    required this.id,
    this.employeeId,
    this.username,
    required this.isActive,
    required this.roleId,
    required this.role,
    this.employee,
    this.positionSlot,
    this.lastLoginAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final int? employeeId;
  final String? username;
  final bool isActive;
  final String roleId;
  final RoleRef role;
  final UserEmployeeInfo? employee;
  final PositionSlotInfo? positionSlot;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName {
    final empName = employee?.fullName;
    if (empName != null && empName.isNotEmpty) return empName;
    if (positionSlot != null && positionSlot!.name.isNotEmpty) {
      return positionSlot!.name;
    }
    if (username != null && username!.isNotEmpty) return username!;
    return 'Unknown';
  }

  String get displaySubtitle {
    final code = employee?.employeeCode;
    if (code != null && code.isNotEmpty) return code;
    if (positionSlot != null) {
      final des = positionSlot!.designationName ?? positionSlot!.code;
      return 'ALIAS · $des';
    }
    if (username != null && username!.isNotEmpty) return 'POSITION';
    return '—';
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    final roleRaw = json['role'];
    final empRaw = json['employee'];
    final slotRaw = json['positionSlot'];

    return UserAccount(
      id: json['id']?.toString() ?? '',
      employeeId: _parseInt(json['employeeId']),
      username: json['username']?.toString(),
      isActive: json['isActive'] == true,
      roleId: json['roleId']?.toString() ??
          (roleRaw is Map ? roleRaw['id']?.toString() : null) ??
          '',
      role: roleRaw is Map
          ? RoleRef.fromJson(Map<String, dynamic>.from(roleRaw))
          : const RoleRef(id: '', name: ''),
      employee: empRaw is Map
          ? UserEmployeeInfo.fromJson(Map<String, dynamic>.from(empRaw))
          : null,
      positionSlot: slotRaw is Map
          ? PositionSlotInfo.fromJson(Map<String, dynamic>.from(slotRaw))
          : null,
      lastLoginAt: _parseDate(json['lastLoginAt']),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }
}

class RoleSummary {
  const RoleSummary({
    required this.id,
    required this.name,
    this.description,
    this.positionName,
    this.userCount = 0,
    this.isSystem = false,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final String? positionName;
  final int userCount;
  final bool isSystem;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RoleSummary.fromJson(Map<String, dynamic> json) {
    final countRaw = json['userCount'] ?? json['_count'];
    int count = 0;
    if (countRaw is int) {
      count = countRaw;
    } else if (countRaw is Map) {
      count = _parseInt(countRaw['users']) ?? 0;
    }

    return RoleSummary(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      positionName: json['positionName']?.toString(),
      userCount: count,
      isSystem: json['isSystem'] == true,
      isActive: json['isActive'] != false,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }
}

class SystemModule {
  const SystemModule({
    required this.key,
    required this.name,
    this.description,
    this.isActive = true,
  });

  final String key;
  final String name;
  final String? description;
  final bool isActive;

  factory SystemModule.fromJson(Map<String, dynamic> json) {
    return SystemModule(
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? json['moduleName']?.toString() ?? '',
      description: json['description']?.toString(),
      isActive: json['isActive'] != false,
    );
  }
}

class ModulePermission {
  const ModulePermission({
    this.id,
    required this.moduleKey,
    required this.canRead,
    required this.canWrite,
    required this.canApprove,
    required this.canDelete,
    required this.canExport,
    this.employeeViewScope = EmployeeViewScope.none,
    this.module,
  });

  final String? id;
  final String moduleKey;
  final bool canRead;
  final bool canWrite;
  final bool canApprove;
  final bool canDelete;
  final bool canExport;
  final EmployeeViewScope employeeViewScope;
  final SystemModule? module;

  ModulePermission copyWith({
    bool? canRead,
    bool? canWrite,
    bool? canApprove,
    bool? canDelete,
    bool? canExport,
    EmployeeViewScope? employeeViewScope,
  }) {
    return ModulePermission(
      id: id,
      moduleKey: moduleKey,
      canRead: canRead ?? this.canRead,
      canWrite: canWrite ?? this.canWrite,
      canApprove: canApprove ?? this.canApprove,
      canDelete: canDelete ?? this.canDelete,
      canExport: canExport ?? this.canExport,
      employeeViewScope: employeeViewScope ?? this.employeeViewScope,
      module: module,
    );
  }

  factory ModulePermission.fromJson(Map<String, dynamic> json) {
    final moduleRaw = json['module'];
    final key = json['moduleKey']?.toString() ??
        (moduleRaw is Map ? moduleRaw['key']?.toString() : null) ??
        '';

    return ModulePermission(
      id: json['id']?.toString(),
      moduleKey: key,
      canRead: json['canRead'] == true,
      canWrite: json['canWrite'] == true,
      canApprove: json['canApprove'] == true,
      canDelete: json['canDelete'] == true,
      canExport: json['canExport'] == true,
      employeeViewScope: employeeViewScopeFromJson(
        json['employeeViewScope']?.toString(),
      ),
      module: moduleRaw is Map
          ? SystemModule.fromJson(Map<String, dynamic>.from(moduleRaw))
          : (json['moduleName'] != null
              ? SystemModule(
                  key: key,
                  name: json['moduleName']?.toString() ?? key,
                )
              : null),
    );
  }
}

class AccountCredentials {
  const AccountCredentials({
    required this.userId,
    this.loginId,
    required this.accountType,
    required this.isFirstLogin,
    this.password,
    required this.passwordNote,
    required this.canLogin,
  });

  final String userId;
  final String? loginId;
  final String accountType;
  final bool isFirstLogin;
  final String? password;
  final String passwordNote;
  final bool canLogin;

  factory AccountCredentials.fromJson(Map<String, dynamic> json) {
    return AccountCredentials(
      userId: json['userId']?.toString() ?? '',
      loginId: json['loginId']?.toString(),
      accountType: json['accountType']?.toString() ?? 'SYSTEM',
      isFirstLogin: json['isFirstLogin'] == true,
      password: json['password']?.toString(),
      passwordNote: json['passwordNote']?.toString() ?? '',
      canLogin: json['canLogin'] == true,
    );
  }
}

class PasswordResetResult {
  const PasswordResetResult({
    this.loginId,
    required this.password,
    this.message,
  });

  final String? loginId;
  final String password;
  final String? message;

  factory PasswordResetResult.fromJson(Map<String, dynamic> json) {
    return PasswordResetResult(
      loginId: json['loginId']?.toString(),
      password: json['password']?.toString() ?? '',
      message: json['message']?.toString(),
    );
  }
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
