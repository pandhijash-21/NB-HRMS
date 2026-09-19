import '../../../core/network/dio_client.dart';

class AppUserNotification {
  const AppUserNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.createdAt,
    this.path,
    this.senderId,
    this.readAt,
  });

  final String id;
  final String title;
  final String body;
  final String kind;
  final DateTime createdAt;
  final String? path;
  final String? senderId;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory AppUserNotification.fromJson(Map<String, dynamic> json) {
    return AppUserNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Notification',
      body: json['body']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'announce',
      path: json['path']?.toString(),
      senderId: json['senderId']?.toString(),
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
      readAt: json['readAt'] != null
          ? DateTime.tryParse('${json['readAt']}')
          : null,
    );
  }
}

class NotificationsRepository {
  NotificationsRepository({required DioClient dioClient}) : _dio = dioClient;

  final DioClient _dio;

  Future<List<AppUserNotification>> list({int limit = 50}) {
    return _dio.getEnvelope<List<AppUserNotification>>(
      'notifications',
      queryParameters: {'limit': limit},
      parse: (raw) {
        if (raw is! List) return const [];
        return raw
            .whereType<Map>()
            .map((e) => AppUserNotification.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
    );
  }

  Future<int> unreadCount() {
    return _dio.getEnvelope<int>(
      'notifications/unread-count',
      parse: (raw) {
        if (raw is Map && raw['count'] is int) return raw['count'] as int;
        if (raw is Map) return int.tryParse('${raw['count']}') ?? 0;
        return 0;
      },
    );
  }

  Future<({int sent})> broadcast({
    required String title,
    required String body,
  }) {
    return _dio.postEnvelope(
      'notifications/broadcast',
      data: {'title': title, 'body': body, 'path': '/notifications'},
      parse: (raw) {
        final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        return (sent: int.tryParse('${map['sent']}') ?? 0);
      },
    );
  }

  Future<void> markRead(String id) {
    return _dio.postEnvelope<void>('notifications/$id/read', parse: (_) {});
  }

  Future<void> markAllRead() {
    return _dio.postEnvelope<void>('notifications/read-all', parse: (_) {});
  }
}
