import '../../../core/network/dio_client.dart';
import '../domain/dpr_models.dart';

class DprRepository {
  const DprRepository({required DioClient dioClient}) : _dio = dioClient;

  final DioClient _dio;

  Future<List<ErpDpr>> list({String? projectId}) async {
    return _dio.getEnvelope<List<ErpDpr>>(
      'dpr',
      queryParameters: projectId != null ? {'projectId': projectId} : null,
      parse: (raw) {
        if (raw is! List) return [];
        return raw.map((e) => ErpDpr.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      },
    );
  }

  Future<ErpDpr> getById(String id) async {
    return _dio.getEnvelope<ErpDpr>(
      'dpr/$id',
      parse: (raw) => ErpDpr.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpDpr> create(Map<String, dynamic> body) async {
    return _dio.postEnvelope<ErpDpr>(
      'dpr',
      data: body,
      parse: (raw) => ErpDpr.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> remove(String id) async {
    await _dio.deleteEnvelope('dpr/$id', parse: (_) => true);
  }
}
