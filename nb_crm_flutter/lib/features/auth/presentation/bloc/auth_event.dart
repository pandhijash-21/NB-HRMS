import 'package:flutter/foundation.dart';

@immutable
sealed class AuthEvent {
  const AuthEvent();
}

/// Fired on app start to restore existing session token and credentials.
class AuthBootstrapRequested extends AuthEvent {
  const AuthBootstrapRequested();
}

/// Fired when user submits username/email and password.
class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({
    required this.identifier,
    required this.password,
  });

  final String identifier;
  final String password;
}

/// Fired when user requests password change.
class AuthChangePasswordRequested extends AuthEvent {
  const AuthChangePasswordRequested({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;
}

/// Fired when user completes email verification.
class AuthEmailVerificationCompleted extends AuthEvent {
  const AuthEmailVerificationCompleted();
}

/// Fired periodically or on demand to refresh role permissions from server.
class AuthPermissionsRefreshRequested extends AuthEvent {
  const AuthPermissionsRefreshRequested();
}

/// Fired when the unauthorized gate receives a 401 from backend.
class AuthUnauthorizedKicked extends AuthEvent {
  const AuthUnauthorizedKicked();
}

/// Fired when user taps logout.
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Fired to clear error messages.
class AuthClearErrorRequested extends AuthEvent {
  const AuthClearErrorRequested();
}

/// Fired to clear info messages.
class AuthClearInfoRequested extends AuthEvent {
  const AuthClearInfoRequested();
}
