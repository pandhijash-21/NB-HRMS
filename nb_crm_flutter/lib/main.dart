import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/services/background_tracking_service.dart';
import 'core/theme/app_breakpoints.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/presentation/permission_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      title: 'NB Developer',
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
          child: PermissionGuard(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
