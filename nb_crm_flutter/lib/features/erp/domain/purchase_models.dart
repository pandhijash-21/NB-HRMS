class ErpPurchaseSettings {
  const ErpPurchaseSettings({
    required this.id,
    this.defaultApproverEmployeeId,
    this.defaultApproverName,
    this.csApproverEmployeeId,
    this.csApproverName,
    this.defaultPoTerms = const [],
  });

  final String id;
  final int? defaultApproverEmployeeId;
  final String? defaultApproverName;
  final int? csApproverEmployeeId;
  final String? csApproverName;
  final List<String> defaultPoTerms;

  factory ErpPurchaseSettings.fromJson(Map<String, dynamic> json) {
    final approver = json['defaultApprover'];
    final cs = json['csApprover'];
    final termsRaw = json['defaultPoTerms'];
    return ErpPurchaseSettings(
      id: json['id']?.toString() ?? '',
      defaultApproverEmployeeId: json['defaultApproverEmployeeId'] is int
          ? json['defaultApproverEmployeeId'] as int
          : int.tryParse('${json['defaultApproverEmployeeId'] ?? ''}'),
      defaultApproverName: approver is Map ? approver['name']?.toString() : null,
      csApproverEmployeeId: json['csApproverEmployeeId'] is int
          ? json['csApproverEmployeeId'] as int
          : int.tryParse('${json['csApproverEmployeeId'] ?? ''}'),
      csApproverName: cs is Map ? cs['name']?.toString() : null,
      defaultPoTerms: termsRaw is List
          ? termsRaw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
          : const [],
    );
  }
}

class ErpPurchaseOrderDetail {
  const ErpPurchaseOrderDetail({
    required this.id,
    required this.poNumber,
    required this.vendorName,
    required this.orderDate,
    required this.status,
    this.totalAmount,
    this.cgstRate = 9,
    this.sgstRate = 9,
    this.termsAndConditions = const [],
    this.remarks,
  });

  final String id;
  final String poNumber;
  final String vendorName;
  final DateTime orderDate;
  final String status;
  final double? totalAmount;
  final double cgstRate;
  final double sgstRate;
  final List<String> termsAndConditions;
  final String? remarks;

