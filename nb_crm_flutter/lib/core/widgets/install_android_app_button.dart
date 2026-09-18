import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/nb_icon.dart';
import '../utils/open_url.dart';

/// Web-only control that downloads the Android APK (not a PWA install).
class InstallAndroidAppButton extends StatelessWidget {
  const InstallAndroidAppButton._({
    required _InstallVariant variant,
    this.expanded = true,
  }) : _variant = variant;

  factory InstallAndroidAppButton.login() =>
      const InstallAndroidAppButton._(variant: _InstallVariant.login);

  factory InstallAndroidAppButton.sidebar({required bool expanded}) =>
      InstallAndroidAppButton._(
        variant: _InstallVariant.sidebar,
        expanded: expanded,
      );

  factory InstallAndroidAppButton.drawer() =>
      const InstallAndroidAppButton._(variant: _InstallVariant.drawer);

  final _InstallVariant _variant;
  final bool expanded;

  static bool get visible => kIsWeb;

  static String get apkUrl {
    final origin = Uri.base.origin;
    if (origin.isEmpty || origin == 'null') {
      return '/downloads/nb-crm.apk';
    }
    return '$origin/downloads/nb-crm.apk';
  }

  static Future<void> download(BuildContext context) async {
    final ok = await downloadUrl(apkUrl, 'nb-crm.apk');
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start the Android app download. Try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    switch (_variant) {
      case _InstallVariant.login:
        return TextButton.icon(
          onPressed: () => download(context),
          icon: const Icon(Icons.android_rounded, size: 18, color: Color(0xFFC5A059)),
          label: const Text(
            'Install Android app (.apk)',
            style: TextStyle(
              color: Color(0xFFC5A059),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case _InstallVariant.drawer:
        // Drawer chrome matches always-dark sidebar.
        return InkWell(
          onTap: () => download(context),
          borderRadius: BorderRadius.circular(12),
          child: const SizedBox(
            height: 44,
            child: Row(
              children: [
                SizedBox(width: 12),
                NbIcon(
                  Icons.android_rounded,
                  color: Color(0xFFD6BC85),
                  size: 22,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Install Android app',
                    style: TextStyle(
                      color: Color(0xFFE8E4DC),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      case _InstallVariant.sidebar:
        // Sidebar chrome is always dark — don't follow app light/dark theme.
        const iconColor = Color(0xFFD6BC85);
        const textColor = Color(0xFFE8E4DC);
        return Tooltip(
          message: 'Install Android app (.apk)',
          child: InkWell(
            onTap: () => download(context),
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 44,
              child: expanded
                  ? Row(
                      children: [
                        const SizedBox(width: 12),
                        const NbIcon(Icons.android_rounded, color: iconColor, size: 22),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Install Android app',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Center(
                      child: NbIcon(Icons.android_rounded, color: iconColor, size: 22),
                    ),
            ),
          ),
        );
    }
  }
}

enum _InstallVariant { login, sidebar, drawer }
