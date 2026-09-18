import '../models/tour_models.dart';

/// Spoken hello that is prepended before every tour queue.
class MrNbIntro {
  MrNbIntro._();

  static const stepId = 'mrnb.intro';
  static const moduleId = 'platform.mr_nb';
  static const sectionId = 'platform.mr_nb.meet';

  static const module = TourModule(
    id: moduleId,
    title: 'Mr. NB',
    description: 'Meet your in-app guide.',
    category: TourCategory.other,
    sections: [section],
  );

  static const section = TourSection(
    id: sectionId,
    moduleId: moduleId,
    title: 'Meet Mr. NB',
    description: 'Who I am and how this walkthrough works.',
    estimatedMinutes: 1,
    steps: [step],
  );

  static const step = TourStep(
    id: stepId,
    sectionId: sectionId,
    title: 'Hello, I am Mr. NB',
    description:
        'Your guide inside NB CRM. I will walk the screens you can open, point at the buttons that matter, and read each card out loud. Use Next to continue, Back to hear the previous stop, Replay voice if you missed me, and Close if you want to pause. Stay in this desktop browser — the tour does not run in the mobile app. Tap Let\'s begin when you are ready.',
    order: 0,
    type: TourStepType.intro,
    placement: TourPlacement.auto,
    useMascot: true,
    mascotClip: 'welcome',
    autoScroll: false,
    includeInComplete: false,
  );

  static const queued = QueuedTourStep(module: module, section: section, step: step);

  static bool isIntro(TourStep step) => step.id == stepId;

  static List<QueuedTourStep> prepend(List<QueuedTourStep> queue) {
    if (queue.isEmpty) return queue;
    if (queue.first.step.id == stepId) return queue;
    return [queued, ...queue];
  }
}
