import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/services/web_live_tracking_service.dart';
import '../domain/auth_user.dart';
import 'auth_providers.dart';
import '../../profile/presentation/profile_notifier.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.permissions = const <String, List<String>>{},
    this.isFirstLogin = false,
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
  final String? errorMessage;
  final String? infoMessage;
  final bool isSubmitting;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    Map<String, List<String>>? permissions,
    bool? isFirstLogin,
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
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final gate = ref.read(unauthorizedGateProvider);
    gate.bind(_handleUnauthorized);

    Future.microtask(_bootstrap);
    return const AuthState.unknown();
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(authRepositoryProvider);
    final restored = await repo.restoreSession();
    if (restored == null) {
      state = const AuthState.unauthenticated();
      return;
    }
    state = AuthState(
      status: AuthStatus.authenticated,
      user: restored.user,
      permissions: restored.permissions,
      isFirstLogin: restored.isFirstLogin,
    );
    await WebLiveTrackingService.ensureRunning();
  }

  Future<void> _handleUnauthorized() async {
    // Ignore late 401s after user already signed out / while restoring.
    if (state.status != AuthStatus.authenticated) return;
    final repo = ref.read(authRepositoryProvider);
    await repo.clearSession();
    WebLiveTrackingService.stop();
    _stopSessionWatch();
    state = const AuthState.unauthenticated(
      infoMessage:
          'You were signed out because this account signed in on another device or browser.',
    );
  }

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true, clearInfo: true);
    final repo = ref.read(authRepositoryProvider);

    try {
      final result = await repo.login(
        identifier: identifier,
        password: password,
      );

      if (result.token.isEmpty) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'Login succeeded but no token was returned.',
        );
        return false;
      }

      await repo.persistSession(
        token: result.token,
        user: result.user,
        permissions: result.permissions,
        isFirstLogin: result.isFirstLogin,
      );

      state = AuthState(
        status: AuthStatus.authenticated,
        user: result.user,
        permissions: result.permissions,
        isFirstLogin: result.isFirstLogin,
        isSubmitting: false,
      );
      ref.invalidate(profileProvider);
      ref.invalidate(activeProfileEmployeeIdProvider);
      await WebLiveTrackingService.ensureRunning();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        status: AuthStatus.unauthenticated,
        errorMessage: 'Unable to sign in. Please try again.',
      );
      return false;
    }
  }

  /// Change password, then wipe the local session so the user must sign in again.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    final repo = ref.read(authRepositoryProvider);

    try {
      final message = await repo.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      await repo.clearSession();
      state = AuthState.unauthenticated(
        infoMessage: message.isNotEmpty
            ? message
            : 'Password changed. Please log in again.',
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Unable to change password. Please try again.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logoutRemote();
    await repo.clearSession();
    WebLiveTrackingService.stop();
    ref.invalidate(profileProvider);
    ref.invalidate(activeProfileEmployeeIdProvider);
    state = const AuthState.unauthenticated();
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  void clearInfo() {
    if (state.infoMessage != null) {
      state = state.copyWith(clearInfo: true);
    }
  }
}
