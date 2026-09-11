import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/app_config.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/web_live_tracking_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
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
    _gate.bind(() async {
      add(const AuthUnauthorizedKicked());
    });

    on<AuthBootstrapRequested>(_onBootstrap);
    on<AuthLoginRequested>(_onLogin);
    on<AuthChangePasswordRequested>(_onChangePassword);
    on<AuthEmailVerificationCompleted>(_onEmailVerificationCompleted);
    on<AuthPermissionsRefreshRequested>(_onPermissionsRefresh);
    on<AuthUnauthorizedKicked>(_onUnauthorizedKicked);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthClearErrorRequested>(_onClearError);
    on<AuthClearInfoRequested>(_onClearInfo);

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
    _sessionWatch = Timer.periodic(const Duration(seconds: 5), (_) {
      add(const AuthPermissionsRefreshRequested());
    });
  }

  Future<void> _onBootstrap(
    AuthBootstrapRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final restored = await _repo.restoreSession();
      if (restored == null) {
        emit(const AuthState.unauthenticated());
        return;
      }

      emit(AuthState(
        status: AuthStatus.authenticated,
        user: restored.user,
        permissions: restored.permissions,
        isFirstLogin: restored.isFirstLogin,
        needsEmailVerification: restored.needsEmailVerification,
      ));

      // Only start session polling after initial password change + email
      // verification are done. Polling during first-login is unnecessary and
      // its state emissions can trigger widget rebuilds (flicker on web).
      if (!restored.isFirstLogin) {
        _startSessionWatch();
      }
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
            );
          }
        } catch (_) {}
      }

      await WebLiveTrackingService.ensureRunning();
    } catch (_) {
      emit(const AuthState.unauthenticated());
    }
  }

  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true, clearInfo: true));

    try {
      final result = await _repo.login(
        identifier: event.identifier,
        password: event.password,
        portal: event.portal,
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
      );

      emit(AuthState(
        status: AuthStatus.authenticated,
        user: result.user,
        permissions: result.permissions,
        isFirstLogin: result.isFirstLogin,
        needsEmailVerification: result.needsEmailVerification,
        isSubmitting: false,
      ));

      _startSessionWatch();
      await WebLiveTrackingService.ensureRunning();
    } on ApiException catch (e) {
      // Automatic local to live failover if local server is unreachable
      final currentUrl = _dio.baseUrl;
      final isLocal = currentUrl.contains('127.0.0.1') || currentUrl.contains('localhost');
      if (isLocal &&
          (e.message.contains('Unable to reach server') ||
              e.message.contains('reach the server') ||
              e.statusCode == null)) {
        try {
          AppConfig.setApiBaseUrl(AppConfig.liveApiBaseUrl);
          _dio.updateBaseUrl(AppConfig.liveApiBaseUrl);

          final result = await _repo.login(
            identifier: event.identifier,
            password: event.password,
            portal: event.portal,
          );

          if (result.token.isNotEmpty) {
            await _repo.persistSession(
              token: result.token,
              user: result.user,
              permissions: result.permissions,
              isFirstLogin: result.isFirstLogin,
              needsEmailVerification: result.needsEmailVerification,
            );

            emit(AuthState(
              status: AuthStatus.authenticated,
              user: result.user,
              permissions: result.permissions,
              isFirstLogin: result.isFirstLogin,
              needsEmailVerification: result.needsEmailVerification,
              isSubmitting: false,
            ));

            _startSessionWatch();
            await WebLiveTrackingService.ensureRunning();
            return;
          }
        } catch (failoverError) {
          if (failoverError is ApiException) {
            emit(state.copyWith(
              isSubmitting: false,
              status: AuthStatus.unauthenticated,
              errorMessage: failoverError.message,
            ));
            return;
          }
        }
      }

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

      await _repo.clearSession();
      WebLiveTrackingService.stop();
      _stopSessionWatch();

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
    );
  }

  Future<void> _onPermissionsRefresh(
    AuthPermissionsRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state.status != AuthStatus.authenticated) return;
    try {
      final me = await _dio.getEnvelope<Map<String, dynamic>>(
        'auth/me',
        parse: (raw) {
          if (raw is Map) return Map<String, dynamic>.from(raw);
          return <String, dynamic>{};
        },
      );

      final needs = me['needsEmailVerification'] == true;
      final permissions = Permissions.mapFromJson(me['permissions']);
      final permsChanged = !Permissions.mapsEqual(permissions, state.permissions);
      final needsChanged = needs != state.needsEmailVerification && !state.isFirstLogin;
      final roleName = me['roleName'] as String?;
      final roleChanged = roleName != null &&
          roleName.trim().isNotEmpty &&
          roleName.trim() != state.user?.role;

      if (!permsChanged && !needsChanged && !roleChanged) return;

      emit(state.copyWith(
        permissions: permsChanged ? permissions : state.permissions,
        needsEmailVerification: needsChanged ? needs : state.needsEmailVerification,
        user: roleChanged && state.user != null
            ? state.user!.copyWith(role: roleName.trim())
            : state.user,
      ));

      final token = await _storage.readToken();
      if (token != null && state.user != null) {
        await _repo.persistSession(
          token: token,
          user: state.user!,
          permissions: state.permissions,
          isFirstLogin: state.isFirstLogin,
          needsEmailVerification: state.needsEmailVerification,
        );
      }
    } catch (_) {
      // 401 is triggered via UnauthorizedGate -> AuthUnauthorizedKicked
    }
  }

  Future<void> _onUnauthorizedKicked(
    AuthUnauthorizedKicked event,
    Emitter<AuthState> emit,
  ) async {
    if (state.status != AuthStatus.authenticated) return;
    await _repo.clearSession();
    WebLiveTrackingService.stop();
    _stopSessionWatch();

    emit(const AuthState.unauthenticated(
      infoMessage:
          'You were signed out because this account signed in on another device or browser.',
    ));
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _repo.logoutRemote();
    await _repo.clearSession();
    WebLiveTrackingService.stop();
    _stopSessionWatch();
    emit(const AuthState.unauthenticated());
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

  @override
  Future<void> close() {
    _stopSessionWatch();
    return super.close();
  }
}
