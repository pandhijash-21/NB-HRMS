import 'dart:typed_data';

import 'package:livekit_client/livekit_client.dart';

class LivekitWebSttTap {
  static const supported = false;

  bool get attached => false;

  DateTime? get chunkStarted => null;

  void attach(Room room, {required bool micOn}) {}

  void setMicEnabled(bool on) {}

  void stop() {}

  ({Uint8List bytes, DateTime started, DateTime ended})? takeChunk() => null;
}
