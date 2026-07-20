import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

void downloadLetterPdf({
  required String title,
  required String html,
  void Function(String message)? onMessage,
}) {
  final safeTitle = title
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  final w = window.open('', '_blank');
  if (w == null) {
    onMessage?.call('Please allow pop-ups to download the PDF');
    return;
  }

  final docHtml = '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <title>$safeTitle</title>
  <style>
    @page { margin: 18mm; size: A4; }
    body { margin: 0; font-family: Arial, Helvetica, sans-serif; color: #111; background: #fff; }
    .sheet { padding: 8mm; }
    img { max-width: 100%; }
  </style>
</head>
<body>
  <div class="sheet">$html</div>
</body>
</html>''';

  w.document.open();
  w.document.write(docHtml.toJS);
  w.document.close();
  Future<void>.delayed(const Duration(milliseconds: 300), () {
    w.print();
  });
}
