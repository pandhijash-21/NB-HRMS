import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/open_url.dart';
import '../domain/collab_models.dart';

String meetWhen(DateTime? value) {
  if (value == null) return '';
  final d = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

String meetDurationLabel(DateTime? start, DateTime? end) {
  if (start == null) return '';
  final finish = end ?? DateTime.now();
  final d = finish.difference(start);
  if (d.isNegative) return '';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
  return '${s}s';
}

String meetingRoomPath(String code, {bool voice = false, bool guest = false}) {
  final path = guest ? '/meet/guest/$code' : '/meet/r/$code';
  return voice ? '$path?voice=1' : path;
}

/// Flutter web uses hash routes; the API joinUrl points at the Next.js app.
String meetingRoomUrl(String code, {bool voice = false, bool guest = false}) {
  final path = meetingRoomPath(code, voice: voice, guest: guest);
  if (kIsWeb) return '${Uri.base.origin}/#$path';
  return path;
}

/// Share URL for this client. Flutter web uses hash routes; the API joinUrl
/// points at the Next.js app on :3000, which is often not running in local Flutter work.
String meetingShareUrl(MeetingItem item) {
  if (kIsWeb && item.code.isNotEmpty) {
    return meetingRoomUrl(item.code);
  }
  return item.joinUrl ?? item.code;
}

/// Opens the call in a **new browser tab** on web so CRM stays on this page.
/// Native builds keep the in-app route. If a popup is blocked, falls back in-app.
Future<void> openMeetRoom(
  BuildContext context,
  String code, {
  bool voice = false,
  bool guest = false,
  PendingBrowserTab? tab,
}) async {
  final inApp = meetingRoomPath(code, voice: voice, guest: guest);
  if (!kIsWeb) {
    tab?.dismiss();
    if (context.mounted) context.push(inApp);
    return;
  }
  final url = meetingRoomUrl(code, voice: voice, guest: guest);
  if (tab != null) {
    tab.goTo(url);
    return;
  }
  final ok = await openExternalUrl(url);
  if (!ok && context.mounted) context.push(inApp);
}

final _meetCodeInText = RegExp(r'/meet/r/([A-Za-z0-9-]+)');

({String code, bool voice})? meetLinkInText(String? content) {
  if (content == null || content.isEmpty) return null;
  final m = _meetCodeInText.firstMatch(content);
  if (m == null) return null;
  final voice = content.contains('voice=1') || content.toLowerCase().contains('voice call');
  return (code: m.group(1)!, voice: voice);
}

/// Voice cards only stay joinable while the meeting is LIVE.
bool meetCardEnded(String? status, {required bool voice}) {
  final s = (status ?? '').trim().toUpperCase();
  if (s == 'ENDED' || s == 'CANCELLED') return true;
  if (s.isEmpty) return false;
  if (voice) return s != 'LIVE';
  return s != 'LIVE' && s != 'SCHEDULED';
}

/// Call from a button press *before* awaiting meeting create, so the tab is not blocked.
PendingBrowserTab? prepareMeetTab() => kIsWeb ? openPendingTab() : null;

void copyMeetLink(BuildContext context, MeetingItem item) {
  Clipboard.setData(ClipboardData(text: meetingShareUrl(item)));
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite copied')));
}

const _sessionKind = 'meet_session_kind_';
const _sessionToken = 'meet_session_token_';
const _sessionName = 'meet_session_name_';
const _sessionAt = 'meet_session_at_';

Future<void> saveMeetSession({
  required String code,
  required bool guest,
  String? guestToken,
  String? guestName,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('$_sessionKind$code', guest ? 'guest' : 'member');
  await prefs.setInt('$_sessionAt$code', DateTime.now().millisecondsSinceEpoch);
  if (guestToken != null) await prefs.setString('$_sessionToken$code', guestToken);
  if (guestName != null) await prefs.setString('$_sessionName$code', guestName);
}

Future<({bool guest, String? guestToken, String? guestName})?> loadMeetSession(String code) async {
  final prefs = await SharedPreferences.getInstance();
  final kind = prefs.getString('$_sessionKind$code');
  if (kind == null) return null;
  final at = prefs.getInt('$_sessionAt$code') ?? 0;
  if (DateTime.now().millisecondsSinceEpoch - at > const Duration(hours: 6).inMilliseconds) {
    await clearMeetSession(code);
    return null;
  }
  return (
    guest: kind == 'guest',
    guestToken: prefs.getString('$_sessionToken$code'),
    guestName: prefs.getString('$_sessionName$code'),
  );
}

Future<void> clearMeetSession(String code) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('$_sessionKind$code');
  await prefs.remove('$_sessionToken$code');
  await prefs.remove('$_sessionName$code');
  await prefs.remove('$_sessionAt$code');
}
