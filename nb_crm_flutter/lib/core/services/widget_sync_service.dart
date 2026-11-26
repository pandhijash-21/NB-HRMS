import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

class WidgetSyncService {
  static const String androidWidgetName = 'AttendanceWidgetProvider';
  static const String qualifiedAndroidName = 'com.nbdeveloper.nb_crm_flutter.AttendanceWidgetProvider';
  static const String appGroupId = 'group.com.nbsince1946.hrms';

  static bool _initialized = false;

  /// Initializes widget group and registers click listener
  static Future<void> init({Function(Uri? uri)? onWidgetClick}) async {
    if (kIsWeb) return;
    if (_initialized) return;
    _initialized = true;

    try {
      await HomeWidget.setAppGroupId(appGroupId);
      
      // Check if launched directly from widget click
      final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (initialUri != null) {
        onWidgetClick?.call(initialUri);
      }

      // Listen for runtime clicks
      HomeWidget.widgetClicked.listen((Uri? uri) {
        if (uri != null) {
          onWidgetClick?.call(uri);
        }
      });
    } catch (e) {
      debugPrint('[WidgetSyncService] Init error: $e');
    }
  }

  /// Syncs current employee & attendance state into the Android Home Screen Widget
  static Future<void> syncAttendance({
    required String employeeName,
    String? employeeCode,
    String? punchInIso,
    String? punchOutIso,
  }) async {
    if (kIsWeb) return;

    try {
      final punchedIn = punchInIso != null && punchInIso.isNotEmpty;
      final punchedOut = punchOutIso != null &&
          punchOutIso.isNotEmpty &&
          punchOutIso != punchInIso;

      int cooldownRemainingMin = 0;
      if (punchedIn && !punchedOut) {
        final inTime = DateTime.tryParse(punchInIso);
        if (inTime != null) {
          final elapsed = DateTime.now().difference(inTime.toLocal());
          const minGapSec = 20 * 60; // 20 minutes cooldown
          final remSec = minGapSec - elapsed.inSeconds;
          if (remSec > 0) {
            cooldownRemainingMin = (remSec / 60).ceil();
          }
        }
      }

      final dateStr = DateFormat('EEE, d MMM').format(DateTime.now());

      String formatTime(String? iso) {
        if (iso == null || iso.isEmpty) return '—';
        try {
          final dt = DateTime.parse(iso).toLocal();
          return DateFormat('hh:mm a').format(dt);
        } catch (_) {
          return '—';
        }
      }

      await HomeWidget.saveWidgetData<String>('employee_name', employeeName);
      await HomeWidget.saveWidgetData<String>('employee_code', employeeCode ?? '');
      await HomeWidget.saveWidgetData<String>('date_str', dateStr);
      await HomeWidget.saveWidgetData<String>('punch_in', punchedIn ? formatTime(punchInIso) : '—');
      await HomeWidget.saveWidgetData<String>('punch_out', punchedOut ? formatTime(punchOutIso) : '—');
      await HomeWidget.saveWidgetData<bool>('is_punched_in', punchedIn);
      await HomeWidget.saveWidgetData<bool>('is_punched_out', punchedOut);
      await HomeWidget.saveWidgetData<int>('cooldown_remaining_min', cooldownRemainingMin);

      await HomeWidget.updateWidget(
        androidName: androidWidgetName,
        qualifiedAndroidName: qualifiedAndroidName,
      );
    } catch (e) {
      debugPrint('[WidgetSyncService] Sync error: $e');
    }
  }

  /// Clears widget state on user sign out
  static Future<void> clearWidget() async {
    if (kIsWeb) return;

    try {
      await HomeWidget.saveWidgetData<String>('employee_name', 'Not Logged In');
      await HomeWidget.saveWidgetData<String>('employee_code', '');
      await HomeWidget.saveWidgetData<String>('date_str', 'Today');
      await HomeWidget.saveWidgetData<String>('punch_in', '—');
      await HomeWidget.saveWidgetData<String>('punch_out', '—');
      await HomeWidget.saveWidgetData<bool>('is_punched_in', false);
      await HomeWidget.saveWidgetData<bool>('is_punched_out', false);
      await HomeWidget.saveWidgetData<int>('cooldown_remaining_min', 0);

      await HomeWidget.updateWidget(
        androidName: androidWidgetName,
        qualifiedAndroidName: qualifiedAndroidName,
      );
    } catch (e) {
      debugPrint('[WidgetSyncService] Clear error: $e');
    }
  }
}
