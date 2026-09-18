import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';

/// Software tour needs a persistent left sidebar and room for the spotlight.
class TourDesktop {
  TourDesktop._();

  static bool supported(BuildContext context) =>
      kIsWeb && AppBreakpoints.isWide(context);

  static Future<bool> ensureCanStart(BuildContext context) async {
    if (supported(context)) return true;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        const gold = Color(0xFFC5A36A);
        return AlertDialog(
          title: const Text('Use desktop web for the tour'),
          content: const Text(
            'The Software Tour highlights real buttons, tabs and cards. '
            'Open NB CRM in a desktop browser to take it. '
            'The mobile app does not run this walkthrough.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK', style: TextStyle(color: gold)),
            ),
          ],
        );
      },
    );
    return false;
  }
}
