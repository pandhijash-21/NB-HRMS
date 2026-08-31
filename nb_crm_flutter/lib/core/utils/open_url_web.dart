import 'package:web/web.dart';

Future<bool> openExternalUrl(String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return false;
  final opened = window.open(trimmed, '_blank');
  if (opened != null) return true;
  // Some browsers block window.open after an await; an <a target=_blank> click
  // still works when it is the same user-gesture chain.
  final a = HTMLAnchorElement()
    ..href = trimmed
    ..target = '_blank'
    ..rel = 'noopener';
  document.body?.append(a);
  a.click();
  a.remove();
  return true;
}

/// Open a blank tab in the same click; navigate it after an async join/create.
/// Opening `/#/` first boots the CRM and races the later hash change, so the
/// host lands on the lobby instead of joining their own room.
(void Function(String url), void Function())? openPendingTab() {
  final win = window.open('about:blank', '_blank');
  if (win == null) return null;
  return (
    (String url) {
      try {
        win.location.assign(url);
      } catch (_) {
        win.location.href = url;
      }
    },
    () {
      try {
        win.close();
      } catch (_) {}
    },
  );
}

Future<bool> downloadUrl(String url, String fileName) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return false;
  final a = HTMLAnchorElement()
    ..href = trimmed
    ..download = fileName
    ..target = '_blank'
    ..rel = 'noopener';
  document.body?.append(a);
  a.click();
  a.remove();
  return true;
}
