import 'open_url_io.dart' if (dart.library.html) 'open_url_web.dart' as impl;

/// Opens an http(s) URL in the system browser / a new tab.
Future<bool> openExternalUrl(String url) => impl.openExternalUrl(url);

/// Best-effort file download. Cross-origin hosts may still open in a tab.
Future<bool> downloadUrl(String url, String fileName) => impl.downloadUrl(url, fileName);

/// A tab opened during a click so it can be pointed at a URL after an await
/// (browsers otherwise block `window.open` once the gesture is gone).
class PendingBrowserTab {
  const PendingBrowserTab(this._goTo, [this._close]);

  final void Function(String url) _goTo;
  final void Function()? _close;

  void goTo(String url) => _goTo(url);

  void dismiss() => _close?.call();
}

/// Must be called from a user gesture (button press), before any `await`.
PendingBrowserTab? openPendingTab() {
  final pair = impl.openPendingTab();
  if (pair == null) return null;
  return PendingBrowserTab(pair.$1, pair.$2);
}
