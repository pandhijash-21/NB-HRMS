import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import 'location_alert_sound_stub.dart'
    if (dart.library.js_interop) 'location_alert_sound_web.dart';

/// Cross-platform location-alert sound (web, PWA, Android, iOS).
class LocationAlertSound {
  LocationAlertSound._();

  static final AudioPlayer _player = AudioPlayer();
  static bool _ready = false;
  static bool _playing = false;

  static Future<void> unlock() async {
    if (_ready) {
      await unlockWebAlertAudio();
      return;
    }
    _ready = true;
    try {
      await unlockWebAlertAudio();
    } catch (_) {}
    if (kIsWeb) return;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.notification,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
    } catch (_) {}
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setPlayerMode(PlayerMode.lowLatency);
      await _player.setVolume(1);
    } catch (_) {}
  }

  static Future<void> play() async {
    if (_playing) return;
    _playing = true;
    try {
      await unlock();
      if (kIsWeb) {
        await playWebAlertBeep();
        return;
      }
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {}
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
      try {
        await _player.stop();
        await _player.play(AssetSource('sounds/location_alert.wav'));
      } catch (_) {
        try {
          await _player.play(AssetSource('sounds/location_alert.wav'));
        } catch (_) {}
      }
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 1100), () {
        _playing = false;
      });
    }
  }
}
