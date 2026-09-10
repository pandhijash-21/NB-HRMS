import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/bloc/app_bloc_observer.dart';
import 'core/bloc/app_module_cubit.dart';
import 'core/di/app_repositories.dart';
import 'core/network/api_url_cubit.dart';
import 'core/router/app_router.dart';
import 'core/services/app_sounds.dart';
import 'core/services/background_tracking_service.dart';
import 'core/services/location_alert_sound.dart';
import 'core/theme/app_breakpoints.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/icon_font_bootstrap.dart';
import 'core/theme/material_icon_keep_alive.dart';
import 'core/theme/theme_cubit.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/permission_guard.dart';
import 'features/collaboration/presentation/notification_bell.dart';
import 'features/lookups/presentation/bloc/lookups_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = const AppBlocObserver();

  // Allow Google Fonts runtime fetching on web / mobile
  GoogleFonts.config.allowRuntimeFetching = true;

  retainMaterialIconGlyphs();
  // Load the icon font after the first frame so the app shell renders immediately
  unawaited(loadFullMaterialIconsFont());
  if (!kIsWeb) {
    unawaited(initializeBackgroundService());
  }

  // DI: Core Repositories
  final appRepositories = AppRepositories();

  // DI: Global BLoCs & Cubits
  final themeCubit = ThemeCubit();
  final appModuleCubit = AppModuleCubit();
  final apiUrlCubit = ApiUrlCubit(dioClient: appRepositories.dioClient);
  final authBloc = AuthBloc(
    authRepository: appRepositories.authRepository,
    dioClient: appRepositories.dioClient,
    secureStorage: appRepositories.storage,
    unauthorizedGate: appRepositories.unauthorizedGate,
  );
  final lookupsBloc = LookupsBloc(lookupRepository: appRepositories.lookupRepository);

  final router = createAppRouter(authBloc);

  runApp(
    appRepositories.wrapWithProviders(
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ThemeCubit>.value(value: themeCubit),
          BlocProvider<AppModuleCubit>.value(value: appModuleCubit),
          BlocProvider<ApiUrlCubit>.value(value: apiUrlCubit),
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<LookupsBloc>.value(value: lookupsBloc),
        ],
        child: ProviderScope(
          child: NbCrmApp(router: router),
        ),
      ),
    ),
  );
}

class NbCrmApp extends StatelessWidget {
  const NbCrmApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      buildWhen: (previous, current) => previous != current,
      builder: (context, themeMode) {
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
                        AppSounds.unlock();
                      },
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: PermissionGuard(child: child ?? const SizedBox.shrink()),
                          ),
                          const IncomingCallHost(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
