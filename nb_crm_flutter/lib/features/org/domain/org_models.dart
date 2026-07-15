Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

int _asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool _asBool(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

class LinkedRole {
  const LinkedRole({required this.id, required this.name});

  final String id;
  final String name;

  factory LinkedRole.fromJson(Map<String, dynamic> json) {
    return LinkedRole(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class Institute {
  const Institute({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
    required this.sortOrder,
  });

  final String id;
  final String code;
  final String name;
  final bool isActive;
  final int sortOrder;

  factory Institute.fromJson(Map<String, dynamic> json) {
    return Institute(
      id: json['id']?.toString() ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isActive: _asBool(json['isActive'], true),
      sortOrder: _asInt(json['sortOrder']),
    );
  }
}

class Designation {
  const Designation({
    required this.id,
    required this.name,
    required this.slug,
    required this.isAlias,
    this.linkedRoleId,
    required this.isActive,
    required this.sortOrder,
    this.linkedRole,
  });

  final String id;
  final String name;
  final String slug;
  final bool isAlias;
  final String? linkedRoleId;
  final bool isActive;
  final int sortOrder;
  final LinkedRole? linkedRole;

  factory Designation.fromJson(Map<String, dynamic> json) {
    final linked = _asMap(json['linkedRole']);
    return Designation(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      isAlias: _asBool(json['isAlias']),
      linkedRoleId: json['linkedRoleId']?.toString(),
      isActive: _asBool(json['isActive'], true),
      sortOrder: _asInt(json['sortOrder']),
      linkedRole: linked != null ? LinkedRole.fromJson(linked) : null,
    );
  }
}

class Position {
  const Position({
    required this.id,
    required this.name,
    required this.linkedRoleId,
    required this.linkedRoleName,
  });

  final String id;
  final String name;
  final String linkedRoleId;
  final String linkedRoleName;

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      linkedRoleId: json['linkedRoleId']?.toString() ?? '',
      linkedRoleName: json['linkedRoleName'] as String? ?? '',
    );
  }
}

class PositionSlotUser {
  const PositionSlotUser({
    required this.id,
    required this.username,
    required this.isActive,
    this.isFirstLogin,
    this.lastLoginAt,
  });

  final String id;
  final String username;
  final bool isActive;
  final bool? isFirstLogin;
  final String? lastLoginAt;

  factory PositionSlotUser.fromJson(Map<String, dynamic> json) {
    return PositionSlotUser(
      id: json['id']?.toString() ?? '',
      username: json['username'] as String? ?? '',
      isActive: _asBool(json['isActive'], true),
      isFirstLogin: json['isFirstLogin'] as bool?,
      lastLoginAt: json['lastLoginAt'] as String?,
    );
  }
}

class PositionSlot {
  const PositionSlot({
    required this.id,
    required this.code,
    required this.name,
    required this.designationId,
    required this.linkedRoleId,
    this.subOrganization,
    this.userId,
    required this.isActive,
    required this.designation,
    required this.linkedRole,
    this.institute,
    this.user,
  });

  final String id;
  final String code;
  final String name;
  final String designationId;
  final String linkedRoleId;
  final String? subOrganization;
  final String? userId;
  final bool isActive;
  final Designation designation;
  final LinkedRole linkedRole;
  final Institute? institute;
  final PositionSlotUser? user;

  factory PositionSlot.fromJson(Map<String, dynamic> json) {
    final designationMap = _asMap(json['designation']);
    final linkedRoleMap = _asMap(json['linkedRole']);
    final instituteMap = _asMap(json['institute']);
    final userMap = _asMap(json['user']);

    return PositionSlot(
      id: json['id']?.toString() ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      designationId: json['designationId']?.toString() ?? '',
      linkedRoleId: json['linkedRoleId']?.toString() ?? '',
      subOrganization: json['subOrganization'] as String?,
      userId: json['userId']?.toString(),
      isActive: _asBool(json['isActive'], true),
      designation: designationMap != null
          ? Designation.fromJson(designationMap)
          : Designation(
              id: json['designationId']?.toString() ?? '',
              name: '',
              slug: '',
              isAlias: true,
              isActive: true,
              sortOrder: 0,
            ),
      linkedRole: linkedRoleMap != null
          ? LinkedRole.fromJson(linkedRoleMap)
          : LinkedRole(id: json['linkedRoleId']?.toString() ?? '', name: ''),
      institute: instituteMap != null ? Institute.fromJson(instituteMap) : null,
      user: userMap != null ? PositionSlotUser.fromJson(userMap) : null,
    );
  }
}

class AliasAccount {
  const AliasAccount({
    required this.id,
    required this.code,
    required this.name,
    this.subOrganization,
    required this.designationName,
    required this.linkedRoleName,
    this.userActive,
  });

  final String id;
  final String code;
  final String name;
  final String? subOrganization;
  final String designationName;
  final String linkedRoleName;
  final bool? userActive;

  factory AliasAccount.fromJson(Map<String, dynamic> json) {
    final designation = _asMap(json['designation']);
    final linkedRole = _asMap(json['linkedRole']);
    final user = _asMap(json['user']);

    return AliasAccount(
      id: json['id']?.toString() ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      subOrganization: json['subOrganization'] as String?,
      designationName: designation?['name'] as String? ?? '',
      linkedRoleName: linkedRole?['name'] as String? ?? '',
      userActive: user != null ? _asBool(user['isActive'], true) : null,
    );
  }
}

class InstituteMemberGeneralInfo {
  const InstituteMemberGeneralInfo({
    this.fullName,
    this.employeeCode,
    this.designation,
    this.department,
    this.subOrganization,
  });

  final String? fullName;
  final String? employeeCode;
  final String? designation;
  final String? department;
  final String? subOrganization;

  factory InstituteMemberGeneralInfo.fromJson(Map<String, dynamic> json) {
    return InstituteMemberGeneralInfo(
      fullName: json['fullName'] as String?,
      employeeCode: json['employeeCode'] as String?,
      designation: json['designation'] as String?,
      department: json['department'] as String?,
      subOrganization: json['subOrganization'] as String?,
    );
  }
}

class InstituteMember {
  const InstituteMember({
    required this.id,
    required this.status,
    this.generalInfo,
  });

  final int id;
  final String status;
  final InstituteMemberGeneralInfo? generalInfo;

  factory InstituteMember.fromJson(Map<String, dynamic> json) {
    final general = _asMap(json['generalInfo']);
    return InstituteMember(
      id: _asInt(json['id']),
      status: json['status'] as String? ?? 'ACTIVE',
      generalInfo:
          general != null ? InstituteMemberGeneralInfo.fromJson(general) : null,
    );
  }
}

class InstituteMembersPayload {
  const InstituteMembersPayload({
    required this.institute,
    required this.employees,
    required this.aliases,
  });

  final Institute institute;
  final List<InstituteMember> employees;
  final List<AliasAccount> aliases;

  factory InstituteMembersPayload.fromJson(Map<String, dynamic> json) {
    final instituteMap = _asMap(json['institute']);
    final employeesRaw = json['employees'];
    final aliasesRaw = json['aliases'];

    return InstituteMembersPayload(
      institute: instituteMap != null
          ? Institute.fromJson(instituteMap)
          : Institute(id: '', code: '', name: '', isActive: true, sortOrder: 0),
      employees: employeesRaw is List
          ? employeesRaw
              .map((e) => InstituteMember.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : const [],
      aliases: aliasesRaw is List
          ? aliasesRaw
              .map((e) => AliasAccount.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : const [],
    );
  }
}

class CreatePositionResult {
  const CreatePositionResult({
    required this.role,
    required this.designation,
  });

  final LinkedRole role;
  final Designation designation;

  factory CreatePositionResult.fromJson(Map<String, dynamic> json) {
    final roleMap = _asMap(json['role']);
    final designationMap = _asMap(json['designation']);
    return CreatePositionResult(
      role: roleMap != null
          ? LinkedRole.fromJson(roleMap)
          : const LinkedRole(id: '', name: ''),
      designation: designationMap != null
          ? Designation.fromJson(designationMap)
          : Designation(
              id: '',
              name: '',
              slug: '',
              isAlias: true,
              isActive: true,
              sortOrder: 0,
            ),
    );
  }
}

class CreatePositionSlotResult {
  const CreatePositionSlotResult({
    required this.slot,
    this.loginId,
    this.password,
  });

  final PositionSlot slot;
  final String? loginId;
  final String? password;

  factory CreatePositionSlotResult.fromJson(Map<String, dynamic> json) {
    final credentials = _asMap(json['credentials']);
    return CreatePositionSlotResult(
      slot: PositionSlot.fromJson(json),
      loginId: credentials?['loginId'] as String?,
      password: credentials?['password'] as String?,
    );
  }
}
