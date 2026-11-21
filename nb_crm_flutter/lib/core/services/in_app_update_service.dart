import 'dart:async';

import 'package:flutter/foundation.dart';

// Use conditional import: on web, use the stub; on IO (Android/iOS), use
// the platform implementation which will further check Platform.isAndroid.
import 'in_app_update_stub.dart'
    if (dart.library.io) 'in_app_update_android.dart' as platform_update;

/// Result of an in-app update attempt.
enum InAppUpdateResult {
  /// Update was started/completed successfully.
  started,

  /// No update is available via the platform store.
  notAvailable,

  /// In-app update is not supported on this platform (iOS, Web, desktop).
  unsupported,

  /// The user cancelled or declined the update.
  userCancelled,

  /// An error occurred (not installed from Play Store, API failure, etc.).
  error,
}

/// Wraps the platform-specific in-app update flow.
///
/// On **Android**: Uses Google Play In-App Updates API via `in_app_update`.
/// - Hard update → `AppUpdateType.immediate` (blocking full-screen)
/// - Soft update → `AppUpdateType.flexible` (background download, then install prompt)
///
/// On **iOS / Web / Desktop**: Returns [InAppUpdateResult.unsupported] so the
/// caller can fall back to opening an external store/download link.
class InAppUpdateService {
  InAppUpdateService._();
  static final InAppUpdateService instance = InAppUpdateService._();

  bool _flexibleDownloadComplete = false;

  /// Whether a flexible update has been downloaded and is waiting to install.
  bool get hasFlexibleDownloadReady => _flexibleDownloadComplete;

  /// Check whether an in-app update is available on this platform.
  ///
  /// Returns `true` only on Android when the Play Store has a newer version.
  Future<bool> isUpdateAvailable() async {
    try {
      return await platform_update.checkUpdateAvailable();
    } catch (e) {
      debugPrint('[InAppUpdate] isUpdateAvailable error: $e');
      return false;
    }
  }

  /// Attempt an **immediate** (blocking) in-app update.
  ///
  /// The Play Store takes over the entire screen. If the update succeeds the
  /// app restarts automatically. If the user backs out, [InAppUpdateResult.userCancelled]
  /// is returned.
  Future<InAppUpdateResult> performImmediateUpdate() async {
    try {
      final available = await platform_update.checkUpdateAvailable();
      if (!available) return InAppUpdateResult.notAvailable;

      final result = await platform_update.startImmediateUpdate();
      return result;
    } catch (e) {
      debugPrint('[InAppUpdate] immediateUpdate error: $e');
      return InAppUpdateResult.error;
    }
  }

  /// Attempt a **flexible** (background) in-app update.
  ///
  /// Downloads in the background. When done, call [completeFlexibleUpdate]
  /// to trigger the install (which restarts the app).
  Future<InAppUpdateResult> performFlexibleUpdate() async {
    _flexibleDownloadComplete = false;
    try {
      final available = await platform_update.checkUpdateAvailable();
      if (!available) return InAppUpdateResult.notAvailable;

      final result = await platform_update.startFlexibleUpdate();
      if (result == InAppUpdateResult.started) {
        _flexibleDownloadComplete = true;
      }
      return result;
    } catch (e) {
      debugPrint('[InAppUpdate] flexibleUpdate error: $e');
      return InAppUpdateResult.error;
    }
  }

  /// Complete a previously downloaded flexible update (restarts the app).
  Future<void> completeFlexibleUpdate() async {
    if (!_flexibleDownloadComplete) return;
    try {
      await platform_update.completeUpdate();
      _flexibleDownloadComplete = false;
    } catch (e) {
      debugPrint('[InAppUpdate] completeFlexibleUpdate error: $e');
    }
  }
}
