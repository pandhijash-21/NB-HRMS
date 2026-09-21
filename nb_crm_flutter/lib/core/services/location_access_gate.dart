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

  static bool _statusOk(PermissionStatus s) =>
      s.isGranted || s.isLimited || s == PermissionStatus.provisional;

  /// True when the OS (or Geolocator) says we have always / background location.
  ///
  /// Some OEMs show “Allow all the time” in Settings while
  /// [Permission.locationAlways] still reports denied. Geolocator’s
  /// [LocationPermission.always] is the more reliable signal in that case.
  static Future<bool> hasAlwaysLocation() async {
    final geo = await Geolocator.checkPermission();
    if (geo == LocationPermission.always) return true;

    final always = await Permission.locationAlways.status;
    if (_statusOk(always)) return true;

    // Android < 10: fine/coarse grants background automatically.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final whenInUse = await Permission.locationWhenInUse.status;
      final fine = await Permission.location.status;
      if (_statusOk(whenInUse) || _statusOk(fine)) {
        // If background permission is not in the “denied forever” state and
        // Geolocator already upgraded to always after Settings, trust geo above.
        // Some OEMs never expose BACKGROUND via permission_handler — accept
        // when-in-use + working GPS for the gate, FGS still runs in foreground.
        if (geo == LocationPermission.whileInUse && always.isDenied && !always.isPermanentlyDenied) {
          // Re-read geo once more (settings change may lag plugins).
          final geo2 = await Geolocator.checkPermission();
          if (geo2 == LocationPermission.always) return true;
        }
      }
    }
    return false;
  }

  static Future<bool> _hasForegroundLocation() async {
    final geo = await Geolocator.checkPermission();
    if (geo == LocationPermission.always || geo == LocationPermission.whileInUse) {
      return true;
    }
    final whenInUse = await Permission.locationWhenInUse.status;
    if (_statusOk(whenInUse)) return true;
    final loc = await Permission.location.status;
    return _statusOk(loc);
  }

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

    // Step 1: foreground
    var whenInUse = await Permission.locationWhenInUse.status;
    if (!_statusOk(whenInUse)) {
      whenInUse = await Permission.locationWhenInUse.request();
    }
    if (!_statusOk(whenInUse)) {
      final loc = await Permission.location.request();
      if (!_statusOk(loc)) return;
    }

    // Step 2: always — only if not already always (re-request opens Settings
    // and can falsely look like a denial on some OEMs).
    if (await hasAlwaysLocation()) return;

    await Permission.locationAlways.request();
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

    // Foreground first (required before Always on Android 10+).
    if (!await _hasForegroundLocation()) {
      var whenInUse = await Permission.locationWhenInUse.request();
      if (!_statusOk(whenInUse)) {
        whenInUse = await Permission.location.request();
      }
      if (!_statusOk(whenInUse) && !await _hasForegroundLocation()) {
        return const LocationAccessResult.blocked(
          'Location permission is MANDATORY. Allow location to log in.',
        );
      }
    }

    // Always / All the time — do not re-prompt if already granted (OEM bug).
    if (!await hasAlwaysLocation()) {
      await Permission.locationAlways.request();
      // Brief pause so Settings → Always is visible to plugins.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!await hasAlwaysLocation()) {
        // Last resort: if GPS fix works and foreground is granted, many OEMs
        // already have BACKGROUND in Settings but report denied to plugins.
        // Accept when we can actually read location; FGS still needs Always
        // in Settings for closed-app tracking.
        final foregroundOk = await _hasForegroundLocation();
        if (!foregroundOk) {
          return const LocationAccessResult.blocked(
            'Allow location “All the time” in App Settings — live tracking is MANDATORY.',
          );
        }
        if (requireGpsFix) {
          try {
            final pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: _fixTimeout,
              ),
            );
            // Working GPS + foreground: allow entry. Soft message only if
            // Geolocator still says whileInUse (user may need Settings → Always).
            final geo = await Geolocator.checkPermission();
            if (geo == LocationPermission.always || await hasAlwaysLocation()) {
              return LocationAccessResult.ok(position: pos);
            }
            // Treat as OK for gate if we have a fix — closed-app tracking
            // will keep working once Always is correctly reflected.
            return LocationAccessResult.ok(position: pos);
          } catch (_) {
            return const LocationAccessResult.blocked(
              'Allow location “All the time” in App Settings (NB CRM → Permissions → Location). It already looks allowed on some phones but the app still needs that option.',
            );
          }
        }
        return const LocationAccessResult.ok();
      }
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
