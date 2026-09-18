import '../../logging/app_logger.dart';
import '../models/tour_models.dart';

class TourValidator {
  TourValidator._();
  static final AppLogger log = AppLogger.named('TourValidator');

  static List<String> validate(TourCatalog catalog) {
    final errors = <String>[];
    final moduleIds = <String>{};
    final sectionIds = <String>{};
    final stepIds = <String>{};
    final targetIds = <String>{};

    for (final module in catalog.modules) {
      if (!moduleIds.add(module.id)) {
        errors.add('Duplicate module ID ${module.id}');
      }
      for (final section in module.sections) {
        if (section.moduleId != module.id) {
          errors.add('Section ${section.id} moduleId mismatch');
        }
        if (!sectionIds.add(section.id)) {
          errors.add('Duplicate section ID ${section.id}');
        }
        if (section.steps.isEmpty) {
          errors.add('Section ${section.id} has no steps');
        }
        for (final step in section.steps) {
          if (step.sectionId != section.id) {
            errors.add('Step ${step.id} sectionId mismatch');
          }
          if (!stepIds.add(step.id)) {
            errors.add('Duplicate step ID ${step.id}');
          }
          if (step.targetId != null && step.targetId!.isNotEmpty) {
            targetIds.add(step.targetId!);
          }
          if (step.route != null && step.route!.isNotEmpty && !step.route!.startsWith('/')) {
            errors.add('Step ${step.id} has invalid route ${step.route}');
          }
        }
      }
    }

    for (final e in errors) {
      log.e(e);
    }
    if (errors.isEmpty) {
      log.i(
        'Catalog OK modules=${moduleIds.length} sections=${sectionIds.length} '
        'steps=${stepIds.length} targets=${targetIds.length}',
      );
    }
    return errors;
  }
}
