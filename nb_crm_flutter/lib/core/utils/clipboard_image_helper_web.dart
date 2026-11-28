import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'picked_file_data.dart';

Future<PickedFileData?> _readImageFromFile(web.File file) async {
  final completer = Completer<PickedFileData?>();
  final reader = web.FileReader();

  reader.addEventListener(
    'loadend',
    (web.Event _) {
      final buffer = reader.result as JSArrayBuffer?;
      if (buffer == null) {
        completer.complete(null);
        return;
      }
      final bytes = Uint8List.view(buffer.toDart);
      completer.complete(
        PickedFileData(
          bytes: bytes,
          name: file.name.isNotEmpty
              ? file.name
              : 'pasted_image_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );
    }.toJS,
  );

  reader.addEventListener(
    'error',
    (web.Event _) {
      if (!completer.isCompleted) completer.complete(null);
    }.toJS,
  );

  reader.readAsArrayBuffer(file);
  return completer.future;
}

/// Reads an image from the clipboard asynchronously.
Future<PickedFileData?> pasteImageFromClipboard() async {
  try {
    final clipboard = web.window.navigator.clipboard;
    final items = await clipboard.read().toDart;
    final dartItems = items.toDart;
    for (final item in dartItems) {
      final types = item.types.toDart;
      for (final type in types) {
        final typeStr = type.toDart;
        if (typeStr.startsWith('image/')) {
          final blob = await item.getType(typeStr).toDart;
          final file = web.File([blob].toJS, 'pasted_image.png', web.FilePropertyBag(type: typeStr));
          return await _readImageFromFile(file);
        }
      }
    }
  } catch (_) {
    // Clipboard API might be restricted; user can also paste directly via Ctrl+V event
  }
  return null;
}

/// Attaches a global window 'paste' listener that triggers whenever an image is pasted.
/// Returns a disposer function to unregister the listener.
void Function() attachClipboardPasteListener(void Function(PickedFileData data) onImagePasted) {
  final jsListener = (web.Event event) {
    if (!event.isA<web.ClipboardEvent>()) return;
    final clipboardEvent = event as web.ClipboardEvent;
    final clipboardData = clipboardEvent.clipboardData;
    if (clipboardData == null) return;

    final items = clipboardData.items;
    final len = items.length;
    for (var i = 0; i < len; i++) {
      final item = items[i];
      if (item.type.startsWith('image/')) {
        final file = item.getAsFile();
        if (file != null) {
          event.preventDefault();
          unawaited(
            _readImageFromFile(file).then((data) {
              if (data != null) {
                onImagePasted(data);
              }
            }),
          );
          break;
        }
      }
    }
  }.toJS;

  web.window.addEventListener('paste', jsListener);
  return () {
    web.window.removeEventListener('paste', jsListener);
  };
}
