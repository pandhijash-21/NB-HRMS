import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../services/mr_nb_tour_service.dart';
import '../availability/tour_availability.dart';
import '../engine/tour_engine.dart';
import '../mascot/mascot_clip_registry.dart';
import '../mascot/mascot_presenter.dart';
import '../models/tour_models.dart';
import '../persistence/tour_progress_store.dart';
import '../tour_desktop.dart';

class FirstVisitHost extends StatefulWidget {
  const FirstVisitHost({super.key});

  @override
  State<FirstVisitHost> createState() => _FirstVisitHostState();
}

class _FirstVisitHostState extends State<FirstVisitHost> {
  bool _welcome = false;
  bool _checking = true;
  List<TourSection> _newSections = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  TourAuthContext _ctx(AuthState auth) {
    return TourAuthContext.fromUser(
      permissions: auth.permissions,
      enabledModules: auth.user?.enabledModules,
      role: auth.user?.role,
      employeeViewScope: auth.user?.employeeViewScope,
    );
  }

  Future<void> _check() async {
    final auth = context.read<AuthBloc>().state;
    if (!auth.isAuthenticated ||
        auth.isFirstLogin ||
        auth.needsEmailVerification ||
        auth.user == null) {
      if (mounted) {
        setState(() {
          _checking = false;
          _welcome = false;
          _newSections = const [];
        });
      }
      return;
    }

    TourEngine.instance.updateAuth(userId: auth.user!.id, auth: _ctx(auth));

    final seen = kDebugMode
        ? false
        : await TourProgressStore.instance.hasSeenOnboarding(auth.user!.id);
    if (!mounted) return;
    if (!seen) {
      setState(() {
        _checking = false;
        _welcome = true;
        _newSections = const [];
      });
      return;
    }

    final newly = await _detectNewSections(auth);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _welcome = false;
      _newSections = newly;
    });
  }

  Future<List<TourSection>> _detectNewSections(AuthState auth) async {
    if (TourEngine.instance.isActive) return const [];
    final userId = auth.user?.id;
    if (userId == null) return const [];
    final ctx = _ctx(auth);
    final available = TourEngine.instance.resolver.productSections(
      TourEngine.instance.catalog,
      ctx,
    );
    final known = await TourProgressStore.instance.loadKnownSections(userId);
    if (known.isEmpty) {
      await TourProgressStore.instance.saveKnownSections(
        userId,
        available.map((s) => s.id),
      );
      return const [];
    }
    return available.where((s) => !known.contains(s.id)).toList();
  }

  Future<void> _snapshotKnown(AuthState auth) async {
    final userId = auth.user?.id;
    if (userId == null) return;
    final available = TourEngine.instance.resolver.productSections(
      TourEngine.instance.catalog,
      _ctx(auth),
    );
    await TourProgressStore.instance.saveKnownSections(
      userId,
      available.map((s) => s.id),
    );
  }

  Future<void> _dismissWelcome({
    bool startQuick = false,
    bool startFirst = false,
    bool startComplete = false,
  }) async {
    final auth = context.read<AuthBloc>().state;
    if (!mounted) return;
    setState(() => _welcome = false);
    if (startComplete || startFirst || startQuick) {
      if (!TourDesktop.supported(context)) {
        await TourDesktop.ensureCanStart(context);
        await _snapshotKnown(auth);
        return;
      }
      final ctx = _ctx(auth);
      TourEngine.instance.updateAuth(userId: auth.user?.id, auth: ctx);
      unawaited(MrNbTourService.instance.unlock());
      MrNbTourService.instance.unmute();
      if (startComplete) {
        unawaited(TourEngine.instance.startComplete(auth: ctx));
      } else if (startFirst) {
        unawaited(TourEngine.instance.startFirstVisit());
      } else if (startQuick) {
        unawaited(TourEngine.instance.startQuick());
      }
    }
    if (auth.user != null && !kDebugMode) {
      unawaited(TourProgressStore.instance.markOnboardingSeen(auth.user!.id));
    }
    unawaited(_snapshotKnown(auth));
  }

  Future<void> _startNewModules() async {
    final auth = context.read<AuthBloc>().state;
    final ids = _newSections.map((s) => s.id).toList();
    if (!mounted) return;
    setState(() => _newSections = const []);
    if (!TourDesktop.supported(context)) {
      await TourDesktop.ensureCanStart(context);
      await _snapshotKnown(auth);
      return;
    }
    final ctx = _ctx(auth);
    TourEngine.instance.updateAuth(userId: auth.user?.id, auth: ctx);
    unawaited(MrNbTourService.instance.unlock());
    MrNbTourService.instance.unmute();
    unawaited(TourEngine.instance.startSelected(ids, auth: ctx));
    unawaited(_snapshotKnown(auth));
  }

  Future<void> _dismissNewModules() async {
    final auth = context.read<AuthBloc>().state;
    await _snapshotKnown(auth);
    if (mounted) setState(() => _newSections = const []);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (p, c) =>
          p.isAuthenticated != c.isAuthenticated ||
          p.user?.id != c.user?.id ||
          p.permissions != c.permissions,
      listener: (_, __) => _check(),
      child: _checking
          ? const SizedBox.shrink()
          : _welcome
              ? _welcomeCard()
              : _newSections.isEmpty
                  ? const SizedBox.shrink()
                  : _newAccessCard(),
    );
  }

  Widget _welcomeCard() {
    final desktop = TourDesktop.supported(context);
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            color: const Color(0xFF1A201C),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MascotPresenter(clip: MascotClipRegistry.welcome, size: 168),
                  const SizedBox(height: 16),
                  const Text(
                    'Welcome to NB CRM',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    desktop
                        ? 'Your ERP, CRM and HRMS workspace. Mr. NB walks every module you can open, and switches suites when your role allows it.'
                        : 'The Software Tour highlights real buttons, tabs and cards. Open NB CRM in a desktop browser to take it. The mobile app does not run this walkthrough.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  if (desktop) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFC5A36A),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          unawaited(MrNbTourService.instance.unlock());
                          MrNbTourService.instance.unmute();
                          unawaited(_dismissWelcome(startComplete: true));
                        },
                        child: const Text('Whole Software Tour'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Visits every allowed HRMS, ERP, CRM and Collaboration screen and explains how to use it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
                        ),
                        onPressed: () {
                          unawaited(MrNbTourService.instance.unlock());
                          MrNbTourService.instance.unmute();
                          unawaited(_dismissWelcome(startFirst: true));
                        },
                        child: const Text('Quick Tour'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () {
                        TourEngine.instance.go('/software-tour');
                        _dismissWelcome();
                      },
                      child: const Text('Explore modules'),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFC5A36A),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => _dismissWelcome(),
                        child: const Text('Continue on this device'),
                      ),
                    ),
                  ],
                  TextButton(
                    onPressed: () => _dismissWelcome(),
                    child: const Text("I'll explore myself"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _newAccessCard() {
    final names = _newSections.map((s) => s.title).toSet().toList();
    final preview = names.take(8).join(', ');
    final extra = names.length > 8 ? ' and ${names.length - 8} more' : '';
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            color: const Color(0xFF1A201C),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MascotPresenter(clip: MascotClipRegistry.wave, size: 132),
                  const SizedBox(height: 16),
                  const Text(
                    'New modules for you',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your role was updated. You now have access to $preview$extra. I can walk those screens once, then I will not ask again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  if (TourDesktop.supported(context))
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFC5A36A),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _startNewModules,
                        child: const Text('Tour new modules'),
                      ),
                    )
                  else
                    const Text(
                      'Open NB CRM in a desktop browser to take the tour. The mobile app does not run this walkthrough.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  TextButton(
                    onPressed: _dismissNewModules,
                    child: const Text('Not now'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
