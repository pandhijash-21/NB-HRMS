import 'package:web/web.dart';

Future<bool> openExternalUrl(String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return false;
  final opened = window.open(trimmed, '_blank');
  return opened != null;
}
