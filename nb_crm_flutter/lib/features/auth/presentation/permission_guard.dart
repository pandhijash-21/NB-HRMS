import 'dart:ui';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/services/background_tracking_service.dart';
import '../../../core/services/location_access_gate.dart';
import '../../../core/services/web_live_tracking_service.dart';
import '../../../core/widgets/nb_brand_loader.dart';

/// Hard-gates the app until location is allowed AND a GPS fix is obtained.
/// Native: Always location + battery opt-out + live tracking notification.
/// Web: browser geolocation. No access until granted.
/// Login itself is also blocked when GPS is off (see LoginScreen).
class PermissionGuard extends StatefulWidget {
  final Widget child;

  const PermissionGuard({super.key, required this.child});

  @override
  State<PermissionGuard> createState() => _PermissionGuardState();
}

class _PermissionGuardState extends State<PermissionGuard> {
  bool _hasPermissions = false;
  bool _checking = true;
  String _errorMsg = "";
  String _loaderStatus = 'Checking location…';
  Timer? _timer;
  DateTime? _lastServiceEnsureAt;

  String _currentPath() {
    try {
      return GoRouterState.of(context).matchedLocation;
    } catch (_) {}
    try {
      return GoRouter.of(context).state.matchedLocation;
    } catch (_) {}
    if (kIsWeb) {
      final frag = Uri.base.fragment;
      if (frag.isNotEmpty) return frag.startsWith('/') ? frag : '/$frag';
    }
    return '';
  }

  bool _isAuthRoute() {
    final path = _currentPath();
    return path == '/login' ||
        path == '/change-password' ||
        path == '/verify-emails';
  }

