import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/network/app_config.dart';
import '../domain/collab_models.dart';

class CollabSocket {
  io.Socket? _socket;
  Timer? _heartbeat;
  String? _token;
  String? _joinedMeetingId;
  String? _joinedChannelId;

  final _newMessage = <void Function(ChatMessage)>[];
  final _messageUpdated = <void Function(ChatMessage)>[];
  final _channelRead = <void Function(String, String, DateTime?)>[];
  final _userTyping = <void Function(String, String)>[];
  final _meetingEnded = <void Function(String meetingId, String? code)>[];
  final _presence = <void Function(String userId, bool online)>[];

  io.Socket connect({required String token}) {
    if (_socket != null && _token == token) {
      if (!_socket!.connected) _socket!.connect();
      return _socket!;
    }
    _heartbeat?.cancel();
    _socket?.dispose();
    _token = token;
    final socket = io.io(
      AppConfig.socketOrigin,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .setAuth({'token': token})
          .setPath('/socket.io')
          .build(),
    );
    socket.on('connect', (_) {
      final meetingId = _joinedMeetingId;
      if (meetingId != null && meetingId.isNotEmpty) {
        socket.emit('join_meeting', meetingId);
      }
      final channelId = _joinedChannelId;
      if (channelId != null && channelId.isNotEmpty) {
        socket.emit('join_channel', channelId);
      }
    });
    socket.on('new_message', (data) {
      if (data is! Map) return;
      final message = ChatMessage.fromJson(Map<String, dynamic>.from(data));
      for (final cb in List.of(_newMessage)) {
        cb(message);
      }
    });
    socket.on('message_updated', (data) {
      if (data is! Map) return;
      final message = ChatMessage.fromJson(Map<String, dynamic>.from(data));
      for (final cb in List.of(_messageUpdated)) {
        cb(message);
      }
    });
    socket.on('channel_read', (data) {
      if (data is! Map) return;
      final channelId = '${data['channelId'] ?? ''}';
      final userId = '${data['userId'] ?? ''}';
      final at = DateTime.tryParse('${data['lastReadAt'] ?? ''}');
      for (final cb in List.of(_channelRead)) {
        cb(channelId, userId, at);
      }
    });
    socket.on('user_typing', (data) {
      if (data is! Map) return;
      final channelId = '${data['channelId'] ?? ''}';
      final name = '${data['name'] ?? ''}';
      for (final cb in List.of(_userTyping)) {
        cb(channelId, name);
      }
    });
    socket.on('meeting_ended', (data) {
      if (data is! Map) return;
      final id = data['meetingId']?.toString() ?? '';
      final code = data['code']?.toString();
      if (id.isEmpty && (code == null || code.isEmpty)) return;
      for (final cb in List.of(_meetingEnded)) {
        cb(id, code);
      }
    });
    socket.on('presence', (data) {
      if (data is! Map) return;
      final userId = data['userId']?.toString() ?? '';
      if (userId.isEmpty) return;
      final online = data['online'] == true;
      for (final cb in List.of(_presence)) {
        cb(userId, online);
      }
    });
    socket.connect();
    _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) {
      if (socket.connected) socket.emit('heartbeat');
    });
    _socket = socket;
    return socket;
  }

  void joinChannel(String id) {
    if (id.isEmpty) return;
    _joinedChannelId = id;
    _socket?.emit('join_channel', id);
  }

  void leaveChannel(String id) {
    if (id.isEmpty) return;
    if (_joinedChannelId == id) _joinedChannelId = null;
    _socket?.emit('leave_channel', id);
  }
  void sendMessage(String channelId, String content, {String? replyToId}) =>
      _socket?.emit('send_message', {
        'channelId': channelId,
        'content': content,
        if (replyToId != null) 'replyToId': replyToId,
      });
  void typing(String channelId) => _socket?.emit('typing', {'channelId': channelId});
  void react(String messageId, String emoji) =>
      _socket?.emit('react', {'messageId': messageId, 'emoji': emoji});

  void joinMeeting(String id) {
    _joinedMeetingId = id;
    if (_socket?.connected == true) {
      _socket!.emit('join_meeting', id);
    }
  }

  void meetingChat({
    required String meetingId,
    required String content,
    String scope = 'ROOM',
    String? recipientUserId,
  }) {
    _socket?.emit('meeting_chat', {
      'meetingId': meetingId,
      'content': content,
      'scope': scope,
      if (recipientUserId != null) 'recipientUserId': recipientUserId,
    });
  }

  void meetingHand({required String meetingId, required bool raised}) {
    _socket?.emit('meeting_hand', {'meetingId': meetingId, 'raised': raised});
  }

  void meetingReaction({required String meetingId, required String emoji}) {
    _socket?.emit('meeting_reaction', {'meetingId': meetingId, 'emoji': emoji});
  }

  void onNewMessage(void Function(ChatMessage) cb) {
    if (!_newMessage.contains(cb)) _newMessage.add(cb);
  }

  void offNewMessage(void Function(ChatMessage) cb) => _newMessage.remove(cb);

  void onMessageUpdated(void Function(ChatMessage) cb) {
    if (!_messageUpdated.contains(cb)) _messageUpdated.add(cb);
  }

  void offMessageUpdated(void Function(ChatMessage) cb) => _messageUpdated.remove(cb);

  void onChannelRead(void Function(String channelId, String userId, DateTime? at) cb) {
    if (!_channelRead.contains(cb)) _channelRead.add(cb);
  }

  void offChannelRead(void Function(String, String, DateTime?) cb) => _channelRead.remove(cb);

  void onUserTyping(void Function(String channelId, String name) cb) {
    if (!_userTyping.contains(cb)) _userTyping.add(cb);
  }

  void offUserTyping(void Function(String, String) cb) => _userTyping.remove(cb);

  void onMeetingChat(void Function(Map<String, dynamic>) cb) {
    _socket?.off('meeting_chat');
    _socket?.on('meeting_chat', (data) {
      if (data is Map) cb(Map<String, dynamic>.from(data));
    });
  }

  void onMeetingHand(void Function(Map<String, dynamic>) cb) {
    _socket?.off('meeting_hand');
    _socket?.on('meeting_hand', (data) {
      if (data is Map) cb(Map<String, dynamic>.from(data));
    });
  }

  void onMeetingReaction(void Function(Map<String, dynamic>) cb) {
    _socket?.off('meeting_reaction');
    _socket?.on('meeting_reaction', (data) {
      if (data is Map) cb(Map<String, dynamic>.from(data));
    });
  }

  void onWaitingUpdate(void Function(List<MeetingPerson>) cb) {
    _socket?.off('waiting_update');
    _socket?.on('waiting_update', (data) {
      if (data is Map) {
        final waiting = (data['waiting'] as List? ?? [])
            .whereType<Map>()
            .map((e) => MeetingPerson.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        cb(waiting);
      }
    });
  }

  void onJoinApproved(void Function(String? participantId) cb) {
    _socket?.off('join_approved');
    _socket?.on('join_approved', (data) {
      final id = data is Map ? data['participantId']?.toString() : null;
      cb(id);
    });
  }

  void onJoinDenied(void Function(String? participantId) cb) {
    _socket?.off('join_denied');
    _socket?.on('join_denied', (data) {
      final id = data is Map ? data['participantId']?.toString() : null;
      cb(id);
    });
  }

  void onMeetingEnded(void Function(String meetingId, String? code) cb) {
    if (!_meetingEnded.contains(cb)) _meetingEnded.add(cb);
  }

  void offMeetingEnded(void Function(String meetingId, String? code) cb) =>
      _meetingEnded.remove(cb);

  void onPresence(void Function(String userId, bool online) cb) {
    if (!_presence.contains(cb)) _presence.add(cb);
  }

  void offPresence(void Function(String userId, bool online) cb) => _presence.remove(cb);

  void onMeetingEndProgress(void Function(Map<String, dynamic> row) cb) {
    _socket?.off('meeting_end_progress');
    _socket?.on('meeting_end_progress', (data) {
      if (data is Map) cb(Map<String, dynamic>.from(data));
    });
  }

  void dispose() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _token = null;
    _joinedMeetingId = null;
    _joinedChannelId = null;
    _newMessage.clear();
    _messageUpdated.clear();
    _channelRead.clear();
    _userTyping.clear();
    _meetingEnded.clear();
    _presence.clear();
    _socket?.dispose();
    _socket = null;
  }
}
