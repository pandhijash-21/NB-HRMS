import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: NbCrmApp()));
}

class NbCrmApp extends ConsumerWidget {
  const NbCrmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Always use MaterialApp.router so the browser hash (#/login) is owned by
    // GoRouter. Switching to a plain MaterialApp during bootstrap made Flutter
    // web try "/login" as a named route that did not exist.
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'NB Developer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
