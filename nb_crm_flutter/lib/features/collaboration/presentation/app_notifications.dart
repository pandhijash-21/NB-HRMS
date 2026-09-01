import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/app_sounds.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/collab_socket.dart';
import 'meet_helpers.dart';
import 'collab_providers.dart';

class IncomingCall {
  const IncomingCall({
    required this.code,
    required this.voice,
    required this.title,
    this.body,
    this.channelId,
    this.path,
  });

  final String code;
  final bool voice;
  final String title;
  final String? body;
  final String? channelId;
  final String? path;

  factory IncomingCall.fromJson(Map<String, dynamic> json) {
    final fromLink = meetLinkInText('${json['path'] ?? ''} ${json['body'] ?? ''}');
    final code = sanitizeMeetCode(
      (json['code']?.toString().trim().isNotEmpty == true) ? json['code'].toString() : fromLink?.code,
    );
    final voice = json['voice'] == true ||
        json['kind']?.toString() == 'voice_call' ||
        (json['path']?.toString() ?? '').contains('voice=1') ||
        (json['body']?.toString() ?? '').toLowerCase().contains('voice call');
    return IncomingCall(
      code: code,
      voice: voice,
      title: json['title']?.toString() ?? (voice ? 'Incoming voice call' : 'Incoming meeting'),
      body: json['body']?.toString(),
      channelId: json['channelId']?.toString(),
      path: json['path']?.toString(),
    );
  }
}

class AppNotice {
  const AppNotice({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    this.path,
    this.channelId,
    this.code,
    this.read = false,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final DateTime at;
  final String? path;
  final String? channelId;
  final String? code;
  final bool read;

  AppNotice copyWith({bool? read}) => AppNotice(
        id: id,
        kind: kind,
        title: title,
        body: body,
        at: at,
        path: path,
        channelId: channelId,
        code: code,
        read: read ?? this.read,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'title': title,
        'body': body,
        'at': at.toIso8601String(),
        'path': path,
        'channelId': channelId,
        'code': code,
        'read': read,
      };

  factory AppNotice.fromJson(Map<String, dynamic> json) {
    return AppNotice(
      id: json['id']?.toString() ?? UniqueKey().toString(),
      kind: json['kind']?.toString() ?? 'chat',
      title: json['title']?.toString() ?? 'Notification',
      body: json['body']?.toString() ?? '',
      at: DateTime.tryParse('${json['at'] ?? ''}') ?? DateTime.now(),
      path: json['path']?.toString(),
      channelId: json['channelId']?.toString(),
      code: json['code']?.toString(),
      read: json['read'] == true,
    );
  }
}

class AppNotificationsState {
  const AppNotificationsState({
    this.items = const [],
    this.incoming,
  });

  final List<AppNotice> items;
  final IncomingCall? incoming;

  int get unread => items.where((n) => !n.read).length;
}

class AppNotifications extends Notifier<AppNotificationsState> {
  static const _prefsKey = 'app_notifications_v1';
  bool _listening = false;
  CollabSocket? _socket;
  String? _me;
  AppNotificationsState _latest = const AppNotificationsState();

  @override
  AppNotificationsState build() {
    final authenticated = ref.watch(authNotifierProvider.select((s) => s.isAuthenticated));
    _me = ref.watch(authNotifierProvider.select((s) => s.user?.id));
    ref.onDispose(_detach);
    if (!authenticated) {
      _detach();
      unawaited(AppSounds.stopRingtone());
      _latest = const AppNotificationsState();
      return _latest;
    }
    Future.microtask(_attach);
    return _latest;
  }

  void _set(AppNotificationsState next) {
    _latest = next;
    state = next;
  }

  Future<void> _attach() async {
    if (_listening || !ref.mounted) return;
    if (!ref.read(authNotifierProvider).isAuthenticated) return;
    _listening = true;
    await _hydrate();
    final token = await ref.read(secureStorageProvider).readToken();
    if (token == null || !ref.mounted) {
      _listening = false;
      return;
    }
    final socket = ref.read(collabSocketProvider);
    _socket = socket;
    socket.connect(token: token);
    socket.onPushNotify(_onPush);
    socket.onIncomingCall(_onIncoming);
    socket.onMeetingEnded(_onEnded);
  }

  void _detach() {
    if (!_listening && _socket == null) return;
    _listening = false;
    _socket?.offPushNotify(_onPush);
    _socket?.offIncomingCall(_onIncoming);
    _socket?.offMeetingEnded(_onEnded);
    _socket = null;
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || !ref.mounted) return;
      final list = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => AppNotice.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (!ref.mounted) return;
      _set(AppNotificationsState(items: list, incoming: _latest.incoming));
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(state.items.take(40).map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  void _onPush(Map<String, dynamic> data) {
    if (_me != null && data['senderId']?.toString() == _me) return;
    final kind = data['kind']?.toString() ?? 'chat';
    if (kind == 'voice_call' || kind == 'meet_call') {
      _onIncoming(data);
    }
    final notice = AppNotice(
      id: '${DateTime.now().microsecondsSinceEpoch}-${data['channelId'] ?? data['code'] ?? kind}',
      kind: kind,
      title: data['title']?.toString() ?? 'Notification',
      body: data['body']?.toString() ?? '',
      at: DateTime.now(),
      path: data['path']?.toString(),
      channelId: data['channelId']?.toString(),
      code: data['code']?.toString(),
    );
    _set(AppNotificationsState(
      items: [notice, ...state.items].take(40).toList(),
      incoming: state.incoming,
    ));
    unawaited(_persist());
    if (kind != 'voice_call' && kind != 'meet_call') {
      unawaited(AppSounds.playNotify());
    }
  }

  void _onIncoming(Map<String, dynamic> data) {
    if (_me != null && data['senderId']?.toString() == _me) return;
    final call = IncomingCall.fromJson(data);
    if (call.code.isEmpty) return;
    if (state.incoming?.code == call.code) return;
    _set(AppNotificationsState(items: state.items, incoming: call));
    unawaited(AppSounds.startRingtone());
  }

  void _onEnded(String meetingId, String? code) {
    final incoming = state.incoming;
    if (incoming == null) return;
    final ended = sanitizeMeetCode(code);
    if (ended.isNotEmpty && ended == incoming.code) {
      unawaited(dismissCall());
    }
  }

  Future<void> markAllRead() async {
    _set(AppNotificationsState(
      items: [for (final n in state.items) n.copyWith(read: true)],
      incoming: state.incoming,
    ));
    await _persist();
  }

  Future<void> clearAll() async {
    _set(AppNotificationsState(incoming: state.incoming));
    await _persist();
  }

  Future<void> dismissCall() async {
    await AppSounds.stopRingtone();
    if (!ref.mounted) return;
    _set(AppNotificationsState(items: state.items));
  }

  Future<void> acceptCall(BuildContext context) async {
    final call = state.incoming;
    await dismissCall();
    if (call == null || !context.mounted) return;
    await openMeetRoom(context, call.code, voice: call.voice, auto: true);
  }
}

final appNotificationsProvider =
    NotifierProvider<AppNotifications, AppNotificationsState>(AppNotifications.new);
