import 'picked_file_data.dart';

/// Reads an image from the system clipboard on desktop / mobile platforms.
Future<PickedFileData?> pasteImageFromClipboard() async {
  return null;
}

/// Attaches a global paste listener. Returns a dispose callback.
void Function() attachClipboardPasteListener(void Function(PickedFileData data) onImagePasted) {
  return () {};
}
