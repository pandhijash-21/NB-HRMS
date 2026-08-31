import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/services/background_tracking_service.dart';
import 'core/services/location_alert_sound.dart';
import 'core/theme/app_breakpoints.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/icon_font_bootstrap.dart';
import 'core/theme/material_icon_keep_alive.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/presentation/permission_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  retainMaterialIconGlyphs();
  await loadFullMaterialIconsFont();
  if (!kIsWeb) {
    await initializeBackgroundService();
  }
  runApp(const ProviderScope(child: NbCrmApp()));
}

class NbCrmApp extends ConsumerWidget {
  const NbCrmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'NB CRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      scrollBehavior: AppScrollBehavior(),
      routerConfig: router,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final capped = mq.textScaler.clamp(
          minScaleFactor: 0.90,
          maxScaleFactor: 1.20,
        );
        return MediaQuery(
          data: mq.copyWith(textScaler: capped),
          child: Stack(
            children: [
              const MaterialIconKeepAlive(),
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) {
                    LocationAlertSound.unlock();
                  },
                  child: PermissionGuard(child: child ?? const SizedBox.shrink()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
