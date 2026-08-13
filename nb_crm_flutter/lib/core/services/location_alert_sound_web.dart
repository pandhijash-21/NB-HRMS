import 'dart:js_interop';

import 'package:web/web.dart';

AudioContext? _ctx;

Future<void> unlockWebAlertAudio() async {
  try {
    _ctx ??= AudioContext();
    await _ctx!.resume().toDart;
  } catch (_) {}
}

Future<void> playWebAlertBeep() async {
  await unlockWebAlertAudio();
  final ctx = _ctx;
  if (ctx == null) return;

  void beep(num freq, num start, num dur) {
    final osc = ctx.createOscillator();
    final gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(freq, ctx.currentTime + start);
    final t0 = ctx.currentTime + start;
    gain.gain.setValueAtTime(0.0001, t0);
    gain.gain.exponentialRampToValueAtTime(0.2, t0 + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(t0);
    osc.stop(t0 + dur + 0.03);
  }

  beep(880, 0, 0.16);
  beep(1175, 0.22, 0.16);
  beep(988, 0.44, 0.24);
}
