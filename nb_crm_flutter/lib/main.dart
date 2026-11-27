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
import 'core/network/app_config.dart';
import 'core/router/app_router.dart';
import 'core/services/app_sounds.dart';
import 'core/services/background_tracking_service.dart';
import 'core/services/branding_config.dart';
import 'core/services/location_alert_sound.dart';
import 'core/services/mr_nb_tour_service.dart';
import 'core/services/splash_video_cache.dart';
import 'core/services/widget_sync_service.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/theme/app_breakpoints.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/icon_font_bootstrap.dart';
import 'core/theme/material_icon_keep_alive.dart';
import 'core/theme/theme_cubit.dart';
import 'core/tracking/app_activity_tracker.dart';
import 'core/widgets/app_version_gate.dart';
import 'core/widgets/maintenance_gate.dart';
import 'core/widgets/splash_video_audio.dart';
import 'core/widgets/splash_video_host.dart';
import 'core/tour/catalog/nb_platform_catalog.dart';
import 'core/tour/engine/tour_engine.dart';
import 'core/tour/onboarding/first_visit_host.dart';
import 'core/tour/overlay/tour_overlay_host.dart';
import 'core/tour/validation/tour_validator.dart';
import 'core/tour/widgets/tour_debug_inspector.dart';
import 'features/auth/presentation/auth_riverpod_bridge.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/permission_guard.dart';
import 'features/collaboration/presentation/notification_bell.dart';
import 'features/lookups/presentation/bloc/lookups_bloc.dart';
import 'core/router/url_strategy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureAppUrlStrategy();
  Bloc.observer = const AppBlocObserver();

  // Parallel prefs hydrate — sequential SharedPreferences awaits delayed first frame.
  await Future.wait([
    AppConfig.hydrate(),
    BrandingConfig.hydrateFromCache(),
  ]);

  // Fonts may fetch once then cache; image weight was the real login bottleneck.
  GoogleFonts.config.allowRuntimeFetching = true;

  retainMaterialIconGlyphs();
  if (kDebugMode) {
    TourValidator.validate(NbPlatformCatalog.build());
  }
  // Load the icon font after the first frame so the app shell renders immediately
  unawaited(loadFullMaterialIconsFont());
  if (!kIsWeb) {
    unawaited(initializeBackgroundService());
    // One-time: copy Keystore JWT into prefs so FGS can post GPS after upgrade.
    unawaited(() async {
      try {
        final storage = SecureStorageService();
        final token = await storage.readToken();
        if (token != null && token.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', token);
        }
        await AppConfig.mirrorApiBaseUrlForBackground();
      } catch (_) {}
    }());
  }

  // DI: Core Repositories
  final appRepositories = AppRepositories();
  // Do not block first frame on branding API — cached URL (or asset) is enough to start splash.
  unawaited(BrandingConfig.fetch(appRepositories.dioClient).then((_) {
    if (!kIsWeb) {
      unawaited(SplashVideoCache.prefetch(BrandingConfig.splashVideoUrl));
    }
  }));
  if (!kIsWeb) {
    unawaited(SplashVideoCache.prefetch(BrandingConfig.splashVideoUrl));
  }

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

  if (!kIsWeb) {
    unawaited(WidgetSyncService.init(onWidgetClick: (uri) {
      if (uri != null) {
        WidgetSyncService.setPendingLaunchUri(uri);
        final action = uri.queryParameters['action'] ?? 'punch';
        if (authBloc.state.isAuthenticated) {
          WidgetSyncService.consumePendingLaunchUri();
          router.go('/attendance?action=$action&source=widget');
        }
      }
    }));
  }

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

AuthStatus? _webSplashStatus;

void _syncWebSplash(AuthStatus status) {
  if (_webSplashStatus == status) return;
  _webSplashStatus = status;
  if (!kIsWeb) {
    if (status == AuthStatus.authenticated) {
      SplashVideoAudio.stop();
    }
    return;
  }
  // Keep the animated loader in loop until auth status is resolved and page paints!
  if (status == AuthStatus.unknown) {
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    SplashVideoAudio.stop();
  });
}

class NbCrmApp extends StatelessWidget {
  const NbCrmApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    TourEngine.instance.attachRouter(router);
    TourEngine.instance.attachModuleCubit(context.read<AppModuleCubit>());
    return BlocBuilder<ThemeCubit, ThemeMode>(
      buildWhen: (previous, current) => previous != current,
      builder: (context, themeMode) {
        return MaterialApp.router(
          title: 'NBSince1946',
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
              child: BlocConsumer<AuthBloc, AuthState>(
                listenWhen: (previous, current) => previous.status != current.status,
                listener: (_, state) {
                  _syncWebSplash(state.status);
                  if (state.status == AuthStatus.authenticated) {
                    final pending = WidgetSyncService.consumePendingLaunchUri();
                    if (pending != null) {
                      final action = pending.queryParameters['action'] ?? 'punch';
                      router.go('/attendance?action=$action&source=widget');
                    }
                  }
                },
                buildWhen: (previous, current) =>
                    previous.status != current.status ||
                    previous.user?.role != current.user?.role,
                builder: (context, auth) {
                  _syncWebSplash(auth.status);
                  return AppVersionGate(
                    isSuperAdmin: auth.isSuperAdmin,
                    child: GlobalMaintenanceGate(
                      isSuperAdmin: auth.isSuperAdmin,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const MaterialIconKeepAlive(),
                          Positioned.fill(
                            child: Listener(
                              behavior: HitTestBehavior.translucent,
                              onPointerDown: (event) {
                                LocationAlertSound.unlock();
                                AppSounds.unlock();
                                MrNbTourService.instance.unlock();
                                AppActivityTracker.instance.trackPointerDown(event);
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Positioned.fill(
                                    child: PermissionGuard(
                                      child: AuthRiverpodBridge(
                                        child: child ?? const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                  const IncomingCallHost(),
                                  const TourOverlayHost(),
                                  const FirstVisitHost(),
                                  const TourDebugInspector(),
                                ],
                              ),
                            ),
                          ),
                          if (!kIsWeb && auth.status == AuthStatus.unknown)
                            const Positioned.fill(
                              child: SplashVideoHost(),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
