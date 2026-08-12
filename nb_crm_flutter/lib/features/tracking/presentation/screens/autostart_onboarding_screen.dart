import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/logging/app_logger.dart';

class AutostartOnboardingScreen extends StatefulWidget {
  const AutostartOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<AutostartOnboardingScreen> createState() => _AutostartOnboardingScreenState();
}

class _AutostartOnboardingScreenState extends State<AutostartOnboardingScreen> {
  String _manufacturer = 'Unknown';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _detectManufacturer();
  }

  Future<void> _detectManufacturer() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      setState(() {
        _manufacturer = androidInfo.manufacturer.toLowerCase();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestBatteryExemption() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    final prefs = await SharedPreferences.getInstance();
    
    if (status.isGranted) {
      await prefs.setBool('batteryOptimizationExempt', true);
    } else {
      await prefs.setBool('batteryOptimizationExempt', false);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status.isGranted ? 'Battery Exemption Granted' : 'Battery Exemption Denied')),
      );
    }
  }

  Future<void> _openAppInfoSettings() async {
    try {
      final intent = AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        data: 'package:com.nbdeveloper.nb_crm_flutter',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
    } catch (e) {
      AppLogger.app.w('Failed to open app settings: $e');
    }
  }

  Future<void> _openAutostartSettings() async {
    try {
      AndroidIntent? intent;
      switch (_manufacturer) {
        case 'xiaomi':
        case 'redmi':
        case 'poco':
          intent = const AndroidIntent(
            action: 'miui.intent.action.OP_AUTO_START',
            category: 'android.intent.category.DEFAULT',
            componentName: 'com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity',
          );
          break;
        case 'oppo':
        case 'realme':
          intent = const AndroidIntent(
            action: 'android.intent.action.MAIN',
            category: 'android.intent.category.DEFAULT',
            componentName: 'com.coloros.safecenter/.startupapp.StartupAppListActivity',
          );
          break;
        case 'vivo':
          intent = const AndroidIntent(
            action: 'android.intent.action.MAIN',
            category: 'android.intent.category.DEFAULT',
            componentName: 'com.vivo.permissionmanager/.activity.BgStartUpManagerActivity',
          );
          break;
        case 'oneplus':
          intent = const AndroidIntent(
            action: 'android.intent.action.MAIN',
            category: 'android.intent.category.DEFAULT',
            componentName: 'com.oneplus.security/.chainlaunch.view.ChainLaunchAppListActivity',
          );
          break;
        case 'samsung':
          intent = const AndroidIntent(
            action: 'android.intent.action.MAIN',
            category: 'android.intent.category.DEFAULT',
            componentName: 'com.samsung.android.lool/com.samsung.android.sm.ui.battery.BatteryActivity',
          );
          break;
      }

      if (intent != null) {
        // Try OEM specific intent
        await intent.launch();
      } else {
        // Unmapped / Unknown manufacturer fallback
        await _openAppInfoSettings();
      }
    } catch (e) {
      // Intent failed (e.g. activity not found on this OS version)
      AppLogger.app.w('OEM Intent failed, falling back to app settings: $e');
      await _openAppInfoSettings();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenAutostartOnboarding', true);
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isKnownOEM = ['xiaomi', 'redmi', 'poco', 'oppo', 'realme', 'vivo', 'oneplus', 'samsung'].contains(_manufacturer);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Tracking Setup'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.battery_alert, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'Required Device Setup',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'To ensure accurate location tracking while the app is in the background, you must configure two settings.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Card(
              child: ListTile(
                leading: const Icon(Icons.battery_charging_full),
                title: const Text('1. Disable Battery Optimization'),
                subtitle: const Text('Allow the app to run without battery restrictions.'),
                trailing: ElevatedButton(
                  onPressed: _requestBatteryExemption,
                  child: const Text('Grant'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.settings_applications),
                title: const Text('2. Allow Background Autostart'),
                subtitle: isKnownOEM
                    ? Text('Your $_manufacturer device frequently kills background apps. Please allow autostart.')
                    : const Text('Please go to Settings > Apps > nb_crm_flutter > Battery, and allow unrestricted background activity.'),
                trailing: ElevatedButton(
                  onPressed: _openAutostartSettings,
                  child: const Text('Settings'),
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              onPressed: _completeOnboarding,
              child: const Text('I Have Completed Setup'),
            ),
          ],
        ),
      ),
    );
  }
}
