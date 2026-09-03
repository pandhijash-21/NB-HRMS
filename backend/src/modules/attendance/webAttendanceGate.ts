/**
 * Web attendance is allowed only on genuine iOS Safari.
 * Native Android/iOS app clients are unchanged.
 */

export type WebAttendanceClientKind = 'native_app' | 'ios_safari' | 'blocked_web';

export type WebAttendanceGateResult = {
  kind: WebAttendanceClientKind;
  allowed: boolean;
  message?: string;
  deviceLabel: string;
  browserLabel: string;
  userAgent: string;
  isIos: boolean;
  isSafari: boolean;
};

function isBrowserUserAgent(ua: string): boolean {
  return /Mozilla\/\d/i.test(ua) && /(Chrome|CriOS|Safari|Firefox|FxiOS|Edg|EdgiOS)\//i.test(ua);
}

/** True Safari on iOS — excludes Chrome/Firefox/Edge/Opera iOS wrappers. */
export function isIosSafariUserAgent(ua: string): boolean {
  if (!ua) return false;
  const isIos = /iPhone|iPad|iPod/i.test(ua);
  if (!isIos) return false;
  // Other browsers on iOS still include "Safari" in UA — exclude them first.
  if (/CriOS|FxiOS|EdgiOS|OPiOS|YaBrowser|DuckDuckGo/i.test(ua)) return false;
  // Desktop Chrome-style tokens shouldn't appear on genuine mobile Safari.
  if (/Chrome\//i.test(ua)) return false;
  return /Safari\//i.test(ua) && /Version\//i.test(ua);
}

export function browserLabelFromUa(ua: string): string {
  if (/CriOS/i.test(ua)) return 'Chrome (iOS)';
  if (/FxiOS/i.test(ua)) return 'Firefox (iOS)';
  if (/EdgiOS/i.test(ua)) return 'Edge (iOS)';
  if (/OPiOS/i.test(ua)) return 'Opera (iOS)';
  if (isIosSafariUserAgent(ua)) return 'Safari (iOS)';
  if (/Edg\//i.test(ua)) return 'Edge';
  if (/Chrome\//i.test(ua) && /Safari\//i.test(ua)) return 'Chrome';
  if (/Firefox\//i.test(ua)) return 'Firefox';
  if (/Safari\//i.test(ua) && /Version\//i.test(ua)) return 'Safari';
  return 'Unknown browser';
}

export function deviceLabelFromUa(ua: string): string {
  if (/iPhone/i.test(ua)) return 'iPhone';
  if (/iPad/i.test(ua)) return 'iPad';
  if (/iPod/i.test(ua)) return 'iPod';
  if (/Android/i.test(ua)) return 'Android device';
  if (/Windows/i.test(ua)) return 'Windows PC';
  if (/Macintosh|Mac OS X/i.test(ua)) return 'Mac';
  if (/Linux/i.test(ua)) return 'Linux PC';
  return 'Unknown device';
}

/**
 * Decide whether this punch/register request may use the web attendance path.
 * Native app (android/ios platform + non-browser UA) always allowed.
 */
export function evaluateWebAttendanceGate(opts: {
  userAgent?: string | null;
  deviceInfo?: Record<string, unknown> | null;
}): WebAttendanceGateResult {
  const userAgent = String(opts.userAgent ?? '').trim();
  const platform = String(opts.deviceInfo?.platform ?? '').toLowerCase();
  const isIos = /iPhone|iPad|iPod/i.test(userAgent);
  const isSafari = isIosSafariUserAgent(userAgent);

  // Native Flutter app: platform android/ios and UA is not a browser.
  if ((platform === 'android' || platform === 'ios') && !isBrowserUserAgent(userAgent)) {
    const deviceLabel =
      String(opts.deviceInfo?.model ?? opts.deviceInfo?.name ?? platform) || platform;
    return {
      kind: 'native_app',
      allowed: true,
      deviceLabel,
      browserLabel: 'Native app',
      userAgent,
      isIos: platform === 'ios',
      isSafari: false,
    };
  }

  // Register/punch from native app without deviceInfo still sends a Dart/IO user-agent.
  if (!isBrowserUserAgent(userAgent)) {
    return {
      kind: 'native_app',
      allowed: true,
      deviceLabel: platform || 'Native app',
      browserLabel: 'Native app',
      userAgent,
      isIos: platform === 'ios',
      isSafari: false,
    };
  }

  // Treat as web (including spoofed platform with browser UA).
  const deviceLabel = deviceLabelFromUa(userAgent);
  const browserLabel = browserLabelFromUa(userAgent);

  if (isIosSafariUserAgent(userAgent)) {
    return {
      kind: 'ios_safari',
      allowed: true,
      deviceLabel,
      browserLabel: 'Safari (iOS)',
      userAgent,
      isIos: true,
      isSafari: true,
    };
  }

  let message =
    'Web attendance is only allowed on Safari on an iPhone or iPad. Use the mobile app on other devices.';
  if (isIos && !isSafari) {
    message =
      'On iPhone/iPad, attendance from the browser is only allowed in Safari. Chrome and other browsers are blocked — open this site in Safari, or use the mobile app.';
  } else if (!isIos && /Safari\//i.test(userAgent)) {
    message =
      'Safari on non-iOS devices cannot be used for attendance. Use the mobile app, or Safari on an iPhone/iPad.';
  }

  return {
    kind: 'blocked_web',
    allowed: false,
    message,
    deviceLabel,
    browserLabel,
    userAgent,
    isIos,
    isSafari: false,
  };
}
