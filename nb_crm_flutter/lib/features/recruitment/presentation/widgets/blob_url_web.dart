import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

String createBlobUrl(Uint8List bytes, String mimeType) {
  final parts = [bytes.toJS].toJS as JSArray<BlobPart>;
  final blob = Blob(parts, BlobPropertyBag(type: mimeType));
  return URL.createObjectURL(blob);
}

void revokeBlobUrl(String? url) {
  if (url == null || url.isEmpty) return;
  URL.revokeObjectURL(url);
}
