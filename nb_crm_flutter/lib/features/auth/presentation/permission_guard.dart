import 'dart:ui';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/background_tracking_service.dart';

// RadarPainter removed, using map image

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

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_hasPermissions && !_checking) {
        _verifyPermissionsQuietly();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
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

    if (kIsWeb) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        setState(() {
          _hasPermissions = true;
          _checking = false;
        });
        return;
      } else {
        setState(() {
          _checking = false;
          _hasPermissions = false;
          _errorMsg = "This app requires location permissions to function.";
        });
        return;
      }
    }

    var locationStatus = await Permission.location.status;
    var locationAlwaysStatus = await Permission.locationAlways.status;

    if (locationStatus.isGranted && locationAlwaysStatus.isGranted) {
      if (!kIsWeb && await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      try {
        // Wait for app to be fully resumed before starting foreground service
        await Future.delayed(const Duration(milliseconds: 500));
        await startBackgroundTracking();
      } catch (e) {
        debugPrint("Failed to start background tracking: $e");
      }
      setState(() {
        _hasPermissions = true;
        _checking = false;
      });
    } else {
      setState(() {
        _checking = false;
        _hasPermissions = false;
        _errorMsg = "This app strictly requires Always-On location permissions to function.";
      });
    }
  }

  Future<void> _verifyPermissionsQuietly() async {
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

    if (kIsWeb) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
        if (mounted) {
          setState(() {
            _hasPermissions = false;
            _errorMsg = "This app requires location permissions to function.";
          });
        }
      }
      return;
    }

    var locationStatus = await Permission.location.status;
    var locationAlwaysStatus = await Permission.locationAlways.status;

    if (!(locationStatus.isGranted && locationAlwaysStatus.isGranted)) {
      if (mounted) {
        setState(() {
          _hasPermissions = false;
          _errorMsg = "This app strictly requires Always-On location permissions to function.";
        });
      }
    }
  }

  Future<void> _requestPermissions() async {
    setState(() => _checking = true);

    if (kIsWeb) {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        setState(() {
          _hasPermissions = true;
          _checking = false;
        });
        return;
      }
    } else {
      // Request foreground first
      var locStatus = await Permission.location.request();
      if (locStatus.isGranted) {
        // Then request background
        var alwaysStatus = await Permission.locationAlways.request();
        if (alwaysStatus.isGranted) {
          if (await Permission.notification.isDenied) {
            await Permission.notification.request();
          }
          try {
            await Future.delayed(const Duration(milliseconds: 500));
            await startBackgroundTracking();
          } catch (e) {
            debugPrint("Failed to start background tracking: $e");
          }
          setState(() {
            _hasPermissions = true;
            _checking = false;
          });
          return;
        }
      }
    }

    setState(() {
      _checking = false;
      _hasPermissions = false;
      if (kIsWeb) {
        _errorMsg = "Location access was denied. Please click the padlock icon in your browser's URL bar, allow location, and refresh the page.";
      } else {
        _errorMsg = "You must allow location 'All the time' for live tracking. Please tap 'Open App Settings' and grant it.";
      }
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
                              _errorMsg,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: Colors.amber.shade50,
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
                            const SizedBox(height: 16),
                            if (!kIsWeb)
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
                              )
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
