import 'dart:convert';

class ErpActivitySubtask {
  const ErpActivitySubtask({
    required this.id,
    required this.activityId,
    required this.name,
    this.description,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String activityId;
  final String name;
  final String? description;
  final bool isActive;
  final int sortOrder;

  factory ErpActivitySubtask.fromJson(Map<String, dynamic> json) => ErpActivitySubtask(
        id: json['id']?.toString() ?? '',
        activityId: json['activityId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        isActive: json['isActive'] == true,
        sortOrder: int.tryParse('${json['sortOrder']}') ?? 0,
      );

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'name': name,
        if (description != null && description!.isNotEmpty) 'description': description,
        'isActive': isActive,
        'sortOrder': sortOrder,
      };
}

class ErpActivity {
  const ErpActivity({
    required this.id,
    required this.name,
    this.isActive = true,
    this.sortOrder = 0,
    this.subtasks = const [],
  });

  final String id;
  final String name;
  final bool isActive;
  final int sortOrder;
  final List<ErpActivitySubtask> subtasks;

  factory ErpActivity.fromJson(Map<String, dynamic> json) {
    final subs = json['subtasks'];
    return ErpActivity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isActive: json['isActive'] != false,
      sortOrder: int.tryParse('${json['sortOrder']}') ?? 0,
      subtasks: subs is List
          ? subs
              .map((e) => ErpActivitySubtask.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'isActive': isActive,
        'sortOrder': sortOrder,
        'subtasks': subtasks.map((s) => s.toJson()).toList(),
      };
}

class ErpContractor {
  const ErpContractor({
    required this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final bool isActive;

  factory ErpContractor.fromJson(Map<String, dynamic> json) => ErpContractor(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        contactPerson: json['contactPerson']?.toString(),
        phone: json['phone']?.toString(),
        email: json['email']?.toString(),
        isActive: json['isActive'] != false,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'contactPerson': contactPerson,
        'phone': phone,
        'email': email,
        'isActive': isActive,
      };
}

class WorkOrderEmployeeRef {
  const WorkOrderEmployeeRef({
    required this.id,
    this.abbreviation,
    this.photoUrl,
    this.fullName,
  });

  final int id;
  final String? abbreviation;
  final String? photoUrl;
  final String? fullName;

  String get displayName => fullName ?? abbreviation ?? '#$id';

  factory WorkOrderEmployeeRef.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WorkOrderEmployeeRef(id: 0);
    final g = json['generalInfo'];
    final general = g is Map ? Map<String, dynamic>.from(g) : <String, dynamic>{};
    return WorkOrderEmployeeRef(
      id: int.tryParse('${json['id']}') ?? 0,
      abbreviation: json['abbreviation']?.toString(),
      photoUrl: json['photoUrl']?.toString(),
      fullName: general['fullName']?.toString(),
    );
  }
}

class WorkOrderProjectRef {
  const WorkOrderProjectRef({
    required this.id,
    required this.name,
    this.projectNo,
    this.imageUrl,
    this.categoryCode,
    this.statusCode,
  });

  final String id;
  final String name;
  final int? projectNo;
  final String? imageUrl;
  final String? categoryCode;
  final String? statusCode;

  factory WorkOrderProjectRef.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WorkOrderProjectRef(id: '', name: '');
    return WorkOrderProjectRef(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      projectNo: int.tryParse('${json['projectNo']}'),
      imageUrl: json['imageUrl']?.toString(),
      categoryCode: json['categoryCode']?.toString(),
      statusCode: json['statusCode']?.toString(),
    );
  }
}

class WorkOrderLine {
  const WorkOrderLine({
    this.id,
    required this.workDetail,
    this.towerIds = const [],
    this.floorNos = const [],
    this.unitIds = const [],
    this.quantity,
    this.unitCode,
    this.rate,
    this.amount,
    this.sortOrder = 0,
  });

  final String? id;
  final String workDetail;
  final List<String> towerIds;
  final List<int> floorNos;
  final List<String> unitIds;
  final double? quantity;
  final String? unitCode;
  final double? rate;
  final double? amount;
  final int sortOrder;

  static List<String> _parseStringList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  static List<int> _parseIntList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw.map((e) => int.tryParse('$e')).whereType<int>().toList();
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => int.tryParse('$e')).whereType<int>().toList();
        }
      } catch (_) {}
    }
    return [];
  }

  factory WorkOrderLine.fromJson(Map<String, dynamic> json) => WorkOrderLine(
        id: json['id']?.toString(),
        workDetail: json['workDetail']?.toString() ?? '',
        towerIds: _parseStringList(json['towerIds']),
        floorNos: _parseIntList(json['floorNos']),
        unitIds: _parseStringList(json['unitIds']),
        quantity: double.tryParse('${json['quantity']}'),
        unitCode: json['unitCode']?.toString(),
        rate: double.tryParse('${json['rate']}'),
        amount: double.tryParse('${json['amount']}'),
        sortOrder: int.tryParse('${json['sortOrder']}') ?? 0,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'workDetail': workDetail,
        'towerIds': towerIds,
        'floorNos': floorNos,
        'unitIds': unitIds,
        'quantity': quantity,
        'unitCode': unitCode,
        'rate': rate,
        'amount': amount ?? ((quantity ?? 0) * (rate ?? 0)),
        'sortOrder': sortOrder,
      };

  WorkOrderLine copyWith({
    String? workDetail,
    List<String>? towerIds,
    List<int>? floorNos,
    List<String>? unitIds,
    double? quantity,
    String? unitCode,
    double? rate,
    double? amount,
  }) =>
      WorkOrderLine(
        id: id,
        workDetail: workDetail ?? this.workDetail,
        towerIds: towerIds ?? this.towerIds,
        floorNos: floorNos ?? this.floorNos,
        unitIds: unitIds ?? this.unitIds,
        quantity: quantity ?? this.quantity,
        unitCode: unitCode ?? this.unitCode,
        rate: rate ?? this.rate,
        amount: amount ?? this.amount,
        sortOrder: sortOrder,
      );
}

