enum ReimbursementStatus {
  PENDING,
  APPROVED,
  REJECTED,
  CANCELLED,
  unknown;

  static ReimbursementStatus fromString(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'PENDING':
        return ReimbursementStatus.PENDING;
      case 'APPROVED':
        return ReimbursementStatus.APPROVED;
      case 'REJECTED':
        return ReimbursementStatus.REJECTED;
      case 'CANCELLED':
        return ReimbursementStatus.CANCELLED;
      default:
        return ReimbursementStatus.unknown;
    }
  }
}

enum ReimbursementAmountMode {
  kmRate,
  manual;

  static ReimbursementAmountMode fromString(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'MANUAL':
        return ReimbursementAmountMode.manual;
      default:
        return ReimbursementAmountMode.kmRate;
    }
  }

  String get api => this == ReimbursementAmountMode.manual ? 'MANUAL' : 'KM_RATE';
}

enum ReimbursementFieldKind {
  text,
  number,
  kmOpening,
  kmClosing,
  date,
  file,
  amount;

  static ReimbursementFieldKind fromString(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'NUMBER':
        return ReimbursementFieldKind.number;
      case 'KM_OPENING':
        return ReimbursementFieldKind.kmOpening;
      case 'KM_CLOSING':
        return ReimbursementFieldKind.kmClosing;
      case 'DATE':
        return ReimbursementFieldKind.date;
      case 'FILE':
        return ReimbursementFieldKind.file;
      case 'AMOUNT':
        return ReimbursementFieldKind.amount;
      default:
        return ReimbursementFieldKind.text;
    }
  }

  String get api {
    switch (this) {
      case ReimbursementFieldKind.text:
        return 'TEXT';
      case ReimbursementFieldKind.number:
        return 'NUMBER';
      case ReimbursementFieldKind.kmOpening:
        return 'KM_OPENING';
      case ReimbursementFieldKind.kmClosing:
        return 'KM_CLOSING';
      case ReimbursementFieldKind.date:
        return 'DATE';
      case ReimbursementFieldKind.file:
        return 'FILE';
      case ReimbursementFieldKind.amount:
        return 'AMOUNT';
    }
  }

  String get label {
    switch (this) {
      case ReimbursementFieldKind.text:
        return 'Text';
      case ReimbursementFieldKind.number:
        return 'Number';
      case ReimbursementFieldKind.kmOpening:
        return 'Opening km';
      case ReimbursementFieldKind.kmClosing:
        return 'Closing km';
      case ReimbursementFieldKind.date:
        return 'Date';
      case ReimbursementFieldKind.file:
        return 'File';
      case ReimbursementFieldKind.amount:
        return 'Amount';
    }
  }
}

class ReimbursementFieldDef {
  const ReimbursementFieldDef({
    required this.id,
    required this.key,
    required this.label,
    required this.fieldKind,
    this.requiresProof = false,
    this.isRequired = true,
    this.sortOrder = 0,
  });

  final String id;
  final String key;
  final String label;
  final ReimbursementFieldKind fieldKind;
  final bool requiresProof;
  final bool isRequired;
  final int sortOrder;

  factory ReimbursementFieldDef.fromJson(Map<String, dynamic> json) {
    return ReimbursementFieldDef(
      id: json['id']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      fieldKind: ReimbursementFieldKind.fromString(json['fieldKind']?.toString()),
      requiresProof: json['requiresProof'] == true,
      isRequired: json['isRequired'] != false,
      sortOrder: (json['sortOrder'] is num) ? (json['sortOrder'] as num).toInt() : 0,
    );
  }

  Map<String, dynamic> toApiJson() => {
        'key': key,
        'label': label,
        'fieldKind': fieldKind.api,
        'requiresProof': requiresProof,
        'isRequired': isRequired,
        'sortOrder': sortOrder,
      };
}

