import 'dart:convert';

class ErpBoqTaskResource {
  const ErpBoqTaskResource({
    this.id,
    required this.resourceType,
    this.configMaterialId,
    this.configMachineId,
    this.configLabourId,
    required this.name,
    this.brand,
    this.unitCode,
    this.size,
    this.quantity = 0,
    this.unitPrice = 0,
    this.totalPrice = 0,
    this.remarks,
    this.sortOrder = 0,
  });

  final String? id;
  final String resourceType; // MATERIAL | MACHINE | LABOUR
  final String? configMaterialId;
  final String? configMachineId;
  final String? configLabourId;
  final String name;
  final String? brand;
  final String? unitCode;
  final String? size;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final String? remarks;
  final int sortOrder;

  factory ErpBoqTaskResource.fromJson(Map<String, dynamic> json) => ErpBoqTaskResource(
        id: json['id']?.toString(),
        resourceType: json['resourceType']?.toString() ?? 'MATERIAL',
        configMaterialId: json['configMaterialId']?.toString(),
        configMachineId: json['configMachineId']?.toString(),
        configLabourId: json['configLabourId']?.toString(),
        name: json['name']?.toString() ?? '',
        brand: json['brand']?.toString(),
        unitCode: json['unitCode']?.toString(),
        size: json['size']?.toString(),
        quantity: _d(json['quantity']),
        unitPrice: _d(json['unitPrice']),
        totalPrice: _d(json['totalPrice']),
        remarks: json['remarks']?.toString(),
        sortOrder: int.tryParse('${json['sortOrder']}') ?? 0,
      );

  Map<String, dynamic> toJson() => {
        if (id != null && id!.isNotEmpty) 'id': id,
        'resourceType': resourceType,
        if (configMaterialId != null) 'configMaterialId': configMaterialId,
        if (configMachineId != null) 'configMachineId': configMachineId,
        if (configLabourId != null) 'configLabourId': configLabourId,
        'name': name,
        if (brand != null) 'brand': brand,
        if (unitCode != null) 'unitCode': unitCode,
        if (size != null) 'size': size,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'totalPrice': totalPrice,
        if (remarks != null) 'remarks': remarks,
        'sortOrder': sortOrder,
      };

  ErpBoqTaskResource copyWith({
    double? quantity,
    double? unitPrice,
    double? totalPrice,
    String? remarks,
  }) =>
      ErpBoqTaskResource(
        id: id,
        resourceType: resourceType,
        configMaterialId: configMaterialId,
        configMachineId: configMachineId,
        configLabourId: configLabourId,
        name: name,
        brand: brand,
        unitCode: unitCode,
        size: size,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        totalPrice: totalPrice ?? this.totalPrice,
        remarks: remarks ?? this.remarks,
        sortOrder: sortOrder,
      );
}

class ErpBoqTask {
  const ErpBoqTask({
    this.id,
    this.taskId,
    this.activityId,
    required this.activityName,
    this.subtaskId,
    required this.taskName,
    this.taskDescription,
    this.isCustomSubtask = false,
    this.towerIds = const [],
    this.floorNos = const [],
    this.unitIds = const [],
    this.quantity,
    this.unitCode,
    this.rate,
    this.amount,
    this.materialAmount = 0,
    this.machineAmount = 0,
    this.labourAmount = 0,
    this.sortOrder = 0,
    this.resources = const [],
  });

  final String? id;
  final String? taskId;
  final String? activityId;
  final String activityName;
  final String? subtaskId;
  final String taskName;
  final String? taskDescription;
  final bool isCustomSubtask;
  final List<String> towerIds;
  final List<int> floorNos;
  final List<String> unitIds;
  final double? quantity;
  final String? unitCode;
  final double? rate;
  final double? amount;
  final double materialAmount;
  final double machineAmount;
  final double labourAmount;
  final int sortOrder;
  final List<ErpBoqTaskResource> resources;

  double get computedAmount => amount ?? ((quantity ?? 0) * (rate ?? 0));

  factory ErpBoqTask.fromJson(Map<String, dynamic> json) {
    final res = json['resources'];
    return ErpBoqTask(
      id: json['id']?.toString(),
      taskId: json['taskId']?.toString(),
      activityId: json['activityId']?.toString(),
      activityName: json['activityName']?.toString() ?? '',
      subtaskId: json['subtaskId']?.toString(),
      taskName: json['taskName']?.toString() ?? '',
      taskDescription: json['taskDescription']?.toString(),
      isCustomSubtask: json['isCustomSubtask'] == true,
      towerIds: _parseStrList(json['towerIds']),
      floorNos: _parseIntList(json['floorNos']),
      unitIds: _parseStrList(json['unitIds']),
      quantity: json['quantity'] != null ? _d(json['quantity']) : null,
      unitCode: json['unitCode']?.toString(),
      rate: json['rate'] != null ? _d(json['rate']) : null,
      amount: json['amount'] != null ? _d(json['amount']) : null,
      materialAmount: _d(json['materialAmount']),
      machineAmount: _d(json['machineAmount']),
      labourAmount: _d(json['labourAmount']),
      sortOrder: int.tryParse('${json['sortOrder']}') ?? 0,
      resources: res is List
          ? res.map((e) => ErpBoqTaskResource.fromJson(Map<String, dynamic>.from(e as Map))).toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null && id!.isNotEmpty) 'id': id,
        if (taskId != null) 'taskId': taskId,
        if (activityId != null) 'activityId': activityId,
        'activityName': activityName,
        if (subtaskId != null) 'subtaskId': subtaskId,
        'taskName': taskName,
        if (taskDescription != null) 'taskDescription': taskDescription,
        'isCustomSubtask': isCustomSubtask,
        'towerIds': towerIds,
        'floorNos': floorNos,
        'unitIds': unitIds,
        if (quantity != null) 'quantity': quantity,
        if (unitCode != null) 'unitCode': unitCode,
        if (rate != null) 'rate': rate,
        if (amount != null) 'amount': amount,
        'materialAmount': materialAmount,
        'machineAmount': machineAmount,
        'labourAmount': labourAmount,
        'sortOrder': sortOrder,
        'resources': resources.map((r) => r.toJson()).toList(),
      };

