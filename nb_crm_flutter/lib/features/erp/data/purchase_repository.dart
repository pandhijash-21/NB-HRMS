import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/realtime/app_event_bus.dart';
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

  Future<ErpPurchaseSettings> updateSettings({
    int? defaultApproverEmployeeId,
    int? csApproverEmployeeId,
    List<String>? defaultPoTerms,
    int? priorityHighWithinDays,
    int? priorityMedWithinDays,
    bool updatePrApprover = false,
    bool updateCsApprover = false,
    bool updateDefaultPoTerms = false,
    bool updatePriorityThresholds = false,
  }) {
    return _dio.patchEnvelope(
      'erp/purchase/settings',
      data: {
        if (updatePrApprover) 'defaultApproverEmployeeId': defaultApproverEmployeeId,
        if (updateCsApprover) 'csApproverEmployeeId': csApproverEmployeeId,
        if (updateDefaultPoTerms) 'defaultPoTerms': defaultPoTerms ?? const <String>[],
        if (updatePriorityThresholds) ...{
          'priorityHighWithinDays': priorityHighWithinDays,
          'priorityMedWithinDays': priorityMedWithinDays,
        },
      },
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

  Future<ErpPurchaseRequest> createRequest(Map<String, dynamic> body) async {
    final res = await _dio.postEnvelope(
      'erp/purchase/requests',
      data: body,
      parse: (raw) => ErpPurchaseRequest.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
    AppEventBus.instance.fireErpMutated(module: 'purchase', entityId: res.id, action: 'created');
    return res;
  }

  Future<ErpPurchaseRequest> updateRequest(String id, Map<String, dynamic> body) async {
    final res = await _dio.patchEnvelope(
      'erp/purchase/requests/$id',
      data: body,
      parse: (raw) => ErpPurchaseRequest.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
    AppEventBus.instance.fireErpMutated(module: 'purchase', entityId: id, action: 'updated');
    return res;
  }

  Future<ErpPurchaseRequest> submitRequest(String id) async {
    final res = await _dio.postEnvelope(
      'erp/purchase/requests/$id/submit',
      data: const {},
      parse: (raw) => ErpPurchaseRequest.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
    AppEventBus.instance.fireErpMutated(module: 'purchase', entityId: id, action: 'submitted');
    return res;
  }

  Future<ErpPurchaseRequest> approveRequest(String id) async {
    final res = await _dio.postEnvelope(
      'erp/purchase/requests/$id/approve',
      data: const {},
      parse: (raw) => ErpPurchaseRequest.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
    AppEventBus.instance.fireErpMutated(module: 'purchase', entityId: id, action: 'approved');
    return res;
  }

  Future<ErpPurchaseRequest> rejectRequest(String id, {String? reason}) async {
    final res = await _dio.postEnvelope(
      'erp/purchase/requests/$id/reject',
      data: {'reason': reason},
      parse: (raw) => ErpPurchaseRequest.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
    AppEventBus.instance.fireErpMutated(module: 'purchase', entityId: id, action: 'rejected');
    return res;
  }

  Future<List<ErpPurchaseQuotation>> listQuotations(String purchaseRequestId) {
    return _dio.getEnvelope<List<ErpPurchaseQuotation>>(
      'erp/purchase/requests/$purchaseRequestId/quotations',
      parse: (raw) {
        if (raw is! List) return [];
        return raw
            .map((e) => ErpPurchaseQuotation.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<ErpPurchaseComparisonSheet> getComparison(String purchaseRequestId) {
    return _dio.getEnvelope(
      'erp/purchase/requests/$purchaseRequestId/comparison',
      parse: (raw) =>
          ErpPurchaseComparisonSheet.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpPurchaseQuotation> createQuotation(
    String purchaseRequestId,
    Map<String, dynamic> body,
  ) {
    return _dio.postEnvelope(
      'erp/purchase/requests/$purchaseRequestId/quotations',
      data: body,
      parse: (raw) => ErpPurchaseQuotation.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpPurchaseQuotation> updateQuotation(String id, Map<String, dynamic> body) {
    return _dio.patchEnvelope(
      'erp/purchase/quotations/$id',
      data: body,
      parse: (raw) => ErpPurchaseQuotation.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpPurchaseQuotation> submitQuotation(String id) {
    return _dio.postEnvelope(
      'erp/purchase/quotations/$id/submit',
      data: const {},
      parse: (raw) => ErpPurchaseQuotation.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<Map<String, dynamic>> selectQuotation(String id) {
    return _dio.postEnvelope(
      'erp/purchase/quotations/$id/select',
      data: const {},
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<void> deleteQuotation(String id) {
    return _dio.deleteEnvelope('erp/purchase/quotations/$id', parse: (_) => true);
  }

  Future<Uint8List> exportComparisonExcel(String purchaseRequestId) async {
    final response = await _dio.dio.get<List<int>>(
      'erp/purchase/requests/$purchaseRequestId/comparison/export.xlsx',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  }

  Future<ErpPurchaseOrderDetail> getPurchaseOrder(String id) {
    return _dio.getEnvelope(
      'erp/purchase/orders/$id',
      parse: (raw) => ErpPurchaseOrderDetail.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpPurchaseOrderDetail> updatePurchaseOrder(
    String id, {
    List<String>? termsAndConditions,
    double? cgstRate,
    double? sgstRate,
  }) {
    return _dio.patchEnvelope(
      'erp/purchase/orders/$id',
      data: {
        if (termsAndConditions != null) 'termsAndConditions': termsAndConditions,
        if (cgstRate != null) 'cgstRate': cgstRate,
        if (sgstRate != null) 'sgstRate': sgstRate,
      },
      parse: (raw) => ErpPurchaseOrderDetail.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<Uint8List> exportPurchaseOrderExcel(String purchaseOrderId) async {
    final response = await _dio.dio.get<List<int>>(
      'erp/purchase/orders/$purchaseOrderId/export.xlsx',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  }
}
