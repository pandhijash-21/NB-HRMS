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
