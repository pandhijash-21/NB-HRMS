import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../bloc/app_module_cubit.dart';
import '../../logging/app_logger.dart';
import '../../services/mr_nb_tour_service.dart';
import '../availability/tour_availability.dart';
import '../catalog/nb_platform_catalog.dart';
import '../mascot/mascot_clip_registry.dart';
import '../mascot/mr_nb_intro.dart';
import '../models/tour_models.dart';
import '../persistence/tour_progress_store.dart';
import '../registry/target_registry.dart';

class TourEngine extends ChangeNotifier {
  TourEngine._();
  static final TourEngine instance = TourEngine._();

  static final AppLogger log = AppLogger.named('TourEngine');

  final TourAvailabilityResolver resolver = const TourAvailabilityResolver();
  TourCatalog catalog = NbPlatformCatalog.build();

  TourSnapshot _snapshot = const TourSnapshot(
    phase: TourEnginePhase.idle,
    mode: null,
    queue: [],
    index: -1,
  );

  GoRouter? _router;
  AppModuleCubit? _modules;
  String? _userId;
  TourAuthContext? _auth;
  String? _lastError;

  /// Bumped on launch / next / back / complete / exit so in-flight
  /// `_presentCurrent` cannot resurrect an overlay after Finish.
  int _run = 0;

  TourSnapshot get snapshot => _snapshot;
  bool get isActive => _snapshot.isActive;
  String? get lastError => _lastError;

  bool _isLive(int run) =>
      run == _run && _snapshot.isActive && _snapshot.current != null;

  void _goIdle({String? logMessage}) {
    _run++;
    _snapshot = const TourSnapshot(
      phase: TourEnginePhase.idle,
      mode: null,
      queue: [],
      index: -1,
    );
    notifyListeners();
    if (logMessage != null) log.i(logMessage);
  }

  void attachRouter(GoRouter router) {
    _router = router;
  }

  void attachModuleCubit(AppModuleCubit cubit) {
    _modules = cubit;
  }

  void go(String location) {
    _router?.go(location);
  }

  void updateAuth({required String? userId, required TourAuthContext auth}) {
    _userId = userId;
    _auth = auth;
  }

  Future<bool> startSection(String sectionId) {
    return _start(
      mode: TourMode.section,
      sectionIds: [sectionId],
    );
  }

  Future<bool> startComplete({TourAuthContext? auth}) async {
    if (auth != null) {
      _auth = auth;
    }
    final current = _auth;
    if (current == null) return false;
    final queue = resolver.completeQueue(catalog: catalog, auth: current);
    log.i(
      'Whole software tour queue=${queue.length} '
      'suites=${current.accessibleSuites.join(",")}',
    );
    return _launch(mode: TourMode.complete, queue: queue);
  }

  Future<bool> startModule(String moduleId, {TourAuthContext? auth}) async {
    if (auth != null) _auth = auth;
    final current = _auth;
    if (current == null) return false;
    final queue = resolver.queueForModule(catalog: catalog, auth: current, moduleId: moduleId);
    return _launch(mode: TourMode.module, queue: queue);
  }

  Future<bool> startSelected(Iterable<String> sectionIds, {TourAuthContext? auth}) {
    if (auth != null) _auth = auth;
    return _start(mode: TourMode.selected, sectionIds: sectionIds);
  }

  Future<bool> startQuick() {
    return startModule('platform.quick');
  }

  Future<bool> startFirstVisit() {
    return startModule('platform.first_visit');
  }

