import 'picked_file_data.dart';
export 'picked_file_data.dart';

import 'clipboard_image_helper_io.dart'
    if (dart.library.html) 'clipboard_image_helper_web.dart' as impl;

/// Reads an image from the clipboard (if available).
Future<PickedFileData?> pasteImageFromClipboard() {
  return impl.pasteImageFromClipboard();
}

/// Attaches a paste listener to capture images pasted via Ctrl+V.
/// Returns a disposer function that removes the listener when disposed.
void Function() attachClipboardPasteListener(void Function(PickedFileData data) onImagePasted) {
  return impl.attachClipboardPasteListener(onImagePasted);
}
