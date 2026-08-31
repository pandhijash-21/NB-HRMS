import 'package:flutter/material.dart';
import 'package:nb_crm_flutter/core/theme/nb_icon.dart';
import 'package:go_router/go_router.dart';

import '../logging/app_logger.dart';

/// Standard AppBar back control using go_router everywhere.
///
/// Pops when possible; otherwise [fallbackLocation] (default `/home`).
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    this.fallbackLocation = '/home',
    this.icon = Icons.arrow_back_rounded,
  });

  final String fallbackLocation;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: NbIcon(icon),
      tooltip: 'Back',
      onPressed: () {
        if (context.canPop()) {
          AppLogger.router.d('back pop @ ${GoRouterState.of(context).uri}');
          context.pop();
        } else {
          AppLogger.router.d('back go → $fallbackLocation');
          context.go(fallbackLocation);
        }
      },
    );
  }
}
