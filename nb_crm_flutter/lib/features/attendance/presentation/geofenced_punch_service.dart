import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';

class GeofencedPunchService {
  GeofencedPunchService(this.dio, {SecureStorageService? storage})
      : storage = storage ?? SecureStorageService();

  final DioClient dio;
  final SecureStorageService storage;
  final LocalAuthentication auth = LocalAuthentication();

  Future<bool> hasLocalToken(int employeeId) async {
    final token = await storage.readBiometricToken(employeeId);
    return token != null && token.isNotEmpty;
  }

  Future<void> clearLocalToken(int employeeId) async {
    await storage.clearBiometricToken(employeeId);
  }

  Future<void> registerBiometrics(BuildContext context, int employeeId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final verified = await _confirmIdentity(
        context,
        title: kIsWeb ? 'Confirm device registration' : 'Authenticate',
        message: kIsWeb
            ? 'Register this browser for attendance punches. Continue only on a trusted device.'
            : 'Please authenticate to set/register your Fingerprint, Face ID, or PIN for this account',
      );
      if (!verified) {
        throw Exception('Authentication failed or canceled.');
      }

      final random = Random.secure();
      final values = List<int>.generate(16, (i) => random.nextInt(256));
      final token = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      await storage.writeBiometricToken(employeeId, token);

      await dio.postEnvelope(
        'attendance/my/register-biometrics',
        data: {'biometricToken': token},
        parse: (r) => r,
      );

      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb
                  ? 'Browser registered for attendance successfully!'
                  : 'Fingerprint set and registered successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showErrorDialog(
        context,
        'Registration Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }

  Future<void> executePunch(BuildContext context, int employeeId) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final token = await storage.readBiometricToken(employeeId);
      if (token == null || token.isEmpty) {
        throw Exception(
          kIsWeb
              ? 'This browser is not registered. Tap “Set Fingerprint / Register device” first.'
              : 'Fingerprint is not set. Please set/register your fingerprint first.',
        );
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception(
          'Location services are disabled. Please enable them in your device settings.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.',
        );
      }

      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Verifying location...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await dio.postEnvelope(
        'attendance/my/verify-location',
        data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        parse: (r) => r,
      );

      final biometricVerified = await _confirmIdentity(
        context,
        title: kIsWeb ? 'Confirm punch' : 'Authenticate',
        message: kIsWeb
            ? 'Confirm this attendance punch from your current browser location.'
            : 'Please authenticate with Fingerprint, Face ID, or PIN to mark your attendance',
      );

      if (!biometricVerified) {
        throw Exception('Authentication failed or canceled.');
      }

      final deviceInfoMap = await _deviceInfo();

      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Recording punch...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      Future<void> sendPunchRequest([String? reason]) async {
        await dio.postEnvelope(
          'attendance/my/punch',
          data: {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'deviceInfo': deviceInfoMap,
            'biometricVerified': biometricVerified,
            'biometricToken': token,
            if (reason != null && reason.isNotEmpty) 'reason': reason,
          },
          parse: (r) => r,
        );
      }

      try {
        await sendPunchRequest();
        if (context.mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Punch registered successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (e.toString().contains('REASON_REQUIRED')) {
          if (!context.mounted) return;
          final reason = await _promptForReason(context);
          if (reason != null && reason.trim().isNotEmpty) {
            if (context.mounted) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Submitting punch with reason...'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
            await sendPunchRequest(reason);
            if (context.mounted) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Punch with reason registered successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            throw Exception('Punch cancelled. Reason is required after 2 punches.');
          }
        } else {
          rethrow;
        }
      }
    } catch (e) {
      _showErrorDialog(
        context,
        'Punch Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<bool> _confirmIdentity(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    if (kIsWeb) {
      if (!context.mounted) return false;
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A059),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );
      return ok == true;
    }

    if (!(await auth.isDeviceSupported())) {
      throw Exception('Device authentication is not supported on this device.');
    }

    return auth.authenticate(
      localizedReason: message,
      biometricOnly: false,
      persistAcrossBackgrounding: true,
    );
  }

  Future<Map<String, dynamic>> _deviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    try {
      if (kIsWeb) {
        final web = await deviceInfoPlugin.webBrowserInfo;
        return {
          'platform': 'web',
          'browser': web.browserName.name,
          'userAgent': web.userAgent,
          'vendor': web.vendor,
        };
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        return {
          'platform': 'android',
          'model': androidInfo.model,
          'brand': androidInfo.brand,
        };
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        return {
          'platform': 'ios',
          'name': iosInfo.name,
          'systemName': iosInfo.systemName,
          'model': iosInfo.model,
        };
      }
    } catch (_) {}
    return {'platform': defaultTargetPlatform.name};
  }

  Future<String?> _promptForReason(BuildContext context) async {
    final ctrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reason Required',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have already reached the limit of 2 device punches today. Please provide a valid reason to punch again.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
                hintText: 'e.g. Returned for evening shift',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC5A059),
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    if (!context.mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50.withOpacity(isDark ? 0.1 : 1.0),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: isDark ? Colors.red.shade400 : Colors.red.shade600,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF212F3D),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF5A6A7D),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A059),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Dismiss',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
