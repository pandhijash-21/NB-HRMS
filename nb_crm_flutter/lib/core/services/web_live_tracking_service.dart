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

/// Foreground live pings + heartbeats while the app/tab is open.
///
/// On native, [background_tracking_service] continues GPS when the app is
/// closed. This service covers the open-app case with the main-isolate token
/// (avoids FGS Keystore failures that showed as "Waiting for first GPS fix").
class WebLiveTrackingService {
  WebLiveTrackingService._();

  static Timer? _timer;
  static StreamSubscription<Position>? _positions;
  static bool _tickInFlight = false;
  static int _epoch = 0;
  static bool _halted = false;
  static Position? _lastFix;
  static DateTime? _lastFixAt;
  static DateTime? _lastPostAt;
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
    // Web: tab-open pings. Native: same while app is in foreground (FGS covers background).
    if (resume) _halted = false;
    if (_halted) return;
    final token = await _storage.readToken();
    if (_halted) return;
    if (token == null || token.isEmpty) {
      stop();
      return;
    }
    if (_timer != null) {
      _ensurePositionStream();
      return;
    }

    AppLogger.tracking.i(
      kIsWeb
          ? 'Starting web live tracking pings'
          : 'Starting native foreground live tracking pings',
    );
    final epoch = _epoch;
    _ensurePositionStream();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_tick(epoch));
    });
    await _tick(epoch);
  }

  static void stop({bool preventRestart = false}) {
    _epoch++;
    if (preventRestart) _halted = true;
    _positions?.cancel();
    _positions = null;
    if (_timer == null) return;
    _timer?.cancel();
    _timer = null;
    _tickInFlight = false;
    AppLogger.tracking.i('Stopped web live tracking pings');
  }

  static void _ensurePositionStream() {
    if (_positions != null) return;
    _positions = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen(
      (position) {
        _lastFix = position;
        _lastFixAt = DateTime.now();
      },
      onError: (Object e) {
        AppLogger.tracking.w('Live position stream error: $e');
        _positions?.cancel();
        _positions = null;
      },
      onDone: () {
        _positions = null;
      },
    );
  }

  static bool _isCurrent(int epoch) => epoch == _epoch;

  static Future<Position?> _resolvePosition() async {
    final cached = _lastFix;
    final cachedAt = _lastFixAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) <= const Duration(seconds: 20)) {
      return cached;
    }

    try {
      final fresh = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      ).timeout(const Duration(seconds: 7));
      _lastFix = fresh;
      _lastFixAt = DateTime.now();
      return fresh;
    } catch (e) {
      AppLogger.tracking.w('Fresh GPS fix unavailable, using last known: $e');
    }

    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) <= const Duration(seconds: 90)) {
      return cached;
    }

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _lastFix = last;
        _lastFixAt ??= DateTime.now();
        return last;
      }
    } catch (_) {}
    return null;
  }

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

      if (_positions == null) _ensurePositionStream();

      final quiet = _lastFixAt == null ||
          DateTime.now().difference(_lastFixAt!) > const Duration(seconds: 25);
      if (quiet) {
        await _positions?.cancel();
        _positions = null;
        _ensurePositionStream();
      }

      LocationPermission permission = LocationPermission.denied;
      try {
        permission = await Geolocator.checkPermission();
      } catch (_) {}
      if (!_isCurrent(epoch)) return;

      final position = await _resolvePosition();
      if (!_isCurrent(epoch)) return;

      final dio = _dio(token);

      if (position != null) {
        try {
          await dio.post(
            'tracking/live',
            data: {
              'latitude': position.latitude,
              'longitude': position.longitude,
              'heading': position.heading.isNaN ? 0 : position.heading,
              'speed': position.speed.isNaN ? 0 : position.speed,
              'accuracy': position.accuracy.isNaN ? null : position.accuracy,
            },
          );
          _lastPostAt = DateTime.now();
        } on DioException catch (e) {
          if (!_isCurrent(epoch)) return;
          if (e.response?.statusCode == 401) {
            AppLogger.tracking.w('Web live ping unauthorized (401) — stopping until re-auth');
            stop(preventRestart: true);
            return;
          }
          AppLogger.tracking.w('Web live ping failed: $e');
        }
      } else if (_lastPostAt == null ||
          DateTime.now().difference(_lastPostAt!) > const Duration(seconds: 20)) {
        AppLogger.tracking.w('Live tracking has no GPS fix yet');
      }
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

      bool locationOn = position != null;
      try {
        locationOn = await Geolocator.isLocationServiceEnabled();
      } catch (_) {}

      try {
        await dio.post(
          'tracking/heartbeat',
          data: {
            'batteryLevel': batteryLevel,
            'networkStatus': networkStatus,
            'permissionStatus': permission.name,
            'locationServiceEnabled': locationOn,
            'lastKnownGapReason': position == null ? 'GPS_SIGNAL_LOST' : null,
          },
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          stop(preventRestart: true);
        }
      }
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
