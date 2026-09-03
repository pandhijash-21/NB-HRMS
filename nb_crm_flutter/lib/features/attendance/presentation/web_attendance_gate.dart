import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Web attendance is allowed only on genuine Safari running on an iPhone/iPad.
/// Desktop Safari, Android browsers, and Chrome/Firefox/Edge on iOS are blocked.
/// Native mobile apps never use this gate (`kIsWeb` is false).
class WebAttendanceGate {
  WebAttendanceGate._();

  static Future<WebAttendanceStatus>? _cached;

  static Future<WebAttendanceStatus> evaluate() {
    _cached ??= _evaluate();
    return _cached!;
  }

  /// Force re-check (e.g. after Refresh Status).
  static Future<WebAttendanceStatus> reevaluate() {
    _cached = _evaluate();
    return _cached!;
  }

  static Future<WebAttendanceStatus> _evaluate() async {
    if (!kIsWeb) {
      return const WebAttendanceStatus(
        allowed: true,
        isWeb: false,
        isIos: false,
        isSafari: false,
        deviceLabel: 'Native app',
        browserLabel: 'App',
      );
    }

    try {
      final web = await DeviceInfoPlugin().webBrowserInfo;
      final ua = web.userAgent ?? '';
      final uaLower = ua.toLowerCase();
      final isIos = uaLower.contains('iphone') ||
          uaLower.contains('ipad') ||
          uaLower.contains('ipod');
      final isOtherIosBrowser = uaLower.contains('crios') ||
          uaLower.contains('fxios') ||
          uaLower.contains('edgios') ||
          uaLower.contains('opios') ||
          uaLower.contains('yabrowser') ||
          uaLower.contains('duckduckgo');
      // Chrome desktop also embeds "Safari/" — require Version/ and no Chrome/.
      final hasChrome = uaLower.contains('chrome/');
      final isSafari = !isOtherIosBrowser &&
          !hasChrome &&
          uaLower.contains('safari/') &&
          uaLower.contains('version/') &&
          (web.browserName == BrowserName.safari || isIos);

      final deviceLabel = _deviceLabel(uaLower);
      final browserLabel = _browserLabel(
        uaLower: uaLower,
        isIos: isIos,
        isSafari: isSafari && isIos,
        isOtherIosBrowser: isOtherIosBrowser,
      );

      if (isIos && isSafari) {
        return WebAttendanceStatus(
          allowed: true,
          isWeb: true,
          isIos: true,
          isSafari: true,
          deviceLabel: deviceLabel,
          browserLabel: 'Safari (iOS)',
          userAgent: ua,
        );
      }

      String message;
      if (isIos && !isSafari) {
        message =
            'On iPhone/iPad, browser attendance works only in Safari. '
            'Chrome and other browsers are blocked. Open this site in Safari, or use the mobile app.';
      } else if (!isIos && uaLower.contains('safari/')) {
        message =
            'Safari on non-iOS devices cannot be used for attendance. '
            'Use the mobile app, or Safari on an iPhone/iPad.';
      } else {
        message =
            'Web attendance is disabled on this browser. '
            'Use the mobile app, or Safari on an iPhone/iPad only.';
      }

      return WebAttendanceStatus(
        allowed: false,
        isWeb: true,
        isIos: isIos,
        isSafari: false,
        deviceLabel: deviceLabel,
        browserLabel: browserLabel,
        userAgent: ua,
        message: message,
      );
    } catch (_) {
      return const WebAttendanceStatus(
        allowed: false,
        isWeb: true,
        isIos: false,
        isSafari: false,
        deviceLabel: 'Unknown',
        browserLabel: 'Unknown',
        message:
            'Unable to verify this browser. Web attendance is only allowed in Safari on iPhone/iPad.',
      );
    }
  }

  static String _deviceLabel(String uaLower) {
    if (uaLower.contains('iphone')) return 'iPhone';
    if (uaLower.contains('ipad')) return 'iPad';
    if (uaLower.contains('ipod')) return 'iPod';
    if (uaLower.contains('android')) return 'Android device';
    if (uaLower.contains('windows')) return 'Windows PC';
    if (uaLower.contains('mac os') || uaLower.contains('macintosh')) return 'Mac';
    if (uaLower.contains('linux')) return 'Linux PC';
    return 'Unknown device';
  }

  static String _browserLabel({
    required String uaLower,
    required bool isIos,
    required bool isSafari,
    required bool isOtherIosBrowser,
  }) {
    if (isSafari) return 'Safari (iOS)';
    if (uaLower.contains('crios')) return 'Chrome (iOS)';
    if (uaLower.contains('fxios')) return 'Firefox (iOS)';
    if (uaLower.contains('edgios')) return 'Edge (iOS)';
    if (isOtherIosBrowser) return 'Other browser (iOS)';
    if (uaLower.contains('edg/')) return 'Edge';
    if (uaLower.contains('chrome/')) return 'Chrome';
    if (uaLower.contains('firefox/')) return 'Firefox';
    if (uaLower.contains('safari/') && uaLower.contains('version/')) {
      return isIos ? 'Safari' : 'Safari (desktop)';
    }
    return 'Unknown browser';
  }
}

class WebAttendanceStatus {
  const WebAttendanceStatus({
    required this.allowed,
    required this.isWeb,
    required this.isIos,
    required this.isSafari,
    required this.deviceLabel,
    required this.browserLabel,
    this.userAgent,
    this.message,
  });

  final bool allowed;
  final bool isWeb;
  final bool isIos;
  final bool isSafari;
  final String deviceLabel;
  final String browserLabel;
  final String? userAgent;
  final String? message;
}
