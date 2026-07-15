/// Salary / payroll domain models (mirrors frontend useSalary types).
library;

enum SalaryColumnCategory { earning, deduction }

SalaryColumnCategory parseSalaryColumnCategory(String? raw) {
  switch (raw?.toUpperCase()) {
    case 'DEDUCTION':
      return SalaryColumnCategory.deduction;
    default:
      return SalaryColumnCategory.earning;
  }
}

String salaryColumnCategoryApi(SalaryColumnCategory c) =>
    c == SalaryColumnCategory.deduction ? 'DEDUCTION' : 'EARNING';

enum SalaryRuleType { fixed, percentage, conditional }

SalaryRuleType parseSalaryRuleType(String? raw) {
  switch (raw?.toUpperCase()) {
    case 'PERCENTAGE':
      return SalaryRuleType.percentage;
    case 'CONDITIONAL':
      return SalaryRuleType.conditional;
    default:
      return SalaryRuleType.fixed;
  }
}

enum SalaryRecordStatus { draft, finalized }

SalaryRecordStatus parseSalaryRecordStatus(String? raw) {
  return raw?.toUpperCase() == 'FINALIZED'
      ? SalaryRecordStatus.finalized
      : SalaryRecordStatus.draft;
}

String salaryRecordStatusApi(SalaryRecordStatus s) =>
    s == SalaryRecordStatus.finalized ? 'FINALIZED' : 'DRAFT';

class PayCommissionCounts {
  const PayCommissionCounts({
    this.columnDefinitions = 0,
    this.salaryStructureTemplates = 0,
    this.employeeSalaryInfos = 0,
  });

  final int columnDefinitions;
  final int salaryStructureTemplates;
  final int employeeSalaryInfos;

  factory PayCommissionCounts.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PayCommissionCounts();
    return PayCommissionCounts(
      columnDefinitions: _asInt(json['columnDefinitions'] ?? json['column_definitions']),
      salaryStructureTemplates: _asInt(
        json['salaryStructureTemplates'] ?? json['salary_structure_templates'],
      ),
      employeeSalaryInfos: _asInt(
        json['employeeSalaryInfos'] ?? json['employee_salary_infos'],
      ),
    );
  }
}

