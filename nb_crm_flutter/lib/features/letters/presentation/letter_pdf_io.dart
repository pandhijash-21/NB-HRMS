void downloadLetterPdf({
  required String title,
  required String html,
  void Function(String message)? onMessage,
}) {
  onMessage?.call('Open the web app to download this letter as PDF.');
}
