import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../domain/project_models.dart';
import '../domain/structure_models.dart';

class ProjectRepository {
  const ProjectRepository({required DioClient dioClient}) : _dio = dioClient;

  final DioClient _dio;

  Future<({int projectNo, String displayId})> nextNumber() async {
    return _dio.getEnvelope(
      'projects/next-number',
      parse: (raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        final no = int.tryParse('${map['projectNo']}') ?? 1;
        return (
          projectNo: no,
          displayId: map['displayId']?.toString() ?? no.toString().padLeft(4, '0'),
        );
      },
    );
  }

  Future<List<ErpProject>> list({bool includeInactive = false}) async {
    return _dio.getEnvelope<List<ErpProject>>(
      'projects',
      queryParameters: includeInactive ? {'includeInactive': 'true'} : null,
      parse: (raw) {
        if (raw is! List) throw const FormatException('Invalid projects response');
        return raw
            .map((e) => ErpProject.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<ErpProject> getById(String id) async {
    return _dio.getEnvelope<ErpProject>(
      'projects/$id',
      parse: (raw) => ErpProject.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpProject> create(Map<String, dynamic> body) async {
    return _dio.postEnvelope<ErpProject>(
      'projects',
      data: body,
      parse: (raw) => ErpProject.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpProject> update(String id, Map<String, dynamic> body) async {
    return _dio.patchEnvelope<ErpProject>(
      'projects/$id',
      data: body,
      parse: (raw) => ErpProject.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> remove(String id) async {
    await _dio.deleteEnvelope('projects/$id', parse: (_) => true);
  }

  Future<List<ErpProjectTower>> listTowers(String projectId) async {
    return _dio.getEnvelope<List<ErpProjectTower>>(
      'projects/$projectId/towers',
      parse: (raw) {
        if (raw is! List) throw const FormatException('Invalid towers response');
        return raw
            .map((e) => ErpProjectTower.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<ErpProjectTower> getTower(String projectId, String towerId) async {
    return _dio.getEnvelope<ErpProjectTower>(
      'projects/$projectId/towers/$towerId',
      parse: (raw) => ErpProjectTower.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpProjectTower> createTower(String projectId, Map<String, dynamic> body) async {
    return _dio.postEnvelope<ErpProjectTower>(
      'projects/$projectId/towers',
      data: body,
      parse: (raw) => ErpProjectTower.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpProjectTower> updateTower(
    String projectId,
    String towerId,
    Map<String, dynamic> body,
  ) async {
    return _dio.patchEnvelope<ErpProjectTower>(
      'projects/$projectId/towers/$towerId',
      data: body,
      parse: (raw) => ErpProjectTower.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> deleteTower(String projectId, String towerId) async {
    await _dio.deleteEnvelope(
      'projects/$projectId/towers/$towerId',
      parse: (_) => true,
    );
  }

  Future<ErpProjectTower> regenerateUnits(String projectId, String towerId) async {
    return _dio.postEnvelope<ErpProjectTower>(
      'projects/$projectId/towers/$towerId/regenerate-units',
      data: const {},
      parse: (raw) => ErpProjectTower.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpProjectUnit> updateUnit({
    required String projectId,
    required String towerId,
    required String unitId,
    required Map<String, dynamic> body,
  }) async {
    return _dio.patchEnvelope<ErpProjectUnit>(
      'projects/$projectId/towers/$towerId/units/$unitId',
      data: body,
      parse: (raw) => ErpProjectUnit.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<({String url, String? fileName, String? mimeType, int? fileSize})> uploadFile({
    required Uint8List bytes,
    required String filename,
    String folder = 'erp/projects',
  }) async {
    final multipart = MultipartFile.fromBytes(bytes, filename: filename);
    final response = await _dio.dio.post<Map<String, dynamic>>(
      'projects/upload',
      data: FormData.fromMap({
        'folder': folder,
        'file': multipart,
      }),
    );
    final body = response.data;
    if (body == null || body['success'] != true) {
      throw Exception(body?['error'] ?? 'Upload failed');
    }
    final data = Map<String, dynamic>.from(body['data'] as Map);
    return (
      url: data['url'] as String,
      fileName: data['fileName']?.toString(),
      mimeType: data['mimeType']?.toString(),
      fileSize: int.tryParse('${data['fileSize']}'),
    );
  }

  Future<List<ProjectEmployeeOption>> listEmployees({int limit = 500}) async {
    return _dio.getEnvelope<List<ProjectEmployeeOption>>(
      'employees',
      queryParameters: {'limit': limit},
      parse: (raw) {
        if (raw is! Map) return [];
        final items = raw['items'] ?? raw['employees'] ?? raw;
        if (items is! List) return [];
        return items.map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          final general = map['generalInfo'] ?? map['general_info'];
          final g = general is Map ? Map<String, dynamic>.from(general) : map;
          return ProjectEmployeeOption(
            id: int.tryParse('${map['id']}') ?? 0,
            fullName: g['fullName']?.toString() ??
                g['full_name']?.toString() ??
                'Employee #${map['id']}',
          );
        }).toList();
      },
    );
  }
}
