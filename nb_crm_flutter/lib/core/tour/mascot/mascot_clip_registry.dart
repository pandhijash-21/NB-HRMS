import '../models/tour_models.dart';

class MascotClip {
  const MascotClip({
    required this.id,
    required this.mp4,
    required this.gif,
  });

  final String id;
  final String mp4;
  final String gif;
}

class MascotClipRegistry {
  MascotClipRegistry._();
  static final MascotClipRegistry instance = MascotClipRegistry._();

  static const welcome = MascotClip(
    id: 'welcome',
    mp4: 'assets/clips/processed/mr_nb_welcome.mp4',
    gif: 'assets/clips/processed/mr_nb_welcome.gif',
  );
  static const wave = MascotClip(
    id: 'wave',
    mp4: 'assets/clips/processed/mr_nb_wave.mp4',
    gif: 'assets/clips/processed/mr_nb_wave.gif',
  );
  static const pointing = MascotClip(
    id: 'pointing',
    mp4: 'assets/clips/processed/mr_nb_pointing.mp4',
    gif: 'assets/clips/processed/mr_nb_pointing.gif',
  );
  static const thinking = MascotClip(
    id: 'thinking',
    mp4: 'assets/clips/processed/mr_nb_thinking.mp4',
    gif: 'assets/clips/processed/mr_nb_thinking.gif',
  );
  static const thumbsUp = MascotClip(
    id: 'thumbs_up',
    mp4: 'assets/clips/processed/mr_nb_thumbs_up.mp4',
    gif: 'assets/clips/processed/mr_nb_thumbs_up.gif',
  );
  static const idle = MascotClip(
    id: 'idle',
    mp4: 'assets/clips/processed/mr_nb_idle.mp4',
    gif: 'assets/clips/processed/mr_nb_idle.gif',
  );
  static const sideWave = MascotClip(
    id: 'side_wave',
    mp4: 'assets/clips/processed/mr_nb_side_wave.mp4',
    gif: 'assets/clips/processed/mr_nb_side_wave.gif',
  );

  static const _all = [
    welcome,
    wave,
    pointing,
    thinking,
    thumbsUp,
    idle,
    sideWave,
  ];

  MascotClip? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final clip in _all) {
      if (clip.id == id) return clip;
    }
    return null;
  }

  MascotClip? resolve({
    required TourStep step,
    String? sectionClip,
    String? moduleClip,
  }) {
    return byId(step.mascotClip) ??
        byId(sectionClip) ??
        byId(moduleClip) ??
        _fallbackFor(step.type);
  }

  MascotClip? _fallbackFor(TourStepType type) {
    return switch (type) {
      TourStepType.intro => welcome,
      TourStepType.navigation => wave,
      TourStepType.highlight => pointing,
      TourStepType.information => thinking,
      TourStepType.video => idle,
      TourStepType.interactive => pointing,
      TourStepType.completion => thumbsUp,
    };
  }
}
