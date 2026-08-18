import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../domain/task_models.dart';

class TasksRepository {
  const TasksRepository({required DioClient dioClient}) : _dio = dioClient;

  final DioClient _dio;

  Future<List<TaskReportee>> listReportees() {
    return _dio.getEnvelope<List<TaskReportee>>(
      'tasks/reportees',
      parse: (raw) {
        if (raw is! List) throw const FormatException('Invalid reportees response');
        return raw
            .whereType<Map>()
            .map((e) => TaskReportee.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
    );
  }

  Future<TaskSummary> summary() {
    return _dio.getEnvelope<TaskSummary>(
      'tasks/summary',
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid summary response');
        return TaskSummary.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<List<WorkTask>> list({String filter = 'all'}) {
    return _dio.getEnvelope<List<WorkTask>>(
      'tasks',
      queryParameters: {'filter': filter},
      parse: (raw) {
        if (raw is! List) throw const FormatException('Invalid tasks response');
        return raw
            .whereType<Map>()
            .map((e) => WorkTask.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
    );
  }

  Future<WorkTask> create({
    required String assigneeUserId,
    required String title,
    String? description,
    required DateTime deadline,
    String? extraApproverUserId,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final map = <String, dynamic>{
      'assigneeUserId': assigneeUserId,
      'title': title,
      'deadline': deadline.toUtc().toIso8601String(),
      if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      if (extraApproverUserId != null && extraApproverUserId.isNotEmpty)
        'extraApproverUserId': extraApproverUserId,
    };
    if (fileBytes != null && fileName != null) {
      map['file'] = MultipartFile.fromBytes(fileBytes, filename: fileName);
    }
    final response = await _dio.dio.post<Map<String, dynamic>>(
      'tasks',
      data: FormData.fromMap(map),
      options: Options(
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    final body = response.data;
    if (body == null || body['success'] != true) {
      throw Exception(body?['error'] ?? 'Failed to create task');
    }
    final data = body['data'];
    if (data is! Map) throw const FormatException('Invalid create task response');
    return WorkTask.fromJson(Map<String, dynamic>.from(data));
  }

  Future<WorkTask> setStatus(String id, String status) {
    return _dio.postEnvelope<WorkTask>(
      'tasks/$id/status',
      data: {'status': status},
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid task response');
        return WorkTask.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<WorkTask> requestExtraApproval(String id, String extraApproverUserId) {
    return _dio.postEnvelope<WorkTask>(
      'tasks/$id/extra-approval',
      data: {'extraApproverUserId': extraApproverUserId},
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid task response');
        return WorkTask.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<WorkTask> decideExtraApproval(String id, {required bool approve, String? remarks}) {
    return _dio.postEnvelope<WorkTask>(
      'tasks/$id/extra-approval/decide',
      data: {'approve': approve, 'remarks': remarks},
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid task response');
        return WorkTask.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<WorkTask> review(
    String id, {
    required String action,
    String? remarks,
    DateTime? newDeadline,
  }) {
    return _dio.postEnvelope<WorkTask>(
      'tasks/$id/review',
      data: {
        'action': action,
        if (remarks != null) 'remarks': remarks,
        if (newDeadline != null) 'newDeadline': newDeadline.toUtc().toIso8601String(),
      },
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid task response');
        return WorkTask.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }
}
