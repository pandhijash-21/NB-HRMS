class ErpDprRef {
  const ErpDprRef({required this.id, required this.name, this.projectNo});
  final String id;
  final String name;
  final int? projectNo;

  factory ErpDprRef.fromJson(Map<String, dynamic> json) => ErpDprRef(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        projectNo: json['projectNo'] is int ? json['projectNo'] as int : int.tryParse('${json['projectNo']}'),
      );
}

class ErpDprMaterialLine {
  const ErpDprMaterialLine({
    this.id,
    this.materialId,
    this.itemCode,
    this.category,
    required this.itemName,
    this.brand,
    this.unitCode,
    this.size,
    this.consumedQty = 0,
    this.remarks,
  });

  final String? id;
  final String? materialId;
  final String? itemCode;
  final String? category;
  final String itemName;
  final String? brand;
  final String? unitCode;
  final String? size;
  final double consumedQty;
  final String? remarks;

  factory ErpDprMaterialLine.fromJson(Map<String, dynamic> json) => ErpDprMaterialLine(
        id: json['id']?.toString(),
        materialId: json['materialId']?.toString(),
        itemCode: json['itemCode']?.toString(),
        category: json['category']?.toString(),
        itemName: json['itemName']?.toString() ?? '',
        brand: json['brand']?.toString(),
        unitCode: json['unitCode']?.toString(),
        size: json['size']?.toString(),
        consumedQty: _d(json['consumedQty']),
        remarks: json['remarks']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        if (materialId != null) 'materialId': materialId,
        if (itemCode != null) 'itemCode': itemCode,
        if (category != null) 'category': category,
        'itemName': itemName,
        if (brand != null) 'brand': brand,
        if (unitCode != null) 'unitCode': unitCode,
        if (size != null) 'size': size,
        'consumedQty': consumedQty,
        if (remarks != null) 'remarks': remarks,
      };
}

class ErpDprLabourLine {
  const ErpDprLabourLine({
    this.id,
    this.labourId,
    required this.name,
    this.unitCode,
    this.consumedQty = 0,
    this.remarks,
  });

  final String? id;
  final String? labourId;
  final String name;
  final String? unitCode;
  final double consumedQty;
  final String? remarks;

  factory ErpDprLabourLine.fromJson(Map<String, dynamic> json) => ErpDprLabourLine(
        id: json['id']?.toString(),
        labourId: json['labourId']?.toString(),
        name: json['name']?.toString() ?? '',
        unitCode: json['unitCode']?.toString(),
        consumedQty: _d(json['consumedQty']),
        remarks: json['remarks']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        if (labourId != null) 'labourId': labourId,
        'name': name,
        if (unitCode != null) 'unitCode': unitCode,
        'consumedQty': consumedQty,
        if (remarks != null) 'remarks': remarks,
      };
}

class ErpDprMachineLine {
  const ErpDprMachineLine({
    this.id,
    this.machineId,
    required this.itemName,
    this.brand,
    this.unitCode,
    this.size,
    this.consumedQty = 0,
    this.remarks,
  });

  final String? id;
  final String? machineId;
  final String itemName;
  final String? brand;
  final String? unitCode;
  final String? size;
  final double consumedQty;
  final String? remarks;

  factory ErpDprMachineLine.fromJson(Map<String, dynamic> json) => ErpDprMachineLine(
        id: json['id']?.toString(),
        machineId: json['machineId']?.toString(),
        itemName: json['itemName']?.toString() ?? '',
        brand: json['brand']?.toString(),
        unitCode: json['unitCode']?.toString(),
        size: json['size']?.toString(),
        consumedQty: _d(json['consumedQty']),
        remarks: json['remarks']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        if (machineId != null) 'machineId': machineId,
        'itemName': itemName,
        if (brand != null) 'brand': brand,
        if (unitCode != null) 'unitCode': unitCode,
        if (size != null) 'size': size,
        'consumedQty': consumedQty,
        if (remarks != null) 'remarks': remarks,
      };
}

class ErpDprLine {
  const ErpDprLine({
    this.id,
    this.contractorId,
    this.contractorName,
    this.activityId,
    this.activityName,
    this.subtaskId,
    this.taskName,
    this.towerId,
    this.towerName,
    this.floorNo,
    this.unitId,
    this.unitLabel,
    this.unitCode,
    this.consumedQty = 0,
    this.gradeCode,
    this.remarks,
    this.statusCode,
    this.completionPct,
    this.actualStartDate,
    this.actualEndDate,
    this.materialRateText = 'No',
    this.labourRateText = 'No',
    this.machineRateText = 'No',
    this.materials = const [],
    this.labour = const [],
    this.machines = const [],
  });

  final String? id;
  final String? contractorId;
  final String? contractorName;
  final String? activityId;
  final String? activityName;
  final String? subtaskId;
  final String? taskName;
  final String? towerId;
  final String? towerName;
  final int? floorNo;
  final String? unitId;
  final String? unitLabel;
  final String? unitCode;
  final double consumedQty;
  final String? gradeCode;
  final String? remarks;
  final String? statusCode;
  final double? completionPct;
  final DateTime? actualStartDate;
  final DateTime? actualEndDate;
  final String materialRateText;
  final String labourRateText;
  final String machineRateText;
  final List<ErpDprMaterialLine> materials;
  final List<ErpDprLabourLine> labour;
  final List<ErpDprMachineLine> machines;

