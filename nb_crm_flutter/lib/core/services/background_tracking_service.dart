import 'dart:async';
import 'dart:ui';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_logger.dart';
import '../network/app_config.dart';
import '../network/transport_crypto.dart';

const _notifChannelId = 'my_foreground';
const _notifId = 888;

Future<void> initializeBackgroundService() async {
  if (kIsWeb) return;

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    _notifChannelId,
    'HRMS Live Tracking',
    description: 'Tracks your location while on duty (foreground + background).',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  await plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      autoStartOnBoot: true,
      isForegroundMode: true,
      notificationChannelId: _notifChannelId,
      initialNotificationTitle: 'HRMS Live Tracking',
      initialNotificationContent: 'Waiting for GPS…',
      foregroundServiceNotificationId: _notifId,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

Future<void> startBackgroundTracking() async {
  if (kIsWeb) return;
  final service = FlutterBackgroundService();
  final running = await service.isRunning();
  if (!running) {
    await service.startService();
  } else {
    service.invoke('setAsForeground');
  }
}

Future<void> stopBackgroundTracking() async {
  if (kIsWeb) return;
  final service = FlutterBackgroundService();
  if (await service.isRunning()) {
    service.invoke('stopService');
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((_) {
      service.setAsBackgroundService();
    });
    service.on('stopService').listen((_) {
      service.stopSelf();
    });
    // Stay as a location FGS so tracking continues with app closed / screen off.
    await service.setAsForegroundService();
  }

  final battery = Battery();
  final connectivity = Connectivity();

  double? lastLat;
  double? lastLng;
  DateTime? lastPostAt;
  int tickCount = 0;

  Future<String?> readToken() async {
    try {
      const secureStorage = FlutterSecureStorage();
      final t = await secureStorage.read(key: 'access_token');
      if (t != null && t.isNotEmpty) return t;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('access_token');
    } catch (_) {
      return null;
    }
  }

  Future<Dio?> buildDio() async {
    final token = await readToken();
    if (token == null || token.isEmpty) return null;
    final rawBaseUrl = AppConfig.apiBaseUrl;
    final normalizedUrl = rawBaseUrl.endsWith('/') ? rawBaseUrl : '$rawBaseUrl/';
    return Dio(BaseOptions(
      baseUrl: normalizedUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      headers: {
        'Authorization': 'Bearer $token',
        transportEncHeader: '$transportEncVersion',
      },
    ))
      ..interceptors.add(transportEncryptionInterceptor());
  }

  Future<void> updateNotif(AndroidServiceInstance android, String body) async {
    android.setForegroundNotificationInfo(
      title: 'HRMS Live Tracking',
      content: body,
    );
  }

  Future<void> postLive(Position position) async {
    final dio = await buildDio();
    if (dio == null) return;

    double heading = position.heading;
    final speed = position.speed;

    // Prefer movement bearing when GPS heading is missing / unreliable.
    if ((heading < 0 || heading.isNaN || (speed < 0.4 && heading == 0)) &&
        lastLat != null &&
        lastLng != null) {
      final dist = Geolocator.distanceBetween(
        lastLat!,
        lastLng!,
        position.latitude,
        position.longitude,
      );
      if (dist >= 2.5) {
        heading = Geolocator.bearingBetween(
          lastLat!,
          lastLng!,
          position.latitude,
          position.longitude,
        );
        if (heading < 0) heading += 360;
      }
    }

    lastLat = position.latitude;
    lastLng = position.longitude;
    lastPostAt = DateTime.now();

    try {
      await dio.post('tracking/live', data: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'heading': heading.isNaN ? 0 : heading,
        'speed': speed.isNaN ? 0 : speed,
        'accuracy': position.accuracy,
      });
    } catch (e) {
      AppLogger.tracking.w('[BackgroundTracking] live update failed: $e');
    }

    if (service is AndroidServiceInstance) {
      final t = TimeOfDay.fromDateTime(DateTime.now());
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      await updateNotif(
        service,
        'On duty · last ping $hh:$mm',
      );
    }
  }

  Future<void> postHeartbeat({
    required bool locationServiceEnabled,
    required LocationPermission permission,
  }) async {
    final dio = await buildDio();
    if (dio == null) return;

    try {
      final batteryLevel = await battery.batteryLevel;
      final connectivityResult = await connectivity.checkConnectivity();
      final networkStatus =
          connectivityResult.contains(ConnectivityResult.none) ? 'none' : 'connected';

      final prefs = await SharedPreferences.getInstance();
      if (batteryLevel < 5) {
        await prefs.setString('lastKnownGapReason', 'BATTERY_DIED');
      } else if (networkStatus == 'none') {
        await prefs.setString('lastKnownGapReason', 'NETWORK_UNAVAILABLE');
      }

      final lastKnownGapReason = prefs.getString('lastKnownGapReason');
      if (lastKnownGapReason != null && networkStatus == 'connected') {
        await prefs.remove('lastKnownGapReason');
      }

      final permString =
          (permission == LocationPermission.always || permission == LocationPermission.whileInUse)
              ? 'granted'
              : 'denied';
      final batteryOptimizationExempt =
          prefs.getBool('batteryOptimizationExempt') ?? false;

      await dio.post('tracking/heartbeat', data: {
        'batteryLevel': batteryLevel,
        'networkStatus': networkStatus,
        'permissionStatus': permString,
        'locationServiceEnabled': locationServiceEnabled,
        'lastKnownGapReason': lastKnownGapReason,
        'batteryOptimizationExempt': batteryOptimizationExempt,
      });
    } catch (_) {}
  }

  // Continuous GPS stream — works with app backgrounded / screen off while FGS runs.
  LocationSettings locationSettings;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
      intervalDuration: const Duration(seconds: 2),
      forceLocationManager: false,
    );
  } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    locationSettings = AppleSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      activityType: ActivityType.automotiveNavigation,
      distanceFilter: 5,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
      allowBackgroundLocationUpdates: true,
    );
  } else {
    locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );
  }

  StreamSubscription<Position>? posSub;
  try {
    posSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (position) {
        unawaited(postLive(position));
      },
      onError: (e) {
        AppLogger.tracking.e('[BackgroundTracking] position stream error: $e');
      },
    );
  } catch (e) {
    AppLogger.tracking.e('[BackgroundTracking] failed to start stream: $e');
  }

  // Heartbeat + fallback poll if stream is quiet (e.g. standing still).
  Timer.periodic(const Duration(seconds: 3), (timer) async {
    tickCount++;
    final isHeartbeatTick = tickCount % 10 == 1;

    bool locationServiceEnabled = false;
    LocationPermission permission = LocationPermission.denied;

    try {
      locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      permission = await Geolocator.checkPermission();

      final stale = lastPostAt == null ||
          DateTime.now().difference(lastPostAt!) > const Duration(seconds: 8);

      if (stale &&
          locationServiceEnabled &&
          (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse)) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
          ),
        );
        await postLive(position);
      }
    } catch (e) {
      AppLogger.tracking.w('[BackgroundTracking] fallback poll failed: $e');
    }

    if (isHeartbeatTick) {
      await postHeartbeat(
        locationServiceEnabled: locationServiceEnabled,
        permission: permission,
      );
    }
  });

  service.on('stopService').listen((_) async {
    await posSub?.cancel();
  });
}

/// Tiny helper so we can format notification time without importing Material in isolate oddly.
class TimeOfDay {
  final int hour;
  final int minute;
  TimeOfDay(this.hour, this.minute);
  factory TimeOfDay.fromDateTime(DateTime dt) => TimeOfDay(dt.hour, dt.minute);
}
