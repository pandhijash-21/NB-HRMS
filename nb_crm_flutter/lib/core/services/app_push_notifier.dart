import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../logging/app_logger.dart';
import '../router/app_navigation_service.dart';

/// Lightweight OS push / heads-up notifications for support / chat / admin / profile events.
class AppPushNotifier {
  AppPushNotifier._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static int _seq = 9000;

  static const _channelId = 'hrms_alerts';
  static const _channelName = 'HRMS Alerts';

  static Future<void> ensureInitialized() async {
    if (_ready || kIsWeb) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        AppLogger.app.i('Notification tapped: payload=$payload');
        if (payload != null && payload.isNotEmpty) {
          AppNavigationService.navigateTo(payload);
        }
      },
    );

    // Request permissions for Android 13+ (API 33+)
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Support tickets, chat, announcements, and task updates',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        ),
      );
    }

    // Check if app was cold-launched by tapping an OS notification
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        AppLogger.app.i('App cold-launched from notification payload=$payload');
        AppNavigationService.navigateTo(payload);
      }
    }

    _ready = true;
  }

  static Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    try {
      await ensureInitialized();
      await _plugin.show(
        _seq++,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription:
                'Support tickets, chat, announcements, and task updates',
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      AppLogger.app.w('Failed to display OS notification: $e');
    }
  }
}
