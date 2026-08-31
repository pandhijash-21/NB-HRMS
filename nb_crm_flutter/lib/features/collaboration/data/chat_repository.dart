import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../domain/collab_models.dart';

class ChatRepository {
  const ChatRepository({required DioClient dioClient}) : _dio = dioClient;
  final DioClient _dio;

  Future<List<CollabProfile>> directory(String q, {int limit = 40, int skip = 0}) {
    return _dio.getEnvelope(
      'chat/directory',
      queryParameters: {'q': q, 'limit': limit, 'skip': skip},
      parse: (raw) => (raw as List? ?? [])
          .whereType<Map>()
          .map((e) => CollabProfile.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Future<List<ChatChannel>> channels() {
    return _dio.getEnvelope(
      'chat/channels',
      parse: (raw) => (raw as List? ?? [])
          .whereType<Map>()
          .map((e) => ChatChannel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Future<ChatChannel> startDm(String userId) {
    return _dio.postEnvelope(
      'chat/channels/dm',
      data: {'userId': userId},
      parse: (raw) => ChatChannel.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ChatChannel> createGroup(String name, List<String> memberIds) {
    return _dio.postEnvelope(
      'chat/channels/group',
      data: {'name': name, 'memberIds': memberIds},
      parse: (raw) => ChatChannel.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ChatChannel> getChannel(String channelId) {
    return _dio.getEnvelope(
      'chat/channels/$channelId',
      parse: (raw) => ChatChannel.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ChatChannel> updateGroup(
    String channelId, {
    String? name,
    String? topic,
    String? avatarUrl,
    bool clearAvatar = false,
    List<String>? addMemberIds,
    List<String>? removeMemberIds,
  }) {
    return _dio.patchEnvelope(
      'chat/channels/$channelId',
      data: {
        if (name != null) 'name': name,
        if (topic != null) 'topic': topic,
        if (clearAvatar) 'avatarUrl': null,
        if (!clearAvatar && avatarUrl != null) 'avatarUrl': avatarUrl,
        if (addMemberIds != null) 'addMemberIds': addMemberIds,
        if (removeMemberIds != null) 'removeMemberIds': removeMemberIds,
      },
      parse: (raw) => ChatChannel.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ChatChannel> setMemberRole(String channelId, String userId, String role) {
    return _dio.patchEnvelope(
      'chat/channels/$channelId/members/$userId',
      data: {'role': role},
      parse: (raw) => ChatChannel.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> leaveGroup(String channelId) async {
    await _dio.postEnvelope<Map<String, dynamic>>(
      'chat/channels/$channelId/leave',
      data: {},
      parse: (raw) => Map<String, dynamic>.from((raw as Map?) ?? const {}),
    );
  }

  Future<List<ChatMessage>> messages(String channelId) {
    return _dio.getEnvelope(
      'chat/channels/$channelId/messages',
      parse: (raw) {
        final items = raw is Map ? raw['items'] : raw;
        return (items as List? ?? [])
            .whereType<Map>()
            .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
    );
  }

  Future<void> markRead(String channelId) async {
    await _dio.postEnvelope<Map<String, dynamic>>(
      'chat/channels/$channelId/read',
      data: {},
      parse: (raw) => Map<String, dynamic>.from((raw as Map?) ?? const {}),
    );
  }

  Future<ChatMessage> send({
    required String channelId,
    String? content,
    String? replyToId,
    List<Map<String, dynamic>>? attachments,
  }) {
    return _dio.postEnvelope(
      'chat/channels/$channelId/messages',
      data: {
        if (content != null) 'content': content,
        if (replyToId != null) 'replyToId': replyToId,
        if (attachments != null) 'attachments': attachments,
      },
      parse: (raw) => ChatMessage.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ChatMessage> editMessage(String id, String content) {
    return _dio.patchEnvelope(
      'chat/messages/$id',
      data: {'content': content},
      parse: (raw) => ChatMessage.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ChatMessage> deleteMessage(String id) {
    return _dio.deleteEnvelope(
      'chat/messages/$id',
      parse: (raw) => ChatMessage.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<String> attachmentUrl(String id) {
    return _dio.getEnvelope(
      'chat/attachments/$id',
      parse: (raw) {
        final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        return map['url']?.toString() ?? '';
      },
    );
  }

  Future<Map<String, dynamic>> upload(List<int> bytes, String fileName) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final res = await _dio.dio.post<Map<String, dynamic>>('chat/uploads', data: form);
    final body = res.data;
    if (body == null || body['success'] != true) {
      throw Exception(body?['error'] ?? 'Upload failed');
    }
    return Map<String, dynamic>.from(body['data'] as Map);
  }
}
