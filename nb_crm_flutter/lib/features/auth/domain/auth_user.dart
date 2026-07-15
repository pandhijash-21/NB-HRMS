/// Authenticated user returned from `POST /auth/login` (inside `data.user`).
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.role,
    this.employeeId,
    this.username,
    this.photoUrl,
    this.subOrganization,
    this.employeeViewScope,
  });

  final String id;
  final String name;
  final String role;
  final int? employeeId;
  final String? username;
  final String? photoUrl;
  final String? subOrganization;
  final String? employeeViewScope;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'User',
      role: json['role'] as String? ?? 'EMPLOYEE',
      employeeId: json['employeeId'] is int
          ? json['employeeId'] as int
          : int.tryParse('${json['employeeId'] ?? ''}'),
      username: json['username'] as String?,
      photoUrl: json['photoUrl'] as String?,
      subOrganization: json['subOrganization'] as String?,
      employeeViewScope: json['employeeViewScope'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'employeeId': employeeId,
        'username': username,
        'photoUrl': photoUrl,
        'subOrganization': subOrganization,
        'employeeViewScope': employeeViewScope,
      };
}

/// Full login payload inside `{ success, data }`.
class LoginResult {
  const LoginResult({
    required this.token,
    required this.isFirstLogin,
    required this.user,
    required this.permissions,
  });

  final String token;
  final bool isFirstLogin;
  final AuthUser user;
  final Map<String, List<String>> permissions;

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    final permsRaw = json['permissions'];
    final permissions = <String, List<String>>{};
    if (permsRaw is Map) {
      permsRaw.forEach((key, value) {
        if (value is List) {
          permissions[key.toString()] =
              value.map((e) => e.toString()).toList();
        }
      });
    }

    final userMap = json['user'];
    if (userMap is! Map<String, dynamic>) {
      throw const FormatException('Login response missing user object');
    }

    return LoginResult(
      token: json['token'] as String? ?? '',
      isFirstLogin: json['isFirstLogin'] == true,
      user: AuthUser.fromJson(userMap),
      permissions: permissions,
    );
  }
}
