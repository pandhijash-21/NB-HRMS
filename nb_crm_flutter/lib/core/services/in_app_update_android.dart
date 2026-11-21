import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_update_flutter/in_app_update_flutter.dart';

import 'in_app_update_service.dart';

final _updater = InAppUpdateFlutter();

// ─────────────────────────────────────────────
// Android
// ─────────────────────────────────────────────

Future<bool> _checkAndroid() async {
  try {
    final info = await _updater.checkUpdateAndroid();
    debugPrint(
      '[InAppUpdate] Android updateAvailability=${info.updateAvailability}, '
      'immediateAllowed=${info.immediateUpdateAllowed}, '
      'flexibleAllowed=${info.flexibleUpdateAllowed}, '
      'installStatus=${info.installStatus}',
    );
    return info.updateAvailability ==
        UpdateAvailabilityAndroid.updateAvailable;
  } catch (e) {
    debugPrint('[InAppUpdate] Android checkForUpdate failed: $e');
    return false;
  }
}

Future<InAppUpdateResult> _immediateAndroid() async {
  try {
    final info = await _updater.checkUpdateAndroid();
    if (info.updateAvailability != UpdateAvailabilityAndroid.updateAvailable) {
      return InAppUpdateResult.notAvailable;
    }
    if (!info.immediateUpdateAllowed) {
      debugPrint('[InAppUpdate] immediate update not allowed by Play policy');
      return InAppUpdateResult.unsupported;
    }
    await _updater.startImmediateUpdateAndroid();
    // If we return here, the user either completed or backed out.
    // Immediate update restarts the app on success, so reaching this
    // line usually means the user cancelled.
    return InAppUpdateResult.started;
  } catch (e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('cancel') || msg.contains('denied')) {
      return InAppUpdateResult.userCancelled;
    }
    debugPrint('[InAppUpdate] startImmediateUpdateAndroid failed: $e');
    return InAppUpdateResult.error;
  }
}

Future<InAppUpdateResult> _flexibleAndroid() async {
  try {
    final info = await _updater.checkUpdateAndroid();
    if (info.updateAvailability != UpdateAvailabilityAndroid.updateAvailable) {
      return InAppUpdateResult.notAvailable;
    }
    if (!info.flexibleUpdateAllowed) {
      debugPrint('[InAppUpdate] flexible update not allowed by Play');
      return InAppUpdateResult.unsupported;
    }
    await _updater.startFlexibleUpdateAndroid();
    // Wait for download to complete via the install state stream
    final completer = Completer<InAppUpdateResult>();
    late StreamSubscription<InstallStateAndroid> sub;
    sub = _updater.installStateStreamAndroid.listen(
      (state) {
        debugPrint('[InAppUpdate] installState=${state.installStatus}');
        if (state.installStatus == InstallStatusAndroid.downloaded) {
          if (!completer.isCompleted) completer.complete(InAppUpdateResult.started);
          sub.cancel();
        } else if (state.installStatus == InstallStatusAndroid.failed ||
            state.installStatus == InstallStatusAndroid.canceled) {
          if (!completer.isCompleted) {
            completer.complete(state.installStatus == InstallStatusAndroid.canceled
                ? InAppUpdateResult.userCancelled
                : InAppUpdateResult.error);
          }
          sub.cancel();
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.complete(InAppUpdateResult.error);
        sub.cancel();
      },
    );
    // Safety timeout: 10 minutes max wait for download
    return completer.future.timeout(
      const Duration(minutes: 10),
      onTimeout: () {
        sub.cancel();
        return InAppUpdateResult.error;
      },
    );
  } catch (e) {
    debugPrint('[InAppUpdate] startFlexibleUpdateAndroid failed: $e');
    return InAppUpdateResult.error;
  }
}

Future<void> _completeAndroid() async {
  try {
    await _updater.completeUpdateAndroid();
  } catch (e) {
    debugPrint('[InAppUpdate] completeUpdateAndroid failed: $e');
    rethrow;
  }
}

// ─────────────────────────────────────────────
// iOS
// ─────────────────────────────────────────────

Future<bool> _checkIos() async {
  try {
    final info = await _updater.checkUpdateIos();
    debugPrint(
      '[InAppUpdate] iOS updateAvailability=${info.updateAvailability}, '
      'appStoreId=${info.appStoreId}',
    );
    return info.updateAvailability == UpdateAvailabilityIos.updateAvailable;
  } catch (e) {
    debugPrint('[InAppUpdate] iOS checkUpdate failed: $e');
    return false;
  }
}

String? _iosAppStoreId;

Future<InAppUpdateResult> _showIosUpdate() async {
  try {
    final info = await _updater.checkUpdateIos();
    if (info.updateAvailability != UpdateAvailabilityIos.updateAvailable) {
      return InAppUpdateResult.notAvailable;
    }
    _iosAppStoreId = info.appStoreId;
    await _updater.showUpdateForIos(appStoreId: info.appStoreId);
    return InAppUpdateResult.started;
  } catch (e) {
    debugPrint('[InAppUpdate] showUpdateForIos failed: $e');
    return InAppUpdateResult.error;
  }
}

// ─────────────────────────────────────────────
// Public API (called by InAppUpdateService via conditional import)
// ─────────────────────────────────────────────

/// Check if an update is available on this platform.
Future<bool> checkUpdateAvailable() async {
  if (Platform.isAndroid) return _checkAndroid();
  if (Platform.isIOS) return _checkIos();
  return false;
}

/// Start an immediate (blocking) update.
/// Android: full-screen Play Store flow.
/// iOS: presents native App Store product sheet.
Future<InAppUpdateResult> startImmediateUpdate() async {
  if (Platform.isAndroid) return _immediateAndroid();
  if (Platform.isIOS) return _showIosUpdate();
  return InAppUpdateResult.unsupported;
}

/// Start a flexible (background) update.
/// Android: downloads in background, then caller must call completeUpdate().
/// iOS: same as immediate (App Store sheet) since iOS has no flexible concept.
Future<InAppUpdateResult> startFlexibleUpdate() async {
  if (Platform.isAndroid) return _flexibleAndroid();
  if (Platform.isIOS) return _showIosUpdate();
  return InAppUpdateResult.unsupported;
}

/// Complete a flexible update (Android only — restarts the app).
Future<void> completeUpdate() async {
  if (Platform.isAndroid) return _completeAndroid();
  // iOS: no-op — the App Store sheet handles it.
}
