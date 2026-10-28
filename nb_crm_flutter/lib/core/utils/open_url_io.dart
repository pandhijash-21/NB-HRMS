import 'dart:io';
import 'dart:typed_data';

import 'package:url_launcher/url_launcher.dart';

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
      final uri = Uri.tryParse(trimmed);
      if (uri == null) return false;
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    return false;
  }
  return false;
}

Future<bool> downloadUrl(String url, String fileName) => openExternalUrl(url);

Future<bool> downloadBytes(Uint8List bytes, String fileName, {String mimeType = 'application/octet-stream'}) async {
  try {
    final file = File(fileName);
    await file.writeAsBytes(bytes);
    return true;
  } catch (_) {
    return false;
  }
}

(void Function(String url), void Function())? openPendingTab() {
  return (
    (String url) {
      openExternalUrl(url);
    },
    () {},
  );
}