  Future<bool> resume() async {
    final userId = _userId;
    final auth = _auth;
    if (userId == null || auth == null) return false;
    final saved = await TourProgressStore.instance.loadResume(userId);
    if (saved == null) return false;
    final ids = (saved['sectionIds'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final index = (saved['stepIndex'] as num?)?.toInt() ?? 0;
    final queue = resolver.queueForSections(
      catalog: catalog,
      auth: auth,
      sectionIds: ids,
    );
    return _launch(mode: TourMode.resume, queue: queue, startIndex: index.clamp(0, queue.length));
  }

  Future<bool> _start({
    required TourMode mode,
    required Iterable<String> sectionIds,
  }) async {
    final auth = _auth;
    if (auth == null) return false;
    final queue = resolver.queueForSections(
      catalog: catalog,
      auth: auth,
      sectionIds: sectionIds,
    );
    return _launch(mode: mode, queue: queue);
  }

  Future<bool> _launch({
    required TourMode mode,
    required List<QueuedTourStep> queue,
    int startIndex = 0,
  }) async {
    if (isActive) {
      log.w('Tour already running');
      _lastError = 'A tour is already running.';
      notifyListeners();
      return false;
    }
    if (queue.isEmpty) {
      log.w('Empty tour queue after authorization filter');
      _lastError = 'No accessible tour steps for your role.';
      notifyListeners();
      return false;
    }
    unawaited(MrNbTourService.instance.unlock());
    MrNbTourService.instance.unmute();
    _lastError = null;
    // Fresh starts always meet Mr. NB first. Resume mid-tour keeps saved indices.
    final steps = startIndex == 0 ? MrNbIntro.prepend(queue) : queue;
    final index = startIndex.clamp(0, steps.length - 1);
    _run++;
    final run = _run;
    _snapshot = TourSnapshot(
      phase: TourEnginePhase.starting,
      mode: mode,
      queue: steps,
      index: index,
    );
    notifyListeners();
    log.i('Starting tour mode=${mode.name} steps=${steps.length}');
    _kickSpeech();
    unawaited(_presentCurrent(run: run, speak: false));
    return true;
  }

  Future<void> next() async {
    if (!_snapshot.isActive) return;
    final nextIndex = _snapshot.index + 1;
    if (nextIndex >= _snapshot.queue.length) {
      await complete();
      return;
    }
    unawaited(_markCurrent(TourProgressStatus.inProgress));
    _run++;
    final run = _run;
    _snapshot = TourSnapshot(
      phase: TourEnginePhase.transitioning,
      mode: _snapshot.mode,
      queue: _snapshot.queue,
      index: nextIndex,
    );
    notifyListeners();
    _kickSpeech();
    unawaited(_presentCurrent(run: run, speak: false));
  }

  Future<void> back() async {
    if (!_snapshot.isActive || _snapshot.index <= 0) return;
    _run++;
    final run = _run;
    _snapshot = TourSnapshot(
      phase: TourEnginePhase.transitioning,
      mode: _snapshot.mode,
      queue: _snapshot.queue,
      index: _snapshot.index - 1,
    );
    notifyListeners();
    _kickSpeech();
    unawaited(_presentCurrent(run: run, speak: false));
  }

  Future<void> skip() async {
    unawaited(_markCurrent(TourProgressStatus.skipped));
    await next();
  }

  Future<void> exit() async {
    final userId = _userId;
    final snap = _snapshot;
    unawaited(MrNbTourService.instance.stop());
    _goIdle(logMessage: 'Tour exited');
    unawaited(_persistResumeFrom(snap, userId));
  }

  Future<void> complete() async {
    final userId = _userId;
    final auth = _auth;
    final queue = List<QueuedTourStep>.from(_snapshot.queue);
    unawaited(MrNbTourService.instance.stop());
    _goIdle(logMessage: 'Tour completed');
    unawaited(_persistCompletion(userId: userId, auth: auth, queue: queue));
  }

  Future<void> _persistCompletion({
    required String? userId,
    required TourAuthContext? auth,
    required List<QueuedTourStep> queue,
  }) async {
    if (userId == null) return;
    final seen = <String>{};
    for (final item in queue) {
      if (!seen.add(item.section.id)) continue;
      await TourProgressStore.instance.setSectionStatus(
        userId: userId,
        sectionId: item.section.id,
        status: TourProgressStatus.completed,
      );
    }
    await TourProgressStore.instance.clearResume(userId);
    if (auth == null) return;
    final available = resolver.productSections(catalog, auth);
    await TourProgressStore.instance.saveKnownSections(
      userId,
      available.map((s) => s.id),
    );
  }

  void reportTargetAction(String targetId) {
    final current = _snapshot.current;
    if (current == null) return;
    if (current.step.type == TourStepType.interactive && current.step.targetId == targetId) {
      next();
    }
  }

  Future<void> _presentCurrent({required int run, bool speak = true}) async {
    if (!_isLive(run)) return;
    final item = _snapshot.current;
    if (item == null) {
      await complete();
      return;
    }
    final step = item.step;
    log.i(
      'Step ${ _snapshot.index + 1}/${_snapshot.total} '
      'module=${item.module.id} section=${item.section.id} '
      'id=${step.id} route=${step.route} target=${step.targetId}',
    );

    _snapshot = TourSnapshot(
      phase: TourEnginePhase.preparing,
      mode: _snapshot.mode,
      queue: _snapshot.queue,
      index: _snapshot.index,
    );
    notifyListeners();
    if (speak) _kickSpeech();

    if (step.route != null && step.route!.isNotEmpty) {
      if (!_isLive(run)) return;
      _snapshot = TourSnapshot(
        phase: TourEnginePhase.navigating,
        mode: _snapshot.mode,
        queue: _snapshot.queue,
        index: _snapshot.index,
      );
      notifyListeners();
      _switchSuite(step.route!);
      _router?.go(step.route!);
    }

    if (step.targetId != null) {
      if (!_isLive(run)) return;
      _snapshot = TourSnapshot(
        phase: TourEnginePhase.waitingForTarget,
        mode: _snapshot.mode,
        queue: _snapshot.queue,
        index: _snapshot.index,
      );
      notifyListeners();
      final found = await _waitForTarget(step.targetId!, run);
      if (!_isLive(run)) return;
      if (found == null) {
        log.w('Target missing ${step.targetId} — continuing without highlight');
      } else if (step.autoScroll) {
        _snapshot = TourSnapshot(
          phase: TourEnginePhase.scrolling,
          mode: _snapshot.mode,
          queue: _snapshot.queue,
          index: _snapshot.index,
        );
        notifyListeners();
        final ctx = found.key.currentContext;
        if (ctx != null && ctx.mounted) {
          await Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 220),
            alignment: 0.35,
            curve: Curves.easeOutCubic,
          );
        }
        if (!_isLive(run)) return;
      }
    }

    if (!_isLive(run)) return;
    _snapshot = TourSnapshot(
      phase: TourEnginePhase.showing,
      mode: _snapshot.mode,
      queue: _snapshot.queue,
      index: _snapshot.index,
    );
    notifyListeners();
    unawaited(_markCurrent(TourProgressStatus.inProgress));
    unawaited(_persistResume());

    if (!_isLive(run)) return;
    _snapshot = TourSnapshot(
      phase: TourEnginePhase.waitingForUser,
      mode: _snapshot.mode,
      queue: _snapshot.queue,
      index: _snapshot.index,
    );
    notifyListeners();
  }

