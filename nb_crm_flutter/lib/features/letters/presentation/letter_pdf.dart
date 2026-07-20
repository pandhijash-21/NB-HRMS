import 'letter_pdf_io.dart'
    if (dart.library.html) 'letter_pdf_web.dart' as impl;

/// Opens a print/Save-as-PDF window (web) or shows guidance (mobile).
void downloadLetterPdf({
  required String title,
  required String html,
  void Function(String message)? onMessage,
}) {
  impl.downloadLetterPdf(title: title, html: html, onMessage: onMessage);
}
