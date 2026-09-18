/// Generic tour domain. Engine knows only these types — never ERP/CRM/HRMS logic.

enum TourCategory { erp, crm, hrms, collaboration, other }

enum TourMode { firstVisit, quick, complete, module, section, selected, resume }

enum TourStepType {
  intro,
  highlight,
  video,
  information,
  navigation,
  interactive,
  completion,
}

enum TourPlacement {
  auto,
  top,
  bottom,
  left,
  right,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

enum TourEnginePhase {
  idle,
  starting,
  preparing,
  navigating,
  waitingForTarget,
  scrolling,
  showing,
  waitingForUser,
  transitioning,
  recovering,
  completed,
}

enum TourProgressStatus { notStarted, inProgress, completed, skipped, currentlyUnavailable }

class TourIds {
  TourIds._();

  static String nav(String route) {
    final path = route.split('?').first.replaceAll(RegExp(r'^/+'), '').replaceAll('/', '.');
    return 'nav.$path';
  }

  static String page(String route) {
    final path = route.split('?').first.replaceAll(RegExp(r'^/+'), '').replaceAll('/', '.');
    return 'page.$path';
  }

  static String card(String route) {
    final path = route.split('?').first.replaceAll(RegExp(r'^/+'), '').replaceAll('/', '.');
    return 'card.$path';
  }

  static String ui(String name) => 'ui.$name';

  static String step(String sectionId, int order) => ui('$sectionId.$order');
}

class TourPermissionReq {
  const TourPermissionReq({
    this.module,
    this.action = 'READ',
    this.suite,
    this.anyOf = const [],
  });

  /// Existing RBAC module key (e.g. `LEAVE`, `PROJECTS`).
  final String? module;
  final String action;

  /// Suite license key: HRMS / CRM / ERP.
  final String? suite;

  /// Alternative permission pairs; any match grants access.
  final List<TourPermissionReq> anyOf;
}

class TourStep {
  const TourStep({
    required this.id,
    required this.sectionId,
    required this.title,
    required this.description,
    required this.order,
    this.targetId,
    this.route,
    this.mascotClip,
    this.type = TourStepType.highlight,
    this.placement = TourPlacement.auto,
    this.autoScroll = true,
    this.required = false,
    this.useMascot = false,
    this.permission,
    this.includeInComplete = true,
  });

  final String id;
  final String sectionId;
  final String title;
  final String description;
  final int order;
  final String? targetId;
  final String? route;
  final String? mascotClip;
  final TourStepType type;
  final TourPlacement placement;
  final bool autoScroll;
  final bool required;
  final bool useMascot;
  final TourPermissionReq? permission;

  /// Per-section "done" beats are omitted from the whole-software walkthrough.
  final bool includeInComplete;
}

class TourSection {
  const TourSection({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.description,
    required this.steps,
    this.estimatedMinutes = 2,
    this.permission,
  });

  final String id;
  final String moduleId;
  final String title;
  final String description;
  final List<TourStep> steps;
  final int estimatedMinutes;
  final TourPermissionReq? permission;
}

class TourModule {
  const TourModule({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.sections,
    this.permission,
  });

  final String id;
  final String title;
  final String description;
  final TourCategory category;
  final List<TourSection> sections;
  final TourPermissionReq? permission;
}

class TourCatalog {
  const TourCatalog(this.modules);
  final List<TourModule> modules;

  TourModule? moduleById(String id) {
    for (final m in modules) {
      if (m.id == id) return m;
    }
    return null;
  }

  TourSection? sectionById(String id) {
    for (final m in modules) {
      for (final s in m.sections) {
        if (s.id == id) return s;
      }
    }
    return null;
  }
}

class QueuedTourStep {
  const QueuedTourStep({
    required this.module,
    required this.section,
    required this.step,
  });

  final TourModule module;
  final TourSection section;
  final TourStep step;
}

class TourSnapshot {
  const TourSnapshot({
    required this.phase,
    required this.mode,
    required this.queue,
    required this.index,
    this.error,
  });

  final TourEnginePhase phase;
  final TourMode? mode;
  final List<QueuedTourStep> queue;
  final int index;
  final String? error;

  QueuedTourStep? get current =>
      (index >= 0 && index < queue.length) ? queue[index] : null;

  int get total => queue.length;
  bool get isActive =>
      current != null &&
      phase != TourEnginePhase.idle &&
      phase != TourEnginePhase.completed;
}
