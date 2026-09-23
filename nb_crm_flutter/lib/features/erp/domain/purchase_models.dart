class ErpPurchaseSettings {
  const ErpPurchaseSettings({
    required this.id,
    this.defaultApproverEmployeeId,
    this.defaultApproverName,
  });

  final String id;
  final int? defaultApproverEmployeeId;
  final String? defaultApproverName;

  factory ErpPurchaseSettings.fromJson(Map<String, dynamic> json) {
    final approver = json['defaultApprover'];
    return ErpPurchaseSettings(
      id: json['id']?.toString() ?? '',
      defaultApproverEmployeeId: json['defaultApproverEmployeeId'] is int
          ? json['defaultApproverEmployeeId'] as int
          : int.tryParse('${json['defaultApproverEmployeeId'] ?? ''}'),
      defaultApproverName: approver is Map ? approver['name']?.toString() : null,
    );
  }
}

class ErpPurchaseRequestLine {
  const ErpPurchaseRequestLine({
    this.id,
    this.materialId,
    this.itemCode,
    this.categoryCode,
    this.brandCode,
    this.brand,
    required this.itemName,
    this.unitCode,
    this.sizeCode,
    this.size,
    required this.qty,
    this.remark,
  });

  final String? id;
  final String? materialId;
  final String? itemCode;
  final String? categoryCode;
  final String? brandCode;
  final String? brand;
  final String itemName;
  final String? unitCode;
  final String? sizeCode;
  final String? size;
  final double qty;
  final String? remark;

  factory ErpPurchaseRequestLine.fromJson(Map<String, dynamic> json) => ErpPurchaseRequestLine(
        id: json['id']?.toString(),
        materialId: json['materialId']?.toString(),
        itemCode: json['itemCode']?.toString(),
        categoryCode: json['categoryCode']?.toString(),
        brandCode: json['brandCode']?.toString(),
        brand: json['brand']?.toString(),
        itemName: json['itemName']?.toString() ?? '',
        unitCode: json['unitCode']?.toString(),
        sizeCode: json['sizeCode']?.toString(),
        size: json['size']?.toString(),
        qty: double.tryParse('${json['qty'] ?? 0}') ?? 0,
        remark: json['remark']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        if (materialId != null) 'materialId': materialId,
        if (itemCode != null) 'itemCode': itemCode,
        if (categoryCode != null) 'categoryCode': categoryCode,
        if (brandCode != null) 'brandCode': brandCode,
        if (brand != null) 'brand': brand,
        'itemName': itemName,
        if (unitCode != null) 'unitCode': unitCode,
        if (sizeCode != null) 'sizeCode': sizeCode,
        if (size != null) 'size': size,
        'qty': qty,
        if (remark != null) 'remark': remark,
      };
}

class ErpPurchaseRequest {
  const ErpPurchaseRequest({
    required this.id,
    required this.prNumber,
    required this.prDate,
    this.prTypeCode,
    this.projectId,
    this.projectName,
    this.activityId,
    this.activityName,
    this.vendorId,
    this.vendorName,
    this.requestedByName,
    this.requiredByDate,
    this.priorityCode,
    this.storeId,
    this.storeName,
    this.propertyId,
    required this.status,
    this.approverName,
    this.rejectionReason,
    this.remarks,
    this.lines = const [],
  });

  final String id;
  final String prNumber;
  final DateTime prDate;
  final String? prTypeCode;
  final String? projectId;
  final String? projectName;
  final String? activityId;
  final String? activityName;
  final String? vendorId;
  final String? vendorName;
  final String? requestedByName;
  final DateTime? requiredByDate;
  final String? priorityCode;
  final String? storeId;
  final String? storeName;
  final String? propertyId;
  final String status;
  final String? approverName;
  final String? rejectionReason;
  final String? remarks;
  final List<ErpPurchaseRequestLine> lines;

  factory ErpPurchaseRequest.fromJson(Map<String, dynamic> json) {
    final project = json['project'];
    final activity = json['activity'];
    final vendor = json['vendor'];
    final store = json['store'];
    final requestedBy = json['requestedBy'];
    final approver = json['approver'];
    return ErpPurchaseRequest(
      id: json['id']?.toString() ?? '',
      prNumber: json['prNumber']?.toString() ?? '',
      prDate: DateTime.tryParse(json['prDate']?.toString() ?? '') ?? DateTime.now(),
      prTypeCode: json['prTypeCode']?.toString(),
      projectId: json['projectId']?.toString() ?? (project is Map ? project['id']?.toString() : null),
      projectName: project is Map ? project['name']?.toString() : null,
      activityId: json['activityId']?.toString() ?? (activity is Map ? activity['id']?.toString() : null),
      activityName: activity is Map ? activity['name']?.toString() : null,
      vendorId: json['vendorId']?.toString() ?? (vendor is Map ? vendor['id']?.toString() : null),
      vendorName: vendor is Map ? vendor['name']?.toString() : null,
      requestedByName: requestedBy is Map ? requestedBy['name']?.toString() : null,
      requiredByDate: DateTime.tryParse(json['requiredByDate']?.toString() ?? ''),
      priorityCode: json['priorityCode']?.toString(),
      storeId: json['storeId']?.toString() ?? (store is Map ? store['id']?.toString() : null),
      storeName: store is Map ? store['name']?.toString() : null,
      propertyId: json['propertyId']?.toString(),
      status: json['status']?.toString() ?? 'DRAFT',
      approverName: approver is Map ? approver['name']?.toString() : null,
      rejectionReason: json['rejectionReason']?.toString(),
      remarks: json['remarks']?.toString(),
      lines: json['lines'] is List
          ? (json['lines'] as List)
              .map((e) => ErpPurchaseRequestLine.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
    );
  }
}
