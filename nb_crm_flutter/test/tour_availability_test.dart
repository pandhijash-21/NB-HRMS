import 'package:flutter_test/flutter_test.dart';
import 'package:nb_crm_flutter/core/tour/availability/tour_availability.dart';
import 'package:nb_crm_flutter/core/tour/catalog/nb_platform_catalog.dart';
import 'package:nb_crm_flutter/core/tour/mascot/mr_nb_intro.dart';
import 'package:nb_crm_flutter/core/tour/models/tour_models.dart';
import 'package:nb_crm_flutter/core/tour/validation/tour_validator.dart';
import 'package:nb_crm_flutter/features/auth/domain/permissions.dart';

void main() {
  final catalog = NbPlatformCatalog.build();
  const resolver = TourAvailabilityResolver();

  test('catalog IDs are unique and well-formed', () {
    expect(TourValidator.validate(catalog), isEmpty);
  });

  test('employee without CRM suite does not see CRM tours', () {
    const auth = TourAuthContext(
      permissions: {
        'LEAVE': ['READ', 'WRITE'],
        'ATTENDANCE': ['READ'],
        'PERSONAL_INFO': ['READ'],
      },
      enabledModules: ['HRMS'],
      role: 'STAFF',
      employeeViewScope: 'SELF',
    );
    final filtered = resolver.filterCatalog(catalog, auth);
    expect(filtered.modules.any((m) => m.category == TourCategory.crm), isFalse);
    expect(filtered.modules.any((m) => m.id == 'hrms'), isTrue);
    expect(filtered.sectionById('hrms.leave'), isNotNull);
    expect(filtered.sectionById('hrms.payroll'), isNull);
  });

  test('create permission missing removes write-only requirement but keeps view sections', () {
    const auth = TourAuthContext(
      permissions: {
        'CRM_DASHBOARD': ['READ'],
        'CRM_PRE_SALES': ['READ'],
      },
      enabledModules: ['CRM'],
      role: 'SALES',
    );
    final filtered = resolver.filterCatalog(catalog, auth);
    expect(filtered.sectionById('crm.dashboard'), isNotNull);
    expect(filtered.sectionById('crm.pre_sales'), isNotNull);
    expect(filtered.sectionById('crm.settings'), isNull);
    expect(filtered.sectionById('hrms.leave'), isNull);
  });

  test('selected tours revalidate and drop unauthorized sections', () {
    const auth = TourAuthContext(
      permissions: {
        'CRM_PRE_SALES': ['READ'],
        'PROJECTS': ['READ'],
      },
      enabledModules: ['CRM', 'ERP'],
      role: 'MANAGER',
    );
    final queue = resolver.queueForSections(
      catalog: catalog,
      auth: auth,
      sectionIds: ['crm.pre_sales', 'hrms.payroll', 'erp.projects'],
    );
    expect(queue.any((q) => q.section.id == 'hrms.payroll'), isFalse);
    expect(queue.any((q) => q.section.id == 'crm.pre_sales'), isTrue);
    expect(queue.any((q) => q.section.id == 'erp.projects'), isTrue);
  });

  test('complete tour walks shell then only accessible feature sections', () {
    const auth = TourAuthContext(
      permissions: {
        'CHAT': ['READ'],
      },
      enabledModules: ['HRMS', 'CRM', 'ERP'],
      role: 'STAFF',
    );
    final queue = resolver.completeQueue(catalog: catalog, auth: auth);
    final sectionIds = queue.map((q) => q.section.id).toSet();
    expect(sectionIds.contains('platform.complete.intro'), isTrue);
    expect(sectionIds.contains('platform.first_visit.intro'), isTrue);
    expect(sectionIds.contains('platform.quick.shell'), isTrue);
    expect(sectionIds.contains('collab.chat'), isTrue);
    expect(sectionIds.contains('platform.complete.wrapup'), isTrue);
    expect(sectionIds.contains('hrms.leave'), isFalse);
    expect(sectionIds.contains('crm.dashboard'), isFalse);
    expect(sectionIds.contains('erp.projects'), isFalse);
    expect(
      queue.where((q) => q.section.id == 'collab.chat').every((q) => q.step.type != TourStepType.completion),
      isTrue,
    );
    expect(queue.last.step.id, 'complete.wrapup');
  });

  test('complete tour walks HRMS, ERP and CRM when the role can open all three', () {
    const auth = TourAuthContext(
      permissions: {
        'LEAVE': ['READ'],
        'ATTENDANCE': ['READ'],
        'PERSONAL_INFO': ['READ'],
        'PROJECTS': ['READ'],
        'WORK_ORDERS': ['READ'],
        'CRM_DASHBOARD': ['READ'],
        'CRM_PRE_SALES': ['READ'],
        'CHAT': ['READ'],
        'TASKS': ['READ'],
      },
      enabledModules: ['HRMS', 'CRM', 'ERP'],
      role: 'MANAGER',
    );
    final queue = resolver.completeQueue(catalog: catalog, auth: auth);
    final modules = queue.map((q) => q.module.id).toSet();
    expect(modules.contains('hrms'), isTrue);
    expect(modules.contains('erp'), isTrue);
    expect(modules.contains('crm'), isTrue);
    expect(modules.contains('collaboration'), isTrue);
    expect(queue.any((q) => q.section.id == 'erp.projects'), isTrue);
    expect(queue.any((q) => q.section.id == 'crm.pre_sales'), isTrue);
    expect(queue.length, greaterThan(20));
    expect(queue.last.step.id, 'complete.wrapup');
  });

  test('Mr. NB intro is prepended once before any tour queue', () {
    const auth = TourAuthContext(
      permissions: {
        'LEAVE': ['READ'],
      },
      enabledModules: ['HRMS'],
      role: 'STAFF',
    );
    final leave = resolver.queueForSections(
      catalog: catalog,
      auth: auth,
      sectionIds: ['hrms.leave'],
    );
    final withIntro = MrNbIntro.prepend(leave);
    expect(withIntro.first.step.id, MrNbIntro.stepId);
    expect(withIntro.length, leave.length + 1);
    expect(MrNbIntro.prepend(withIntro).length, withIntro.length);
  });
}
