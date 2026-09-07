import '../../../core/network/dio_client.dart';
import '../domain/boq_models.dart';
import '../domain/resource_models.dart';

class BoqRepository {
  const BoqRepository({required DioClient dioClient}) : _dio = dioClient;

  final DioClient _dio;

  Future<List<ErpBoq>> list({String? projectId}) async {
    return _dio.getEnvelope<List<ErpBoq>>(
      'boq',
      queryParameters: projectId != null ? {'projectId': projectId} : null,
      parse: (raw) {
        if (raw is! List) return [];
        return raw.map((e) => ErpBoq.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      },
    );
  }

  Future<ErpBoq> getById(String id) async {
    return _dio.getEnvelope<ErpBoq>(
      'boq/$id',
      parse: (raw) => ErpBoq.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpBoq> create(Map<String, dynamic> body) async {
    return _dio.postEnvelope<ErpBoq>(
      'boq',
      data: body,
      parse: (raw) => ErpBoq.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpBoq> update(String id, Map<String, dynamic> body) async {
    return _dio.patchEnvelope<ErpBoq>(
      'boq/$id',
      data: body,
      parse: (raw) => ErpBoq.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> remove(String id) async {
    await _dio.deleteEnvelope('boq/$id', parse: (_) => true);
  }

  Future<List<ErpMaterial>> listMaterials({bool includeInactive = false}) async {
    return _dio.getEnvelope<List<ErpMaterial>>(
      'erp/resources/materials',
      queryParameters: includeInactive ? {'includeInactive': 'true'} : null,
      parse: (raw) {
        if (raw is! List) return [];
        return raw.map((e) => ErpMaterial.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      },
    );
  }

  Future<ErpMaterial> createMaterial(Map<String, dynamic> body) async {
    return _dio.postEnvelope<ErpMaterial>(
      'erp/resources/materials',
      data: body,
      parse: (raw) => ErpMaterial.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpMaterial> addMaterialStock(String id, Map<String, dynamic> body) async {
    return _dio.postEnvelope<ErpMaterial>(
      'erp/resources/materials/$id/stock',
      data: body,
      parse: (raw) => ErpMaterial.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> dispatchMaterialOutward(
    String id, {
    required double quantity,
    required String contractorId,
    String? remarks,
  }) async {
    await _dio.postEnvelope(
      'erp/resources/materials/$id/outward',
      data: {
        'quantity': quantity,
        'contractorId': contractorId,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      },
      parse: (_) => true,
    );
  }

  Future<List<ErpMaterialStockLog>> getMaterialLogs(String id) async {
    return _dio.getEnvelope<List<ErpMaterialStockLog>>(
      'erp/resources/materials/$id/logs',
      parse: (raw) {
        if (raw is! List) return [];
        return raw
            .map((e) => ErpMaterialStockLog.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<void> removeMaterial(String id) async {
    await _dio.deleteEnvelope('erp/resources/materials/$id', parse: (_) => true);
  }

  Future<List<ErpMachine>> listMachines({bool includeInactive = false}) async {
    return _dio.getEnvelope<List<ErpMachine>>(
      'erp/resources/machines',
      queryParameters: includeInactive ? {'includeInactive': 'true'} : null,
      parse: (raw) {
        if (raw is! List) return [];
        return raw.map((e) => ErpMachine.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      },
    );
  }

  Future<ErpMachine> createMachine(Map<String, dynamic> body) async {
    return _dio.postEnvelope<ErpMachine>(
      'erp/resources/machines',
      data: body,
      parse: (raw) => ErpMachine.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ErpMachine> addMachineStock(String id, Map<String, dynamic> body) async {
    return _dio.postEnvelope<ErpMachine>(
      'erp/resources/machines/$id/stock',
      data: body,
      parse: (raw) => ErpMachine.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> issueMachine(
    String id, {
    required double quantity,
    required String contractorId,
    DateTime? issueDate,
    String? remarks,
  }) async {
    await _dio.postEnvelope(
      'erp/resources/machines/$id/issue',
      data: {
        'quantity': quantity,
        'contractorId': contractorId,
        if (issueDate != null) 'issueDate': issueDate.toIso8601String(),
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      },
      parse: (_) => true,
    );
  }

  Future<void> returnMachine(
    String issueId, {
    required double quantity,
    DateTime? returnDate,
    String? remarks,
  }) async {
    await _dio.postEnvelope(
      'erp/resources/machines/issues/$issueId/return',
      data: {
        'quantity': quantity,
        if (returnDate != null) 'returnDate': returnDate.toIso8601String(),
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      },
      parse: (_) => true,
    );
  }

  Future<List<ErpMachineIssue>> listActiveMachineIssues({String? contractorId, String? machineId}) async {
    return _dio.getEnvelope<List<ErpMachineIssue>>(
      'erp/resources/machines/issues/active',
      queryParameters: {
        if (contractorId != null && contractorId.isNotEmpty) 'contractorId': contractorId,
        if (machineId != null && machineId.isNotEmpty) 'machineId': machineId,
      },
      parse: (raw) {
        if (raw is! List) return [];
        return raw
            .map((e) => ErpMachineIssue.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<Map<String, dynamic>> getMachineLogs(String id) async {
    return _dio.getEnvelope<Map<String, dynamic>>(
      'erp/resources/machines/$id/logs',
      parse: (raw) {
        if (raw is! Map) return {'issues': <ErpMachineIssue>[], 'stockLogs': <ErpMachineStockLog>[]};
        final m = Map<String, dynamic>.from(raw);
        final issues = m['issues'] is List
            ? (m['issues'] as List)
                .map((e) => ErpMachineIssue.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList()
            : <ErpMachineIssue>[];
        final stockLogs = m['stockLogs'] is List
            ? (m['stockLogs'] as List)
                .map((e) => ErpMachineStockLog.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList()
            : <ErpMachineStockLog>[];
        return {'issues': issues, 'stockLogs': stockLogs};
      },
    );
  }

  Future<void> removeMachine(String id) async {
    await _dio.deleteEnvelope('erp/resources/machines/$id', parse: (_) => true);
  }

  Future<List<ErpLabour>> listLabour() async {
    return _dio.getEnvelope<List<ErpLabour>>(
      'erp/resources/labour',
      parse: (raw) {
        if (raw is! List) return [];
        return raw.map((e) => ErpLabour.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      },
    );
  }

  Future<ErpLabour> createLabour(Map<String, dynamic> body) async {
    return _dio.postEnvelope<ErpLabour>(
      'erp/resources/labour',
      data: body,
      parse: (raw) => ErpLabour.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> removeLabour(String id) async {
    await _dio.deleteEnvelope('erp/resources/labour/$id', parse: (_) => true);
  }
}
