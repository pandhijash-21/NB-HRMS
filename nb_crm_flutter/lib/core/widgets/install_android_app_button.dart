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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return InkWell(
          onTap: () => download(context),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                const SizedBox(width: 12),
                NbIcon(
                  Icons.android_rounded,
                  color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF263238),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Install Android app',
                    style: TextStyle(
                      color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF263238),
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final iconColor =
            isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF263238);
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
                        NbIcon(Icons.android_rounded, color: iconColor, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Install Android app',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : const Color(0xFF263238),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: NbIcon(Icons.android_rounded, color: iconColor, size: 22),
                    ),
            ),
          ),
        );
    }
  }
}

enum _InstallVariant { login, sidebar, drawer }
