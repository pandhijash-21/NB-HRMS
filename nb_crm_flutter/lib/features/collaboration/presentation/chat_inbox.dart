import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/collab_models.dart';
import 'collab_providers.dart';

const _lastChatKey = 'last_chat_channel_id';

final chatUnreadProvider = NotifierProvider<ChatUnread, int>(ChatUnread.new);

class ChatUnread extends Notifier<int> {
  bool _listening = false;

  @override
  int build() {
    final authenticated = ref.watch(
      authNotifierProvider.select((s) => s.isAuthenticated),
    );
    ref.onDispose(_detach);
    if (!authenticated) {
      _detach();
      return 0;
    }
    Future.microtask(_attach);
    return 0;
  }

  Future<void> refresh() async {
    if (!ref.mounted) return;
    try {
      final channels = await ref.read(chatRepositoryProvider).channels();
      if (!ref.mounted) return;
      state = channels.fold<int>(0, (sum, c) => sum + c.unread);
    } catch (_) {
      /* keep last known count */
    }
  }

  Future<void> _attach() async {
    if (_listening || !ref.mounted) return;
    _listening = true;
    final token = await ref.read(secureStorageProvider).readToken();
    if (token == null || !ref.mounted) {
      _listening = false;
      return;
    }
    final socket = ref.read(collabSocketProvider);
    socket.connect(token: token);
    socket.onNewMessage(_onMessage);
    await refresh();
  }

  void _detach() {
    if (!_listening) return;
    _listening = false;
    try {
      ref.read(collabSocketProvider).offNewMessage(_onMessage);
    } catch (_) {
      /* provider already disposed */
    }
  }

  void _onMessage(ChatMessage message) {
    unawaited(refresh());
  }
}

Future<String?> loadLastChatChannelId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_lastChatKey);
}

Future<void> saveLastChatChannelId(String id) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_lastChatKey, id);
}

Future<void> clearLastChatChannelId() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_lastChatKey);
}
