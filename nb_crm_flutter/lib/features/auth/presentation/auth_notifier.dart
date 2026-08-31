import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/services/web_live_tracking_service.dart';
import '../domain/auth_user.dart';
import '../domain/permissions.dart';
import 'auth_providers.dart';
import '../../profile/presentation/profile_notifier.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

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
}

class AuthNotifier extends Notifier<AuthState> {
  Timer? _sessionWatch;

  @override
  AuthState build() {
    final gate = ref.read(unauthorizedGateProvider);
    gate.bind(_handleUnauthorized);
    ref.onDispose(_stopSessionWatch);

    Future.microtask(_bootstrap);
    return const AuthState.unknown();
  }

  void _stopSessionWatch() {
    _sessionWatch?.cancel();
    _sessionWatch = null;
  }

  /// Polls auth/me so a displaced device is kicked even when idle.
  void _startSessionWatch() {
    _stopSessionWatch();
    _sessionWatch = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (state.status != AuthStatus.authenticated) return;
      try {
        final dio = ref.read(dioClientProvider);
        final me = await dio.getEnvelope<Map<String, dynamic>>(
          'auth/me',
          parse: (raw) {
            if (raw is Map) return Map<String, dynamic>.from(raw);
            return <String, dynamic>{};
          },
        );
        final needs = me['needsEmailVerification'] == true;
        final permissions = Permissions.mapFromJson(me['permissions']);
        final permsChanged =
            permissions.isNotEmpty && !Permissions.mapsEqual(permissions, state.permissions);
        final needsChanged = needs != state.needsEmailVerification && !state.isFirstLogin;
        if (!permsChanged && !needsChanged) return;
        state = state.copyWith(
          permissions: permsChanged ? permissions : state.permissions,
          needsEmailVerification: needsChanged ? needs : state.needsEmailVerification,
        );
        final repo = ref.read(authRepositoryProvider);
        final token = await ref.read(secureStorageProvider).readToken();
        if (token != null && state.user != null) {
          await repo.persistSession(
            token: token,
            user: state.user!,
            permissions: state.permissions,
            isFirstLogin: state.isFirstLogin,
            needsEmailVerification: state.needsEmailVerification,
          );
        }
      } catch (_) {
        // 401 is handled by UnauthorizedGate → _handleUnauthorized.
      }
    });
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
      needsEmailVerification: restored.needsEmailVerification,
    );
    _startSessionWatch();
    // Refresh gate from server (emails may have been verified elsewhere).
    if (!restored.isFirstLogin) {
      try {
        final status = await repo.fetchEmailVerificationStatus();
        if (status.needsEmailVerification != restored.needsEmailVerification) {
          state = state.copyWith(
            needsEmailVerification: status.needsEmailVerification,
          );
          await repo.persistSession(
            token: restored.token,
            user: restored.user,
            permissions: restored.permissions,
            isFirstLogin: restored.isFirstLogin,
            needsEmailVerification: status.needsEmailVerification,
          );
        }
      } catch (_) {
        // Stale token: UnauthorizedGate will sign out. Don't keep calling APIs.
      }
    }
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
        needsEmailVerification: result.needsEmailVerification,
      );

      state = AuthState(
        status: AuthStatus.authenticated,
        user: result.user,
        permissions: result.permissions,
        isFirstLogin: result.isFirstLogin,
        needsEmailVerification: result.needsEmailVerification,
        isSubmitting: false,
      );
      ref.invalidate(profileProvider);
      ref.invalidate(activeProfileEmployeeIdProvider);
      _startSessionWatch();
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
      WebLiveTrackingService.stop();
      _stopSessionWatch();
      state = AuthState.unauthenticated(
        infoMessage: message.isNotEmpty
            ? '$message Then verify your email address(es).'
            : 'Password changed. Please log in again to verify your email.',
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

  Future<void> markEmailVerificationComplete() async {
    if (!state.isAuthenticated || state.user == null) return;
    final repo = ref.read(authRepositoryProvider);
    final token = await ref.read(secureStorageProvider).readToken();
    if (token == null) return;
    state = state.copyWith(needsEmailVerification: false);
    await repo.persistSession(
      token: token,
      user: state.user!,
      permissions: state.permissions,
      isFirstLogin: state.isFirstLogin,
      needsEmailVerification: false,
    );
  }

  Future<void> refreshEmailVerificationGate() async {
    if (!state.isAuthenticated || state.isFirstLogin) return;
    final repo = ref.read(authRepositoryProvider);
    try {
      final status = await repo.fetchEmailVerificationStatus();
      state = state.copyWith(
        needsEmailVerification: status.needsEmailVerification,
      );
      final token = await ref.read(secureStorageProvider).readToken();
      if (token != null && state.user != null) {
        await repo.persistSession(
          token: token,
          user: state.user!,
          permissions: state.permissions,
          isFirstLogin: state.isFirstLogin,
          needsEmailVerification: status.needsEmailVerification,
        );
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logoutRemote();
    await repo.clearSession();
    WebLiveTrackingService.stop();
    _stopSessionWatch();
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