  factory ErpPurchaseOrderDetail.fromJson(Map<String, dynamic> json) {
    final termsRaw = json['termsAndConditions'];
    return ErpPurchaseOrderDetail(
      id: json['id']?.toString() ?? '',
      poNumber: json['poNumber']?.toString() ?? '',
      vendorName: json['vendorName']?.toString() ?? '',
      orderDate: DateTime.tryParse(json['orderDate']?.toString() ?? '') ?? DateTime.now(),
      status: json['status']?.toString() ?? 'OPEN',
      totalAmount: json['totalAmount'] == null
          ? null
          : double.tryParse('${json['totalAmount']}'),
      cgstRate: double.tryParse('${json['cgstRate'] ?? 9}') ?? 9,
      sgstRate: double.tryParse('${json['sgstRate'] ?? 9}') ?? 9,
      termsAndConditions: termsRaw is List
          ? termsRaw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
          : const [],
      remarks: json['remarks']?.toString(),
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

class ErpPurchaseQuotationLine {
  const ErpPurchaseQuotationLine({
    this.id,
    this.purchaseRequestLineId,
    this.materialId,
    this.itemCode,
    this.brand,
    required this.itemName,
    this.unitCode,
    this.size,
    required this.qty,
    required this.rate,
    required this.amount,
  });

  final String? id;
  final String? purchaseRequestLineId;
  final String? materialId;
  final String? itemCode;
  final String? brand;
  final String itemName;
  final String? unitCode;
  final String? size;
  final double qty;
  final double rate;
  final double amount;

  factory ErpPurchaseQuotationLine.fromJson(Map<String, dynamic> json) {
    final qty = double.tryParse('${json['qty'] ?? 0}') ?? 0;
    final rate = double.tryParse('${json['rate'] ?? 0}') ?? 0;
    final amount = double.tryParse('${json['amount'] ?? (qty * rate)}') ?? (qty * rate);
    return ErpPurchaseQuotationLine(
      id: json['id']?.toString(),
      purchaseRequestLineId: json['purchaseRequestLineId']?.toString(),
      materialId: json['materialId']?.toString(),
      itemCode: json['itemCode']?.toString(),
      brand: json['brand']?.toString(),
      itemName: json['itemName']?.toString() ?? '',
      unitCode: json['unitCode']?.toString(),
      size: json['size']?.toString(),
      qty: qty,
      rate: rate,
      amount: amount,
    );
  }

  Map<String, dynamic> toJson() => {
        if (purchaseRequestLineId != null) 'purchaseRequestLineId': purchaseRequestLineId,
        if (materialId != null) 'materialId': materialId,
        if (itemCode != null) 'itemCode': itemCode,
        if (brand != null) 'brand': brand,
        'itemName': itemName,
        if (unitCode != null) 'unitCode': unitCode,
        if (size != null) 'size': size,
        'qty': qty,
        'rate': rate,
        'amount': amount,
      };

  ErpPurchaseQuotationLine copyWith({double? rate}) {
    final r = rate ?? this.rate;
    return ErpPurchaseQuotationLine(
      id: id,
      purchaseRequestLineId: purchaseRequestLineId,
      materialId: materialId,
      itemCode: itemCode,
      brand: brand,
      itemName: itemName,
      unitCode: unitCode,
      size: size,
      qty: qty,
      rate: r,
      amount: double.parse((qty * r).toStringAsFixed(2)),
    );
  }
}

class ErpPurchaseQuotation {
  const ErpPurchaseQuotation({
    required this.id,
    required this.purchaseRequestId,
    required this.quotationNo,
    required this.quotationDate,
    this.vendorId,
    required this.vendorName,
    this.address,
    this.gstNo,
    this.panNo,
    required this.status,
    required this.totalAmount,
    this.remarks,
    this.selectedByName,
    this.purchaseOrderId,
    this.purchaseOrderNo,
    this.lines = const [],
  });

  final String id;
  final String purchaseRequestId;
  final String quotationNo;
  final DateTime quotationDate;
  final String? vendorId;
  final String vendorName;
  final String? address;
  final String? gstNo;
  final String? panNo;
  final String status;
  final double totalAmount;
  final String? remarks;
  final String? selectedByName;
  final String? purchaseOrderId;
  final String? purchaseOrderNo;
  final List<ErpPurchaseQuotationLine> lines;

  factory ErpPurchaseQuotation.fromJson(Map<String, dynamic> json) {
    final selectedBy = json['selectedBy'];
    final po = json['purchaseOrder'];
    return ErpPurchaseQuotation(
      id: json['id']?.toString() ?? '',
      purchaseRequestId: json['purchaseRequestId']?.toString() ?? '',
      quotationNo: json['quotationNo']?.toString() ?? '',
      quotationDate:
          DateTime.tryParse(json['quotationDate']?.toString() ?? '') ?? DateTime.now(),
      vendorId: json['vendorId']?.toString(),
      vendorName: json['vendorName']?.toString() ?? '',
      address: json['address']?.toString(),
      gstNo: json['gstNo']?.toString(),
      panNo: json['panNo']?.toString(),
      status: json['status']?.toString() ?? 'DRAFT',
      totalAmount: double.tryParse('${json['totalAmount'] ?? 0}') ?? 0,
      remarks: json['remarks']?.toString(),
      selectedByName: selectedBy is Map ? selectedBy['name']?.toString() : null,
      purchaseOrderId: po is Map ? po['id']?.toString() : null,
      purchaseOrderNo: po is Map ? po['poNumber']?.toString() : null,
      lines: json['lines'] is List
          ? (json['lines'] as List)
              .map((e) => ErpPurchaseQuotationLine.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
    );
  }
}

class ErpPurchaseComparisonSheet {
  const ErpPurchaseComparisonSheet({
    required this.purchaseRequest,
    this.quotations = const [],
  });

  final ErpPurchaseRequest purchaseRequest;
  final List<ErpPurchaseQuotation> quotations;

  factory ErpPurchaseComparisonSheet.fromJson(Map<String, dynamic> json) {
    final pr = json['purchaseRequest'];
    return ErpPurchaseComparisonSheet(
      purchaseRequest: ErpPurchaseRequest.fromJson(
        Map<String, dynamic>.from(pr is Map ? pr : json),
      ),
      quotations: json['quotations'] is List
          ? (json['quotations'] as List)
              .map((e) => ErpPurchaseQuotation.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
    );
  }
}
