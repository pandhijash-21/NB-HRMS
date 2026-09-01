import 'package:livekit_client/livekit_client.dart';

class MeetLocalRecorder {
  bool get active => false;

  Future<void> start({required Room room, required String code}) async {
    throw UnsupportedError(
      'Record this meeting on the host phone or computer app, or in a desktop browser. The file stays on that device.',
    );
  }

  Future<String?> stopAndSave() async => null;

  Future<void> discard() async {}
}
