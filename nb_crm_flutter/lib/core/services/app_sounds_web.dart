import 'dart:js_interop';

import 'package:web/web.dart';

AudioContext? _ctx;

Future<void> unlockWebAppAudio() async {
  try {
    _ctx ??= AudioContext();
    await _ctx!.resume().toDart;
  } catch (_) {}
}

void _beep(num freq, num start, num dur, {num amp = 0.2}) {
  final ctx = _ctx;
  if (ctx == null) return;
  final osc = ctx.createOscillator();
  final gain = ctx.createGain();
  osc.type = 'sine';
  osc.frequency.setValueAtTime(freq, ctx.currentTime + start);
  final t0 = ctx.currentTime + start;
  gain.gain.setValueAtTime(0.0001, t0);
  gain.gain.exponentialRampToValueAtTime(amp, t0 + 0.02);
  gain.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  osc.connect(gain);
  gain.connect(ctx.destination);
  osc.start(t0);
  osc.stop(t0 + dur + 0.03);
}

Future<void> playWebNotifyBeep() async {
  await unlockWebAppAudio();
  _beep(880, 0, 0.08, amp: 0.16);
  _beep(1320, 0.1, 0.14, amp: 0.18);
}

Future<void> playWebRingBurst() async {
  await unlockWebAppAudio();
  _beep(440, 0, 0.38, amp: 0.22);
  _beep(554, 0.46, 0.38, amp: 0.22);
}

void stopWebRingtone() {}
