import '../../../core/network/dio_client.dart';
import '../domain/salary_models.dart';

class SalaryRepository {
  const SalaryRepository({required DioClient dioClient}) : _dio = dioClient;

  final DioClient _dio;

  Future<List<PayCommission>> listPayCommissions() async {
    return _dio.getEnvelope<List<PayCommission>>(
      'salary/pay-commissions',
      parse: _parsePayCommissionList,
    );
  }

  Future<PayCommission> createPayCommission(Map<String, dynamic> body) async {
    return _dio.postEnvelope<PayCommission>(
      'salary/pay-commissions',
      data: body,
      parse: (raw) => PayCommission.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<PayCommission> getPayCommission(String id) async {
    return _dio.getEnvelope<PayCommission>(
      'salary/pay-commissions/$id',
      parse: (raw) => PayCommission.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<PayCommission> updatePayCommission(
    String id,
    Map<String, dynamic> body,
  ) async {
    return _dio.patchEnvelope<PayCommission>(
      'salary/pay-commissions/$id',
      data: body,
      parse: (raw) => PayCommission.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<PayCommissionColumn> createPayCommissionColumn(
    String payCommissionId,
    Map<String, dynamic> body,
  ) async {
    return _dio.postEnvelope<PayCommissionColumn>(
      'salary/pay-commissions/$payCommissionId/columns',
      data: body,
      parse: (raw) =>
          PayCommissionColumn.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<PayCommissionColumn> updatePayCommissionColumn(
    String columnId,
    Map<String, dynamic> body,
  ) async {
    return _dio.patchEnvelope<PayCommissionColumn>(
      'salary/pay-commissions/columns/$columnId',
      data: body,
      parse: (raw) =>
          PayCommissionColumn.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> deletePayCommissionColumn(String columnId) async {
    await _dio.deleteEnvelope<void>(
      'salary/pay-commissions/columns/$columnId',
      parse: (_) {},
    );
  }

  Future<List<SalaryStructureStatus>> getStructureStatus() async {
    return _dio.getEnvelope<List<SalaryStructureStatus>>(
      'salary/structures/status',
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid structure status response');
        }
        return raw
            .map((e) => SalaryStructureStatus.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList();
      },
    );
  }

  Future<SalaryTemplate> createTemplate({
    required String designationId,
    required String payCommissionCode,
  }) async {
    return _dio.postEnvelope<SalaryTemplate>(
      'salary/templates',
      data: {
        'designationId': designationId,
        'payCommissionCode': payCommissionCode,
      },
      parse: (raw) => SalaryTemplate.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<SalaryTemplateBundle> getTemplateByDesignation(
    String designationId,
    String commissionCode,
  ) async {
    return _dio.getEnvelope<SalaryTemplateBundle>(
      'salary/templates/by-designation/$designationId/$commissionCode',
      parse: (raw) =>
          SalaryTemplateBundle.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<List<SalaryRule>> getTemplateRules(String templateId) async {
    return _dio.getEnvelope<List<SalaryRule>>(
      'salary/templates/$templateId/rules',
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid template rules response');
        }
        return raw
            .map((e) => SalaryRule.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<void> updateTemplateColumnVisibility(
    String templateId,
    Map<String, bool> columnVisibility,
  ) async {
    await _dio.patchEnvelope<void>(
      'salary/templates/$templateId/column-visibility',
      data: {'columnVisibility': columnVisibility},
      parse: (_) {},
    );
  }

  Future<SalaryRule> upsertColumnRule({
    required String templateId,
    required String columnIdentifier,
    required String category,
    required Map<String, dynamic> body,
  }) async {
    return _dio.putEnvelope<SalaryRule>(
      'salary/templates/$templateId/rules/$columnIdentifier',
      data: body,
      queryParameters: {'category': category},
      parse: (raw) => SalaryRule.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<ComputedSalaryResult> computeSalary({
    required String templateId,
    Map<String, num>? overrides,
    int? employeeId,
    Map<String, dynamic>? employeeRules,
  }) async {
    return _dio.postEnvelope<ComputedSalaryResult>(
      'salary/compute',
      data: {
        'templateId': templateId,
        if (overrides != null && overrides.isNotEmpty) 'overrides': overrides,
        if (employeeId != null) 'employeeId': employeeId,
        if (employeeRules != null && employeeRules.isNotEmpty)
          'employeeRules': employeeRules,
      },
      parse: (raw) =>
          ComputedSalaryResult.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<EmployeeSalaryProfileResponse> getEmployeeProfile(int employeeId) async {
    return _dio.getEnvelope<EmployeeSalaryProfileResponse>(
      'salary/employees/$employeeId/profile',
      parse: (raw) => EmployeeSalaryProfileResponse.fromJson(
        Map<String, dynamic>.from(raw as Map),
      ),
    );
  }

  Future<EmployeeSalaryPreview> getEmployeeSalaryPreview(int employeeId) async {
    return _dio.getEnvelope<EmployeeSalaryPreview>(
      'salary/employees/$employeeId/salary-preview',
      parse: (raw) => EmployeeSalaryPreview.fromJson(
        Map<String, dynamic>.from(raw as Map),
      ),
    );
  }

  Future<void> updateEmployeeProfile(
    int employeeId, {
    String? payCommissionCode,
    Map<String, num>? columnOverrides,
    Map<String, Map<String, dynamic>>? columnRules,
    bool clearOverrides = false,
    bool clearRules = false,
  }) async {
    await _dio.patchEnvelope<Object?>(
      'salary/employees/$employeeId/profile',
      data: {
        if (payCommissionCode != null) 'payCommissionCode': payCommissionCode,
        if (clearOverrides)
          'columnOverrides': null
        else if (columnOverrides != null)
          'columnOverrides': columnOverrides,
        if (clearRules)
          'columnRules': null
        else if (columnRules != null)
          'columnRules': columnRules,
      },
      parse: (raw) => raw,
    );
  }

  Future<List<SalaryRecord>> listRecords({
    int? employeeId,
    int? salaryMonth,
    int? salaryYear,
    String? status,
    String? designationId,
    String? payCommissionCode,
  }) async {
    return _dio.getEnvelope<List<SalaryRecord>>(
      'salary/records',
      queryParameters: {
        if (employeeId != null) 'employeeId': employeeId,
        if (salaryMonth != null) 'salaryMonth': salaryMonth,
        if (salaryYear != null) 'salaryYear': salaryYear,
        if (status != null && status.isNotEmpty) 'status': status,
        if (designationId != null && designationId.isNotEmpty)
          'designationId': designationId,
        if (payCommissionCode != null && payCommissionCode.isNotEmpty)
          'payCommissionCode': payCommissionCode,
      },
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid salary records response');
        }
        return raw
            .map((e) => SalaryRecord.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<SalaryRecord> createRecord({
    required int employeeId,
    required int salaryMonth,
    required int salaryYear,
  }) async {
    return _dio.postEnvelope<SalaryRecord>(
      'salary/records',
      data: {
        'employeeId': employeeId,
        'salaryMonth': salaryMonth,
        'salaryYear': salaryYear,
      },
      parse: (raw) => SalaryRecord.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<SalaryRecord> updateRecord(
    String id, {
    Map<String, num>? overrides,
  }) async {
    return _dio.patchEnvelope<SalaryRecord>(
      'salary/records/$id',
      data: {if (overrides != null) 'overrides': overrides},
      parse: (raw) => SalaryRecord.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<SalaryRecord> markRecordPaid(String id) async {
    return _dio.postEnvelope<SalaryRecord>(
      'salary/records/$id/mark-paid',
      parse: (raw) => SalaryRecord.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<SalaryRecord> markRecordUnpaid(String id) async {
    return _dio.postEnvelope<SalaryRecord>(
      'salary/records/$id/mark-unpaid',
      parse: (raw) => SalaryRecord.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  /// Legacy alias — marks salary as paid.
  Future<SalaryRecord> finalizeRecord(String id) => markRecordPaid(id);

  Future<Map<String, dynamic>> getMonthPayroll({
    required int year,
    required int month,
  }) async {
    return _dio.getEnvelope<Map<String, dynamic>>(
      'salary/payroll/month',
      queryParameters: {'year': year, 'month': month},
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid payroll month response');
        return Map<String, dynamic>.from(raw);
      },
    );
  }

  Future<SalarySlip> getSlip(String recordId) async {
    return _dio.getEnvelope<SalarySlip>(
      'salary/records/$recordId/slip',
      parse: (raw) => SalarySlip.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<Map<String, dynamic>> getEmployeeMonthlyOverview({
    required int employeeId,
    required int year,
    required int month,
  }) async {
    return _dio.getEnvelope<Map<String, dynamic>>(
      'salary/employees/$employeeId/monthly-overview',
      queryParameters: {'year': year, 'month': month},
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid monthly overview');
        return Map<String, dynamic>.from(raw);
      },
    );
  }

  Future<Map<String, dynamic>> calculateEmployeeMonthlySalary({
    required int employeeId,
    required int year,
    required int month,
  }) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'salary/employees/$employeeId/monthly-calc',
      data: {'year': year, 'month': month},
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid monthly calc');
        return Map<String, dynamic>.from(raw);
      },
    );
  }

  Future<Map<String, dynamic>> saveEmployeeMonthlySalary({
    required int employeeId,
    required int year,
    required int month,
  }) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'salary/employees/$employeeId/monthly-save',
      data: {'year': year, 'month': month},
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid monthly save');
        return Map<String, dynamic>.from(raw);
      },
    );
  }

  Future<SalarySlip> getEmployeeSlip({
    required int employeeId,
    required String recordId,
  }) async {
    return _dio.getEnvelope<SalarySlip>(
      'salary/employees/$employeeId/slip/$recordId',
      parse: (raw) => SalarySlip.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<List<SalaryEmployeeOption>> listEmployeesForEntry({int limit = 500}) async {
    return _dio.getEnvelope<List<SalaryEmployeeOption>>(
      'employees',
      queryParameters: {'limit': limit},
      parse: (raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid employees response');
        }
        final items = raw['items'] ?? raw['employees'] ?? raw;
        if (items is! List) return [];
        return items.map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          final general = map['generalInfo'] ?? map['general_info'];
          final g = general is Map ? Map<String, dynamic>.from(general) : map;
          return SalaryEmployeeOption(
            id: _asInt(map['id']),
            fullName: g['fullName']?.toString() ??
                g['full_name']?.toString() ??
                'Employee #${map['id']}',
            designationId: g['designationId']?.toString() ??
                g['designation_id']?.toString(),
          );
        }).toList();
      },
    );
  }

  List<PayCommission> _parsePayCommissionList(Object? raw) {
    if (raw is! List) {
      throw const FormatException('Invalid pay commissions response');
    }
    return raw
        .map((e) => PayCommission.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

int _asInt(Object? value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}
