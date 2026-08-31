import '../../../core/network/dio_client.dart';
import '../domain/work_order_models.dart';

class WorkOrderRepository {
  const WorkOrderRepository({required DioClient dioClient}) : _dio = dioClient;

  final DioClient _dio;

  Future<List<ErpWorkOrder>> list() async {
    return _dio.getEnvelope<List<ErpWorkOrder>>(
      'work-orders',
      parse: (raw) {
        if (raw is! List) throw const FormatException('Invalid work orders response');
        return raw
            .map((e) => ErpWorkOrder.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<ErpWorkOrder> getById(String id) async {
    return _dio.getEnvelope<ErpWorkOrder>(
      'work-orders/$id',
      parse: (raw) => ErpWorkOrder.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpWorkOrder> create(Map<String, dynamic> body) async {
    return _dio.postEnvelope<ErpWorkOrder>(
      'work-orders',
      data: body,
      parse: (raw) => ErpWorkOrder.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpWorkOrder> update(String id, Map<String, dynamic> body) async {
    return _dio.patchEnvelope<ErpWorkOrder>(
      'work-orders/$id',
      data: body,
      parse: (raw) => ErpWorkOrder.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpWorkOrder> updateStatus(String id, String status) async {
    return _dio.patchEnvelope<ErpWorkOrder>(
      'work-orders/$id/status',
      data: {'status': status},
      parse: (raw) => ErpWorkOrder.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpWorkOrder> updateApproval(String id, String approvalStatus) async {
    return _dio.patchEnvelope<ErpWorkOrder>(
      'work-orders/$id/approval',
      data: {'approvalStatus': approvalStatus},
      parse: (raw) => ErpWorkOrder.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> remove(String id) async {
    await _dio.deleteEnvelope('work-orders/$id', parse: (_) => true);
  }

  Future<List<ErpActivity>> listActivities({bool includeInactive = false}) async {
    return _dio.getEnvelope<List<ErpActivity>>(
      'erp/activities',
      queryParameters: includeInactive ? {'includeInactive': 'true'} : null,
      parse: (raw) {
        if (raw is! List) throw const FormatException('Invalid activities response');
        return raw
            .map((e) => ErpActivity.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<List<ErpActivity>> listActivitiesAdmin() async {
    return _dio.getEnvelope<List<ErpActivity>>(
      'erp/activities/admin',
      parse: (raw) {
        if (raw is! List) throw const FormatException('Invalid activities response');
        return raw
            .map((e) => ErpActivity.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<ErpActivity> createActivity(Map<String, dynamic> body) async {
    return _dio.postEnvelope<ErpActivity>(
      'erp/activities',
      data: body,
      parse: (raw) => ErpActivity.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpActivity> updateActivity(String id, Map<String, dynamic> body) async {
    return _dio.patchEnvelope<ErpActivity>(
      'erp/activities/$id',
      data: body,
      parse: (raw) => ErpActivity.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpActivity> toggleActivity(String id) async {
    return _dio.postEnvelope<ErpActivity>(
      'erp/activities/$id/toggle',
      data: const {},
      parse: (raw) => ErpActivity.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> removeActivity(String id) async {
    await _dio.deleteEnvelope('erp/activities/$id', parse: (_) => true);
  }

  Future<List<ErpContractor>> listContractors({bool includeInactive = false}) async {
    return _dio.getEnvelope<List<ErpContractor>>(
      'erp/contractors',
      queryParameters: includeInactive ? {'includeInactive': 'true'} : null,
      parse: (raw) {
        if (raw is! List) throw const FormatException('Invalid contractors response');
        return raw
            .map((e) => ErpContractor.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<ErpContractor> createContractor(Map<String, dynamic> body) async {
    return _dio.postEnvelope<ErpContractor>(
      'erp/contractors',
      data: body,
      parse: (raw) => ErpContractor.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpContractor> updateContractor(String id, Map<String, dynamic> body) async {
    return _dio.patchEnvelope<ErpContractor>(
      'erp/contractors/$id',
      data: body,
      parse: (raw) => ErpContractor.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpContractor> toggleContractor(String id) async {
    return _dio.postEnvelope<ErpContractor>(
      'erp/contractors/$id/toggle',
      data: const {},
      parse: (raw) => ErpContractor.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> removeContractor(String id) async {
    await _dio.deleteEnvelope('erp/contractors/$id', parse: (_) => true);
  }
}