class PayCommission {
  const PayCommission({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.isActive = true,
    this.ruleEditorEnabled = true,
    this.sortOrder = 0,
    this.counts,
    this.columnDefinitions = const [],
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final bool isActive;
  final bool ruleEditorEnabled;
  final int sortOrder;
  final PayCommissionCounts? counts;
  final List<PayCommissionColumn> columnDefinitions;

  factory PayCommission.fromJson(Map<String, dynamic> json) {
    final cols = json['columnDefinitions'] ?? json['column_definitions'];
    return PayCommission(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      isActive: json['isActive'] ?? json['is_active'] ?? true,
      ruleEditorEnabled:
          json['ruleEditorEnabled'] ?? json['rule_editor_enabled'] ?? true,
      sortOrder: _asInt(json['sortOrder'] ?? json['sort_order']),
      counts: PayCommissionCounts.fromJson(
        json['_count'] is Map
            ? Map<String, dynamic>.from(json['_count'] as Map)
            : null,
      ),
      columnDefinitions: cols is List
          ? cols
              .map((e) => PayCommissionColumn.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : const [],
    );
  }
}

class PayCommissionColumn {
  const PayCommissionColumn({
    required this.id,
    required this.columnIdentifier,
    required this.displayName,
    required this.category,
    required this.evaluationOrder,
    this.isRuleConfigurable = true,
  });

  final String id;
  final String columnIdentifier;
  final String displayName;
  final SalaryColumnCategory category;
  final int evaluationOrder;
  final bool isRuleConfigurable;

  String get categoryKey => salaryColumnCategoryApi(category);

  String get visibilityKey => '$categoryKey::$columnIdentifier';

  factory PayCommissionColumn.fromJson(Map<String, dynamic> json) {
    return PayCommissionColumn(
      id: json['id']?.toString() ?? '',
      columnIdentifier: json['columnIdentifier']?.toString() ??
          json['column_identifier']?.toString() ??
          '',
      displayName: json['displayName']?.toString() ??
          json['display_name']?.toString() ??
          '',
      category: parseSalaryColumnCategory(
        json['category']?.toString(),
      ),
      evaluationOrder: _asInt(json['evaluationOrder'] ?? json['evaluation_order']),
      isRuleConfigurable: json['isRuleConfigurable'] ??
          json['is_rule_configurable'] ??
          true,
    );
  }
}

class DesignationRef {
  const DesignationRef({required this.id, required this.name});

  final String id;
  final String name;

  factory DesignationRef.fromJson(Map<String, dynamic> json) {
    return DesignationRef(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class SalaryStructureCommissionStatus {
  const SalaryStructureCommissionStatus({
    required this.payCommission,
    required this.configured,
    this.templateId,
  });

  final PayCommission payCommission;
  final bool configured;
  final String? templateId;

  factory SalaryStructureCommissionStatus.fromJson(Map<String, dynamic> json) {
    final pc = json['payCommission'] ?? json['pay_commission'];
    return SalaryStructureCommissionStatus(
      payCommission: PayCommission.fromJson(
        Map<String, dynamic>.from(pc as Map? ?? const {}),
      ),
      configured: json['configured'] == true,
      templateId: json['templateId']?.toString() ??
          json['template_id']?.toString(),
    );
  }
}

class SalaryStructureStatus {
  const SalaryStructureStatus({
    required this.designation,
    required this.commissions,
  });

  final DesignationRef designation;
  final List<SalaryStructureCommissionStatus> commissions;

  factory SalaryStructureStatus.fromJson(Map<String, dynamic> json) {
    final comms = json['commissions'];
    return SalaryStructureStatus(
      designation: DesignationRef.fromJson(
        Map<String, dynamic>.from(json['designation'] as Map? ?? const {}),
      ),
      commissions: comms is List
          ? comms
              .map((e) => SalaryStructureCommissionStatus.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : const [],
    );
  }
}

class SalaryTemplate {
  const SalaryTemplate({
    required this.id,
    this.designation,
    this.payCommission,
    this.columnVisibility = const {},
  });

  final String id;
  final DesignationRef? designation;
  final PayCommission? payCommission;
  final Map<String, bool> columnVisibility;

  factory SalaryTemplate.fromJson(Map<String, dynamic> json) {
    final vis = json['columnVisibility'] ?? json['column_visibility'];
    final visibility = <String, bool>{};
    if (vis is Map) {
      vis.forEach((k, v) {
        visibility[k.toString()] = v == true;
      });
    }
    return SalaryTemplate(
      id: json['id']?.toString() ?? '',
      designation: json['designation'] is Map
          ? DesignationRef.fromJson(
              Map<String, dynamic>.from(json['designation'] as Map),
            )
          : null,
      payCommission: json['payCommission'] is Map
          ? PayCommission.fromJson(
              Map<String, dynamic>.from(json['payCommission'] as Map),
            )
          : json['pay_commission'] is Map
              ? PayCommission.fromJson(
                  Map<String, dynamic>.from(json['pay_commission'] as Map),
                )
              : null,
      columnVisibility: visibility,
    );
  }
}

class SalaryRuleReferenceColumn {
  const SalaryRuleReferenceColumn({
    required this.columnIdentifier,
    this.weight = 1,
  });

  final String columnIdentifier;
  final num weight;

  factory SalaryRuleReferenceColumn.fromJson(Map<String, dynamic> json) {
    return SalaryRuleReferenceColumn(
      columnIdentifier: json['column_identifier']?.toString() ??
          json['columnIdentifier']?.toString() ??
          '',
      weight: json['weight'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'column_identifier': columnIdentifier,
        'weight': weight,
      };
}

class SalaryRuleCondition {
  const SalaryRuleCondition({
    required this.id,
    required this.comparator,
    required this.referenceColumnIdentifier,
    required this.thresholdValue,
    required this.resultType,
    required this.resultValue,
    this.resultReferenceColumnIdentifier,
    this.resultReferenceColumns = const [],
    this.sortOrder = 0,
    this.isElseFallback = false,
  });

  final String id;
  final String comparator;
  final String referenceColumnIdentifier;
  final String thresholdValue;
  final String resultType;
  final String resultValue;
  final String? resultReferenceColumnIdentifier;
  final List<SalaryRuleReferenceColumn> resultReferenceColumns;
  final int sortOrder;
  final bool isElseFallback;

  factory SalaryRuleCondition.fromJson(Map<String, dynamic> json) {
    final refs = json['resultReferenceColumns'] ?? json['result_reference_columns'];
    return SalaryRuleCondition(
      id: json['id']?.toString() ?? '',
      comparator: json['comparator']?.toString() ?? '',
      referenceColumnIdentifier: json['referenceColumnIdentifier']?.toString() ??
          json['reference_column_identifier']?.toString() ??
          '',
      thresholdValue: json['thresholdValue']?.toString() ??
          json['threshold_value']?.toString() ??
          '0',
      resultType: json['resultType']?.toString() ??
          json['result_type']?.toString() ??
          'FIXED_AMOUNT',
      resultValue: json['resultValue']?.toString() ??
          json['result_value']?.toString() ??
          '0',
      resultReferenceColumnIdentifier:
          json['resultReferenceColumnIdentifier']?.toString() ??
              json['result_reference_column_identifier']?.toString(),
      resultReferenceColumns: refs is List
          ? refs
              .map((e) => SalaryRuleReferenceColumn.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : const [],
      sortOrder: _asInt(json['sortOrder'] ?? json['sort_order']),
      isElseFallback: json['isElseFallback'] ?? json['is_else_fallback'] ?? false,
    );
  }
}

class SalaryRule {
  const SalaryRule({
    required this.id,
    required this.columnIdentifier,
    required this.category,
    required this.ruleType,
    this.formulaPreview = '',
    this.fixedDefaultValue,
    this.percentageValue,
    this.percentageReferenceColumns = const [],
    this.conditions = const [],
  });

  final String id;
  final String columnIdentifier;
  final SalaryColumnCategory category;
  final SalaryRuleType ruleType;
  final String formulaPreview;
  final String? fixedDefaultValue;
  final String? percentageValue;
  final List<SalaryRuleReferenceColumn> percentageReferenceColumns;
  final List<SalaryRuleCondition> conditions;

  String get mapKey =>
      '${salaryColumnCategoryApi(category)}::$columnIdentifier';

  factory SalaryRule.fromJson(Map<String, dynamic> json) {
    final pctRefs =
        json['percentageReferenceColumns'] ?? json['percentage_reference_columns'];
    final conds = json['conditions'];
    return SalaryRule(
      id: json['id']?.toString() ?? '',
      columnIdentifier: json['columnIdentifier']?.toString() ??
          json['column_identifier']?.toString() ??
          '',
      category: parseSalaryColumnCategory(json['category']?.toString()),
      ruleType: parseSalaryRuleType(
        json['ruleType']?.toString() ?? json['rule_type']?.toString(),
      ),
      formulaPreview: json['formulaPreview']?.toString() ??
          json['formula_preview']?.toString() ??
          '',
      fixedDefaultValue: json['fixedDefaultValue']?.toString() ??
          json['fixed_default_value']?.toString(),
      percentageValue: json['percentageValue']?.toString() ??
          json['percentage_value']?.toString(),
      percentageReferenceColumns: pctRefs is List
          ? pctRefs
              .map((e) => SalaryRuleReferenceColumn.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : const [],
      conditions: conds is List
          ? conds
              .map((e) => SalaryRuleCondition.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : const [],
    );
  }
}

class SalaryTemplateBundle {
  const SalaryTemplateBundle({
    this.template,
    this.columnDefinitions = const [],
    this.configured = false,
    this.payCommission,
    this.designation,
  });

  final SalaryTemplate? template;
  final List<PayCommissionColumn> columnDefinitions;
  final bool configured;
  final PayCommission? payCommission;
  final DesignationRef? designation;

  factory SalaryTemplateBundle.fromJson(Map<String, dynamic> json) {
    final cols = json['columnDefinitions'] ?? json['column_definitions'];
    return SalaryTemplateBundle(
      template: json['template'] != null
          ? SalaryTemplate.fromJson(
              Map<String, dynamic>.from(json['template'] as Map),
            )
          : null,
      columnDefinitions: cols is List
          ? cols
              .map((e) => PayCommissionColumn.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : const [],
      configured: json['configured'] == true,
      payCommission: json['payCommission'] is Map
          ? PayCommission.fromJson(
              Map<String, dynamic>.from(json['payCommission'] as Map),
            )
          : null,
      designation: json['designation'] is Map
          ? DesignationRef.fromJson(
              Map<String, dynamic>.from(json['designation'] as Map),
            )
          : json['template'] is Map &&
                  (json['template'] as Map)['designation'] is Map
              ? DesignationRef.fromJson(
                  Map<String, dynamic>.from(
                    (json['template'] as Map)['designation'] as Map,
                  ),
                )
              : null,
    );
  }
}

class ComputedSalaryColumn {
  const ComputedSalaryColumn({
    required this.columnIdentifier,
    required this.category,
    required this.ruleComputedValue,
    required this.effectiveValue,
    this.displayName,
    this.formulaPreview = '',
  });

  final String columnIdentifier;
  final String category;
  final String? displayName;
  final num ruleComputedValue;
  final num effectiveValue;
  final String formulaPreview;

  String get key => '$category::$columnIdentifier';

  factory ComputedSalaryColumn.fromJson(Map<String, dynamic> json) {
    return ComputedSalaryColumn(
      columnIdentifier: json['column_identifier']?.toString() ??
          json['columnIdentifier']?.toString() ??
          '',
      category: json['category']?.toString() ?? 'EARNING',
      displayName: json['display_name']?.toString() ??
          json['displayName']?.toString(),
      ruleComputedValue: _asNum(
        json['rule_computed_value'] ?? json['ruleComputedValue'],
      ),
      effectiveValue: _asNum(
        json['effective_value'] ?? json['effectiveValue'],
      ),
      formulaPreview: json['formula_preview']?.toString() ??
          json['formulaPreview']?.toString() ??
          '',
    );
  }
}

class ComputedSalaryResult {
  const ComputedSalaryResult({
    required this.columns,
    required this.grossPay,
    required this.totalDeductions,
    required this.netPay,
  });

  final List<ComputedSalaryColumn> columns;
  final num grossPay;
  final num totalDeductions;
  final num netPay;

  factory ComputedSalaryResult.fromJson(Map<String, dynamic> json) {
    final cols = json['columns'];
    return ComputedSalaryResult(
      columns: cols is List
          ? cols
              .map((e) => ComputedSalaryColumn.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : const [],
      grossPay: _asNum(json['gross_pay'] ?? json['grossPay']),
      totalDeductions: _asNum(
        json['total_deductions'] ?? json['totalDeductions'],
      ),
      netPay: _asNum(json['net_pay'] ?? json['netPay']),
    );
  }
}

class SalaryRecordColumnValue {
  const SalaryRecordColumnValue({
    required this.columnIdentifier,
    required this.category,
    required this.ruleComputedValue,
    required this.effectiveValue,
    this.overrideValue,
    this.formulaPreview = '',
  });

  final String columnIdentifier;
  final String category;
  final String ruleComputedValue;
  final String? overrideValue;
  final String effectiveValue;
  final String formulaPreview;

  String get key => '$category::$columnIdentifier';

  factory SalaryRecordColumnValue.fromJson(Map<String, dynamic> json) {
    return SalaryRecordColumnValue(
      columnIdentifier: json['columnIdentifier']?.toString() ??
          json['column_identifier']?.toString() ??
          '',
      category: json['category']?.toString() ?? 'EARNING',
      ruleComputedValue: json['ruleComputedValue']?.toString() ??
          json['rule_computed_value']?.toString() ??
          '0',
      overrideValue: json['overrideValue']?.toString() ??
          json['override_value']?.toString(),
      effectiveValue: json['effectiveValue']?.toString() ??
          json['effective_value']?.toString() ??
          '0',
      formulaPreview: json['formulaPreview']?.toString() ??
          json['formula_preview']?.toString() ??
          '',
    );
  }
}

class SalaryRecordEmployee {
  const SalaryRecordEmployee({this.fullName, this.department});

  final String? fullName;
  final String? department;

  factory SalaryRecordEmployee.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SalaryRecordEmployee();
    final general = json['generalInfo'] ?? json['general_info'];
    if (general is Map) {
      final g = Map<String, dynamic>.from(general);
      return SalaryRecordEmployee(
        fullName: g['fullName']?.toString() ?? g['full_name']?.toString(),
        department: g['department']?.toString(),
      );
    }
    return SalaryRecordEmployee(
      fullName: json['fullName']?.toString() ?? json['full_name']?.toString(),
      department: json['department']?.toString(),
    );
  }
}

class SalaryRecord {
  const SalaryRecord({
    required this.id,
    required this.employeeId,
    required this.salaryMonth,
    required this.salaryYear,
    required this.status,
    required this.grossPay,
    required this.totalDeductions,
    required this.netPay,
    required this.payCommissionCode,
    this.employee,
    this.template,
    this.columnValues = const [],
  });

  final String id;
  final int employeeId;
  final int salaryMonth;
  final int salaryYear;
  final SalaryRecordStatus status;
  final String grossPay;
  final String totalDeductions;
  final String netPay;
  final String payCommissionCode;
  final SalaryRecordEmployee? employee;
  final SalaryTemplate? template;
  final List<SalaryRecordColumnValue> columnValues;

  factory SalaryRecord.fromJson(Map<String, dynamic> json) {
    final cols = json['columnValues'] ?? json['column_values'];
    return SalaryRecord(
      id: json['id']?.toString() ?? '',
      employeeId: _asInt(json['employeeId'] ?? json['employee_id']),
      salaryMonth: _asInt(json['salaryMonth'] ?? json['salary_month']),
      salaryYear: _asInt(json['salaryYear'] ?? json['salary_year']),
      status: parseSalaryRecordStatus(
        json['status']?.toString(),
      ),
      grossPay: json['grossPay']?.toString() ??
          json['gross_pay']?.toString() ??
          '0',
      totalDeductions: json['totalDeductions']?.toString() ??
          json['total_deductions']?.toString() ??
          '0',
      netPay: json['netPay']?.toString() ?? json['net_pay']?.toString() ?? '0',
      payCommissionCode: json['payCommissionCode']?.toString() ??
          json['payCommissionType']?.toString() ??
          json['pay_commission_code']?.toString() ??
          '',
      employee: json['employee'] is Map
          ? SalaryRecordEmployee.fromJson(
              Map<String, dynamic>.from(json['employee'] as Map),
            )
          : null,
      template: json['template'] is Map
          ? SalaryTemplate.fromJson(
              Map<String, dynamic>.from(json['template'] as Map),
            )
          : null,
      columnValues: cols is List
          ? cols
              .map((e) => SalaryRecordColumnValue.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : const [],
    );
  }
}

class SalarySlipLine {
  const SalarySlipLine({
    required this.columnIdentifier,
    required this.effectiveValue,
    this.formulaPreview,
  });

  final String columnIdentifier;
  final String effectiveValue;
  final String? formulaPreview;

  factory SalarySlipLine.fromJson(Map<String, dynamic> json) {
    return SalarySlipLine(
      columnIdentifier: json['columnIdentifier']?.toString() ??
          json['column_identifier']?.toString() ??
          '',
      effectiveValue: json['effectiveValue']?.toString() ??
          json['effective_value']?.toString() ??
          '0',
      formulaPreview: json['formulaPreview']?.toString() ??
          json['formula_preview']?.toString(),
    );
  }
}

class SalarySlipEmployee {
  const SalarySlipEmployee({
    required this.id,
    required this.name,
    required this.designation,
    required this.department,
  });

  final int id;
  final String name;
  final String designation;
  final String department;

  factory SalarySlipEmployee.fromJson(Map<String, dynamic> json) {
    return SalarySlipEmployee(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
    );
  }
}

class SalarySlip {
  const SalarySlip({
    required this.institutionName,
    required this.monthYear,
    required this.employee,
    required this.earnings,
    required this.deductions,
    required this.grossPay,
    required this.totalDeductions,
    required this.netPay,
  });

  final String institutionName;
  final String monthYear;
  final SalarySlipEmployee employee;
  final List<SalarySlipLine> earnings;
  final List<SalarySlipLine> deductions;
  final num grossPay;
  final num totalDeductions;
  final num netPay;

  factory SalarySlip.fromJson(Map<String, dynamic> json) {
    final earnings = json['earnings'];
    final deductions = json['deductions'];
    return SalarySlip(
      institutionName: json['institutionName']?.toString() ??
          json['institution_name']?.toString() ??
          '',
      monthYear: json['monthYear']?.toString() ??
          json['month_year']?.toString() ??
          '',
      employee: SalarySlipEmployee.fromJson(
        Map<String, dynamic>.from(json['employee'] as Map? ?? const {}),
      ),
      earnings: earnings is List
          ? earnings
              .map((e) => SalarySlipLine.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : const [],
      deductions: deductions is List
          ? deductions
              .map((e) => SalarySlipLine.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : const [],
      grossPay: _asNum(json['grossPay'] ?? json['gross_pay']),
      totalDeductions: _asNum(
        json['totalDeductions'] ?? json['total_deductions'],
      ),
      netPay: _asNum(json['netPay'] ?? json['net_pay']),
    );
  }
}

class PayCommissionRef {
  const PayCommissionRef({required this.code, this.name});

  final String code;
  final String? name;

  factory PayCommissionRef.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PayCommissionRef(code: '');
    return PayCommissionRef(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString(),
    );
  }
}

class EmployeeSalaryProfile {
  const EmployeeSalaryProfile({
    this.designationId,
    this.payCommissionRef,
    this.columnOverrides = const {},
    this.columnRules = const {},
  });

  final String? designationId;
  final PayCommissionRef? payCommissionRef;
  final Map<String, num> columnOverrides;
  final Map<String, Map<String, dynamic>> columnRules;

  factory EmployeeSalaryProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EmployeeSalaryProfile();
    final overrides = json['columnOverrides'] ?? json['column_overrides'];
    final rules = json['columnRules'] ?? json['column_rules'];
    final overrideMap = <String, num>{};
    if (overrides is Map) {
      overrides.forEach((k, v) {
        overrideMap[k.toString()] = _asNum(v);
      });
    }
    final rulesMap = <String, Map<String, dynamic>>{};
    if (rules is Map) {
      rules.forEach((k, v) {
        if (v is Map) {
          rulesMap[k.toString()] = Map<String, dynamic>.from(v);
        }
      });
    }
    final pc = json['payCommissionRef'] ?? json['pay_commission_ref'];
    return EmployeeSalaryProfile(
      designationId: json['designationId']?.toString() ??
          json['designation_id']?.toString(),
      payCommissionRef: pc is Map
          ? PayCommissionRef.fromJson(Map<String, dynamic>.from(pc))
          : null,
      columnOverrides: overrideMap,
      columnRules: rulesMap,
    );
  }
}

class EmployeeSalaryProfileResponse {
  const EmployeeSalaryProfileResponse({
    this.profile,
    this.latestFinalizedRecord,
  });

  final EmployeeSalaryProfile? profile;
  final SalaryRecord? latestFinalizedRecord;

  factory EmployeeSalaryProfileResponse.fromJson(Map<String, dynamic> json) {
    return EmployeeSalaryProfileResponse(
      profile: json['profile'] is Map
          ? EmployeeSalaryProfile.fromJson(
              Map<String, dynamic>.from(json['profile'] as Map),
            )
          : null,
      latestFinalizedRecord: json['latestFinalizedRecord'] is Map
          ? SalaryRecord.fromJson(
              Map<String, dynamic>.from(json['latestFinalizedRecord'] as Map),
            )
          : json['latest_finalized_record'] is Map
              ? SalaryRecord.fromJson(
                  Map<String, dynamic>.from(
                    json['latest_finalized_record'] as Map,
                  ),
                )
              : null,
    );
  }
}

class SalaryEmployeeOption {
  const SalaryEmployeeOption({
    required this.id,
    required this.fullName,
    this.designationId,
  });

  final int id;
  final String fullName;
  final String? designationId;
}

int _asInt(Object? value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

num _asNum(Object? value, [num fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value;
  return num.tryParse(value.toString()) ?? fallback;
}