  ErpBoqTask copyWith({
    String? taskId,
    String? taskName,
    String? taskDescription,
    List<String>? towerIds,
    List<int>? floorNos,
    List<String>? unitIds,
    double? quantity,
    String? unitCode,
    double? rate,
    double? amount,
    List<ErpBoqTaskResource>? resources,
    double? materialAmount,
    double? machineAmount,
    double? labourAmount,
    int? sortOrder,
  }) =>
      ErpBoqTask(
        id: id,
        taskId: taskId ?? this.taskId,
        activityId: activityId,
        activityName: activityName,
        subtaskId: subtaskId,
        taskName: taskName ?? this.taskName,
        taskDescription: taskDescription ?? this.taskDescription,
        isCustomSubtask: isCustomSubtask,
        towerIds: towerIds ?? this.towerIds,
        floorNos: floorNos ?? this.floorNos,
        unitIds: unitIds ?? this.unitIds,
        quantity: quantity ?? this.quantity,
        unitCode: unitCode ?? this.unitCode,
        rate: rate ?? this.rate,
        amount: amount ?? this.amount,
        materialAmount: materialAmount ?? this.materialAmount,
        machineAmount: machineAmount ?? this.machineAmount,
        labourAmount: labourAmount ?? this.labourAmount,
        sortOrder: sortOrder ?? this.sortOrder,
        resources: resources ?? this.resources,
      );
}

class ErpBoq {
  const ErpBoq({
    required this.id,
    required this.boqNo,
    required this.title,
    this.rateSource = 'ESTIMATED_RATE',
    required this.projectId,
    this.isActive = true,
    this.project,
    this.tasks = const [],
  });

  final String id;
  final String boqNo;
  final String title;
  final String rateSource;
  final String projectId;
  final bool isActive;
  final ErpBoqProjectRef? project;
  final List<ErpBoqTask> tasks;

  double get totalQty => tasks.fold(0, (s, t) => s + (t.quantity ?? 0));
  double get totalAmount => tasks.fold(0, (s, t) => s + t.computedAmount);
  double get totalMaterial => tasks.fold(0, (s, t) => s + t.materialAmount);
  double get totalMachine => tasks.fold(0, (s, t) => s + t.machineAmount);
  double get totalLabour => tasks.fold(0, (s, t) => s + t.labourAmount);
  double get grandTotal => totalAmount + totalMaterial + totalMachine + totalLabour;

  factory ErpBoq.fromJson(Map<String, dynamic> json) {
    final tasksRaw = json['tasks'];
    return ErpBoq(
      id: json['id']?.toString() ?? '',
      boqNo: json['boqNo']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      rateSource: json['rateSource']?.toString() ?? 'ESTIMATED_RATE',
      projectId: json['projectId']?.toString() ?? '',
      isActive: json['isActive'] != false,
      project: json['project'] is Map
          ? ErpBoqProjectRef.fromJson(Map<String, dynamic>.from(json['project'] as Map))
          : null,
      tasks: tasksRaw is List
          ? tasksRaw.map((e) => ErpBoqTask.fromJson(Map<String, dynamic>.from(e as Map))).toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'boqNo': boqNo,
        'title': title,
        'rateSource': rateSource,
        'projectId': projectId,
        'tasks': tasks.map((t) => t.toJson()).toList(),
      };
}

class ErpBoqProjectRef {
  const ErpBoqProjectRef({required this.id, required this.name, this.projectNo});

  final String id;
  final String name;
  final int? projectNo;

  factory ErpBoqProjectRef.fromJson(Map<String, dynamic> json) => ErpBoqProjectRef(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        projectNo: int.tryParse('${json['projectNo']}'),
      );
}

double _d(dynamic v) {
  if (v == null) return 0;
  return double.tryParse('$v') ?? 0;
}

List<ErpBoqTask> withPreviewTaskIds(List<ErpBoqTask> tasks) {
  return [
    for (var i = 0; i < tasks.length; i++)
      tasks[i].taskId != null && tasks[i].taskId!.isNotEmpty
          ? tasks[i]
          : tasks[i].copyWith(taskId: 'TI${(i + 1).toString().padLeft(4, '0')}'),
  ];
}

List<String> _parseStrList(dynamic v) {
  if (v == null) return [];
  if (v is List) return v.map((e) => e.toString()).toList();
  if (v is String && v.isNotEmpty) {
    try {
      final parsed = jsonDecode(v);
      if (parsed is List) return parsed.map((e) => e.toString()).toList();
    } catch (_) {}
  }
  return [];
}

List<int> _parseIntList(dynamic v) {
  if (v == null) return [];
  if (v is List) return v.map((e) => int.tryParse('$e') ?? 0).toList();
  if (v is String && v.isNotEmpty) {
    try {
      final parsed = jsonDecode(v);
      if (parsed is List) return parsed.map((e) => int.tryParse('$e') ?? 0).toList();
    } catch (_) {}
  }
  return [];
}
