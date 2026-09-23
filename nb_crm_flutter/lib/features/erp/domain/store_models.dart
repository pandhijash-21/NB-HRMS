class ErpStoreMaster {
  const ErpStoreMaster({
    required this.id,
    required this.name,
    required this.location,
    this.propertyId,
    this.propertyName,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String location;
  final String? propertyId;
  final String? propertyName;
  final bool isActive;

  factory ErpStoreMaster.fromJson(Map<String, dynamic> json) {
    final prop = json['property'];
    return ErpStoreMaster(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      propertyId: json['propertyId']?.toString() ??
          (prop is Map ? prop['id']?.toString() : null),
      propertyName: prop is Map ? prop['name']?.toString() : null,
      isActive: json['isActive'] != false,
    );
  }
}

class ErpPurchaseOrderItem {
  const ErpPurchaseOrderItem({
    required this.id,
    this.materialId,
    required this.itemName,
    this.brand,
    this.unitCode,
    this.size,
    required this.orderedQty,
    this.receivedQty = 0,
    this.remainingQty = 0,
    this.sortOrder = 0,
  });

  final String id;
  final String? materialId;
  final String itemName;
  final String? brand;
  final String? unitCode;
  final String? size;
  final double orderedQty;
  final double receivedQty;
  final double remainingQty;
  final int sortOrder;

  factory ErpPurchaseOrderItem.fromJson(Map<String, dynamic> json) =>
      ErpPurchaseOrderItem(
        id: json['id']?.toString() ?? '',
        materialId: json['materialId']?.toString(),
        itemName: json['itemName']?.toString() ?? '',
        brand: json['brand']?.toString(),
        unitCode: json['unitCode']?.toString(),
        size: json['size']?.toString(),
        orderedQty: _d(json['orderedQty']),
        receivedQty: _d(json['receivedQty']),
        remainingQty: _d(json['remainingQty']),
        sortOrder: int.tryParse('${json['sortOrder']}') ?? 0,
      );
}

class ErpPurchaseOrderVendor {
  const ErpPurchaseOrderVendor({
    required this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.mobileNo,
    this.email,
    this.contractorTypeCode,
  });

  final String id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? mobileNo;
  final String? email;
  final String? contractorTypeCode;

  factory ErpPurchaseOrderVendor.fromJson(Map<String, dynamic> json) =>
      ErpPurchaseOrderVendor(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        contactPerson: json['contactPerson']?.toString(),
        phone: json['phone']?.toString(),
        mobileNo: json['mobileNo']?.toString(),
        email: json['email']?.toString(),
        contractorTypeCode: json['contractorTypeCode']?.toString(),
      );
}

class ErpPurchaseOrder {
  const ErpPurchaseOrder({
    required this.id,
    required this.poNumber,
    required this.vendorName,
    this.vendorId,
    this.vendor,
    this.projectId,
    required this.orderDate,
    required this.status,
    this.remarks,
    this.items = const [],
    this.totalOrdered = 0,
    this.totalRemaining = 0,
  });

  final String id;
  final String poNumber;
  final String vendorName;
  final String? vendorId;
  final ErpPurchaseOrderVendor? vendor;
  final String? projectId;
  final DateTime orderDate;
  final String status;
  final String? remarks;
  final List<ErpPurchaseOrderItem> items;
  final double totalOrdered;
  final double totalRemaining;

  factory ErpPurchaseOrder.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    final vendorRaw = json['vendor'];
    return ErpPurchaseOrder(
      id: json['id']?.toString() ?? '',
      poNumber: json['poNumber']?.toString() ?? '',
      vendorName: json['vendorName']?.toString() ?? '',
      vendorId: json['vendorId']?.toString(),
      vendor: vendorRaw is Map
          ? ErpPurchaseOrderVendor.fromJson(Map<String, dynamic>.from(vendorRaw))
          : null,
      projectId: json['projectId']?.toString(),
      orderDate: DateTime.tryParse(json['orderDate']?.toString() ?? '') ?? DateTime.now(),
      status: json['status']?.toString() ?? 'OPEN',
      remarks: json['remarks']?.toString(),
      items: itemsRaw is List
          ? itemsRaw
              .map((e) => ErpPurchaseOrderItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
      totalOrdered: _d(json['totalOrdered']),
      totalRemaining: _d(json['totalRemaining']),
    );
  }
}

class ErpStoreInwardLine {
  const ErpStoreInwardLine({
    required this.id,
    required this.purchaseOrderItemId,
    this.materialId,
    required this.itemName,
    this.brand,
    this.unitCode,
    this.size,
    required this.quantityReceived,
    required this.quantityAccepted,
    this.quantityRejected = 0,
  });

  final String id;
  final String purchaseOrderItemId;
  final String? materialId;
  final String itemName;
  final String? brand;
  final String? unitCode;
  final String? size;
  final double quantityReceived;
  final double quantityAccepted;
  final double quantityRejected;

  factory ErpStoreInwardLine.fromJson(Map<String, dynamic> json) =>
      ErpStoreInwardLine(
        id: json['id']?.toString() ?? '',
        purchaseOrderItemId: json['purchaseOrderItemId']?.toString() ?? '',
        materialId: json['materialId']?.toString(),
        itemName: json['itemName']?.toString() ?? '',
        brand: json['brand']?.toString(),
        unitCode: json['unitCode']?.toString(),
        size: json['size']?.toString(),
        quantityReceived: _d(json['quantityReceived']),
        quantityAccepted: _d(json['quantityAccepted']),
        quantityRejected: _d(json['quantityRejected']),
      );
}

class ErpStoreInward {
  const ErpStoreInward({
    required this.id,
    required this.purchaseOrderId,
    required this.storeId,
    required this.inwardDate,
    this.truckNumber,
    this.challanNumber,
    this.challanImageUrl,
    required this.qcStatus,
    this.quantityRejected,
    this.returnDate,
    this.remarks,
    this.poNumber,
    this.vendorName,
    this.storeName,
    this.lines = const [],
  });

  final String id;
  final String purchaseOrderId;
  final String storeId;
  final DateTime inwardDate;
  final String? truckNumber;
  final String? challanNumber;
  final String? challanImageUrl;
  final String qcStatus;
  final double? quantityRejected;
  final DateTime? returnDate;
  final String? remarks;
  final String? poNumber;
  final String? vendorName;
  final String? storeName;
  final List<ErpStoreInwardLine> lines;

  factory ErpStoreInward.fromJson(Map<String, dynamic> json) {
    final po = json['purchaseOrder'];
    final store = json['store'];
    final linesRaw = json['lines'];
    return ErpStoreInward(
      id: json['id']?.toString() ?? '',
      purchaseOrderId: json['purchaseOrderId']?.toString() ?? '',
      storeId: json['storeId']?.toString() ?? '',
      inwardDate: DateTime.tryParse(json['inwardDate']?.toString() ?? '') ?? DateTime.now(),
      truckNumber: json['truckNumber']?.toString(),
      challanNumber: json['challanNumber']?.toString(),
      challanImageUrl: json['challanImageUrl']?.toString(),
      qcStatus: json['qcStatus']?.toString() ?? 'PASSED',
      quantityRejected: json['quantityRejected'] == null ? null : _d(json['quantityRejected']),
      returnDate: DateTime.tryParse(json['returnDate']?.toString() ?? ''),
      remarks: json['remarks']?.toString(),
      poNumber: po is Map ? po['poNumber']?.toString() : null,
      vendorName: po is Map ? po['vendorName']?.toString() : null,
      storeName: store is Map ? store['name']?.toString() : null,
      lines: linesRaw is List
          ? linesRaw
              .map((e) => ErpStoreInwardLine.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
    );
  }
}

double _d(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