class ReimbursementType {
  const ReimbursementType({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.amountMode = ReimbursementAmountMode.kmRate,
    this.ratePerUnit,
    this.approverUserId,
    this.approverName,
    this.isActive = true,
    this.sortOrder = 0,
    this.fields = const [],
    this.claimsCount = 0,
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final ReimbursementAmountMode amountMode;
  final double? ratePerUnit;
  final String? approverUserId;
  final String? approverName;
  final bool isActive;
  final int sortOrder;
  final List<ReimbursementFieldDef> fields;
  final int claimsCount;

  factory ReimbursementType.fromJson(Map<String, dynamic> json) {
    final fieldsRaw = json['fields'];
    final count = json['_count'];
    return ReimbursementType(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      amountMode: ReimbursementAmountMode.fromString(json['amountMode']?.toString()),
      ratePerUnit: json['ratePerUnit'] != null
          ? (json['ratePerUnit'] is num
              ? (json['ratePerUnit'] as num).toDouble()
              : double.tryParse('${json['ratePerUnit']}'))
          : null,
      approverUserId: json['approverUserId']?.toString(),
      approverName: json['approverName']?.toString(),
      isActive: json['isActive'] != false,
      sortOrder: (json['sortOrder'] is num) ? (json['sortOrder'] as num).toInt() : 0,
      fields: fieldsRaw is List
          ? fieldsRaw
              .map((e) => ReimbursementFieldDef.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
      claimsCount: count is Map && count['claims'] is num ? (count['claims'] as num).toInt() : 0,
    );
  }
}

class ReimbursementClaimValue {
  const ReimbursementClaimValue({
    required this.id,
    required this.fieldDefId,
    this.valueText,
    this.valueNumber,
    this.proofUrl,
    this.fieldLabel,
    this.fieldKind,
  });

  final String id;
  final String fieldDefId;
  final String? valueText;
  final double? valueNumber;
  final String? proofUrl;
  final String? fieldLabel;
  final ReimbursementFieldKind? fieldKind;

  factory ReimbursementClaimValue.fromJson(Map<String, dynamic> json) {
    final fd = json['fieldDef'];
    Map<String, dynamic>? field;
    if (fd is Map) field = Map<String, dynamic>.from(fd);
    return ReimbursementClaimValue(
      id: json['id']?.toString() ?? '',
      fieldDefId: json['fieldDefId']?.toString() ?? '',
      valueText: json['valueText']?.toString(),
      valueNumber: json['valueNumber'] != null ? (json['valueNumber'] as num).toDouble() : null,
      proofUrl: json['proofUrl']?.toString(),
      fieldLabel: field?['label']?.toString(),
      fieldKind: field != null
          ? ReimbursementFieldKind.fromString(field['fieldKind']?.toString())
          : null,
    );
  }
}

class ReimbursementApprovalStep {
  const ReimbursementApprovalStep({
    required this.id,
    required this.stepNumber,
    required this.approverRole,
    this.approverUserId,
    this.action,
    this.remarks,
    this.actionAt,
    this.isSuperseded = false,
  });

  final String id;
  final int stepNumber;
  final String approverRole;
  final String? approverUserId;
  final String? action;
  final String? remarks;
  final DateTime? actionAt;
  final bool isSuperseded;

  factory ReimbursementApprovalStep.fromJson(Map<String, dynamic> json) {
    return ReimbursementApprovalStep(
      id: json['id'] as String,
      stepNumber: json['stepNumber'] as int? ?? 0,
      approverRole: json['approverRole'] as String? ?? '',
      approverUserId: json['approverUserId'] as String?,
      action: json['action'] as String?,
      remarks: json['remarks'] as String?,
      actionAt: json['actionAt'] != null ? DateTime.tryParse(json['actionAt'].toString()) : null,
      isSuperseded: json['isSuperseded'] as bool? ?? false,
    );
  }
}

class ReimbursementClaim {
  const ReimbursementClaim({
    required this.id,
    required this.claimNo,
    required this.employeeId,
    required this.title,
    required this.description,
    required this.amount,
    this.typeId,
    this.typeName,
    this.claimDate,
    this.onBehalfBy,
    this.openingKm,
    this.closingKm,
    this.proofUrl,
    this.openingKmPhotoUrl,
    this.closingKmPhotoUrl,
    required this.status,
    this.salaryMonth,
    this.salaryYear,
    this.employeeName,
    this.employeeCode,
    this.designation,
    this.department,
    this.approvalSteps = const [],
    this.values = const [],
    this.appliedAt,
  });

  final String id;
  final String claimNo;
  final int employeeId;
  final String title;
  final String description;
  final double amount;
  final String? typeId;
  final String? typeName;
  final DateTime? claimDate;
  final String? onBehalfBy;
  final double? openingKm;
  final double? closingKm;
  final String? proofUrl;
  final String? openingKmPhotoUrl;
  final String? closingKmPhotoUrl;
  final ReimbursementStatus status;
  final int? salaryMonth;
  final int? salaryYear;
  final String? employeeName;
  final String? employeeCode;
  final String? designation;
  final String? department;
  final List<ReimbursementApprovalStep> approvalSteps;
  final List<ReimbursementClaimValue> values;
  final DateTime? appliedAt;

  factory ReimbursementClaim.fromJson(Map<String, dynamic> json) {
    final emp = json['employee'];
    Map<String, dynamic>? gi;
    if (emp is Map) {
      final g = emp['generalInfo'];
      if (g is Map) gi = Map<String, dynamic>.from(g);
    }
    final type = json['type'];
    final stepsRaw = json['approvalSteps'];
    final valuesRaw = json['values'];
    return ReimbursementClaim(
      id: json['id'] as String,
      claimNo: json['claimNo'] as String? ?? '',
      employeeId: json['employeeId'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse('${json['amount']}') ?? 0,
      typeId: json['typeId']?.toString(),
      typeName: type is Map ? type['name']?.toString() : null,
      claimDate:
          json['claimDate'] != null ? DateTime.tryParse(json['claimDate'].toString()) : null,
      onBehalfBy: json['onBehalfBy']?.toString(),
      openingKm: json['openingKm'] != null ? (json['openingKm'] as num).toDouble() : null,
      closingKm: json['closingKm'] != null ? (json['closingKm'] as num).toDouble() : null,
      proofUrl: json['proofUrl'] as String?,
      openingKmPhotoUrl: json['openingKmPhotoUrl'] as String?,
      closingKmPhotoUrl: json['closingKmPhotoUrl'] as String?,
      status: ReimbursementStatus.fromString(json['status'] as String?),
      salaryMonth: json['salaryMonth'] as int?,
      salaryYear: json['salaryYear'] as int?,
      employeeName: gi?['fullName'] as String?,
      employeeCode: gi?['employeeCode'] as String?,
      designation: gi?['designation'] as String?,
      department: gi?['department'] as String?,
      approvalSteps: stepsRaw is List
          ? stepsRaw
              .map((e) => ReimbursementApprovalStep.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
      values: valuesRaw is List
          ? valuesRaw
              .map((e) => ReimbursementClaimValue.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
      appliedAt: json['appliedAt'] != null ? DateTime.tryParse(json['appliedAt'].toString()) : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case ReimbursementStatus.PENDING:
        return 'Pending';
      case ReimbursementStatus.APPROVED:
        return 'Approved';
      case ReimbursementStatus.REJECTED:
        return 'Rejected';
      case ReimbursementStatus.CANCELLED:
        return 'Cancelled';
      case ReimbursementStatus.unknown:
        return 'Unknown';
    }
  }

  int? get currentStepNumber {
    final pending = approvalSteps.where((s) => !s.isSuperseded && s.action == null).toList();
    if (pending.isEmpty) return null;
    return pending.map((s) => s.stepNumber).reduce((a, b) => a < b ? a : b);
  }
}
