/// IST (+05:30) helpers for recruitment date/time (no Flutter UI deps).

const Duration kIstOffset = Duration(hours: 5, minutes: 30);

String toDateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime? parseApiDate(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  if (m != null) {
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }
  return DateTime.tryParse(s)?.toLocal();
}

DateTime? parseApiDateTimeIst(dynamic raw) {
  if (raw == null) return null;
  final parsed = DateTime.tryParse(raw.toString().trim());
  if (parsed == null) return null;
  final utc = parsed.isUtc ? parsed : parsed.toUtc();
  return utc.add(kIstOffset);
}

String toApiDateTimeFromIst(DateTime istWallClock) {
  final utc = DateTime.utc(
    istWallClock.year,
    istWallClock.month,
    istWallClock.day,
    istWallClock.hour,
    istWallClock.minute,
  ).subtract(kIstOffset);
  return utc.toIso8601String();
}

String fmtIstDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}

String fmtIstDateTime(DateTime? ist) {
  if (ist == null) return '—';
  return '${fmtIstDate(ist)} '
      '${ist.hour.toString().padLeft(2, '0')}:'
      '${ist.minute.toString().padLeft(2, '0')} IST';
}