  factory ErpDprLine.fromJson(Map<String, dynamic> json) {
    final mats = json['materials'];
    final labs = json['labour'];
    final macs = json['machines'];
    return ErpDprLine(
      id: json['id']?.toString(),
      contractorId: json['contractorId']?.toString(),
      contractorName: json['contractorName']?.toString() ??
          (json['contractor'] is Map ? (json['contractor'] as Map)['name']?.toString() : null),
      activityId: json['activityId']?.toString(),
      activityName: json['activityName']?.toString(),
      subtaskId: json['subtaskId']?.toString(),
      taskName: json['taskName']?.toString(),
      towerId: json['towerId']?.toString(),
      towerName: json['towerName']?.toString(),
      floorNo: json['floorNo'] is int ? json['floorNo'] as int : int.tryParse('${json['floorNo']}'),
      unitId: json['unitId']?.toString(),
      unitLabel: json['unitLabel']?.toString(),
      unitCode: json['unitCode']?.toString(),
      consumedQty: _d(json['consumedQty']),
      gradeCode: json['gradeCode']?.toString(),
      remarks: json['remarks']?.toString(),
      statusCode: json['statusCode']?.toString(),
      completionPct: json['completionPct'] != null ? _d(json['completionPct']) : null,
      actualStartDate: _date(json['actualStartDate']),
      actualEndDate: _date(json['actualEndDate']),
      materialRateText: json['materialRateText']?.toString() ?? 'No',
      labourRateText: json['labourRateText']?.toString() ?? 'No',
      machineRateText: json['machineRateText']?.toString() ?? 'No',
      materials: mats is List
          ? mats.map((e) => ErpDprMaterialLine.fromJson(Map<String, dynamic>.from(e as Map))).toList()
          : const [],
      labour: labs is List
          ? labs.map((e) => ErpDprLabourLine.fromJson(Map<String, dynamic>.from(e as Map))).toList()
          : const [],
      machines: macs is List
          ? macs.map((e) => ErpDprMachineLine.fromJson(Map<String, dynamic>.from(e as Map))).toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        if (contractorId != null) 'contractorId': contractorId,
        if (contractorName != null) 'contractorName': contractorName,
        if (activityId != null) 'activityId': activityId,
        if (activityName != null) 'activityName': activityName,
        if (subtaskId != null) 'subtaskId': subtaskId,
        if (taskName != null) 'taskName': taskName,
        if (towerId != null) 'towerId': towerId,
        if (towerName != null) 'towerName': towerName,
        if (floorNo != null) 'floorNo': floorNo,
        if (unitId != null) 'unitId': unitId,
        if (unitLabel != null) 'unitLabel': unitLabel,
        if (unitCode != null) 'unitCode': unitCode,
        'consumedQty': consumedQty,
        if (gradeCode != null) 'gradeCode': gradeCode,
        if (remarks != null) 'remarks': remarks,
        if (statusCode != null) 'statusCode': statusCode,
        if (completionPct != null) 'completionPct': completionPct,
        if (actualStartDate != null) 'actualStartDate': actualStartDate!.toIso8601String(),
        if (actualEndDate != null) 'actualEndDate': actualEndDate!.toIso8601String(),
        'materialRateText': materialRateText,
        'labourRateText': labourRateText,
        'machineRateText': machineRateText,
        'materials': materials.map((e) => e.toJson()).toList(),
        'labour': labour.map((e) => e.toJson()).toList(),
        'machines': machines.map((e) => e.toJson()).toList(),
      };
}

class ErpDpr {
  const ErpDpr({
    required this.id,
    required this.dprNo,
    required this.reportDate,
    required this.projectId,
    this.createdByName,
    this.remarks,
    this.project,
    this.lines = const [],
    this.lineCount,
  });

  final String id;
  final String dprNo;
  final DateTime reportDate;
  final String projectId;
  final String? createdByName;
  final String? remarks;
  final ErpDprRef? project;
  final List<ErpDprLine> lines;
  final int? lineCount;

  factory ErpDpr.fromJson(Map<String, dynamic> json) {
    final linesRaw = json['lines'];
    final count = json['_count'];
    return ErpDpr(
      id: json['id']?.toString() ?? '',
      dprNo: json['dprNo']?.toString() ?? '',
      reportDate: _date(json['reportDate']) ?? DateTime.now(),
      projectId: json['projectId']?.toString() ?? '',
      createdByName: json['createdByName']?.toString(),
      remarks: json['remarks']?.toString(),
      project: json['project'] is Map
          ? ErpDprRef.fromJson(Map<String, dynamic>.from(json['project'] as Map))
          : null,
      lines: linesRaw is List
          ? linesRaw.map((e) => ErpDprLine.fromJson(Map<String, dynamic>.from(e as Map))).toList()
          : const [],
      lineCount: count is Map ? int.tryParse('${count['lines']}') : null,
    );
  }
}

double _d(dynamic v) => double.tryParse('$v') ?? 0;

DateTime? _date(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}
