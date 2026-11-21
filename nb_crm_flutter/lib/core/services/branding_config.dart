import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/platform/domain/maintenance_policy.dart';
import '../network/dio_client.dart';

/// Public branding assets (splash video URL from Cloudinary / DB) and maintenance policy.
class BrandingConfig {
  BrandingConfig._();

  static String? splashVideoUrl;
  static String minVersion = '';
  static String maxVersion = '';
  static String updateUrlWeb = '';
  static String updateUrlAndroid = '';
  static String updateUrlIos = '';

  // Maintenance configuration
  static bool isGlobalMaintenance = false;
  static String globalMaintenanceTitle = '';
  static String globalMaintenanceMessage = '';
  static String? maintenanceEstimatedEndTime;
  static Map<String, ModuleConfig> modulesMaintenance = {
    'CRM': const ModuleConfig(),
    'HRMS': const ModuleConfig(),
    'ERP': const ModuleConfig(),
    'COLLAB': const ModuleConfig(),
  };

  /// Notifier triggered whenever maintenance status updates.
  static final ValueNotifier<int> maintenanceNotifier = ValueNotifier<int>(0);

  static const _prefsKey = 'nb_crm_splash_video_url';
  static const _minKey = 'nb_crm_min_version';
  static const _maxKey = 'nb_crm_max_version';
  static const _webKey = 'nb_crm_update_url_web';
  static const _androidKey = 'nb_crm_update_url_android';
  static const _iosKey = 'nb_crm_update_url_ios';
  static const _maintenanceKey = 'nb_crm_maintenance_policy';

  static Future<void> hydrateFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_prefsKey);
    if (cached != null && cached.trim().isNotEmpty) {
      splashVideoUrl = cached.trim();
    }
    minVersion = prefs.getString(_minKey)?.trim() ?? '';
    maxVersion = prefs.getString(_maxKey)?.trim() ?? '';
    updateUrlWeb = prefs.getString(_webKey)?.trim() ?? '';
    updateUrlAndroid = prefs.getString(_androidKey)?.trim() ?? '';
    updateUrlIos = prefs.getString(_iosKey)?.trim() ?? '';

    final mRaw = prefs.getString(_maintenanceKey);
    if (mRaw != null && mRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(mRaw);
        if (decoded is Map<String, dynamic>) {
          _applyMaintenanceMap(decoded);
        }
      } catch (_) {}
    }
  }

  static void _applyMaintenanceMap(Map<String, dynamic> m) {
    maintenanceEstimatedEndTime = m['estimatedEndTime']?.toString();
    if (m['global'] is Map) {
      final g = Map<String, dynamic>.from(m['global'] as Map);
      isGlobalMaintenance = g['enabled'] == true;
      globalMaintenanceTitle = g['title']?.toString() ?? '';
      globalMaintenanceMessage = g['message']?.toString() ?? '';
    } else {
      isGlobalMaintenance = false;
      globalMaintenanceTitle = '';
      globalMaintenanceMessage = '';
    }

    if (m['modules'] is Map) {
      final mods = Map<String, dynamic>.from(m['modules'] as Map);
      final Map<String, ModuleConfig> updatedMods = {};
      for (final key in ['CRM', 'HRMS', 'ERP', 'COLLAB']) {
        updatedMods[key] = ModuleConfig.fromJson(
          mods[key] is Map ? Map<String, dynamic>.from(mods[key] as Map) : null,
        );
      }
      modulesMaintenance = updatedMods;
    }

    maintenanceNotifier.value++;
  }

  static Future<void> fetch(DioClient dio) async {
    try {
      final data = await dio.getEnvelope<Map<String, dynamic>>(
        'auth/branding',
        parse: (raw) {
          if (raw is Map) return Map<String, dynamic>.from(raw);
          return <String, dynamic>{};
        },
      );
      final url = data['splashVideoUrl']?.toString().trim();
      minVersion = data['minVersion']?.toString().trim() ?? '';
      maxVersion = data['maxVersion']?.toString().trim() ?? '';
      updateUrlWeb = data['updateUrlWeb']?.toString().trim() ?? '';
      updateUrlAndroid = data['updateUrlAndroid']?.toString().trim() ?? '';
      updateUrlIos = data['updateUrlIos']?.toString().trim() ?? '';

      final prefs = await SharedPreferences.getInstance();
      if (url != null && url.isNotEmpty) {
        splashVideoUrl = url;
        await prefs.setString(_prefsKey, url);
      }
      await prefs.setString(_minKey, minVersion);
      await prefs.setString(_maxKey, maxVersion);
      await prefs.setString(_webKey, updateUrlWeb);
      await prefs.setString(_androidKey, updateUrlAndroid);
      await prefs.setString(_iosKey, updateUrlIos);

      if (data['maintenance'] is Map) {
        final m = Map<String, dynamic>.from(data['maintenance'] as Map);
        _applyMaintenanceMap(m);
        await prefs.setString(_maintenanceKey, jsonEncode(m));
      }
    } catch (_) {
      // Keep cached / asset fallback.
    }
  }

  /// Whether a specific module is under maintenance.
  static bool isModuleInMaintenance(String moduleKey) {
    final mod = modulesMaintenance[moduleKey.toUpperCase()];
    return mod?.enabled == true;
  }

  /// Configuration for a specific module under maintenance.
  static ModuleConfig? getModuleMaintenance(String moduleKey) {
    return modulesMaintenance[moduleKey.toUpperCase()];
  }

  /// Link for the app that is running: web, Android, or iOS.
  static String updateLinkForThisDevice() {
    if (kIsWeb) return updateUrlWeb.trim();
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return updateUrlIos.trim();
      case TargetPlatform.android:
        return updateUrlAndroid.trim();
      default:
        return updateUrlWeb.trim();
    }
  }

  /// Light splash still (GIF was ~4.4MB and slowed every cold start).
  static String resolveSplashSource() {
    return 'assets/images/mrnb_splash.webp';
  }

  static bool get hasRemoteSplash => false;
}
