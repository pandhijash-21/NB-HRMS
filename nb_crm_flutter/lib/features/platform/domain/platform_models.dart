class PlatformStats {
  const PlatformStats({
    required this.totalCompanies,
    required this.activeCompanies,
    required this.totalSystemAdmins,
    required this.totalUsers,
    this.totalTrash = 0,
    required this.uptimeSeconds,
    required this.dbStatus,
    required this.redisStatus,
    required this.platformVersion,
  });

  final int totalCompanies;
  final int activeCompanies;
  final int totalSystemAdmins;
  final int totalUsers;
  final int totalTrash;
  final int uptimeSeconds;
  final String dbStatus;
  final String redisStatus;
  final String platformVersion;

  factory PlatformStats.fromJson(Map<String, dynamic> json) {
    return PlatformStats(
      totalCompanies: json['totalCompanies'] as int? ?? 0,
      activeCompanies: json['activeCompanies'] as int? ?? 0,
      totalSystemAdmins: json['totalSystemAdmins'] as int? ?? 0,
      totalUsers: json['totalUsers'] as int? ?? 0,
      totalTrash: json['totalTrash'] as int? ?? 0,
      uptimeSeconds: json['uptimeSeconds'] as int? ?? 0,
      dbStatus: json['dbStatus'] as String? ?? 'UNKNOWN',
      redisStatus: json['redisStatus'] as String? ?? 'UNKNOWN',
      platformVersion: json['platformVersion'] as String? ?? '2.5.0',
    );
  }
}

class ClientCompany {
  const ClientCompany({
    required this.id,
    required this.name,
    required this.code,
    this.contactPerson,
    this.email,
    this.mobileNo,
    this.address,
    required this.isActive,
    required this.enabledModules,
    required this.userCount,
    this.primaryAdminUsername,
    this.primaryAdminLastLogin,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String code;
  final String? contactPerson;
  final String? email;
  final String? mobileNo;
  final String? address;
  final bool isActive;
  final List<String> enabledModules;
  final int userCount;
  final String? primaryAdminUsername;
  final String? primaryAdminLastLogin;
  final String createdAt;

  factory ClientCompany.fromJson(Map<String, dynamic> json) {
    final rawModules = json['enabledModules'];
    final modules = <String>[];
    if (rawModules is List) {
      for (final m in rawModules) {
        if (m != null) modules.add(m.toString().toUpperCase());
      }
    }
    if (modules.isEmpty) {
      modules.addAll(['HRMS', 'CRM', 'ERP']);
    }

    final adminMap = json['primaryAdmin'] is Map ? json['primaryAdmin'] as Map : null;

    return ClientCompany(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      contactPerson: json['contactPerson']?.toString(),
      email: json['email']?.toString(),
      mobileNo: json['mobileNo']?.toString(),
      address: json['address']?.toString(),
      isActive: json['isActive'] as bool? ?? true,
      enabledModules: modules,
      userCount: json['userCount'] as int? ?? 0,
      primaryAdminUsername: adminMap?['username']?.toString(),
      primaryAdminLastLogin: adminMap?['lastLoginAt']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class PlatformAdminUser {
  const PlatformAdminUser({
    required this.id,
    required this.username,
    required this.companyName,
    required this.role,
    required this.isActive,
    required this.isFirstLogin,
    this.lastLoginAt,
    required this.createdAt,
    this.plainPassword,
    required this.loginBlocked,
    required this.loginTemporarilyLocked,
    this.loginLockedUntil,
    required this.loginFailCount,
  });

  final String id;
  final String username;
  final String companyName;
  final String role;
  final bool isActive;
  final bool isFirstLogin;
  final String? lastLoginAt;
  final String createdAt;
  final String? plainPassword;
  final bool loginBlocked;
  final bool loginTemporarilyLocked;
  final String? loginLockedUntil;
  final int loginFailCount;

  factory PlatformAdminUser.fromJson(Map<String, dynamic> json) {
    return PlatformAdminUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      companyName: json['companyName']?.toString() ?? 'Unassigned',
      role: json['role']?.toString() ?? 'SYSTEM_ADMIN',
      isActive: json['isActive'] as bool? ?? true,
      isFirstLogin: json['isFirstLogin'] as bool? ?? false,
      lastLoginAt: json['lastLoginAt']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
      plainPassword: json['plainPassword']?.toString(),
      loginBlocked: json['loginBlocked'] as bool? ?? false,
      loginTemporarilyLocked: json['loginTemporarilyLocked'] as bool? ?? false,
      loginLockedUntil: json['loginLockedUntil']?.toString(),
      loginFailCount: json['loginFailCount'] as int? ?? 0,
    );
  }
}

class PlatformTrashItem {
  const PlatformTrashItem({
    required this.id,
    required this.name,
    this.code,
    this.companyName,
    this.contactPerson,
    this.email,
    required this.type,
    required this.deletedAt,
    required this.expiresAt,
    required this.daysRemaining,
  });

  final String id;
  final String name;
  final String? code;
  final String? companyName;
  final String? contactPerson;
  final String? email;
  final String type; // 'COMPANY' or 'ADMIN'
  final String deletedAt;
  final String expiresAt;
  final int daysRemaining;

  bool get isCompany => type == 'COMPANY';
  bool get isAdmin => type == 'ADMIN';

  factory PlatformTrashItem.fromCompanyJson(Map<String, dynamic> json) {
    return PlatformTrashItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
      contactPerson: json['contactPerson']?.toString(),
      email: json['email']?.toString(),
      type: 'COMPANY',
      deletedAt: json['deletedAt']?.toString() ?? '',
      expiresAt: json['expiresAt']?.toString() ?? '',
      daysRemaining: json['daysRemaining'] as int? ?? 30,
    );
  }

  factory PlatformTrashItem.fromAdminJson(Map<String, dynamic> json) {
    return PlatformTrashItem(
      id: json['id']?.toString() ?? '',
      name: json['username']?.toString() ?? '',
      companyName: json['companyName']?.toString(),
      type: 'ADMIN',
      deletedAt: json['deletedAt']?.toString() ?? '',
      expiresAt: json['expiresAt']?.toString() ?? '',
      daysRemaining: json['daysRemaining'] as int? ?? 30,
    );
  }
}

class PlatformTrashData {
  const PlatformTrashData({
    required this.companies,
    required this.admins,
    required this.totalCount,
  });

  final List<PlatformTrashItem> companies;
  final List<PlatformTrashItem> admins;
  final int totalCount;

  factory PlatformTrashData.fromJson(Map<String, dynamic> json) {
    final compsRaw = json['companies'] as List? ?? [];
    final adminsRaw = json['admins'] as List? ?? [];

    final companies = compsRaw
        .map((e) => PlatformTrashItem.fromCompanyJson(e as Map<String, dynamic>))
        .toList();
    final admins = adminsRaw
        .map((e) => PlatformTrashItem.fromAdminJson(e as Map<String, dynamic>))
        .toList();

    return PlatformTrashData(
      companies: companies,
      admins: admins,
      totalCount: json['totalCount'] as int? ?? (companies.length + admins.length),
    );
  }
}
