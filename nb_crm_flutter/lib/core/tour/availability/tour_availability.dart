import '../../../features/auth/domain/permissions.dart';
import '../models/tour_models.dart';

class TourAuthContext {
  const TourAuthContext({
    required this.permissions,
    required this.enabledModules,
    this.role,
    this.employeeViewScope,
  });

  factory TourAuthContext.fromUser({
    required PermissionMap? permissions,
    List<String>? enabledModules,
    String? role,
    String? employeeViewScope,
  }) {
    final mods = (enabledModules == null || enabledModules.isEmpty)
        ? const ['HRMS', 'CRM', 'ERP']
        : enabledModules;
    return TourAuthContext(
      permissions: permissions,
      enabledModules: mods,
      role: role,
      employeeViewScope: employeeViewScope,
    );
  }

  final PermissionMap? permissions;
  final List<String> enabledModules;
  final String? role;
  final String? employeeViewScope;

  List<String> get accessibleSuites =>
      Permissions.accessibleSuites(permissions, enabledModules, role);
}

class TourAvailabilityResolver {
  const TourAvailabilityResolver();

  bool isAllowed(TourPermissionReq? req, TourAuthContext auth) {
    if (req == null) return true;
    if (req.anyOf.isNotEmpty) {
      return req.anyOf.any((r) => isAllowed(r, auth));
    }
    if (req.suite != null &&
        req.suite!.isNotEmpty &&
        !auth.accessibleSuites.contains(req.suite!.toUpperCase())) {
      return false;
    }
    if (req.module == null || req.module!.isEmpty) return true;
    if (Permissions.isSuperAdmin(auth.role)) return true;
    if (Permissions.hasPermission(auth.permissions, req.module!, req.action)) {
      return true;
    }
    if (req.action.toUpperCase() != 'READ') return false;
    const elevated = ['WRITE', 'APPROVE', 'DELETE', 'EXPORT'];
    return elevated.any(
      (action) => Permissions.hasPermission(auth.permissions, req.module!, action),
    );
  }

  bool moduleAvailable(TourModule module, TourAuthContext auth) {
    if (!isAllowed(module.permission, auth)) return false;
    return module.sections.any((s) => sectionAvailable(s, auth));
  }

  bool sectionAvailable(TourSection section, TourAuthContext auth) {
    if (!isAllowed(section.permission, auth)) return false;
    return section.steps.any((st) => stepAvailable(st, auth));
  }

  bool stepAvailable(TourStep step, TourAuthContext auth) {
    return isAllowed(step.permission, auth);
  }

  TourCatalog filterCatalog(TourCatalog catalog, TourAuthContext auth) {
    final modules = <TourModule>[];
    for (final module in catalog.modules) {
      if (!isAllowed(module.permission, auth)) continue;
      final sections = <TourSection>[];
      for (final section in module.sections) {
        if (!isAllowed(section.permission, auth)) continue;
        final steps = section.steps.where((s) => stepAvailable(s, auth)).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
        if (steps.isEmpty) continue;
        sections.add(
          TourSection(
            id: section.id,
            moduleId: section.moduleId,
            title: section.title,
            description: section.description,
            estimatedMinutes: section.estimatedMinutes,
            permission: section.permission,
            steps: steps,
          ),
        );
      }
      if (sections.isEmpty) continue;
      modules.add(
        TourModule(
          id: module.id,
          title: module.title,
          description: module.description,
          category: module.category,
          permission: module.permission,
          sections: sections,
        ),
      );
    }
    return TourCatalog(modules);
  }

  List<QueuedTourStep> queueForSections({
    required TourCatalog catalog,
    required TourAuthContext auth,
    required Iterable<String> sectionIds,
  }) {
    final filtered = filterCatalog(catalog, auth);
    final wanted = sectionIds.toSet();
    final out = <QueuedTourStep>[];
    for (final module in filtered.modules) {
      for (final section in module.sections) {
        if (!wanted.contains(section.id)) continue;
        for (final step in section.steps) {
          out.add(QueuedTourStep(module: module, section: section, step: step));
        }
      }
    }
    return out;
  }

  List<QueuedTourStep> queueForModule({
    required TourCatalog catalog,
    required TourAuthContext auth,
    required String moduleId,
  }) {
    final filtered = filterCatalog(catalog, auth);
    final module = filtered.moduleById(moduleId);
    if (module == null) return const [];
    return [
      for (final section in module.sections)
        for (final step in section.steps)
          QueuedTourStep(module: module, section: section, step: step),
    ];
  }

  List<QueuedTourStep> completeQueue({
    required TourCatalog catalog,
    required TourAuthContext auth,
  }) {
    final filtered = filterCatalog(catalog, auth);
    final out = <QueuedTourStep>[];
    final seen = <String>{};

    void addSteps(TourModule module, TourSection section, Iterable<TourStep> steps) {
      for (final step in steps) {
        if (!step.includeInComplete) continue;
        if (!seen.add(step.id)) continue;
        out.add(QueuedTourStep(module: module, section: section, step: step));
      }
    }

    void addModule(
      String id, {
      bool skipCompletion = true,
      bool Function(TourStep step)? where,
    }) {
      final module = filtered.moduleById(id);
      if (module == null) return;
      for (final section in module.sections) {
        addSteps(
          module,
          section,
          section.steps.where((step) {
            if (skipCompletion && step.type == TourStepType.completion) return false;
            return where == null || where(step);
          }),
        );
      }
    }

    addModule('platform.complete', where: (s) => s.sectionId == 'platform.complete.intro');
    addModule(
      'platform.first_visit',
      where: (s) => s.id == 'first.nav' || s.id == 'first.suites',
    );
    addModule(
      'platform.quick',
      where: (s) => s.id == 'quick.search' || s.id == 'quick.alerts',
    );
    const productOrder = ['hrms', 'erp', 'crm', 'collaboration'];
    final remaining = filtered.modules
        .where(
          (m) =>
              m.id != 'platform.quick' &&
              m.id != 'platform.first_visit' &&
              m.id != 'platform.complete',
        )
        .toList();
    remaining.sort((a, b) {
      final ai = productOrder.indexOf(a.id);
      final bi = productOrder.indexOf(b.id);
      return (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
    });
    for (final module in remaining) {
      for (final section in module.sections) {
        addSteps(
          module,
          section,
          section.steps.where((s) => s.type != TourStepType.completion),
        );
      }
    }
    addModule(
      'platform.complete',
      skipCompletion: false,
      where: (s) => s.sectionId == 'platform.complete.wrapup',
    );
    return out;
  }

  List<TourSection> productSections(TourCatalog catalog, TourAuthContext auth) {
    final filtered = filterCatalog(catalog, auth);
    return [
      for (final module in filtered.modules)
        if (module.id != 'platform.quick' &&
            module.id != 'platform.first_visit' &&
            module.id != 'platform.complete')
          ...module.sections,
    ];
  }
}
