import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../logging/app_logger.dart';
import '../network/app_config.dart';
import '../storage/secure_storage_service.dart';

/// Foreground live pings for Flutter web (Netlify).
///
/// `flutter_background_service` does not run on web, so without this the
/// hosted app never POSTs `tracking/live` and the admin map stays empty.
class WebLiveTrackingService {
  WebLiveTrackingService._();

  static Timer? _timer;
  static bool _tickInFlight = false;
  static final SecureStorageService _storage = SecureStorageService();

  static bool get isRunning => _timer != null;

  static Future<void> start() async {
    if (!kIsWeb) return;
    if (_timer != null) return;

    AppLogger.tracking.i('Starting web live tracking pings');
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_tick());
    });
    await _tick();
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
      if (token == null || token.isEmpty) return;

      final permission = await Geolocator.checkPermission();
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

      final base = AppConfig.apiBaseUrl.endsWith('/')
          ? AppConfig.apiBaseUrl
          : '${AppConfig.apiBaseUrl}/';

      final dio = Dio(
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

      await dio.post(
        'tracking/live',
        data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'heading': position.heading.isNaN ? 0 : position.heading,
        },
      );
    } catch (e) {
      AppLogger.tracking.w('Web live ping failed: $e');
    } finally {
      _tickInFlight = false;
    }
  }
}
