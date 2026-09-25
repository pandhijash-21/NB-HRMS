import 'package:flutter/material.dart';
import 'package:nb_crm_flutter/core/theme/nb_icon.dart';

import 'app_route_history.dart';

/// Standard AppBar back control.
///
/// Returns to the previous screen in the trail. [fallbackLocation] is used
/// only when this page was opened directly (no earlier screen).
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
      onPressed: () => tryAppGoBack(context, fallback: fallbackLocation),
    );
  }
}
