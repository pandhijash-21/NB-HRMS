class ErpProjectUnit {
  const ErpProjectUnit({
    required this.id,
    required this.towerId,
    required this.unitNo,
    this.unitTypeCode,
    required this.floorNo,
    this.superBuiltUp,
    this.carpetArea,
    this.areaUnitCode,
    this.statusCode,
    this.facingCode,
    this.categoryCode,
    this.builtUpArea,
    this.balconyArea,
    this.terraceArea,
    this.plotArea,
    this.parkingAllocation,
    this.plc,
    this.baseRate,
    this.totalValue,
    this.remarks,
    this.sortOrder = 0,
  });

  final String id;
  final String towerId;
  final String unitNo;
  final String? unitTypeCode;
  final int floorNo;
  final double? superBuiltUp;
  final double? carpetArea;
  final String? areaUnitCode;
  final String? statusCode;
  final String? facingCode;
  final String? categoryCode;
  final double? builtUpArea;
  final double? balconyArea;
  final double? terraceArea;
  final double? plotArea;
  final String? parkingAllocation;
  final double? plc;
  final double? baseRate;
  final double? totalValue;
  final String? remarks;
  final int sortOrder;

  bool get isComplete =>
      unitNo.trim().isNotEmpty &&
      (unitTypeCode?.isNotEmpty ?? false) &&
      superBuiltUp != null &&
      carpetArea != null &&
      (areaUnitCode?.isNotEmpty ?? false) &&
      (statusCode?.isNotEmpty ?? false) &&
      (facingCode?.isNotEmpty ?? false) &&
      (categoryCode?.isNotEmpty ?? false) &&
      builtUpArea != null &&
      balconyArea != null &&
      terraceArea != null &&
      plotArea != null &&
      (parkingAllocation?.isNotEmpty ?? false) &&
      plc != null &&
      baseRate != null &&
      totalValue != null &&
      (remarks?.isNotEmpty ?? false);

  factory ErpProjectUnit.fromJson(Map<String, dynamic> json) {
    return ErpProjectUnit(
      id: json['id']?.toString() ?? '',
      towerId: json['towerId']?.toString() ?? '',
      unitNo: json['unitNo']?.toString() ?? '',
      unitTypeCode: json['unitTypeCode']?.toString(),
      floorNo: _asInt(json['floorNo']) ?? 0,
      superBuiltUp: _asDouble(json['superBuiltUp']),
      carpetArea: _asDouble(json['carpetArea']),
      areaUnitCode: json['areaUnitCode']?.toString(),
      statusCode: json['statusCode']?.toString(),
      facingCode: json['facingCode']?.toString(),
      categoryCode: json['categoryCode']?.toString(),
      builtUpArea: _asDouble(json['builtUpArea']),
      balconyArea: _asDouble(json['balconyArea']),
      terraceArea: _asDouble(json['terraceArea']),
      plotArea: _asDouble(json['plotArea']),
      parkingAllocation: json['parkingAllocation']?.toString(),
      plc: _asDouble(json['plc']),
      baseRate: _asDouble(json['baseRate']),
      totalValue: _asDouble(json['totalValue']),
      remarks: json['remarks']?.toString(),
      sortOrder: _asInt(json['sortOrder']) ?? 0,
    );
  }
}

class ErpProjectTower {
  const ErpProjectTower({
    required this.id,
    required this.projectId,
    required this.name,
    this.phase,
    this.basementCount = 0,
    required this.floorCount,
    required this.flatsPerFloor,
    this.hasGround = false,
    this.sequence = 0,
    this.statusCode,
    this.remarks,
    this.unitCount = 0,
    this.expectedUnits,
    this.units = const [],
  });

  final String id;
  final String projectId;
  final String name;
  final String? phase;
  final int basementCount;
  final int floorCount;
  final int flatsPerFloor;
  final bool hasGround;
  final int sequence;
  final String? statusCode;
  final String? remarks;
  final int unitCount;
  final int? expectedUnits;
  final List<ErpProjectUnit> units;

  int get plannedUnits => expectedUnits ?? (floorCount * flatsPerFloor);

  factory ErpProjectTower.fromJson(Map<String, dynamic> json) {
    final unitsRaw = json['units'];
    final countMap = json['_count'] is Map ? Map<String, dynamic>.from(json['_count'] as Map) : null;
    return ErpProjectTower(
      id: json['id']?.toString() ?? '',
      projectId: json['projectId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phase: json['phase']?.toString(),
      basementCount: _asInt(json['basementCount']) ?? 0,
      floorCount: _asInt(json['floorCount']) ?? 0,
      flatsPerFloor: _asInt(json['flatsPerFloor']) ?? 0,
      hasGround: json['hasGround'] == true,
      sequence: _asInt(json['sequence']) ?? 0,
      statusCode: json['statusCode']?.toString(),
      remarks: json['remarks']?.toString(),
      unitCount: _asInt(json['unitCount'] ?? countMap?['units']) ??
          (unitsRaw is List ? unitsRaw.length : 0),
      expectedUnits: _asInt(json['expectedUnits']),
      units: unitsRaw is List
          ? unitsRaw
              .map((e) => ErpProjectUnit.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
    );
  }
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _asDouble(Object? value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String floorLabel(int floorNo) {
  if (floorNo == 0) return 'Ground';
  if (floorNo < 0) return 'Basement ${floorNo.abs()}';
  return 'Floor $floorNo';
}
