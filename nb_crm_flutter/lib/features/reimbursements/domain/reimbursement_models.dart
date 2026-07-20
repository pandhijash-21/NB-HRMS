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
    this.openingKm,
    this.closingKm,
    this.proofUrl,
    required this.status,
    this.salaryMonth,
    this.salaryYear,
    this.employeeName,
    this.employeeCode,
    this.designation,
    this.department,
    this.approvalSteps = const [],
    this.appliedAt,
  });

  final String id;
  final String claimNo;
  final int employeeId;
  final String title;
  final String description;
  final double amount;
  final double? openingKm;
  final double? closingKm;
  final String? proofUrl;
  final ReimbursementStatus status;
  final int? salaryMonth;
  final int? salaryYear;
  final String? employeeName;
  final String? employeeCode;
  final String? designation;
  final String? department;
  final List<ReimbursementApprovalStep> approvalSteps;
  final DateTime? appliedAt;

  factory ReimbursementClaim.fromJson(Map<String, dynamic> json) {
    final emp = json['employee'];
    Map<String, dynamic>? gi;
    if (emp is Map) {
      final g = emp['generalInfo'];
      if (g is Map) gi = Map<String, dynamic>.from(g);
    }
    final stepsRaw = json['approvalSteps'];
    return ReimbursementClaim(
      id: json['id'] as String,
      claimNo: json['claimNo'] as String? ?? '',
      employeeId: json['employeeId'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse('${json['amount']}') ?? 0,
      openingKm: json['openingKm'] != null ? (json['openingKm'] as num).toDouble() : null,
      closingKm: json['closingKm'] != null ? (json['closingKm'] as num).toDouble() : null,
      proofUrl: json['proofUrl'] as String?,
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
