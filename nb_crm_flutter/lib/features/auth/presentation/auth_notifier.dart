import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/services/web_live_tracking_service.dart';
import '../domain/auth_user.dart';
import '../domain/permissions.dart';
import 'auth_providers.dart';
import 'bloc/auth_bloc.dart' as bloc;
import '../../profile/presentation/profile_notifier.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.permissions = const <String, List<String>>{},
    this.isFirstLogin = false,
    this.needsEmailVerification = false,
    this.needsEmergencyContact = false,
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
  /// Own employee profile is missing an emergency family contact.
  final bool needsEmergencyContact;
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
    bool? needsEmergencyContact,
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
      needsEmergencyContact:
          needsEmergencyContact ?? this.needsEmergencyContact,
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

    // After the frame (not Future/Timer) so restore does not write while the
    // tree is building, and widget tests are not left with a pending Timer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.mounted) return;
      unawaited(_bootstrap());
    });
    return const AuthState.unknown();
  }

  void _setState(AuthState next) {
    Future<void>(() {
      if (!ref.mounted) return;
      state = next;
    });
  }

  void _stopSessionWatch() {
    _sessionWatch?.cancel();
    _sessionWatch = null;
  }

  /// Forces an immediate refresh of permissions and profile flags from the server.
  Future<void> refreshPermissions() async {
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
      final needsEmergency = me['needsEmergencyContact'] == true;
      final permissions = Permissions.mapFromJson(me['permissions']);
      final permsChanged = !Permissions.mapsEqual(permissions, state.permissions);
      final needsChanged = needs != state.needsEmailVerification && !state.isFirstLogin;
      final emergencyChanged = needsEmergency != state.needsEmergencyContact && !state.isFirstLogin;
      final roleName = me['roleName'] as String?;
      final roleChanged = roleName != null &&
          roleName.trim().isNotEmpty &&
          roleName.trim() != state.user?.role;
      final granted = me['companyAdminGranted'] == true;
      final grantedChanged = granted != (state.user?.companyAdminGranted ?? false);
      final onTrip = me['onTrip'] == true;
      final onTripChanged = onTrip != (state.user?.onTrip ?? false);
      if (!permsChanged && !needsChanged && !emergencyChanged && !roleChanged && !grantedChanged && !onTripChanged) {
        return;
      }
      final next = state.copyWith(
        permissions: permsChanged ? permissions : state.permissions,
        needsEmailVerification: needsChanged ? needs : state.needsEmailVerification,
        needsEmergencyContact:
            emergencyChanged ? needsEmergency : state.needsEmergencyContact,
        user: (roleChanged || grantedChanged || onTripChanged) && state.user != null
            ? state.user!.copyWith(
                role: roleChanged ? roleName.trim() : state.user!.role,
                companyAdminGranted: granted,
                onTrip: onTrip,
              )
            : state.user,
      );
      _setState(next);
      final repo = ref.read(authRepositoryProvider);
      final token = await ref.read(secureStorageProvider).readToken();
      if (token != null && next.user != null) {
        await repo.persistSession(
          token: token,
          user: next.user!,
          permissions: next.permissions,
          isFirstLogin: next.isFirstLogin,
          needsEmailVerification: next.needsEmailVerification,
          needsEmergencyContact: next.needsEmergencyContact,
        );
      }
    } catch (_) {
      // 401 is handled by UnauthorizedGate → _handleUnauthorized.
    }
  }

  /// Polls auth/me so a displaced device is kicked even when idle and permissions stay fresh.
  void _startSessionWatch() {
    _stopSessionWatch();
    _sessionWatch = Timer.periodic(const Duration(seconds: 5), (_) async {
      await refreshPermissions();
    });
  }

  /// Keep Riverpod screens in sync with AuthBloc (login/shell use the bloc).
  void hydrateFromBloc(bloc.AuthState source) {
    final mapped = switch (source.status) {
      bloc.AuthStatus.unknown => AuthStatus.unknown,
      bloc.AuthStatus.authenticated => AuthStatus.authenticated,
      bloc.AuthStatus.unauthenticated => AuthStatus.unauthenticated,
    };
    final next = AuthState(
      status: mapped,
      user: source.user,
      permissions: source.permissions,
      isFirstLogin: source.isFirstLogin,
      needsEmailVerification: source.needsEmailVerification,
      needsEmergencyContact: source.needsEmergencyContact,
      errorMessage: source.errorMessage,
      infoMessage: source.infoMessage,
      isSubmitting: source.isSubmitting,
    );
    _setState(next);
    if (mapped != AuthStatus.authenticated) {
      _stopSessionWatch();
    }
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(authRepositoryProvider);
    final restored = await repo.restoreSession();
    if (restored == null) {
      // Login goes through AuthBloc; do not wipe a session it already restored.
      if (state.isAuthenticated) return;
      state = const AuthState.unauthenticated();
      return;
    }
    state = AuthState(
      status: AuthStatus.authenticated,
      user: restored.user,
      permissions: restored.permissions,
      isFirstLogin: restored.isFirstLogin,
      needsEmailVerification: restored.needsEmailVerification,
      needsEmergencyContact: restored.needsEmergencyContact,
    );
    _startSessionWatch();
    unawaited(refreshPermissions());
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
            needsEmergencyContact: state.needsEmergencyContact,
          );
        }
      } catch (_) {
        // Stale token: UnauthorizedGate will sign out. Don't keep calling APIs.
      }
    }
    await WebLiveTrackingService.start();
  }

  Future<void> _handleUnauthorized() async {
    // Ignore late 401s after user already signed out / while restoring.
    if (state.status != AuthStatus.authenticated) return;
    final repo = ref.read(authRepositoryProvider);
    WebLiveTrackingService.stop(preventRestart: true);
    _stopSessionWatch();
    await repo.clearSession();
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
        needsEmergencyContact: result.needsEmergencyContact,
      );

      state = AuthState(
        status: AuthStatus.authenticated,
        user: result.user,
        permissions: result.permissions,
        isFirstLogin: result.isFirstLogin,
        needsEmailVerification: result.needsEmailVerification,
        needsEmergencyContact: result.needsEmergencyContact,
        isSubmitting: false,
      );
      ref.invalidate(profileProvider);
      ref.invalidate(activeProfileEmployeeIdProvider);
      _startSessionWatch();
      await WebLiveTrackingService.start();
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
      final remembered = await repo.readRememberedCredentials();
      if (remembered != null) {
        await repo.saveRememberedCredentials(
          identifier: remembered.identifier,
          password: newPassword,
        );
      }
      WebLiveTrackingService.stop(preventRestart: true);
      _stopSessionWatch();
      await repo.clearSession();
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
      needsEmergencyContact: state.needsEmergencyContact,
    );
  }

  Future<void> markEmergencyContactComplete() async {
    if (!state.isAuthenticated || state.user == null) return;
    final repo = ref.read(authRepositoryProvider);
    final token = await ref.read(secureStorageProvider).readToken();
    if (token == null) return;
    state = state.copyWith(needsEmergencyContact: false);
    await repo.persistSession(
      token: token,
      user: state.user!,
      permissions: state.permissions,
      isFirstLogin: state.isFirstLogin,
      needsEmailVerification: state.needsEmailVerification,
      needsEmergencyContact: false,
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
          needsEmergencyContact: state.needsEmergencyContact,
        );
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.logoutRemote();
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Unable to sign out. Please try again.');
      return;
    }
    WebLiveTrackingService.stop(preventRestart: true);
    _stopSessionWatch();
    await repo.clearSession();
    WebLiveTrackingService.stop(preventRestart: true);
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
