import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../domain/recruitment_models.dart';

class RecruitmentRepository {
  const RecruitmentRepository({required DioClient dioClient}) : _dio = dioClient;

  final DioClient _dio;

  Future<List<JobRequirement>> listVacancies() async {
    return _dio.getEnvelope<List<JobRequirement>>(
      'recruitment/vacancies',
      parse: (raw) {
        if (raw is! List) throw const FormatException('Invalid vacancies');
        return raw
            .map((e) => JobRequirement.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<JobRequirement> getVacancy(String id) async {
    return _dio.getEnvelope<JobRequirement>(
      'recruitment/vacancies/$id',
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid vacancy');
        return JobRequirement.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<List<JobRequirement>> listRequirements({bool? activeOnly}) async {
    return _dio.getEnvelope<List<JobRequirement>>(
      'recruitment/requirements',
      queryParameters: activeOnly == true ? {'activeOnly': 'true'} : null,
      parse: (raw) {
        if (raw is! List) throw const FormatException('Invalid requirements');
        return raw
            .map((e) => JobRequirement.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<JobRequirement> createRequirement(Map<String, dynamic> body) async {
    return _dio.postEnvelope<JobRequirement>(
      'recruitment/requirements',
      data: body,
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid create requirement');
        return JobRequirement.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<JobRequirement> updateRequirement(String id, Map<String, dynamic> body) async {
    return _dio.patchEnvelope<JobRequirement>(
      'recruitment/requirements/$id',
      data: body,
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid update requirement');
        return JobRequirement.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<JobRequirement> setActive(String id, bool isActive) async {
    return _dio.patchEnvelope<JobRequirement>(
      'recruitment/requirements/$id/active',
      data: {'isActive': isActive},
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid toggle');
        return JobRequirement.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<List<RecruitmentCandidate>> listCandidates({String? requirementId}) async {
    return _dio.getEnvelope<List<RecruitmentCandidate>>(
      'recruitment/candidates',
      queryParameters:
          requirementId != null && requirementId.isNotEmpty ? {'requirementId': requirementId} : null,
      parse: (raw) {
        if (raw is! List) throw const FormatException('Invalid candidates');
        return raw
            .map((e) => RecruitmentCandidate.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<RecruitmentCandidate> getCandidate(String id) async {
    return _dio.getEnvelope<RecruitmentCandidate>(
      'recruitment/candidates/$id',
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid candidate');
        return RecruitmentCandidate.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<RecruitmentCandidate> createCandidate(Map<String, dynamic> body) async {
    return _dio.postEnvelope<RecruitmentCandidate>(
      'recruitment/candidates',
      data: body,
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid create candidate');
        return RecruitmentCandidate.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<RecruitmentCandidate> updateCandidate(
    String id,
    Map<String, dynamic> body,
  ) async {
    return _dio.patchEnvelope<RecruitmentCandidate>(
      'recruitment/candidates/$id',
      data: body,
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid update candidate');
        return RecruitmentCandidate.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<RecruitmentCandidate> scheduleNextRound(
    String candidateId,
    Map<String, dynamic> body,
  ) async {
    return _dio.postEnvelope<RecruitmentCandidate>(
      'recruitment/candidates/$candidateId/rounds',
      data: body,
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid next round');
        return RecruitmentCandidate.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<Map<String, dynamic>> hireCandidate(
    String candidateId,
    Map<String, dynamic> body,
  ) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'recruitment/candidates/$candidateId/hire',
      data: body,
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid hire response');
        return Map<String, dynamic>.from(raw);
      },
    );
  }

  Future<List<MyInterviewItem>> listMyInterviews() async {
    return _dio.getEnvelope<List<MyInterviewItem>>(
      'recruitment/my-interviews',
      parse: (raw) {
        if (raw is! List) throw const FormatException('Invalid my interviews');
        return raw
            .map((e) => MyInterviewItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<RecruitmentCandidate> updateRoundStatus(
    String roundId, {
    required String statusCode,
    String? remarks,
  }) async {
    return _dio.patchEnvelope<RecruitmentCandidate>(
      'recruitment/rounds/$roundId/status',
      data: {
        'statusCode': statusCode,
        if (remarks != null) 'remarks': remarks,
      },
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid status update');
        return RecruitmentCandidate.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<RecruitmentCandidate> confirmRound(String roundId) async {
    return _dio.postEnvelope<RecruitmentCandidate>(
      'recruitment/rounds/$roundId/confirm',
      data: const {},
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid confirm response');
        return RecruitmentCandidate.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<String> uploadResume({
    required Uint8List bytes,
    String? filename,
  }) async {
    final multipart = MultipartFile.fromBytes(
      bytes,
      filename: filename ?? 'resume.bin',
    );
    final response = await _dio.dio.post<Map<String, dynamic>>(
      'upload/resume',
      data: FormData.fromMap({'file': multipart}),
    );
    final body = response.data;
    if (body == null || body['success'] != true) {
      throw Exception(body?['error'] ?? 'Resume upload failed');
    }
    final data = body['data'];
    if (data is Map && data['url'] is String) return data['url'] as String;
    throw const FormatException('Upload response missing URL');
  }
}
