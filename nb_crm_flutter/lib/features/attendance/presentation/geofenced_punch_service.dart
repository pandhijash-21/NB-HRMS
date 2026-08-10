import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math';

import '../../../core/network/dio_client.dart';

class GeofencedPunchService {
  final DioClient dio;
  final LocalAuthentication auth = LocalAuthentication();
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  GeofencedPunchService(this.dio);

  String _getBiometricTokenKey(int employeeId) {
    return 'biometric_token_employee_$employeeId';
  }

  Future<bool> hasLocalToken(int employeeId) async {
    final token = await secureStorage.read(key: _getBiometricTokenKey(employeeId));
    return token != null && token.isNotEmpty;
  }

  Future<void> clearLocalToken(int employeeId) async {
    await secureStorage.delete(key: _getBiometricTokenKey(employeeId));
  }

  Future<void> registerBiometrics(BuildContext context, int employeeId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (kIsWeb) {
        throw Exception('Please use the mobile app to register biometrics.');
      }

      if (!(await auth.isDeviceSupported())) {
        throw Exception('Device authentication is not supported on this device.');
      }

      // Authenticate using biometrics (allow PIN fallback to ensure success)
      bool verified = await auth.authenticate(
        localizedReason: 'Please authenticate to set/register your Fingerprint, Face ID, or PIN for this account',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      if (!verified) {
        throw Exception('Authentication failed or canceled.');
      }

      // Generate a cryptographically secure random token (128-bit hex)
      final random = Random.secure();
      final values = List<int>.generate(16, (i) => random.nextInt(256));
      final token = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      // Save locally
      await secureStorage.write(key: _getBiometricTokenKey(employeeId), value: token);

      // Save on server
      await dio.postEnvelope(
        'attendance/my/register-biometrics',
        data: {
          'biometricToken': token,
        },
        parse: (r) => r,
      );

      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Fingerprint set and registered successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      _showErrorDialog(context, 'Registration Failed', e.toString().replaceAll('Exception: ', ''));
      rethrow;
    }
  }

  Future<void> executePunch(BuildContext context, int employeeId) async {
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      if (kIsWeb) {
        throw Exception('Please use the mobile app to punch in using biometrics.');
      }

      // 1. Retrieve local biometric token
      final token = await secureStorage.read(key: _getBiometricTokenKey(employeeId));
      if (token == null || token.isEmpty) {
        throw Exception('Fingerprint is not set. Please set/register your fingerprint first.');
      }

      if (!(await auth.isDeviceSupported())) {
        throw Exception('Device authentication is not supported on this device.');
      }

      // 3. Fetch Location First
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable them in your device settings.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied, we cannot request permissions.');
      }

      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Verifying location...'), duration: Duration(seconds: 2)),
        );
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 4. Verify Location with Backend
      await dio.postEnvelope(
        'attendance/my/verify-location',
        data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        parse: (r) => r,
      );

      // 4. Authenticate using Biometrics or PIN
      bool biometricVerified = await auth.authenticate(
        localizedReason: 'Please authenticate with Fingerprint, Face ID, or PIN to mark your attendance',
        biometricOnly: false, // PIN allowed
        persistAcrossBackgrounding: true,
      );

      if (!biometricVerified) {
        throw Exception('Authentication failed or canceled.');
      }

      // Capture basic device info for logging
      Map<String, dynamic>? deviceInfoMap;
      final deviceInfoPlugin = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceInfoMap = { 'model': androidInfo.model, 'brand': androidInfo.brand };
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceInfoMap = { 'name': iosInfo.name, 'systemName': iosInfo.systemName, 'model': iosInfo.model };
      }

      // 6. Send Punch Request
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Recording punch...'), duration: Duration(seconds: 2)),
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
            const SnackBar(content: Text('Punch registered successfully!'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (e.toString().contains('REASON_REQUIRED')) {
          if (!context.mounted) return;
          final reason = await _promptForReason(context);
          if (reason != null && reason.trim().isNotEmpty) {
            if (context.mounted) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Submitting punch with reason...'), duration: Duration(seconds: 2)),
              );
            }
            await sendPunchRequest(reason);
            if (context.mounted) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Punch with reason registered successfully!'), backgroundColor: Colors.green),
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
      _showErrorDialog(context, 'Punch Failed', e.toString().replaceAll('Exception: ', ''));
    }
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
          style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF212F3D)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have already reached the limit of 2 device punches today. Please provide a valid reason to punch again.',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
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
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.white),
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
