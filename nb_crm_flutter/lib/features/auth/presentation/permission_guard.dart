import 'dart:ui';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/services/background_tracking_service.dart';
import '../../../core/services/web_live_tracking_service.dart';

/// Hard-gates the app until location is allowed.
/// Native: Always location + battery opt-out.
/// Web: browser geolocation (While using the site). No access until granted.
class PermissionGuard extends StatefulWidget {
  final Widget child;

  const PermissionGuard({Key? key, required this.child}) : super(key: key);

  @override
  State<PermissionGuard> createState() => _PermissionGuardState();
}

class _PermissionGuardState extends State<PermissionGuard> {
  bool _hasPermissions = false;
  bool _checking = true;
  String _errorMsg = "";
  Timer? _timer;
  DateTime? _lastServiceEnsureAt;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_checking) return;
      if (kIsWeb) {
        unawaited(_verifyPermissionsQuietly());
        return;
      }
      if (_hasPermissions) {
        _verifyPermissionsQuietly();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (kIsWeb) {
      WebLiveTrackingService.stop();
    }
    super.dispose();
  }

  Future<bool> _needsBackgroundPermission() async {
    if (kIsWeb) return false;
    return true;
  }

  bool _webLocationGranted(LocationPermission permission) {
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> _isWebLocationReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    final permission = await Geolocator.checkPermission();
    return _webLocationGranted(permission);
  }

  Future<void> _checkPermissions() async {
    if (kIsWeb) {
      setState(() => _checking = true);
      try {
        final ok = await _isWebLocationReady();
        if (!mounted) return;
        setState(() {
          _hasPermissions = ok;
          _checking = false;
          _errorMsg = ok
              ? ''
              : 'This website requires location access. Allow location in the browser prompt to continue.';
        });
        if (ok) {
          unawaited(WebLiveTrackingService.ensureRunning());
        } else {
          WebLiveTrackingService.stop();
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _hasPermissions = false;
          _checking = false;
          _errorMsg = 'Location access is required. Allow location in your browser to use this site.';
        });
      }
      return;
    }

    setState(() => _checking = true);

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _checking = false;
        _hasPermissions = false;
        _errorMsg = "Location services are disabled. Please enable them.";
      });
      return;
    }

    var locationStatus = await Permission.location.status;
    bool needsBg = await _needsBackgroundPermission();
    var bgStatus = needsBg ? await Permission.locationAlways.status : PermissionStatus.granted;
    var batteryStatus = await Permission.ignoreBatteryOptimizations.status;

    if (locationStatus.isGranted && bgStatus.isGranted && batteryStatus.isGranted) {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        await startBackgroundTracking();
      } catch (e) {
        AppLogger.tracking.e('Failed to start background tracking: $e');
      }
      if (mounted) {
        setState(() {
          _hasPermissions = true;
          _checking = false;
        });
        unawaited(_maybeOpenTrackingSetup());
      }
    } else {
      setState(() {
        _checking = false;
        _hasPermissions = false;
        _errorMsg = needsBg
            ? "This app strictly requires Always-On location and Battery Optimization to function."
            : "This app strictly requires location permissions (While using the app) to function.";
      });
    }
  }

  Future<void> _maybeOpenTrackingSetup() async {
    if (kIsWeb || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (prefs.getBool('hasSeenAutostartOnboarding') == true) return;
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc == '/tracking/setup' ||
        loc == '/login' ||
        loc == '/change-password' ||
        loc == '/verify-emails') {
      return;
    }
    if (!mounted) return;
    context.go('/tracking/setup');
  }

  Future<void> _verifyPermissionsQuietly() async {
    if (kIsWeb) {
      final ok = await _isWebLocationReady();
      if (!mounted) return;
      if (ok) {
        if (!_hasPermissions) {
          setState(() {
            _hasPermissions = true;
            _errorMsg = '';
          });
        }
        await WebLiveTrackingService.ensureRunning();
      } else {
        WebLiveTrackingService.stop();
        if (_hasPermissions || _errorMsg.isEmpty) {
          setState(() {
            _hasPermissions = false;
            _errorMsg =
                'Location was blocked. Allow location for this site in the browser address bar, then tap Enable.';
          });
        }
      }
      return;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _hasPermissions = false;
          _errorMsg = "Location services are disabled. Please enable them.";
        });
      }
      return;
    }

    var locationStatus = await Permission.location.status;
    bool needsBg = await _needsBackgroundPermission();
    var bgStatus = needsBg ? await Permission.locationAlways.status : PermissionStatus.granted;
    var batteryStatus = await Permission.ignoreBatteryOptimizations.status;

    if (!locationStatus.isGranted || !bgStatus.isGranted || !batteryStatus.isGranted) {
      if (mounted) {
        setState(() {
          _hasPermissions = false;
          _errorMsg = needsBg
              ? "This app strictly requires Always-On location and Battery Optimization to function."
              : "This app strictly requires location permissions (While using the app) to function.";
        });
      }
    } else {
      final now = DateTime.now();
      if (_lastServiceEnsureAt == null ||
          now.difference(_lastServiceEnsureAt!) > const Duration(seconds: 20)) {
        _lastServiceEnsureAt = now;
        try {
          await startBackgroundTracking();
        } catch (_) {}
      }
    }
  }

  Future<void> _requestPermissions() async {
    setState(() => _checking = true);

    if (kIsWeb) {
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (mounted) {
            setState(() {
              _checking = false;
              _hasPermissions = false;
              _errorMsg = 'Turn on location/GPS on this device, then tap Enable again.';
            });
          }
          return;
        }

        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (_webLocationGranted(permission)) {
          unawaited(WebLiveTrackingService.ensureRunning());
          if (mounted) {
            setState(() {
              _hasPermissions = true;
              _checking = false;
              _errorMsg = '';
            });
          }
          return;
        }

        if (mounted) {
          setState(() {
            _checking = false;
            _hasPermissions = false;
            _errorMsg = permission == LocationPermission.deniedForever
                ? 'Location is blocked for this site. Click the lock/tune icon in the address bar, set Location to Allow, then tap Enable again.'
                : 'You must allow location to use this website.';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _checking = false;
            _hasPermissions = false;
            _errorMsg = 'You must allow location to use this website.';
          });
        }
      }
      return;
    }

    var locStatus = await Permission.location.request();
    bool needsBg = await _needsBackgroundPermission();

    if (locStatus.isGranted) {
      if (needsBg) {
        var bgStatus = await Permission.locationAlways.request();
        if (!bgStatus.isGranted) {
          setState(() {
            _checking = false;
            _hasPermissions = false;
            _errorMsg =
                "You must allow location 'All the time' for live tracking. Please tap 'Open App Settings' and grant it.";
          });
          return;
        }
      }

      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }

      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
        try {
          await DisableBatteryOptimization.showDisableBatteryOptimizationSettings();
        } catch (_) {}
      }

      try {
        await Future.delayed(const Duration(milliseconds: 500));
        await startBackgroundTracking();
      } catch (e) {
        AppLogger.tracking.e('Failed to start background tracking: $e');
      }
      setState(() {
        _hasPermissions = true;
        _checking = false;
      });
      return;
    }

    setState(() {
      _checking = false;
      _hasPermissions = false;
      _errorMsg =
          "You must allow location 'While using the app' for live tracking. Please tap 'Open App Settings' and grant it.";
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Colors.amberAccent)),
      );
    }

    if (_hasPermissions) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/golden_map.jpg',
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.6),
              colorBlendMode: BlendMode.darken,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 32.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.1),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.3),
                                    blurRadius: 25,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.location_on_outlined,
                                size: 64,
                                color: Colors.amberAccent,
                              ),
                            ),
                            const SizedBox(height: 32),
                            const Text(
                              "LOCATION REQUIRED",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMsg.isNotEmpty
                                  ? _errorMsg
                                  : kIsWeb
                                      ? 'Allow location in your browser to continue. Without it you cannot use this website.'
                                      : 'Allow location All the time + disable battery optimization so live tracking continues when the app is closed.',
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: Colors.amber.shade50,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              kIsWeb
                                  ? 'Required: Browser location (Allow). If you previously blocked it, use the lock icon in the address bar.'
                                  : 'Required: Foreground · Background (Always) · Notifications · Battery unrestricted',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: Colors.amber.shade200.withOpacity(0.85),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 40),
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.5),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _requestPermissions,
                                icon: const Icon(Icons.my_location_rounded, size: 20, color: Colors.black87),
                                label: const Text(
                                  "ENABLE PERMISSIONS",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    color: Colors.black87,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            if (!kIsWeb) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: () => openAppSettings(),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    foregroundColor: Colors.amberAccent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Colors.amber.withOpacity(0.4)),
                                    ),
                                  ),
                                  child: const Text(
                                    "OPEN APP SETTINGS",
                                    style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1.2),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
