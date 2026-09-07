class ErpMaterialStockLog {
  const ErpMaterialStockLog({
    required this.id,
    required this.materialId,
    required this.logType,
    required this.quantity,
    this.contractorId,
    this.contractorName,
    this.remarks,
    this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String materialId;
  final String logType; // 'PURCHASE' | 'CONSUMPTION' | 'INITIAL' | 'ADJUSTMENT'
  final double quantity;
  final String? contractorId;
  final String? contractorName;
  final String? remarks;
  final String? createdBy;
  final DateTime createdAt;

  factory ErpMaterialStockLog.fromJson(Map<String, dynamic> json) {
    String? cName = json['contractorName']?.toString();
    if ((cName == null || cName.isEmpty) && json['contractor'] is Map) {
      cName = (json['contractor'] as Map)['name']?.toString();
    }
    return ErpMaterialStockLog(
      id: json['id']?.toString() ?? '',
      materialId: json['materialId']?.toString() ?? '',
      logType: json['logType']?.toString() ?? 'PURCHASE',
      quantity: _d(json['quantity']),
      contractorId: json['contractorId']?.toString(),
      contractorName: cName,
      remarks: json['remarks']?.toString(),
      createdBy: json['createdBy']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class ErpMaterial {
  const ErpMaterial({
    required this.id,
    this.brand,
    required this.name,
    this.unitCode,
    this.size,
    this.activityId,
    this.subtaskId,
    this.qtyOnHand = 0,
    this.qtyTotal = 0,
    this.qtyUsed = 0,
    this.qtyAvailable = 0,
    this.isActive = true,
    this.stockLogs = const [],
  });

  final String id;
  final String? brand;
  final String name;
  final String? unitCode;
  final String? size;
  final String? activityId;
  final String? subtaskId;
  final double qtyOnHand;
  final double qtyTotal;
  final double qtyUsed;
  final double qtyAvailable;
  final bool isActive;
  final List<ErpMaterialStockLog> stockLogs;

  factory ErpMaterial.fromJson(Map<String, dynamic> json) => ErpMaterial(
        id: json['id']?.toString() ?? '',
        brand: json['brand']?.toString(),
        name: json['name']?.toString() ?? '',
        unitCode: json['unitCode']?.toString(),
        size: json['size']?.toString(),
        activityId: json['activityId']?.toString(),
        subtaskId: json['subtaskId']?.toString(),
        qtyOnHand: _d(json['qtyOnHand']),
        qtyTotal: _d(json['qtyTotal'] ?? json['qtyOnHand']),
        qtyUsed: _d(json['qtyUsed']),
        qtyAvailable: _d(json['qtyAvailable']),
        isActive: json['isActive'] != false,
        stockLogs: json['stockLogs'] is List
            ? (json['stockLogs'] as List)
                .map((e) => ErpMaterialStockLog.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList()
            : const [],
      );

  Map<String, dynamic> toJson() => {
        'brand': brand,
        'name': name,
        if (unitCode != null) 'unitCode': unitCode,
        if (size != null) 'size': size,
        if (activityId != null) 'activityId': activityId,
        if (subtaskId != null) 'subtaskId': subtaskId,
        'qtyOnHand': qtyOnHand,
        'isActive': isActive,
      };
}

class ErpMachine {
  const ErpMachine({
    required this.id,
    this.brand,
    required this.name,
    this.unitCode,
    this.size,
    this.activityId,
    this.subtaskId,
    this.qtyOnHand = 0,
    this.qtyTotal = 0,
    this.qtyUsed = 0,
    this.qtyInUse = 0,
    this.qtyAvailable = 0,
    this.isActive = true,
  });

  final String id;
  final String? brand;
  final String name;
  final String? unitCode;
  final String? size;
  final String? activityId;
  final String? subtaskId;
  final double qtyOnHand;
  final double qtyTotal;
  final double qtyUsed;
  final double qtyInUse;
  final double qtyAvailable;
  final bool isActive;

  factory ErpMachine.fromJson(Map<String, dynamic> json) => ErpMachine(
        id: json['id']?.toString() ?? '',
        brand: json['brand']?.toString(),
        name: json['name']?.toString() ?? '',
        unitCode: json['unitCode']?.toString(),
        size: json['size']?.toString(),
        activityId: json['activityId']?.toString(),
        subtaskId: json['subtaskId']?.toString(),
        qtyOnHand: _d(json['qtyOnHand']),
        qtyTotal: _d(json['qtyTotal'] ?? json['qtyOnHand']),
        qtyUsed: _d(json['qtyUsed']),
        qtyInUse: _d(json['qtyInUse']),
        qtyAvailable: _d(json['qtyAvailable']),
        isActive: json['isActive'] != false,
      );

  Map<String, dynamic> toJson() => {
        'brand': brand,
        'name': name,
        if (unitCode != null) 'unitCode': unitCode,
        if (size != null) 'size': size,
        if (activityId != null) 'activityId': activityId,
        if (subtaskId != null) 'subtaskId': subtaskId,
        'qtyOnHand': qtyOnHand,
        'isActive': isActive,
      };
}

class ErpMachineStockLog {
  const ErpMachineStockLog({
    required this.id,
    required this.machineId,
    required this.logType,
    required this.quantity,
    this.contractorId,
    this.contractorName,
    this.remarks,
    this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String machineId;
  final String logType; // 'PURCHASE' | 'CONSUMPTION' | 'INITIAL' | 'ADJUSTMENT'
  final double quantity;
  final String? contractorId;
  final String? contractorName;
  final String? remarks;
  final String? createdBy;
  final DateTime createdAt;

  factory ErpMachineStockLog.fromJson(Map<String, dynamic> json) {
    String? cName = json['contractorName']?.toString();
    if ((cName == null || cName.isEmpty) && json['contractor'] is Map) {
      cName = (json['contractor'] as Map)['name']?.toString();
    }
    return ErpMachineStockLog(
      id: json['id']?.toString() ?? '',
      machineId: json['machineId']?.toString() ?? '',
      logType: json['logType']?.toString() ?? 'PURCHASE',
      quantity: _d(json['quantity']),
      contractorId: json['contractorId']?.toString(),
      contractorName: cName,
      remarks: json['remarks']?.toString(),
      createdBy: json['createdBy']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class ErpMachineReturnLog {
  const ErpMachineReturnLog({
    required this.id,
    required this.machineIssueId,
    required this.machineId,
    required this.contractorId,
    required this.quantityReturned,
    required this.returnDate,
    this.remarks,
    this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String machineIssueId;
  final String machineId;
  final String contractorId;
  final double quantityReturned;
  final DateTime returnDate;
  final String? remarks;
  final String? createdBy;
  final DateTime createdAt;

  factory ErpMachineReturnLog.fromJson(Map<String, dynamic> json) => ErpMachineReturnLog(
        id: json['id']?.toString() ?? '',
        machineIssueId: json['machineIssueId']?.toString() ?? '',
        machineId: json['machineId']?.toString() ?? '',
        contractorId: json['contractorId']?.toString() ?? '',
        quantityReturned: _d(json['quantityReturned']),
        returnDate: DateTime.tryParse(json['returnDate']?.toString() ?? '') ?? DateTime.now(),
        remarks: json['remarks']?.toString(),
        createdBy: json['createdBy']?.toString(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );
}

class ErpMachineIssue {
  const ErpMachineIssue({
    required this.id,
    required this.machineId,
    required this.contractorId,
    this.contractorName,
    required this.quantityTaken,
    this.quantityReturned = 0,
    this.quantityInUse = 0,
    required this.issueDate,
    this.status = 'ACTIVE', // ACTIVE | PARTIALLY_RETURNED | RETURNED
    this.remarks,
    this.createdBy,
    this.machineName,
    this.machineBrand,
    this.unitCode,
    this.returnLogs = const [],
  });

  final String id;
  final String machineId;
  final String contractorId;
  final String? contractorName;
  final double quantityTaken;
  final double quantityReturned;
  final double quantityInUse;
  final DateTime issueDate;
  final String status;
  final String? remarks;
  final String? createdBy;
  final String? machineName;
  final String? machineBrand;
  final String? unitCode;
  final List<ErpMachineReturnLog> returnLogs;

  factory ErpMachineIssue.fromJson(Map<String, dynamic> json) {
    String? cName = json['contractorName']?.toString();
    if ((cName == null || cName.isEmpty) && json['contractor'] is Map) {
      cName = (json['contractor'] as Map)['name']?.toString();
    }
    String? mName;
    String? mBrand;
    String? uCode;
    if (json['machine'] is Map) {
      final m = json['machine'] as Map;
      mName = m['name']?.toString();
      mBrand = m['brand']?.toString();
      uCode = m['unitCode']?.toString();
    }
    return ErpMachineIssue(
      id: json['id']?.toString() ?? '',
      machineId: json['machineId']?.toString() ?? '',
      contractorId: json['contractorId']?.toString() ?? '',
      contractorName: cName,
      quantityTaken: _d(json['quantityTaken']),
      quantityReturned: _d(json['quantityReturned']),
      quantityInUse: _d(json['quantityInUse']),
      issueDate: DateTime.tryParse(json['issueDate']?.toString() ?? '') ?? DateTime.now(),
      status: json['status']?.toString() ?? 'ACTIVE',
      remarks: json['remarks']?.toString(),
      createdBy: json['createdBy']?.toString(),
      machineName: mName,
      machineBrand: mBrand,
      unitCode: uCode,
      returnLogs: json['returnLogs'] is List
          ? (json['returnLogs'] as List)
              .map((e) => ErpMachineReturnLog.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
    );
  }
}

class ErpLabour {
  const ErpLabour({
    required this.id,
    required this.name,
    this.unitCode,
    this.defaultRate,
    this.activityId,
    this.subtaskId,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? unitCode;
  final double? defaultRate;
  final String? activityId;
  final String? subtaskId;
  final bool isActive;

  factory ErpLabour.fromJson(Map<String, dynamic> json) => ErpLabour(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        unitCode: json['unitCode']?.toString(),
        defaultRate: json['defaultRate'] != null ? _d(json['defaultRate']) : null,
        activityId: json['activityId']?.toString(),
        subtaskId: json['subtaskId']?.toString(),
        isActive: json['isActive'] != false,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (unitCode != null) 'unitCode': unitCode,
        if (defaultRate != null) 'defaultRate': defaultRate,
        if (activityId != null) 'activityId': activityId,
        if (subtaskId != null) 'subtaskId': subtaskId,
        'isActive': isActive,
      };
}

double _d(dynamic v) => double.tryParse('$v') ?? 0;
