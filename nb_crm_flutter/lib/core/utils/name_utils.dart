/// Builds an abbreviation from each word in a full name (e.g. "Jash Pandhi" → "JP").
String generateAbbreviation(String fullName) {
  final words = fullName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final buffer = StringBuffer();
  for (final word in words) {
    final letters = word.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (letters.isNotEmpty) {
      buffer.write(letters[0].toUpperCase());
    }
  }
  return buffer.toString();
}

/// Formats a date as increment month label (e.g. "July 2026").
String formatIncrementMonth(DateTime date) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

DateTime? parseIncrementMonth(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  const months = [
    'january', 'february', 'march', 'april', 'may', 'june',
    'july', 'august', 'september', 'october', 'november', 'december',
  ];
  final parts = value.trim().split(RegExp(r'\s+'));
  final monthIndex = months.indexOf(parts.first.toLowerCase());
  if (monthIndex < 0) return null;
  final year = parts.length > 1 ? int.tryParse(parts[1]) : DateTime.now().year;
  return DateTime(year ?? DateTime.now().year, monthIndex + 1);
}
