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

const _notifChannelId = 'hrms_tracking_quiet';
const _notifId = 888;

Future<void> initializeBackgroundService() async {
  if (kIsWeb) return;

  // Importance.low keeps the FGS notification in the shade without heads-up
  // popups. A new channel id is required — Android never lowers an existing
  // channel's importance after first create.
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    _notifChannelId,
    'HRMS Live Tracking',
    description:
        'Quiet ongoing indicator: tracking in progress. Location is mandatory.',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
    showBadge: false,
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
      initialNotificationTitle: 'Tracking in progress',
      initialNotificationContent: 'Location is MANDATORY · waiting for GPS…',
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

  // Ensure prefs hold a token the FGS isolate can read (Keystore often fails there).
  try {
    const secure = FlutterSecureStorage();
    final token = await secure.read(key: 'access_token');
    final prefs = await SharedPreferences.getInstance();
    if (token != null && token.isNotEmpty) {
      await prefs.setString('access_token', token);
    }
    await AppConfig.mirrorApiBaseUrlForBackground();
  } catch (e) {
    AppLogger.tracking.w('Could not mirror session for background tracking: $e');
  }

  final service = FlutterBackgroundService();
  final running = await service.isRunning();
  if (!running) {
    await service.startService();
  } else {
    service.invoke('setAsForeground');
  }

  // Push credentials into the running isolate immediately.
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final api = await AppConfig.resolveApiBaseUrlForBackground();
    if (token != null && token.isNotEmpty) {
      service.invoke('syncSession', {
        'token': token,
        'apiBaseUrl': api,
      });
    }
  } catch (_) {}
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

  String? injectedToken;
  String? injectedApiBase;

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
    service.on('syncSession').listen((event) {
      if (event == null) return;
      final t = event['token']?.toString();
      final api = event['apiBaseUrl']?.toString();
      if (t != null && t.isNotEmpty) injectedToken = t;
      if (api != null && api.isNotEmpty) injectedApiBase = api;
    });
    // Stay as a location FGS so tracking continues with app closed / screen off.
    await service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'Tracking in progress',
      content: 'Location is MANDATORY · acquiring GPS…',
    );
  } else {
    service.on('syncSession').listen((event) {
      if (event == null) return;
      final t = event['token']?.toString();
      final api = event['apiBaseUrl']?.toString();
      if (t != null && t.isNotEmpty) injectedToken = t;
      if (api != null && api.isNotEmpty) injectedApiBase = api;
    });
    service.on('stopService').listen((_) {
      service.stopSelf();
    });
  }

  final battery = Battery();
  final connectivity = Connectivity();

  double? lastLat;
  double? lastLng;
  DateTime? lastPostAt;
  int tickCount = 0;
  int noTokenTicks = 0;

  Future<String?> readToken() async {
    if (injectedToken != null && injectedToken!.isNotEmpty) {
      return injectedToken;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final fromPrefs = prefs.getString('access_token');
      if (fromPrefs != null && fromPrefs.isNotEmpty) {
        injectedToken = fromPrefs;
        return fromPrefs;
      }
    } catch (e) {
      AppLogger.tracking.w('[BackgroundTracking] prefs token read failed: $e');
    }
    try {
      const secureStorage = FlutterSecureStorage();
      final t = await secureStorage.read(key: 'access_token');
      if (t != null && t.isNotEmpty) {
        injectedToken = t;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', t);
        } catch (_) {}
        return t;
      }
    } catch (e) {
      AppLogger.tracking.w('[BackgroundTracking] secure token read failed: $e');
    }
    return null;
  }

  Future<Dio?> buildDio() async {
    final token = await readToken();
    if (token == null || token.isEmpty) {
      noTokenTicks++;
      if (service is AndroidServiceInstance && noTokenTicks <= 3) {
        service.setForegroundNotificationInfo(
          title: 'Tracking blocked',
          content: 'Open NB CRM and stay signed in — session missing',
        );
      }
      AppLogger.tracking.w('[BackgroundTracking] no access token — cannot post GPS');
      return null;
    }
    noTokenTicks = 0;

    String rawBaseUrl = injectedApiBase ?? '';
    if (rawBaseUrl.isEmpty) {
      rawBaseUrl = await AppConfig.resolveApiBaseUrlForBackground();
    }
    final normalizedUrl = rawBaseUrl.endsWith('/') ? rawBaseUrl : '$rawBaseUrl/';
    return Dio(BaseOptions(
      baseUrl: normalizedUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        transportEncHeader: '$transportEncVersion',
      },
    ))
      ..interceptors.add(transportEncryptionInterceptor());
  }

  String? lastNotifBody;
  DateTime? lastNotifAt;

  Future<void> updateNotif(
    AndroidServiceInstance android,
    String body, {
    bool force = false,
  }) async {
    // Avoid rewriting the shade entry every GPS tick (feels like constant popups).
    final now = DateTime.now();
    if (!force &&
        body == lastNotifBody &&
        lastNotifAt != null &&
        now.difference(lastNotifAt!) < const Duration(seconds: 55)) {
      return;
    }
    lastNotifBody = body;
    lastNotifAt = now;
    android.setForegroundNotificationInfo(
      title: 'Tracking in progress',
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
      if (service is AndroidServiceInstance) {
        await updateNotif(
          service,
          'Location is MANDATORY · ping failed — check network',
          force: true,
        );
      }
      return;
    }

    if (service is AndroidServiceInstance) {
      final t = TimeOfDay.fromDateTime(DateTime.now());
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      await updateNotif(
        service,
        'Location is MANDATORY · last ping $hh:$mm',
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
    // Immediate first fix — do not wait for the stream (fixes "Waiting for first GPS fix").
    unawaited(() async {
      try {
        final serviceOn = await Geolocator.isLocationServiceEnabled();
        final permission = await Geolocator.checkPermission();
        if (!serviceOn ||
            (permission != LocationPermission.always &&
                permission != LocationPermission.whileInUse)) {
          if (service is AndroidServiceInstance) {
            await updateNotif(
              service,
              'Location is MANDATORY · turn GPS on',
            );
          }
          return;
        }
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 25),
          ),
        );
        await postLive(position);
      } catch (e) {
        AppLogger.tracking.w('[BackgroundTracking] initial GPS fix failed: $e');
        if (service is AndroidServiceInstance) {
          await updateNotif(
            service,
            'Location is MANDATORY · waiting for GPS fix…',
          );
        }
      }
    }());

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
