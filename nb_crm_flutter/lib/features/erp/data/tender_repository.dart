import '../../../core/network/dio_client.dart';
import '../domain/tender_models.dart';

class TenderRepository {
  const TenderRepository({required DioClient dioClient}) : _dio = dioClient;

  final DioClient _dio;

  Future<List<ErpTender>> list({String? projectId}) async {
    return _dio.getEnvelope<List<ErpTender>>(
      'tenders',
      queryParameters: projectId != null ? {'projectId': projectId} : null,
      parse: (raw) {
        if (raw is! List) return [];
        return raw.map((e) => ErpTender.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      },
    );
  }

  Future<ErpTender> getById(String id) async {
    return _dio.getEnvelope<ErpTender>(
      'tenders/$id',
      parse: (raw) => ErpTender.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpTender> create(Map<String, dynamic> body) async {
    return _dio.postEnvelope<ErpTender>(
      'tenders',
      data: body,
      parse: (raw) => ErpTender.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpTender> update(String id, Map<String, dynamic> body) async {
    return _dio.patchEnvelope<ErpTender>(
      'tenders/$id',
      data: body,
      parse: (raw) => ErpTender.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> remove(String id) async {
    await _dio.deleteEnvelope('tenders/$id', parse: (_) => true);
  }

  Future<List<TenderActivityOption>> activitiesFromBoq(String boqId) async {
    return _dio.getEnvelope<List<TenderActivityOption>>(
      'tenders/helpers/boq-activities',
      queryParameters: {'boqId': boqId},
      parse: (raw) {
        if (raw is! List) return [];
        return raw
            .map((e) => TenderActivityOption.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<List<ErpTenderLine>> previewLines({String? boqId, String? activityId}) async {
    return _dio.getEnvelope<List<ErpTenderLine>>(
      'tenders/helpers/preview-lines',
      queryParameters: {
        if (boqId != null && boqId.isNotEmpty) 'boqId': boqId,
        if (activityId != null && activityId.isNotEmpty) 'activityId': activityId,
      },
      parse: (raw) {
        if (raw is! List) return [];
        return raw.map((e) => ErpTenderLine.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      },
    );
  }

  Future<List<ErpTenderApplication>> listApplications({String? tenderId}) async {
    return _dio.getEnvelope<List<ErpTenderApplication>>(
      'tender-applications',
      queryParameters: tenderId != null ? {'tenderId': tenderId} : null,
      parse: (raw) {
        if (raw is! List) return [];
        return raw
            .map((e) => ErpTenderApplication.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<ErpTenderApplication> createApplication(Map<String, dynamic> body) async {
    return _dio.postEnvelope<ErpTenderApplication>(
      'tender-applications',
      data: body,
      parse: (raw) => ErpTenderApplication.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> removeApplication(String id) async {
    await _dio.deleteEnvelope('tender-applications/$id', parse: (_) => true);
  }
}
