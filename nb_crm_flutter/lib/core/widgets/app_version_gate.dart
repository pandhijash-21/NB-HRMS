import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app_version.dart';
import '../network/dio_client.dart';
import '../services/branding_config.dart';
import '../services/in_app_update_service.dart';
import '../utils/open_url.dart';

/// Whether this device is a native mobile device (Android or iOS, not web).
bool get _kIsMobileDevice {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// Whether this device is a native Android device (not web).
bool get _kIsAndroidDevice {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android;
}

/// Blocks the app when it is below the Superadmin minimum version, and
/// shows a dismissible update notice on each entry when a newer version exists.
///
/// On **Android**, attempts Google Play In-App Updates first:
/// - Hard (below min version) → Immediate update (full-screen blocking)
/// - Soft (below latest)       → Flexible update (background download + install prompt)
///
/// Falls back to external store/download links on failure, iOS, and web.
class AppVersionGate extends StatefulWidget {
  const AppVersionGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppVersionGate> createState() => _AppVersionGateState();
}

class _AppVersionGateState extends State<AppVersionGate> with WidgetsBindingObserver {
  bool _hard = false;
  bool _softVisible = false;
  bool _softDismissedThisVisit = false;
  bool _checking = false;
  bool _inAppUpdateInProgress = false;

  final _inAppUpdate = InAppUpdateService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _softDismissedThisVisit = false;
      return;
    }
    if (state == AppLifecycleState.resumed) {
      // If a flexible update download was completed, prompt to install
      if (_inAppUpdate.hasFlexibleDownloadReady) {
        _showFlexibleInstallPrompt();
        return;
      }
      _check();
    }
  }

  Future<void> _check() async {
    if (!mounted || _checking) return;
    _checking = true;
    try {
      await BrandingConfig.fetch(context.read<DioClient>());
      if (!mounted) return;
      final kind = appUpdateKind(
        current: kAppVersion,
        minVersion: BrandingConfig.minVersion,
        maxVersion: BrandingConfig.maxVersion,
      );

      if (kind == AppUpdateKind.hard) {
        // ── Hard update: must update before continuing ──
        if (_kIsMobileDevice && !_inAppUpdateInProgress) {
          _inAppUpdateInProgress = true;
          final result = await _inAppUpdate.performImmediateUpdate();
          _inAppUpdateInProgress = false;
          if (!mounted) return;

          if (result == InAppUpdateResult.started) {
            // Immediate update takes over — app will restart after install.
            // If we reach here, the user backed out of the store screen.
            setState(() => _hard = true);
            return;
          }

          if (result == InAppUpdateResult.userCancelled) {
            // User cancelled — show our own hard wall as fallback
            debugPrint('[AppVersionGate] User cancelled immediate in-app update');
          } else {
            debugPrint('[AppVersionGate] In-app immediate update unavailable ($result), showing hard wall');
          }
        }
        // Show our own hard-update wall (with external link fallback)
        setState(() => _hard = true);
      } else if (kind == AppUpdateKind.soft) {
        setState(() => _hard = false);
        if (!_softVisible && !_softDismissedThisVisit) {
          _softVisible = true;

          if (_kIsMobileDevice) {
            // ── Soft update: try in-app update on Android/iOS ──
            await _handleFlexibleUpdate();
          } else {
            // Web — show dialog with external link
            _showSoftDialog();
          }
        }
      } else {
        setState(() => _hard = false);
      }
    } finally {
      _checking = false;
    }
  }

  /// Attempts an in-app update on Android/iOS.
  /// Android: flexible (background download) → install prompt.
  /// iOS: shows native App Store product sheet.
  /// Falls back to the standard dialog if unavailable.
  Future<void> _handleFlexibleUpdate() async {
    final result = await _inAppUpdate.performFlexibleUpdate();
    if (!mounted) return;

    switch (result) {
      case InAppUpdateResult.started:
        if (_kIsAndroidDevice) {
          // Android: download completed — prompt user to restart and install
          _showFlexibleInstallPrompt();
        } else {
          // iOS: App Store sheet was shown successfully, dismiss soft state
          _softVisible = false;
          _softDismissedThisVisit = true;
        }
        break;

      case InAppUpdateResult.userCancelled:
        debugPrint('[AppVersionGate] User cancelled in-app update');
        _softVisible = false;
        _softDismissedThisVisit = true;
        break;

      case InAppUpdateResult.notAvailable:
      case InAppUpdateResult.unsupported:
      case InAppUpdateResult.error:
        // Fall back to standard dialog with external link
        debugPrint('[AppVersionGate] In-app update unavailable ($result), showing dialog');
        _showSoftDialog();
        break;
    }
  }

  /// Shows a dialog prompting the user to install the already-downloaded
  /// flexible update. Restarting applies the update.
  void _showFlexibleInstallPrompt() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.download_done_rounded, size: 40, color: Color(0xFF2E7D32)),
          title: const Text('Update ready to install'),
          content: Text(
            'Version ${BrandingConfig.maxVersion} has been downloaded. '
            'Restart the app to apply the update.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Later'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _inAppUpdate.completeFlexibleUpdate();
              },
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Restart & Update'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      _softVisible = false;
      _softDismissedThisVisit = true;
    });
  }

  String get _updateTarget => BrandingConfig.updateLinkForThisDevice();

  Future<void> _openUpdate() async {
    final target = _updateTarget;
    if (!target.startsWith('http')) return;
    await openExternalUrl(target);
  }

  /// Standard soft-update dialog with external link (used on Web,
  /// and as mobile fallback when native In-App Updates fails).
  void _showSoftDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Update available'),
          content: Text(
            'Version ${BrandingConfig.maxVersion} is available. You are on $kAppVersion.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: BrandingConfig.updateLinkForThisDevice().startsWith('http')
                  ? () {
                      Navigator.of(ctx).pop();
                      _openUpdate();
                    }
                  : null,
              child: const Text('Update'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      _softVisible = false;
      _softDismissedThisVisit = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_hard)
          Positioned.fill(child: _HardUpdateWall(onInAppUpdate: _kIsMobileDevice ? _retryImmediateUpdate : null)),
      ],
    );
  }

  /// Retry in-app immediate update from the hard wall "Update" button on Android.
  Future<void> _retryImmediateUpdate() async {
    if (_inAppUpdateInProgress) return;
    _inAppUpdateInProgress = true;
    final result = await _inAppUpdate.performImmediateUpdate();
    _inAppUpdateInProgress = false;
    if (!mounted) return;

    if (result != InAppUpdateResult.started) {
      // In-app update didn't work — fall back to external link
      _openUpdate();
    }
  }
}

class _HardUpdateWall extends StatelessWidget {
  const _HardUpdateWall({this.onInAppUpdate});

  /// If non-null, the "Update now" button first tries in-app update (Android).
  final VoidCallback? onInAppUpdate;

  @override
  Widget build(BuildContext context) {
    final latest = BrandingConfig.maxVersion.trim();
    final hasExternalLink = BrandingConfig.updateLinkForThisDevice().startsWith('http');

    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.black.withValues(alpha: 0.72),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.system_update_alt_rounded, size: 36, color: Color(0xFF1A1F1B)),
                      const SizedBox(height: 14),
                      const Text(
                        'Update required',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A1F1B)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        latest.isEmpty
                            ? 'This version ($kAppVersion) is no longer supported. Install the latest app to continue.'
                            : 'This version ($kAppVersion) is no longer supported. Install $latest or newer to continue.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF6F766F)),
                      ),
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: onInAppUpdate ?? (hasExternalLink
                            ? () => openExternalUrl(BrandingConfig.updateLinkForThisDevice())
                            : null),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1F1B),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF1A1F1B).withValues(alpha: 0.35),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Update now', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
