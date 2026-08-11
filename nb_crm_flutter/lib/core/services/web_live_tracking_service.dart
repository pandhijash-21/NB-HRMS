import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../logging/app_logger.dart';
import '../network/app_config.dart';
import '../storage/secure_storage_service.dart';

/// Foreground live pings + heartbeats for Flutter web (Netlify).
///
/// Native background GPS cannot run in the browser; this keeps tracking
/// working while the tab is open and the user is signed in.
class WebLiveTrackingService {
  WebLiveTrackingService._();

  static Timer? _timer;
  static bool _tickInFlight = false;
  static final SecureStorageService _storage = SecureStorageService();
  static final Battery _battery = Battery();

  static bool get isRunning => _timer != null;

  /// Start only when a session token exists; no-op if already running.
  static Future<void> start() async {
    if (!kIsWeb) return;
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      stop();
      return;
    }
    if (_timer != null) return;

    AppLogger.tracking.i('Starting web live tracking pings');
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_tick());
    });
    await _tick();
  }

  /// Idempotent: start if authenticated, stop if not.
  static Future<void> ensureRunning() async {
    if (!kIsWeb) return;
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      stop();
      return;
    }
    await start();
  }

  static void stop() {
    if (_timer == null) return;
    _timer?.cancel();
    _timer = null;
    AppLogger.tracking.i('Stopped web live tracking pings');
  }

  static Future<void> _tick() async {
    if (_tickInFlight) return;
    _tickInFlight = true;
    try {
      final token = await _storage.readToken();
      if (token == null || token.isEmpty) {
        stop();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final dio = _dio(token);

      await dio.post(
        'tracking/live',
        data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'heading': position.heading.isNaN ? 0 : position.heading,
        },
      );

      int? batteryLevel;
      try {
        batteryLevel = await _battery.batteryLevel;
      } catch (_) {}

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
    } catch (e) {
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
        },
      ),
    );
  }
}
