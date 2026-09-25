/// Release name from `pubspec.yaml` (`version:` before `+`).
/// The web splash label in `web/index.html` (`#nb-splash-version`) must match.
const kAppVersion = '1.0.1';

/// Negative when [a] is older than [b].
int compareAppVersions(String a, String b) {
  ({List<int> parts, int? build}) parse(String raw) {
    final pieces = raw.trim().split('+');
    final core = pieces.first;
    final parts = core
        .split('.')
        .map((n) => int.tryParse(n.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final build = pieces.length > 1 ? int.tryParse(pieces[1]) : null;
    return (parts: parts, build: build);
  }

  final left = parse(a);
  final right = parse(b);
  final len = left.parts.length > right.parts.length ? left.parts.length : right.parts.length;
  for (var i = 0; i < len; i++) {
    final d = (i < left.parts.length ? left.parts[i] : 0) -
        (i < right.parts.length ? right.parts[i] : 0);
    if (d != 0) return d;
  }
  if (left.build != null && right.build != null && left.build != right.build) {
    return left.build! - right.build!;
  }
  return 0;
}

enum AppUpdateKind { none, soft, hard }

AppUpdateKind appUpdateKind({
  required String current,
  required String minVersion,
  required String maxVersion,
}) {
  final min = minVersion.trim();
  final max = maxVersion.trim();
  if (min.isNotEmpty && compareAppVersions(current, min) < 0) {
    return AppUpdateKind.hard;
  }
  if (max.isNotEmpty && compareAppVersions(current, max) < 0) {
    return AppUpdateKind.soft;
  }
  return AppUpdateKind.none;
}
