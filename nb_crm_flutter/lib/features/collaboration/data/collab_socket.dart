import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/network/app_config.dart';
import '../domain/collab_models.dart';

class CollabSocket {
  io.Socket? _socket;
  Timer? _heartbeat;
  String? _token;
  String? _joinedMeetingId;

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
    });
    socket.connect();
    _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) {
      if (socket.connected) socket.emit('heartbeat');
    });
    _socket = socket;
    return socket;
  }

  void joinChannel(String id) => _socket?.emit('join_channel', id);
  void leaveChannel(String id) => _socket?.emit('leave_channel', id);
  void sendMessage(String channelId, String content) =>
      _socket?.emit('send_message', {'channelId': channelId, 'content': content});
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
    _socket?.off('new_message');
    _socket?.on('new_message', (data) {
      if (data is Map) cb(ChatMessage.fromJson(Map<String, dynamic>.from(data)));
    });
  }

  void onMessageUpdated(void Function(ChatMessage) cb) {
    _socket?.off('message_updated');
    _socket?.on('message_updated', (data) {
      if (data is Map) cb(ChatMessage.fromJson(Map<String, dynamic>.from(data)));
    });
  }

  void onChannelRead(void Function(String channelId, String userId, DateTime? at) cb) {
    _socket?.off('channel_read');
    _socket?.on('channel_read', (data) {
      if (data is Map) {
        cb(
          '${data['channelId'] ?? ''}',
          '${data['userId'] ?? ''}',
          DateTime.tryParse('${data['lastReadAt'] ?? ''}'),
        );
      }
    });
  }

  void onUserTyping(void Function(String channelId, String name) cb) {
    _socket?.off('user_typing');
    _socket?.on('user_typing', (data) {
      if (data is Map) {
        cb('${data['channelId'] ?? ''}', '${data['name'] ?? ''}');
      }
    });
  }

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

  void onMeetingEnded(void Function(String meetingId) cb) {
    _socket?.off('meeting_ended');
    _socket?.on('meeting_ended', (data) {
      final id = data is Map ? data['meetingId']?.toString() : null;
      if (id != null && id.isNotEmpty) cb(id);
    });
  }

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
    _socket?.dispose();
    _socket = null;
  }
}
