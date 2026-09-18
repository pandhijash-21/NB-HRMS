import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../logging/app_logger.dart';
import '../network/app_config.dart';
import '../network/transport_crypto.dart';
import '../storage/secure_storage_service.dart';

/// Foreground live pings + heartbeats for Flutter web (Netlify).
///
/// Native background GPS cannot run in the browser; this keeps tracking
/// working while the tab is open and the user is signed in.
class WebLiveTrackingService {
  WebLiveTrackingService._();

  static Timer? _timer;
  static bool _tickInFlight = false;
  static int _epoch = 0;
  static bool _halted = false;
  static final SecureStorageService _storage = SecureStorageService();
  static final Battery _battery = Battery();

  static bool get isRunning => _timer != null;

  /// Start only when a session token exists; no-op if already running.
  /// Clears a logout halt so pings can resume after re-auth.
  static Future<void> start() async {
    await _start(resume: true);
  }

  /// Idempotent: start if authenticated, stop if not.
  /// Does not override a logout halt (avoids 401s while the session is clearing).
  static Future<void> ensureRunning() async {
    if (_halted) return;
    await _start(resume: false);
  }

  static Future<void> _start({required bool resume}) async {
    if (!kIsWeb) return;
    if (resume) _halted = false;
    if (_halted) return;
    final token = await _storage.readToken();
    if (_halted) return;
    if (token == null || token.isEmpty) {
      stop();
      return;
    }
    if (_timer != null) return;

    AppLogger.tracking.i('Starting web live tracking pings');
    final epoch = _epoch;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_tick(epoch));
    });
    await _tick(epoch);
  }

  static void stop({bool preventRestart = false}) {
    _epoch++;
    if (preventRestart) _halted = true;
    if (_timer == null) return;
    _timer?.cancel();
    _timer = null;
    AppLogger.tracking.i('Stopped web live tracking pings');
  }

  static bool _isCurrent(int epoch) => epoch == _epoch;

  static Future<void> _tick(int epoch) async {
    if (!_isCurrent(epoch) || _tickInFlight) return;
    _tickInFlight = true;
    try {
      if (!_isCurrent(epoch)) return;
      final token = await _storage.readToken();
      if (!_isCurrent(epoch)) return;
      if (token == null || token.isEmpty) {
        stop();
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (!_isCurrent(epoch)) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!_isCurrent(epoch)) return;

      final dio = _dio(token);

      await dio.post(
        'tracking/live',
        data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'heading': position.heading.isNaN ? 0 : position.heading,
        },
      );
      if (!_isCurrent(epoch)) return;

      int? batteryLevel;
      try {
        batteryLevel = await _battery.batteryLevel;
      } catch (_) {}
      if (!_isCurrent(epoch)) return;

      String networkStatus = 'unknown';
      try {
        final results = await Connectivity().checkConnectivity();
        if (results.contains(ConnectivityResult.none)) {
          networkStatus = 'offline';
        } else if (results.contains(ConnectivityResult.wifi)) {
          networkStatus = 'wifi';
        } else if (results.contains(ConnectivityResult.mobile)) {
          networkStatus = 'mobile';
        } else if (results.contains(ConnectivityResult.ethernet)) {
          networkStatus = 'ethernet';
        } else {
          networkStatus = 'online';
        }
      } catch (_) {}
      if (!_isCurrent(epoch)) return;

      await dio.post(
        'tracking/heartbeat',
        data: {
          'batteryLevel': batteryLevel,
          'networkStatus': networkStatus,
          'permissionStatus': permission.name,
          'locationServiceEnabled': true,
          'lastKnownGapReason': null,
        },
      );
    } on DioException catch (e) {
      if (!_isCurrent(epoch)) return;
      final status = e.response?.statusCode;
      if (status == 401) {
        // Stale / kicked session — stop until login/bootstrap explicitly start().
        AppLogger.tracking.w('Web live ping unauthorized (401) — stopping until re-auth');
        stop(preventRestart: true);
        return;
      }
      AppLogger.tracking.w('Web live ping failed: $e');
    } catch (e) {
      if (!_isCurrent(epoch)) return;
      AppLogger.tracking.w('Web live ping failed: $e');
    } finally {
      _tickInFlight = false;
    }
  }

  static Dio _dio(String token) {
    final base = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl
        : '${AppConfig.apiBaseUrl}/';
    return Dio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          transportEncHeader: '$transportEncVersion',
        },
      ),
    )..interceptors.add(transportEncryptionInterceptor());
  }
}
