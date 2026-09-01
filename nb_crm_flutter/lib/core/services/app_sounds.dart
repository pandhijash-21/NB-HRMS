import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_sounds_stub.dart' if (dart.library.js_interop) 'app_sounds_web.dart';
import 'location_alert_sound.dart';

/// In-app notification ding and looping incoming-call ringtone.
class AppSounds {
  AppSounds._();

  static final AudioPlayer _notify = AudioPlayer();
  static final AudioPlayer _ring = AudioPlayer();
  static Timer? _webRing;
  static bool _ringing = false;
  static bool _ready = false;

  static Future<void> unlock() async {
    await LocationAlertSound.unlock();
    await unlockWebAppAudio();
    if (_ready) return;
    _ready = true;
    if (kIsWeb) return;
    try {
      await _notify.setReleaseMode(ReleaseMode.stop);
      await _notify.setVolume(1);
      await _ring.setReleaseMode(ReleaseMode.loop);
      await _ring.setVolume(1);
    } catch (_) {}
  }

  static Future<void> playNotify() async {
    try {
      await unlock();
      if (kIsWeb) {
        await playWebNotifyBeep();
        return;
      }
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
      await _notify.stop();
      await _notify.play(AssetSource('sounds/notify.wav'));
    } catch (_) {}
  }

  static Future<void> startRingtone() async {
    if (_ringing) return;
    _ringing = true;
    try {
      await unlock();
      if (kIsWeb) {
        await playWebRingBurst();
        _webRing?.cancel();
        _webRing = Timer.periodic(const Duration(milliseconds: 1700), (_) {
          if (_ringing) unawaited(playWebRingBurst());
        });
        return;
      }
      await _ring.stop();
      await _ring.setReleaseMode(ReleaseMode.loop);
      await _ring.play(AssetSource('sounds/ringtone.wav'));
    } catch (_) {
      _ringing = false;
    }
  }

  static Future<void> stopRingtone() async {
    _ringing = false;
    _webRing?.cancel();
    _webRing = null;
    stopWebRingtone();
    try {
      await _ring.stop();
    } catch (_) {}
  }
}
