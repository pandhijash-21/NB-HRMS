import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../domain/support_models.dart';

class SupportRepository {
  const SupportRepository({required DioClient dioClient}) : _dio = dioClient;

  final DioClient _dio;

  Future<List<SupportTicket>> listMine() {
    return _dio.getEnvelope<List<SupportTicket>>(
      'support/my',
      parse: (raw) {
        if (raw is! List) throw const FormatException('Invalid support list');
        return raw
            .whereType<Map>()
            .map((e) => SupportTicket.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
    );
  }

  Future<List<SupportTicket>> listQueue({bool includeClosed = false}) {
    return _dio.getEnvelope<List<SupportTicket>>(
      'support/queue',
      queryParameters: {if (includeClosed) 'includeClosed': 'true'},
      parse: (raw) {
        if (raw is! List) throw const FormatException('Invalid support queue');
        return raw
            .whereType<Map>()
            .map((e) => SupportTicket.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
    );
  }

  Future<SupportTicket> getById(String id) {
    return _dio.getEnvelope<SupportTicket>(
      'support/$id',
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid support ticket');
        return SupportTicket.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<SupportTicket> create({
    required String title,
    required String description,
    String? photoUrl,
  }) {
    return _dio.postEnvelope<SupportTicket>(
      'support',
      data: {
        'title': title,
        'description': description,
        if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
      },
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid create response');
        return SupportTicket.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<SupportTicket> setInReview(String id, {required DateTime etaAt, String? note}) {
    return _dio.patchEnvelope<SupportTicket>(
      'support/$id/review',
      data: {
        'etaAt': etaAt.toUtc().toIso8601String(),
        if (note != null && note.isNotEmpty) 'note': note,
      },
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid review response');
        return SupportTicket.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<SupportTicket> resolve(String id, {required String remarks}) {
    return _dio.patchEnvelope<SupportTicket>(
      'support/$id/resolve',
      data: {'remarks': remarks},
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid resolve response');
        return SupportTicket.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<SupportTicket> confirm(String id) {
    return _dio.patchEnvelope<SupportTicket>(
      'support/$id/confirm',
      data: const {},
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid confirm response');
        return SupportTicket.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<SupportTicket> deny(String id, {String? note}) {
    return _dio.patchEnvelope<SupportTicket>(
      'support/$id/deny',
      data: {if (note != null && note.isNotEmpty) 'note': note},
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid deny response');
        return SupportTicket.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<SupportTicket> forceClose(String id, {required String remarks}) {
    return _dio.patchEnvelope<SupportTicket>(
      'support/$id/force-close',
      data: {'remarks': remarks},
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid force-close response');
        return SupportTicket.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<SupportCapabilities> capabilities() {
    return _dio.getEnvelope<SupportCapabilities>(
      'support/capabilities',
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid support capabilities');
        return SupportCapabilities.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<List<SupportHandler>> listHandlers() {
    return _dio.getEnvelope<List<SupportHandler>>(
      'support/handlers',
      parse: (raw) {
        if (raw is! List) throw const FormatException('Invalid support handlers');
        return raw
            .whereType<Map>()
            .map((e) => SupportHandler.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
    );
  }

  Future<List<SupportHandler>> setHandlers(List<int> employeeIds) {
    return _dio.putEnvelope<List<SupportHandler>>(
      'support/handlers',
      data: {'employeeIds': employeeIds},
      parse: (raw) {
        if (raw is! List) throw const FormatException('Invalid set handlers response');
        return raw
            .whereType<Map>()
            .map((e) => SupportHandler.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
    );
  }

  Future<String> uploadPhoto({
    required int employeeId,
    required Uint8List bytes,
    String? filename,
  }) async {
    final multipart = MultipartFile.fromBytes(
      bytes,
      filename: filename ?? 'support-photo.bin',
    );
    final response = await _dio.dio.post<Map<String, dynamic>>(
      'upload/support-photo',
      data: FormData.fromMap({
        'employeeId': employeeId,
        'file': multipart,
      }),
    );
    final body = response.data;
    if (body == null || body['success'] != true) {
      throw Exception(body?['error'] ?? 'Photo upload failed');
    }
    final data = body['data'];
    if (data is Map && data['url'] is String) return data['url'] as String;
    throw const FormatException('Upload response missing URL');
  }
}
