import 'package:flutter/foundation.dart';

import '../../domain/auth_user.dart';
import '../../domain/permissions.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

@immutable
class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.permissions = const <String, List<String>>{},
    this.isFirstLogin = false,
    this.needsEmailVerification = false,
    this.errorMessage,
    this.infoMessage,
    this.isSubmitting = false,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  const AuthState.unauthenticated({
    String? errorMessage,
    String? infoMessage,
  }) : this(
          status: AuthStatus.unauthenticated,
          errorMessage: errorMessage,
          infoMessage: infoMessage,
        );

  final AuthStatus status;
  final AuthUser? user;
  final Map<String, List<String>> permissions;
  final bool isFirstLogin;
  final bool needsEmailVerification;
  final String? errorMessage;
  final String? infoMessage;
  final bool isSubmitting;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isSuperAdmin => Permissions.isSuperAdmin(user?.role);

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    Map<String, List<String>>? permissions,
    bool? isFirstLogin,
    bool? needsEmailVerification,
    String? errorMessage,
    bool clearError = false,
    String? infoMessage,
    bool clearInfo = false,
    bool? isSubmitting,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      permissions: permissions ?? this.permissions,
      isFirstLogin: isFirstLogin ?? this.isFirstLogin,
      needsEmailVerification:
          needsEmailVerification ?? this.needsEmailVerification,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          user == other.user &&
          isFirstLogin == other.isFirstLogin &&
          needsEmailVerification == other.needsEmailVerification &&
          errorMessage == other.errorMessage &&
          infoMessage == other.infoMessage &&
          isSubmitting == other.isSubmitting &&
          mapEquals(permissions, other.permissions);

  @override
  int get hashCode =>
      status.hashCode ^
      user.hashCode ^
      isFirstLogin.hashCode ^
      needsEmailVerification.hashCode ^
      errorMessage.hashCode ^
      infoMessage.hashCode ^
      isSubmitting.hashCode;
}
