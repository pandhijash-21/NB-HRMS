import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

import 'picked_file_data.dart';

Future<PickedFileData?> pickFileFromDevice({
  bool imagesOnly = true,
  List<String>? extensions,
}) async {
  final completer = Completer<PickedFileData?>();
  final input = HTMLInputElement()
    ..type = 'file'
    ..accept = _acceptValue(imagesOnly: imagesOnly, extensions: extensions)
    ..multiple = false
    ..style.display = 'none';

  void cleanup() => input.remove();

  input.addEventListener(
    'change',
    (Event event) {
      event;
      final files = input.files;
      if (files == null || files.length == 0) {
        cleanup();
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final file = files.item(0);
      if (file == null) {
        cleanup();
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final reader = FileReader();
      reader.addEventListener(
        'loadend',
        (Event _) {
          cleanup();
          if (completer.isCompleted) return;
          final buffer = reader.result as JSArrayBuffer?;
          if (buffer == null) {
            completer.complete(null);
            return;
          }
          completer.complete(
            PickedFileData(
              bytes: buffer.toDart.asUint8List(),
              name: file.name.isNotEmpty ? file.name : 'upload.jpg',
            ),
          );
        }.toJS,
      );
      reader.readAsArrayBuffer(file);
    }.toJS,
  );

  document.body?.append(input);
  input.click();

  return completer.future.timeout(
    const Duration(minutes: 2),
    onTimeout: () {
      cleanup();
      return null;
    },
  );
}

String _acceptValue({required bool imagesOnly, List<String>? extensions}) {
  if (imagesOnly) return 'image/*';
  if (extensions == null || extensions.isEmpty) return '*/*';
  return extensions.map((ext) {
    final normalized = ext.startsWith('.') ? ext : '.$ext';
    return normalized;
  }).join(',');
}
