import 'dart:typed_data';

import 'package:http/http.dart' as http;

String sttChunkPath() => 'meet-stt.wav';

Future<Uint8List?> readSttChunk(String path) async {
  try {
    final res = await http.get(Uri.parse(path));
    if (res.statusCode >= 200 && res.statusCode < 300) return res.bodyBytes;
  } catch (_) {}
  return null;
}
