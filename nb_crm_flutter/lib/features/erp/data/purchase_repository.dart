import '../../../core/network/dio_client.dart';
import '../domain/purchase_models.dart';

class PurchaseRepository {
  const PurchaseRepository({required DioClient dioClient}) : _dio = dioClient;

  final DioClient _dio;

  Future<ErpPurchaseSettings> getSettings() {
    return _dio.getEnvelope(
      'erp/purchase/settings',
      parse: (raw) => ErpPurchaseSettings.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpPurchaseSettings> updateSettings({required int? defaultApproverEmployeeId}) {
    return _dio.patchEnvelope(
      'erp/purchase/settings',
      data: {'defaultApproverEmployeeId': defaultApproverEmployeeId},
      parse: (raw) => ErpPurchaseSettings.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<List<ErpPurchaseRequest>> listRequests({
    String? status,
    bool pendingForMe = false,
    bool mine = false,
  }) {
    return _dio.getEnvelope<List<ErpPurchaseRequest>>(
      'erp/purchase/requests',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (pendingForMe) 'pendingForMe': 'true',
        if (mine) 'mine': 'true',
      },
      parse: (raw) {
        if (raw is! List) return [];
        return raw
            .map((e) => ErpPurchaseRequest.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<ErpPurchaseRequest> getRequest(String id) {
    return _dio.getEnvelope(
      'erp/purchase/requests/$id',
      parse: (raw) => ErpPurchaseRequest.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpPurchaseRequest> createRequest(Map<String, dynamic> body) {
    return _dio.postEnvelope(
      'erp/purchase/requests',
      data: body,
      parse: (raw) => ErpPurchaseRequest.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpPurchaseRequest> updateRequest(String id, Map<String, dynamic> body) {
    return _dio.patchEnvelope(
      'erp/purchase/requests/$id',
      data: body,
      parse: (raw) => ErpPurchaseRequest.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpPurchaseRequest> submitRequest(String id) {
    return _dio.postEnvelope(
      'erp/purchase/requests/$id/submit',
      data: const {},
      parse: (raw) => ErpPurchaseRequest.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpPurchaseRequest> approveRequest(String id) {
    return _dio.postEnvelope(
      'erp/purchase/requests/$id/approve',
      data: const {},
      parse: (raw) => ErpPurchaseRequest.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpPurchaseRequest> rejectRequest(String id, {String? reason}) {
    return _dio.postEnvelope(
      'erp/purchase/requests/$id/reject',
      data: {'reason': reason},
      parse: (raw) => ErpPurchaseRequest.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }
}
