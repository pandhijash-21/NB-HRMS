import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/background_tracking_service.dart';
import '../../../../core/services/web_live_tracking_service.dart';
import '../../../../core/services/widget_sync_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../collaboration/data/collab_socket.dart';
import '../../data/auth_repository.dart';
import '../../domain/permissions.dart';
import 'auth_event.dart';
import 'auth_state.dart';

export 'auth_event.dart';
export 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required AuthRepository authRepository,
    required DioClient dioClient,
    required SecureStorageService secureStorage,
    required UnauthorizedGate unauthorizedGate,
  })  : _repo = authRepository,
        _dio = dioClient,
        _storage = secureStorage,
        _gate = unauthorizedGate,
        super(const AuthState.unknown()) {
    _gate.bind(({reason}) async {
      add(AuthUnauthorizedKicked(reason: reason));
    });
    CollabSocket.instance.onSessionDisplaced((reason) {
      _gate.notify(reason: reason);
    });

    on<AuthBootstrapRequested>(_onBootstrap);
    on<AuthLoginRequested>(_onLogin);
    on<AuthChangePasswordRequested>(_onChangePassword);
    on<AuthEmailVerificationCompleted>(_onEmailVerificationCompleted);
    on<AuthEmergencyContactCompleted>(_onEmergencyContactCompleted);
    on<AuthPermissionsRefreshRequested>(_onPermissionsRefresh);
    on<AuthUnauthorizedKicked>(_onUnauthorizedKicked);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthClearErrorRequested>(_onClearError);
    on<AuthClearInfoRequested>(_onClearInfo);
    on<AuthSoftwareTourSeenRequested>(_onSoftwareTourSeen);
    on<AuthSoftwareTourSeenSynced>(_onSoftwareTourSeenSynced);

    add(const AuthBootstrapRequested());
  }

  final AuthRepository _repo;
  final DioClient _dio;
  final SecureStorageService _storage;
  final UnauthorizedGate _gate;

  Timer? _sessionWatch;

  void _stopSessionWatch() {
    _sessionWatch?.cancel();
    _sessionWatch = null;
  }

  void _startSessionWatch() {
    _stopSessionWatch();
    // 8s ensures any displaced session (secondary login on another device) is promptly kicked out
    _sessionWatch = Timer.periodic(const Duration(seconds: 8), (_) {
      add(const AuthPermissionsRefreshRequested());
    });
  }

  Future<void> _onBootstrap(
    AuthBootstrapRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final restored = await _repo.restoreSession();
      final rememberMe = await _storage.readRememberMe();

      if (restored == null) {
        if (rememberMe) {
          final creds = await _storage.readRememberedCredentials();
          if (creds != null && creds.identifier.isNotEmpty && creds.password.isNotEmpty) {
            AppLogger.auth.i('Remember Me is active. Seamlessly auto-authenticating.');
            add(AuthLoginRequested(
              identifier: creds.identifier,
              password: creds.password,
              rememberMe: true,
            ));
            return;
          }
        }
        emit(const AuthState.unauthenticated());
        return;
      }

      if (isJwtExpired(restored.token)) {
        if (rememberMe) {
          final creds = await _storage.readRememberedCredentials();
          if (creds != null && creds.identifier.isNotEmpty && creds.password.isNotEmpty) {
            AppLogger.auth.i('Session token expired, but Remember Me is active. Seamlessly auto-authenticating.');
            add(AuthLoginRequested(
              identifier: creds.identifier,
              password: creds.password,
              rememberMe: true,
            ));
            return;
          }
        }
        await _repo.clearSession();
        unawaited(WidgetSyncService.clearWidget());
        emit(const AuthState.unauthenticated(
          infoMessage: 'Your session has expired. Please log in again.',
        ));
        return;
      }

      emit(AuthState(
        status: AuthStatus.authenticated,
        user: restored.user,
        permissions: restored.permissions,
        isFirstLogin: restored.isFirstLogin,
        needsEmailVerification: restored.needsEmailVerification,
        needsEmergencyContact: restored.needsEmergencyContact,
      ));

      // Only start session polling after initial password change + email
      // verification are done. Polling during first-login is unnecessary and
      // its state emissions can trigger widget rebuilds (flicker on web).
      if (!restored.isFirstLogin) {
        _startSessionWatch();
      }
      CollabSocket.instance.connect(token: restored.token);
      add(const AuthPermissionsRefreshRequested());

      if (!restored.isFirstLogin) {
        try {
          final status = await _repo.fetchEmailVerificationStatus();
          if (status.needsEmailVerification != restored.needsEmailVerification) {
            emit(state.copyWith(
              needsEmailVerification: status.needsEmailVerification,
            ));
            await _repo.persistSession(
              token: restored.token,
              user: restored.user,
              permissions: restored.permissions,
              isFirstLogin: restored.isFirstLogin,
              needsEmailVerification: status.needsEmailVerification,
              needsEmergencyContact: state.needsEmergencyContact,
            );
          }
        } catch (_) {}
      }

      await WebLiveTrackingService.start();
      unawaited(startBackgroundTracking());
    } catch (_) {
      emit(const AuthState.unauthenticated());
    }
  }

  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    _stopSessionWatch();
    WebLiveTrackingService.stop();
    emit(state.copyWith(isSubmitting: true, clearError: true, clearInfo: true));

    try {
      final result = await _repo.login(
        identifier: event.identifier,
        password: event.password,
        portal: event.portal,
        rememberMe: event.rememberMe,
      );

      if (result.token.isEmpty) {
        emit(state.copyWith(
          isSubmitting: false,
          errorMessage: 'Login succeeded but no token was returned.',
        ));
        return;
      }

      await _repo.persistSession(
        token: result.token,
        user: result.user,
        permissions: result.permissions,
        isFirstLogin: result.isFirstLogin,
        needsEmailVerification: result.needsEmailVerification,
        needsEmergencyContact: result.needsEmergencyContact,
      );

      if (event.rememberMe && !result.isFirstLogin) {
        await _storage.writeRememberedCredentials(
          identifier: event.identifier.trim(),
          password: event.password,
        );
      } else if (!event.rememberMe) {
        await _storage.clearRememberedCredentials();
      }

      emit(AuthState(
        status: AuthStatus.authenticated,
        user: result.user,
        permissions: result.permissions,
        isFirstLogin: result.isFirstLogin,
        needsEmailVerification: result.needsEmailVerification,
        needsEmergencyContact: result.needsEmergencyContact,
        isSubmitting: false,
      ));

      _startSessionWatch();
      CollabSocket.instance.connect(token: result.token);
      await WebLiveTrackingService.start();
      unawaited(startBackgroundTracking());
    } on ApiException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
      ));
    } catch (_) {
      emit(state.copyWith(
        isSubmitting: false,
        status: AuthStatus.unauthenticated,
        errorMessage: 'Unable to sign in. Please try again.',
      ));
    }
  }

  Future<void> _onChangePassword(
    AuthChangePasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      final message = await _repo.changePassword(
        currentPassword: event.currentPassword,
        newPassword: event.newPassword,
      );

      final remembered = await _repo.readRememberedCredentials();
      if (remembered != null) {
        await _repo.saveRememberedCredentials(
          identifier: remembered.identifier,
          password: event.newPassword,
        );
      }

      WebLiveTrackingService.stop(preventRestart: true);
      unawaited(stopBackgroundTracking());
      _stopSessionWatch();
      await _repo.clearSession();

      emit(AuthState.unauthenticated(
        infoMessage: message.isNotEmpty
            ? '$message Then verify your email address(es).'
            : 'Password changed. Please log in again to verify your email.',
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
    } catch (_) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: 'Unable to change password. Please try again.',
      ));
    }
  }

  Future<void> _onEmailVerificationCompleted(
    AuthEmailVerificationCompleted event,
    Emitter<AuthState> emit,
  ) async {
    if (!state.isAuthenticated || state.user == null) return;
    final token = await _storage.readToken();
    if (token == null) return;

    emit(state.copyWith(needsEmailVerification: false));
    await _repo.persistSession(
      token: token,
      user: state.user!,
      permissions: state.permissions,
      isFirstLogin: state.isFirstLogin,
      needsEmailVerification: false,
      needsEmergencyContact: state.needsEmergencyContact,
    );
  }

  Future<void> _onEmergencyContactCompleted(
    AuthEmergencyContactCompleted event,
    Emitter<AuthState> emit,
  ) async {
    if (!state.isAuthenticated || state.user == null) return;
    final token = await _storage.readToken();
    if (token == null) return;

    emit(state.copyWith(needsEmergencyContact: false));
    await _repo.persistSession(
      token: token,
      user: state.user!,
      permissions: state.permissions,
      isFirstLogin: state.isFirstLogin,
      needsEmailVerification: state.needsEmailVerification,
      needsEmergencyContact: false,
    );
  }

  Future<void> _onPermissionsRefresh(
    AuthPermissionsRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state.status != AuthStatus.authenticated) return;
    try {
      final token = await _storage.readToken();
      if (isJwtExpired(token)) {
        add(const AuthUnauthorizedKicked(
          reason: 'Your session has expired. Please log in again.',
        ));
        return;
      }

      final me = await _dio.getEnvelope<Map<String, dynamic>>(
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
      final emergencyChanged =
          needsEmergency != state.needsEmergencyContact && !state.isFirstLogin;
      final roleName = me['roleName'] as String?;
      final roleChanged = roleName != null &&
          roleName.trim().isNotEmpty &&
          roleName.trim() != state.user?.role;
      final granted = me['companyAdminGranted'] == true;
      final grantedChanged = granted != (state.user?.companyAdminGranted ?? false);
      final tourSeen = me['softwareTourSeen'] == true;
      final tourChanged = tourSeen != (state.user?.softwareTourSeen ?? false);
      final onTrip = me['onTrip'] == true;
      final onTripChanged = onTrip != (state.user?.onTrip ?? false);
      final refreshedToken = me['token']?.toString();

      // Trip sessions: always persist refreshed JWT so the user is not kicked mid-trip.
      if (refreshedToken != null &&
          refreshedToken.isNotEmpty &&
          state.user != null) {
        await _repo.persistSession(
          token: refreshedToken,
          user: state.user!.copyWith(onTrip: onTrip),
          permissions: state.permissions,
          isFirstLogin: state.isFirstLogin,
          needsEmailVerification: state.needsEmailVerification,
          needsEmergencyContact: state.needsEmergencyContact,
        );
        if (onTrip) {
          await WebLiveTrackingService.start();
          unawaited(startBackgroundTracking());
        }
      }

      if (!permsChanged &&
          !needsChanged &&
          !emergencyChanged &&
          !roleChanged &&
          !grantedChanged &&
          !tourChanged &&
          !onTripChanged) {
        return;
      }

      final next = state.copyWith(
        permissions: permsChanged ? permissions : state.permissions,
        needsEmailVerification: needsChanged ? needs : state.needsEmailVerification,
        needsEmergencyContact:
            emergencyChanged ? needsEmergency : state.needsEmergencyContact,
        user: (roleChanged || grantedChanged || tourChanged || onTripChanged) && state.user != null
            ? state.user!.copyWith(
                role: roleChanged ? roleName.trim() : state.user!.role,
                companyAdminGranted: granted,
                softwareTourSeen: tourSeen,
                onTrip: onTrip,
              )
            : state.user,
      );

      // Don't emit in the same turn as an in-progress widget rebuild
      // (session poll + shell watch<AuthBloc> used to lock the tree).
      await Future<void>(() {});
      if (state.status != AuthStatus.authenticated) return;
      emit(next);

      final tokenToSave = refreshedToken?.isNotEmpty == true
          ? refreshedToken
          : await _storage.readToken();
      if (tokenToSave != null && state.user != null) {
        await _repo.persistSession(
          token: tokenToSave,
          user: state.user!,
          permissions: state.permissions,
          isFirstLogin: state.isFirstLogin,
          needsEmailVerification: state.needsEmailVerification,
          needsEmergencyContact: state.needsEmergencyContact,
        );
      }
      if (onTrip) {
        await WebLiveTrackingService.start();
        unawaited(startBackgroundTracking());
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        add(AuthUnauthorizedKicked(reason: e.message));
      }
    } catch (_) {
      // 401 is triggered via UnauthorizedGate -> AuthUnauthorizedKicked
    }
  }

  Future<void> _onUnauthorizedKicked(
    AuthUnauthorizedKicked event,
    Emitter<AuthState> emit,
  ) async {
    // If login is currently in progress or already unauthenticated, never kick or interrupt!
    if (state.isSubmitting || state.status == AuthStatus.unauthenticated) return;
    final wasOnTrip = state.user?.onTrip == true;
    CollabSocket.instance.disconnect();
    WebLiveTrackingService.stop(preventRestart: true);
    unawaited(stopBackgroundTracking());
    _stopSessionWatch();
    final isDisplaced = event.reason != null &&
        (event.reason!.toLowerCase().contains('another device') ||
         event.reason!.toLowerCase().contains('displaced'));

    // Release Redis so an open trip cannot permanently block re-login (strict timeout)
    try {
      await _repo.releaseSessionRemote().timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
    } catch (_) {}
    await _repo.clearSession();
    unawaited(WidgetSyncService.clearWidget());

    // If kicked because another device signed in, clear remembered credentials so this device stays signed out
    if (isDisplaced) {
      await _storage.clearRememberedCredentials();
    }

    final String message;
    if (wasOnTrip) {
      message = 'Your session ended during a trip. Sign in again — location tracking will resume.';
    } else if (event.reason != null && event.reason!.trim().isNotEmpty) {
      final r = event.reason!.trim();
      if (r.toLowerCase().contains('another device') ||
          r.toLowerCase().contains('displaced')) {
        message = 'You were signed out because this account signed in on another device or browser.';
      } else if (r.toLowerCase().contains('expired') ||
          r.toLowerCase().contains('invalid') ||
          r.toLowerCase().contains('unauthorized')) {
        message = 'Your session has expired. Please log in again.';
      } else {
        message = r;
      }
    } else {
      message = 'Your session has expired. Please log in again.';
    }

    emit(AuthState.unauthenticated(
      infoMessage: message,
    ));
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (!event.skipRemote) {
      try {
        await _repo.logoutRemote().timeout(
          const Duration(seconds: 2),
          onTimeout: () {},
        );
      } catch (_) {
        // Best-effort remote logout; always clear local session regardless of remote errors.
      }
    }
    CollabSocket.instance.disconnect();
    WebLiveTrackingService.stop(preventRestart: true);
    unawaited(stopBackgroundTracking());
    _stopSessionWatch();
    await _storage.clearRememberedCredentials();
    await _repo.clearSession();
    WebLiveTrackingService.stop(preventRestart: true);
    unawaited(WidgetSyncService.clearWidget());
    emit(AuthState.unauthenticated(infoMessage: event.infoMessage));
  }

  void _onClearError(AuthClearErrorRequested event, Emitter<AuthState> emit) {
    if (state.errorMessage != null) {
      emit(state.copyWith(clearError: true));
    }
  }

  void _onClearInfo(AuthClearInfoRequested event, Emitter<AuthState> emit) {
    if (state.infoMessage != null) {
      emit(state.copyWith(clearInfo: true));
    }
  }

  Future<void> _onSoftwareTourSeen(
    AuthSoftwareTourSeenRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state.status != AuthStatus.authenticated || state.user == null) return;
    if (state.user!.softwareTourSeen) return;
    try {
      await _repo.markSoftwareTourSeen();
    } catch (_) {
      // Still mark locally so the welcome does not reappear every session.
    }
    final nextUser = state.user!.copyWith(softwareTourSeen: true);
    emit(state.copyWith(user: nextUser));
    final token = await _storage.readToken();
    if (token != null) {
      await _repo.persistSession(
        token: token,
        user: nextUser,
        permissions: state.permissions,
        isFirstLogin: state.isFirstLogin,
        needsEmailVerification: state.needsEmailVerification,
        needsEmergencyContact: state.needsEmergencyContact,
      );
    }
  }

  Future<void> _onSoftwareTourSeenSynced(
    AuthSoftwareTourSeenSynced event,
    Emitter<AuthState> emit,
  ) async {
    if (state.status != AuthStatus.authenticated || state.user == null) return;
    if (state.user!.softwareTourSeen) return;
    final nextUser = state.user!.copyWith(softwareTourSeen: true);
    emit(state.copyWith(user: nextUser));
    final token = await _storage.readToken();
    if (token != null) {
      await _repo.persistSession(
        token: token,
        user: nextUser,
        permissions: state.permissions,
        isFirstLogin: state.isFirstLogin,
        needsEmailVerification: state.needsEmailVerification,
        needsEmergencyContact: state.needsEmergencyContact,
      );
    }
  }

  @override
  Future<void> close() {
    _stopSessionWatch();
    return super.close();
  }
}
