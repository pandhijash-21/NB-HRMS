import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../domain/reimbursement_models.dart';

class ReimbursementsRepository {
  const ReimbursementsRepository({required DioClient dioClient}) : _dio = dioClient;

  final DioClient _dio;

  Future<List<ReimbursementClaim>> listMine() async {
    return _dio.getEnvelope<List<ReimbursementClaim>>(
      'reimbursements/my',
      parse: (raw) {
        if (raw is! List) throw const FormatException('Invalid reimbursements list');
        return raw
            .map((e) => ReimbursementClaim.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<List<ReimbursementClaim>> listPending() async {
    return _dio.getEnvelope<List<ReimbursementClaim>>(
      'reimbursements/my/pending',
      parse: (raw) {
        if (raw is! List) throw const FormatException('Invalid pending reimbursements');
        return raw
            .map((e) => ReimbursementClaim.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<List<ReimbursementClaim>> listAdmin({String? status}) async {
    return _dio.getEnvelope<List<ReimbursementClaim>>(
      'reimbursements/admin',
      queryParameters: status != null && status.isNotEmpty ? {'status': status} : null,
      parse: (raw) {
        if (raw is! List) throw const FormatException('Invalid admin reimbursements');
        return raw
            .map((e) => ReimbursementClaim.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<ReimbursementClaim> apply(Map<String, dynamic> body) async {
    return _dio.postEnvelope<ReimbursementClaim>(
      'reimbursements/apply',
      data: body,
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid apply response');
        return ReimbursementClaim.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<ReimbursementClaim> approve(String id, {String? remarks}) async {
    return _dio.postEnvelope<ReimbursementClaim>(
      'reimbursements/claims/$id/approve',
      data: {if (remarks != null && remarks.isNotEmpty) 'remarks': remarks},
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid approve response');
        return ReimbursementClaim.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<ReimbursementClaim> reject(String id, {String? remarks}) async {
    return _dio.postEnvelope<ReimbursementClaim>(
      'reimbursements/claims/$id/reject',
      data: {if (remarks != null && remarks.isNotEmpty) 'remarks': remarks},
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid reject response');
        return ReimbursementClaim.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<ReimbursementClaim> cancel(String id) async {
    return _dio.postEnvelope<ReimbursementClaim>(
      'reimbursements/claims/$id/cancel',
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid cancel response');
        return ReimbursementClaim.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<String> uploadProof({
    required int employeeId,
    required Uint8List bytes,
    String? filename,
  }) async {
    final multipart = MultipartFile.fromBytes(
      bytes,
      filename: filename ?? 'reimbursement-proof.bin',
    );
    final response = await _dio.dio.post<Map<String, dynamic>>(
      'upload/reimbursement-proof',
      data: FormData.fromMap({
        'employeeId': employeeId,
        'file': multipart,
      }),
    );
    final body = response.data;
    if (body == null || body['success'] != true) {
      throw Exception(body?['error'] ?? 'Proof upload failed');
    }
    final data = body['data'];
    if (data is Map && data['url'] is String) return data['url'] as String;
    throw const FormatException('Upload response missing URL');
  }
}