  bool _isPublicMeetRoute() {
    final path = _currentPath();
    return path.startsWith('/meet/r/') || path.startsWith('/meet/guest/');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isPublicMeetRoute()) {
        if (kIsWeb) WebLiveTrackingService.stop();
        setState(() {
          _checking = false;
          _errorMsg = '';
        });
        return;
      }
      // Login still asks for location itself; after auth we hard-gate.
      if (_isAuthRoute()) {
        if (kIsWeb) WebLiveTrackingService.stop();
        setState(() {
          _checking = false;
          _errorMsg = '';
        });
        return;
      }
      _checkPermissions();
    });
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || _checking) return;
      if (_isPublicMeetRoute() || _isAuthRoute()) {
        if (kIsWeb) WebLiveTrackingService.stop();
        return;
      }
      unawaited(_verifyPermissionsQuietly());
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

  Future<void> _startTracking() async {
    if (kIsWeb) {
      await WebLiveTrackingService.ensureRunning();
      return;
    }
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    try {
      await startBackgroundTracking();
    } catch (e) {
      AppLogger.tracking.e('Failed to start background tracking: $e');
    }
  }

  Future<void> _checkPermissions() async {
    if (_isPublicMeetRoute() || _isAuthRoute()) {
      if (kIsWeb) WebLiveTrackingService.stop();
      if (mounted) {
        setState(() {
          _checking = false;
          _errorMsg = '';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _checking = true;
        _loaderStatus = 'Location is MANDATORY — checking GPS…';
      });
    }

    final result = await LocationAccessGate.ensureReadyForApp();
    if (!mounted) return;

    if (!result.allowed) {
      setState(() {
        _hasPermissions = false;
        _checking = false;
        _errorMsg = result.message;
      });
      if (kIsWeb) WebLiveTrackingService.stop();
      return;
    }

    if (!kIsWeb) {
      final battery = await Permission.ignoreBatteryOptimizations.status;
      if (!battery.isGranted) {
        setState(() {
          _hasPermissions = false;
          _checking = false;
          _errorMsg =
              'Disable battery optimization — live tracking is MANDATORY and must keep running.';
        });
        return;
      }
    }

    if (mounted) {
      setState(() => _loaderStatus = 'Starting live tracking…');
    }
    await _startTracking();
    if (!mounted) return;

    setState(() {
      _hasPermissions = true;
      _checking = false;
      _errorMsg = '';
    });
    unawaited(_maybeOpenTrackingSetup());
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
        loc == '/verify-emails' ||
        loc.startsWith('/meet/r/') ||
        loc.startsWith('/meet/guest/')) {
      return;
    }
    if (!mounted) return;
    context.go('/tracking/setup');
  }

  Future<void> _verifyPermissionsQuietly() async {
    if (_isPublicMeetRoute() || _isAuthRoute()) {
      if (kIsWeb) WebLiveTrackingService.stop();
      return;
    }

    final result = await LocationAccessGate.ensureReadyForLogin(
      requireGpsFix: false,
    );
    if (!mounted) return;

    if (!result.allowed) {
      if (kIsWeb) WebLiveTrackingService.stop();
      if (_hasPermissions || _errorMsg.isEmpty) {
        setState(() {
          _hasPermissions = false;
          _errorMsg = result.message;
        });
      }
      return;
    }

    if (!kIsWeb) {
      final battery = await Permission.ignoreBatteryOptimizations.status;
      if (!battery.isGranted) {
        setState(() {
          _hasPermissions = false;
          _errorMsg =
              'Disable battery optimization — live tracking is MANDATORY and must keep running.';
        });
        return;
      }
    }

    if (!_hasPermissions) {
      setState(() {
        _hasPermissions = true;
        _errorMsg = '';
      });
    }

    final now = DateTime.now();
    if (_lastServiceEnsureAt == null ||
        now.difference(_lastServiceEnsureAt!) > const Duration(seconds: 20)) {
      _lastServiceEnsureAt = now;
      await _startTracking();
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _checking = true;
      _loaderStatus = 'Requesting location — this is MANDATORY…';
    });

    if (kIsWeb) {
      final result = await LocationAccessGate.ensureReadyForApp();
      if (!mounted) return;
      if (result.allowed) {
        await _startTracking();
        if (!mounted) return;
        setState(() {
          _hasPermissions = true;
          _checking = false;
          _errorMsg = '';
        });
      } else {
        setState(() {
          _checking = false;
          _hasPermissions = false;
          _errorMsg = result.message;
        });
        WebLiveTrackingService.stop();
      }
      return;
    }

    final result = await LocationAccessGate.ensureReadyForApp();
    if (!mounted) return;
    if (!result.allowed) {
      setState(() {
        _checking = false;
        _hasPermissions = false;
        _errorMsg = result.message;
      });
      return;
    }

    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
      try {
        await DisableBatteryOptimization.showDisableBatteryOptimizationSettings();
      } catch (_) {}
    }

    final battery = await Permission.ignoreBatteryOptimizations.status;
    if (!battery.isGranted) {
      setState(() {
        _checking = false;
        _hasPermissions = false;
        _errorMsg =
            'Disable battery optimization — live tracking is MANDATORY and must keep running.';
      });
      return;
    }

    try {
      await Future.delayed(const Duration(milliseconds: 400));
      await _startTracking();
    } catch (e) {
      AppLogger.tracking.e('Failed to start background tracking: $e');
    }

    if (!mounted) return;
    setState(() {
      _hasPermissions = true;
      _checking = false;
      _errorMsg = '';
    });
    unawaited(_maybeOpenTrackingSetup());
  }

  @override
  Widget build(BuildContext context) {
    if (_isPublicMeetRoute() || _isAuthRoute() || _currentPath().isEmpty) {
      return widget.child;
    }
    if (_checking) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: NbBrandLoader(
          statusLines: [
            _loaderStatus,
            'Location is MANDATORY',
          ],
        ),
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
              color: Colors.black.withValues(alpha: 0.6),
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
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.1),
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
                                color: Colors.amber.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withValues(alpha: 0.3),
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
                              "LOCATION IS MANDATORY",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.6,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMsg.isNotEmpty
                                  ? _errorMsg
                                  : kIsWeb
                                      ? 'Allow location in your browser. Without it you cannot use this website.'
                                      : 'Turn on GPS, allow location All the time, and disable battery optimization. Live tracking cannot be skipped.',
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
                                  ? 'Required: Browser location (Allow).'
                                  : 'Required: GPS ON · Always location · Notifications · Battery unrestricted',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: Colors.amber.shade200.withValues(alpha: 0.85),
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
                                    color: Colors.amber.withValues(alpha: 0.5),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _requestPermissions,
                                icon: const Icon(Icons.my_location_rounded, size: 20, color: Colors.black87),
                                label: const Text(
                                  "ENABLE LOCATION",
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
                                      side: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
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
