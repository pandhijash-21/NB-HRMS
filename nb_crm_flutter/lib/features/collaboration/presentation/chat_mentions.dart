import 'package:flutter/material.dart';

import '../domain/collab_models.dart';

class MentionChoice {
  const MentionChoice({
    required this.label,
    required this.insert,
    this.person,
    this.everyone = false,
  });

  final String label;
  final String insert;
  final CollabProfile? person;
  final bool everyone;
}

final _atToken = RegExp(r'(^|[\s])@([^\s@]*)$');

({int start, String query})? mentionDraftQuery(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) return null;
  final before = text.substring(0, cursor);
  final match = _atToken.firstMatch(before);
  if (match == null) return null;
  final at = match.start + match.group(1)!.length;
  return (start: at, query: match.group(2) ?? '');
}

List<MentionChoice> mentionChoicesFor({
  required ChatChannel channel,
  required String? me,
  required String query,
}) {
  if (!channel.isGroup) return const [];
  final q = query.trim().toLowerCase();
  final others = channel.members.where((m) => m.userId != me && m.userId.isNotEmpty).toList();
  final hits = <MentionChoice>[
    if (q.isEmpty || 'all'.startsWith(q) || 'everyone'.startsWith(q))
      const MentionChoice(label: 'Everyone', insert: '@all ', everyone: true),
  ];
  for (final p in others) {
    final name = p.name.trim();
    if (name.isEmpty) continue;
    final hay = [
      name,
      name.split(RegExp(r'\s+')).first,
      p.email ?? '',
      '${p.employeeId ?? ''}',
    ].join(' ').toLowerCase();
    if (q.isNotEmpty && !hay.contains(q)) continue;
    hits.add(MentionChoice(label: name, insert: '@$name ', person: p));
  }
  return hits.take(8).toList();
}

void applyMentionInsert({
  required TextEditingController draft,
  required int atIndex,
  required String insert,
}) {
  final text = draft.text;
  final cursor = draft.selection.baseOffset < 0 ? text.length : draft.selection.baseOffset;
  final end = cursor.clamp(0, text.length);
  final start = atIndex.clamp(0, end);
  final next = text.replaceRange(start, end, insert);
  draft.value = TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: start + insert.length),
  );
}

List<InlineSpan> mentionTextSpans({
  required String text,
  required List<CollabProfile> members,
  required Color mentionColor,
}) {
  final tokens = <String>['all'];
  for (final m in members) {
    final name = m.name.trim();
    if (name.isEmpty) continue;
    tokens.add(name);
    final first = name.split(RegExp(r'\s+')).first;
    if (first.isNotEmpty && first.toLowerCase() != name.toLowerCase()) {
      tokens.add(first);
    }
  }
  tokens.sort((a, b) => b.length.compareTo(a.length));
  final unique = <String>{};
  final parts = <String>[];
  for (final t in tokens) {
    final key = t.toLowerCase();
    if (unique.add(key)) parts.add(RegExp.escape(t));
  }
  if (parts.isEmpty || !text.contains('@')) {
    return [TextSpan(text: text)];
  }
  final re = RegExp('(@(?:${parts.join('|')}))(?=\$|[\\s,.!?;:])', caseSensitive: false);
  final spans = <InlineSpan>[];
  var last = 0;
  for (final match in re.allMatches(text)) {
    if (match.start > last) {
      spans.add(TextSpan(text: text.substring(last, match.start)));
    }
    spans.add(
      TextSpan(
        text: match.group(0),
        style: TextStyle(color: mentionColor, fontWeight: FontWeight.w700),
      ),
    );
    last = match.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return spans;
}
