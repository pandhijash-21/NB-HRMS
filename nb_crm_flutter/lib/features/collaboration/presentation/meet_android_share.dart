import 'dart:io';

import 'package:flutter_background/flutter_background.dart';
import 'package:livekit_client/livekit_client.dart';

Future<bool> prepareAndroidScreenShare() async {
  if (!Platform.isAndroid) return true;
  final allowed = await Hardware.instance.requestCapturePermission();
  if (!allowed) return false;
  try {
    const androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: 'Screen sharing',
      notificationText: 'NB CRM is sharing your screen',
      notificationImportance: AndroidNotificationImportance.normal,
      notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
    );
    var hasPermissions = await FlutterBackground.hasPermissions;
    hasPermissions = await FlutterBackground.initialize(androidConfig: androidConfig) || hasPermissions;
    if (hasPermissions && !FlutterBackground.isBackgroundExecutionEnabled) {
      await FlutterBackground.enableBackgroundExecution();
    }
  } catch (_) {
    try {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.enableBackgroundExecution();
      }
    } catch (_) {}
  }
  return true;
}

Future<void> stopAndroidScreenShare() async {
  if (!Platform.isAndroid) return;
  try {
    if (FlutterBackground.isBackgroundExecutionEnabled) {
      await FlutterBackground.disableBackgroundExecution();
    }
  } catch (_) {}
}