class WorkOrderActivityGroup {
  const WorkOrderActivityGroup({
    this.id,
    this.activityId,
    required this.activityName,
    this.sortOrder = 0,
    this.lines = const [],
  });

  final String? id;
  final String? activityId;
  final String activityName;
  final int sortOrder;
  final List<WorkOrderLine> lines;

  factory WorkOrderActivityGroup.fromJson(Map<String, dynamic> json) {
    final linesRaw = json['lines'];
    return WorkOrderActivityGroup(
      id: json['id']?.toString(),
      activityId: json['activityId']?.toString(),
      activityName: json['activityName']?.toString() ?? '',
      sortOrder: int.tryParse('${json['sortOrder']}') ?? 0,
      lines: linesRaw is List
          ? linesRaw
              .map((e) => WorkOrderLine.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'activityId': activityId,
        'activityName': activityName,
        'sortOrder': sortOrder,
        'lines': lines.map((l) => l.toJson()).toList(),
      };

  double get subtotal => lines.fold(0, (s, l) => s + (l.amount ?? 0));
}

class ErpWorkOrder {
  const ErpWorkOrder({
    required this.id,
    required this.workOrderId,
    required this.orderDate,
    this.dueDate,
    required this.projectId,
    this.tenderRef,
    this.contractorId,
    this.categoryCode,
    this.status = 'ISSUED',
    this.approvalStatus = 'PENDING',
    this.approverEmployeeId,
    this.ownerEmployeeId,
    this.totalAmount = 0,
    this.project,
    this.contractor,
    this.owner,
    this.approver,
    this.activities = const [],
  });

  final String id;
  final String workOrderId;
  final DateTime orderDate;
  final DateTime? dueDate;
  final String projectId;
  final String? tenderRef;
  final String? contractorId;
  final String? categoryCode;
  final String status;
  final String approvalStatus;
  final int? approverEmployeeId;
  final int? ownerEmployeeId;
  final double totalAmount;
  final WorkOrderProjectRef? project;
  final ErpContractor? contractor;
  final WorkOrderEmployeeRef? owner;
  final WorkOrderEmployeeRef? approver;
  final List<WorkOrderActivityGroup> activities;

  factory ErpWorkOrder.fromJson(Map<String, dynamic> json) {
    final acts = json['activities'];
    final contractorRaw = json['contractor'];
    return ErpWorkOrder(
      id: json['id']?.toString() ?? '',
      workOrderId: json['workOrderId']?.toString() ?? '',
      orderDate: DateTime.tryParse(json['orderDate']?.toString() ?? '') ?? DateTime.now(),
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate'].toString()) : null,
      projectId: json['projectId']?.toString() ?? '',
      tenderRef: json['tenderRef']?.toString(),
      contractorId: json['contractorId']?.toString(),
      categoryCode: json['categoryCode']?.toString(),
      status: json['status']?.toString() ?? 'ISSUED',
      approvalStatus: json['approvalStatus']?.toString() ?? 'PENDING',
      approverEmployeeId: int.tryParse('${json['approverEmployeeId']}'),
      ownerEmployeeId: int.tryParse('${json['ownerEmployeeId']}'),
      totalAmount: double.tryParse('${json['totalAmount']}') ?? 0,
      project: WorkOrderProjectRef.fromJson(
        json['project'] is Map ? Map<String, dynamic>.from(json['project'] as Map) : null,
      ),
      contractor: contractorRaw is Map
          ? ErpContractor.fromJson(Map<String, dynamic>.from(contractorRaw))
          : null,
      owner: WorkOrderEmployeeRef.fromJson(
        json['owner'] is Map ? Map<String, dynamic>.from(json['owner'] as Map) : null,
      ),
      approver: WorkOrderEmployeeRef.fromJson(
        json['approver'] is Map ? Map<String, dynamic>.from(json['approver'] as Map) : null,
      ),
      activities: acts is List
          ? acts
              .map((e) => WorkOrderActivityGroup.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toCreateJson() => {
        'workOrderId': workOrderId,
        'orderDate': orderDate.toIso8601String().split('T').first,
        if (dueDate != null) 'dueDate': dueDate!.toIso8601String().split('T').first,
        'projectId': projectId,
        if (tenderRef != null) 'tenderRef': tenderRef,
        if (contractorId != null) 'contractorId': contractorId,
        if (categoryCode != null) 'categoryCode': categoryCode,
        'status': status,
        'approvalStatus': approvalStatus,
        if (approverEmployeeId != null) 'approverEmployeeId': approverEmployeeId,
        if (ownerEmployeeId != null) 'ownerEmployeeId': ownerEmployeeId,
        'activities': activities.map((a) => a.toJson()).toList(),
      };
}
