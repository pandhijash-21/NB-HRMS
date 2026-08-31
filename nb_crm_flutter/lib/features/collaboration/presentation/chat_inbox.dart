import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/collab_socket.dart';
import '../domain/collab_models.dart';
import 'collab_providers.dart';

const _lastChatKey = 'last_chat_channel_id';

final chatUnreadProvider = NotifierProvider<ChatUnread, int>(ChatUnread.new);

class ChatUnread extends Notifier<int> {
  bool _listening = false;
  CollabSocket? _socket;

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
    if (!ref.read(authNotifierProvider).isAuthenticated) return;
    try {
      final channels = await ref.read(chatRepositoryProvider).channels();
      if (!ref.mounted) return;
      if (!ref.read(authNotifierProvider).isAuthenticated) return;
      state = channels.fold<int>(0, (sum, c) => sum + c.unread);
    } catch (_) {
      /* keep last known count */
    }
  }

  Future<void> _attach() async {
    if (_listening || !ref.mounted) return;
    if (!ref.read(authNotifierProvider).isAuthenticated) return;
    _listening = true;
    final token = await ref.read(secureStorageProvider).readToken();
    if (token == null || !ref.mounted || !ref.read(authNotifierProvider).isAuthenticated) {
      _listening = false;
      return;
    }
    final socket = ref.read(collabSocketProvider);
    _socket = socket;
    socket.connect(token: token);
    socket.onNewMessage(_onMessage);
    await refresh();
  }

  void _detach() {
    if (!_listening && _socket == null) return;
    _listening = false;
    _socket?.offNewMessage(_onMessage);
    _socket = null;
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
