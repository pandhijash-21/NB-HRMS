void printQuotationWeb({
  required String title,
  required String htmlContent,
  void Function(String message)? onMessage,
}) {
  onMessage?.call('Printing is supported directly in the web browser.');
}
