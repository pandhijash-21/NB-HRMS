import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/dio_client.dart';

class GeofencedPunchService {
  final DioClient dio;
  final LocalAuthentication auth = LocalAuthentication();

  GeofencedPunchService(this.dio);

  Future<void> executePunch(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      if (kIsWeb) {
        throw Exception('Please use the mobile app to punch in using biometrics.');
      }

      // 1. Enforce Biometrics Availability
      bool canCheckBiometrics = false;
      try {
        canCheckBiometrics = await auth.canCheckBiometrics;
      } catch (e) {
        // Ignored
      }
      
      if (!canCheckBiometrics) {
        throw Exception('Biometrics not supported on this device.');
      }

      final availableBiometrics = await auth.getAvailableBiometrics();
      if (!availableBiometrics.contains(BiometricType.fingerprint) && 
          !availableBiometrics.contains(BiometricType.face) &&
          !availableBiometrics.contains(BiometricType.strong)) {
        throw Exception('Fingerprint or Face ID is not added. Please set up biometric security to punch in.');
      }

      // 2. Fetch Location First
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

      // 3. Verify Location with Backend
      await dio.postEnvelope(
        'attendance/my/verify-location',
        data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        parse: (r) => r,
      );

      // 4. Authenticate using Biometrics ONLY
      bool biometricVerified = await auth.authenticate(
        localizedReason: 'Please authenticate with Fingerprint or Face ID to mark your attendance',
        biometricOnly: true, // No PIN allowed
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

      // 5. Send Punch Request
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Recording punch...'), duration: Duration(seconds: 2)),
        );
      }

      await dio.postEnvelope(
        'attendance/my/punch',
        data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'deviceInfo': deviceInfoMap,
          'biometricVerified': biometricVerified,
        },
        parse: (r) => r,
      );

      // Success message
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Punch registered successfully!'), backgroundColor: Colors.green),
        );
      }

    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
