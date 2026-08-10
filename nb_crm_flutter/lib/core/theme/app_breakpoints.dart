import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

/// Shared breakpoints & layout helpers (UI only — no feature logic).
abstract final class AppBreakpoints {
  static const double phone = 600;
  static const double tablet = 900;
  static const double desktop = 1200;

  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < phone;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= phone && w < tablet;
  }

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;

  /// Comfortable page padding that grows with width.
  static EdgeInsets pagePadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= desktop) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    }
    if (w >= tablet) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
    }
    if (w >= phone) {
      return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 14);
  }

  /// Content max width for readable lists/forms on ultra-wide monitors.
  static double contentMaxWidth(
    BuildContext context, {
    double fallback = 1200,
  }) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= desktop) return fallback;
    return double.infinity;
  }

  static int gridColumns(
    BuildContext context, {
    int phone = 1,
    int tablet = 2,
    int wide = 3,
  }) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= AppBreakpoints.tablet) return wide;
    if (w >= AppBreakpoints.phone) return tablet;
    return phone;
  }
}

/// Smooth scrolling on desktop/web (mouse drag + trackpad).
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
