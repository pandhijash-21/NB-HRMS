import 'dart:io';
import 'dart:typed_data';

String sttChunkPath() {
  return '${Directory.systemTemp.path}${Platform.pathSeparator}meet-stt-${DateTime.now().millisecondsSinceEpoch}.wav';
}

Future<Uint8List?> readSttChunk(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  final bytes = await file.readAsBytes();
  try {
    await file.delete();
  } catch (_) {}
  return bytes;
}
