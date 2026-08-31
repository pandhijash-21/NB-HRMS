import 'dart:io';

Future<bool> openExternalUrl(String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return false;
  try {
    if (Platform.isWindows) {
      await Process.start('cmd', ['/c', 'start', '', trimmed], runInShell: true);
      return true;
    }
    if (Platform.isMacOS) {
      await Process.start('open', [trimmed]);
      return true;
    }
    if (Platform.isLinux) {
      await Process.start('xdg-open', [trimmed]);
      return true;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile builds should add url_launcher; for now fail gracefully.
      return false;
    }
  } catch (_) {
    return false;
  }
  return false;
}

Future<bool> downloadUrl(String url, String fileName) => openExternalUrl(url);

(void Function(String url), void Function())? openPendingTab() {
  return (
    (String url) {
      openExternalUrl(url);
    },
    () {},
  );
}
