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

class PendingEmail {
  const PendingEmail({
    required this.kind,
    required this.email,
    required this.verified,
    this.cooldownSeconds = 0,
  });

  final String kind; // personal | institute
  final String email;
  final bool verified;
  final int cooldownSeconds;

  String get label =>
      kind == 'institute' ? 'Institutional email' : 'Personal email';

  factory PendingEmail.fromJson(Map<String, dynamic> json) {
    return PendingEmail(
      kind: json['kind']?.toString() ?? 'personal',
      email: json['email']?.toString() ?? '',
      verified: json['verified'] == true,
      cooldownSeconds: json['cooldownSeconds'] is int
          ? json['cooldownSeconds'] as int
          : int.tryParse('${json['cooldownSeconds'] ?? 0}') ?? 0,
    );
  }
}

/// Full login payload inside `{ success, data }`.
class LoginResult {
  const LoginResult({
    required this.token,
    required this.isFirstLogin,
    required this.needsEmailVerification,
    required this.user,
    required this.permissions,
    this.pendingEmails = const [],
  });

  final String token;
  final bool isFirstLogin;
  final bool needsEmailVerification;
  final AuthUser user;
  final Map<String, List<String>> permissions;
  final List<PendingEmail> pendingEmails;

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
    if (userMap is! Map) {
      throw const FormatException('Login response missing user object');
    }

    final pendingRaw = json['pendingEmails'];
    final pending = <PendingEmail>[];
    if (pendingRaw is List) {
      for (final item in pendingRaw) {
        if (item is Map) {
          pending.add(PendingEmail.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return LoginResult(
      token: json['token'] as String? ?? '',
      isFirstLogin: json['isFirstLogin'] == true,
      needsEmailVerification: json['needsEmailVerification'] == true,
      user: AuthUser.fromJson(Map<String, dynamic>.from(userMap)),
      permissions: permissions,
      pendingEmails: pending,
    );
  }
}
