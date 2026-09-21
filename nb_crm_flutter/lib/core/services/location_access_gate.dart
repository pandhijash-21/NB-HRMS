import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Result of a mandatory location check (GPS service + permission + fix).
class LocationAccessResult {
  const LocationAccessResult.ok({this.position})
      : allowed = true,
        message = '';

  const LocationAccessResult.blocked(this.message)
      : allowed = false,
        position = null;

  final bool allowed;
  final String message;
  final Position? position;
}

/// Location is mandatory for NB HRMS: no login / no app shell without it.
class LocationAccessGate {
  LocationAccessGate._();

  static const _fixTimeout = Duration(seconds: 20);

  /// Ask for permission early (login / splash) without blocking forever on GPS.
  static Future<void> requestPermissionPrompt() async {
    if (kIsWeb) {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      return;
    }

    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) return;

    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
    }
    if (status.isGranted) {
      final always = await Permission.locationAlways.status;
      if (!always.isGranted) {
        await Permission.locationAlways.request();
      }
    }
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  /// Hard gate used at login: GPS must be ON, permission granted, and a fix obtained.
  static Future<LocationAccessResult> ensureReadyForLogin({
    bool requireGpsFix = true,
  }) async {
    if (kIsWeb) {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationAccessResult.blocked(
          'Location is MANDATORY. Allow location in your browser to log in.',
        );
      }
      if (!requireGpsFix) return const LocationAccessResult.ok();
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: _fixTimeout,
          ),
        );
        return LocationAccessResult.ok(position: pos);
      } catch (_) {
        return const LocationAccessResult.blocked(
          'Could not fetch your location. Turn on GPS / allow location, then try again.',
        );
      }
    }

    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      return const LocationAccessResult.blocked(
        'Location (GPS) is OFF. Turn on Location in phone Settings — it is MANDATORY to log in.',
      );
    }

    var loc = await Permission.location.status;
    if (!loc.isGranted) {
      loc = await Permission.location.request();
    }
    if (!loc.isGranted) {
      return const LocationAccessResult.blocked(
        'Location permission is MANDATORY. Allow location to log in.',
      );
    }

    var always = await Permission.locationAlways.status;
    if (!always.isGranted) {
      always = await Permission.locationAlways.request();
    }
    if (!always.isGranted) {
      return const LocationAccessResult.blocked(
        'Allow location “All the time” — live tracking is MANDATORY for this app.',
      );
    }

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    if (!requireGpsFix) return const LocationAccessResult.ok();

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _fixTimeout,
        ),
      );
      return LocationAccessResult.ok(position: pos);
    } catch (_) {
      return const LocationAccessResult.blocked(
        'GPS is on but no location fix yet. Go outdoors / wait a few seconds, then try again. Location is MANDATORY.',
      );
    }
  }

  /// After auth: services + permissions must stay on (used by PermissionGuard).
  static Future<LocationAccessResult> ensureReadyForApp() async {
    return ensureReadyForLogin(requireGpsFix: true);
  }
}