  void _kickSpeech() {
    final step = _snapshot.current?.step;
    if (step == null) return;
    final clip = MascotClipRegistry.instance.resolve(step: step);
    MrNbTourService.instance.unmute();
    MrNbTourService.instance.beginNarration(
      MrNbNarrationStep(
        title: step.title,
        speechText: step.description,
        expression: _expressionFor(clip?.id),
      ),
    );
  }

  Future<void> speakCurrent() async {
    unawaited(MrNbTourService.instance.unlock());
    MrNbTourService.instance.unmute();
    _kickSpeech();
  }

  Future<RegisteredTourTarget?> _waitForTarget(String id, int run) async {
    final deadline = DateTime.now().add(const Duration(milliseconds: 900));
    while (DateTime.now().isBefore(deadline)) {
      if (!_isLive(run)) return null;
      final target = TargetRegistry.instance.find(id);
      if (target != null && target.mounted && target.visible) return target;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!_isLive(run)) return null;
    final last = TargetRegistry.instance.find(id);
    if (last != null && last.mounted) return last;
    return null;
  }

  void _switchSuite(String route) {
    final cubit = _modules;
    if (cubit == null) return;
    if (route.startsWith('/erp')) {
      cubit.setModule(AppModule.erp);
    } else if (route.startsWith('/crm')) {
      cubit.setModule(AppModule.crm);
    } else if (!isSharedShellPath(route)) {
      cubit.setModule(AppModule.hrms);
    }
  }

  Future<void> _markCurrent(TourProgressStatus status) async {
    final userId = _userId;
    final item = _snapshot.current;
    if (userId == null || item == null) return;
    if (status == TourProgressStatus.completed || status == TourProgressStatus.inProgress) {
      await TourProgressStore.instance.setSectionStatus(
        userId: userId,
        sectionId: item.section.id,
        status: status,
      );
    } else if (status == TourProgressStatus.skipped) {
      await TourProgressStore.instance.setSectionStatus(
        userId: userId,
        sectionId: item.section.id,
        status: TourProgressStatus.skipped,
      );
    }
  }

  Future<void> _persistResume() async {
    await _persistResumeFrom(_snapshot, _userId);
  }

  Future<void> _persistResumeFrom(TourSnapshot snap, String? userId) async {
    final mode = snap.mode;
    if (userId == null || mode == null || snap.queue.isEmpty) return;
    final ids = snap.queue.map((e) => e.section.id).toSet().toList();
    await TourProgressStore.instance.saveResume(
      userId: userId,
      mode: mode,
      sectionIds: ids,
      stepIndex: snap.index,
      currentSectionId: snap.current?.section.id,
    );
  }
}

MrNbExpression _expressionFor(String? clipId) {
  return switch (clipId) {
    'welcome' => MrNbExpression.welcome,
    'wave' => MrNbExpression.wave,
    'pointing' => MrNbExpression.pointing,
    'thinking' => MrNbExpression.thinking,
    'thumbs_up' => MrNbExpression.thumbsUp,
    'side_wave' => MrNbExpression.sideWave,
    _ => MrNbExpression.idle,
  };
}
