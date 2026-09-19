import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/auth/data/auth_repository.dart';
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
  int _checkGen = 0;

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
    final gen = ++_checkGen;
    final auth = context.read<AuthBloc>().state;
    if (!auth.isAuthenticated ||
        auth.isFirstLogin ||
        auth.needsEmailVerification ||
        auth.user == null) {
      if (mounted && gen == _checkGen) {
        setState(() {
          _checking = false;
          _welcome = false;
          _newSections = const [];
        });
      }
      return;
    }

    TourEngine.instance.updateAuth(userId: auth.user!.id, auth: _ctx(auth));

    var seenOnServer = auth.user!.softwareTourSeen;
    final seenLocal =
        await TourProgressStore.instance.hasSeenOnboarding(auth.user!.id);
    if (!mounted || gen != _checkGen) return;

    // Confirm with live /auth/me so older cached sessions (missing the flag)
    // and pre-existing accounts do not flash the welcome again.
    if (!seenOnServer && !seenLocal) {
      try {
        final repo = context.read<AuthRepository>();
        seenOnServer = await repo.fetchSoftwareTourSeen();
        if (seenOnServer && mounted) {
          // Server already marked — sync local session only (no re-POST).
          unawaited(
            TourProgressStore.instance.markOnboardingSeen(auth.user!.id),
          );
          final bloc = context.read<AuthBloc>();
          final u = bloc.state.user;
          if (u != null && !u.softwareTourSeen) {
            bloc.add(const AuthSoftwareTourSeenSynced());
          }
        }
      } catch (_) {}
      if (!mounted || gen != _checkGen) return;
    }

    final seen = seenOnServer || seenLocal;
    if (seen) {
      final newly = await _detectNewSections(auth);
      if (!mounted || gen != _checkGen) return;
      setState(() {
        _checking = false;
        _welcome = false;
        _newSections = newly;
      });
      return;
    }

    setState(() {
      _checking = false;
      _welcome = true;
      _newSections = const [];
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

  Future<void> _markTourSeen(AuthState auth) async {
    if (auth.user == null) return;
    unawaited(TourProgressStore.instance.markOnboardingSeen(auth.user!.id));
    context.read<AuthBloc>().add(const AuthSoftwareTourSeenRequested());
  }

  Future<void> _dismissWelcome({
    bool startQuick = false,
    bool startFirst = false,
    bool startComplete = false,
  }) async {
    final auth = context.read<AuthBloc>().state;
    if (!mounted) return;
    setState(() => _welcome = false);
    unawaited(_markTourSeen(auth));
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
          p.user?.softwareTourSeen != c.user?.softwareTourSeen ||
          p.isFirstLogin != c.isFirstLogin ||
          p.needsEmailVerification != c.needsEmailVerification ||
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

  Widget _responsiveShell({required Widget child}) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final maxW = math.min(460.0, size.width - 24);
    final maxH = size.height - pad.vertical - 24;
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxW,
              maxHeight: maxH.clamp(280, size.height),
            ),
            child: Card(
              color: const Color(0xFF1A201C),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcomeCard() {
    final desktop = TourDesktop.supported(context);
    final narrow = MediaQuery.sizeOf(context).width < 420;
    final short = MediaQuery.sizeOf(context).height < 720;
    final mascotSize = short || narrow ? 112.0 : 168.0;
    final titleSize = narrow ? 18.0 : 22.0;
    final pad = narrow ? 16.0 : 24.0;

    return _responsiveShell(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, pad - 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MascotPresenter(
              clip: MascotClipRegistry.welcome,
              size: mascotSize,
            ),
            SizedBox(height: short ? 10 : 16),
            Text(
              'Welcome to NB CRM',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: titleSize,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              desktop
                  ? 'Your ERP, CRM and HRMS workspace. Mr. NB walks every module you can open, and switches suites when your role allows it.'
                  : 'The Software Tour highlights real buttons, tabs and cards. Open NB CRM in a desktop browser to take it. The mobile app does not run this walkthrough.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                height: 1.35,
                fontSize: narrow ? 13 : 14,
              ),
            ),
            SizedBox(height: short ? 14 : 20),
            if (desktop) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC5A36A),
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: narrow ? 12 : 14),
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
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  onPressed: () {
                    unawaited(MrNbTourService.instance.unlock());
                    MrNbTourService.instance.unmute();
                    unawaited(_dismissWelcome(startFirst: true));
                  },
                  child: const Text('Quick Tour'),
                ),
              ),
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
                    padding: EdgeInsets.symmetric(vertical: narrow ? 12 : 14),
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
    );
  }

  Widget _newAccessCard() {
    final names = _newSections.map((s) => s.title).toSet().toList();
    final preview = names.take(8).join(', ');
    final extra = names.length > 8 ? ' and ${names.length - 8} more' : '';
    final narrow = MediaQuery.sizeOf(context).width < 420;
    final short = MediaQuery.sizeOf(context).height < 720;
    final pad = narrow ? 16.0 : 24.0;

    return _responsiveShell(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MascotPresenter(
              clip: MascotClipRegistry.wave,
              size: short || narrow ? 96.0 : 132.0,
            ),
            SizedBox(height: short ? 10 : 16),
            Text(
              'New modules for you',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: narrow ? 18 : 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your role was updated. You now have access to $preview$extra. I can walk those screens once, then I will not ask again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                height: 1.35,
                fontSize: narrow ? 13 : 14,
              ),
            ),
            SizedBox(height: short ? 14 : 20),
            if (TourDesktop.supported(context))
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC5A36A),
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: narrow ? 12 : 14),
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
    );
  }
}
