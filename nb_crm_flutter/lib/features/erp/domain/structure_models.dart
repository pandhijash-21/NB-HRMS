class ErpUnitTax {
  final String name;
  final double ratePercent;
  final double amount;

  const ErpUnitTax({
    required this.name,
    required this.ratePercent,
    required this.amount,
  });

  factory ErpUnitTax.fromJson(Map<String, dynamic> json) {
    return ErpUnitTax(
      name: json['name']?.toString() ?? '',
      ratePercent: _asDouble(json['ratePercent']) ??
          _asDouble(json['percent']) ??
          0.0,
      amount: _asDouble(json['amount']) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'ratePercent': ratePercent,
        'amount': amount,
      };
}

class ErpUnitMaintenance {
  final String name;
  final double? ratePerSqft;
  final double amount;
  final String? calculationType;

  const ErpUnitMaintenance({
    required this.name,
    this.ratePerSqft,
    required this.amount,
    this.calculationType,
  });

  factory ErpUnitMaintenance.fromJson(Map<String, dynamic> json) {
    return ErpUnitMaintenance(
      name: json['name']?.toString() ?? '',
      ratePerSqft: _asDouble(json['ratePerSqft']),
      amount: _asDouble(json['amount']) ?? 0.0,
      calculationType: json['calculationType']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (ratePerSqft != null) 'ratePerSqft': ratePerSqft,
        'amount': amount,
        if (calculationType != null) 'calculationType': calculationType,
      };
}

class ErpUnitOtherCharge {
  final String name;
  final int? docCount;
  final double? feePerDoc;
  final double amount;

  const ErpUnitOtherCharge({
    required this.name,
    this.docCount,
    this.feePerDoc,
    required this.amount,
  });

  factory ErpUnitOtherCharge.fromJson(Map<String, dynamic> json) {
    return ErpUnitOtherCharge(
      name: json['name']?.toString() ?? '',
      docCount: _asInt(json['docCount']) ?? _asInt(json['docsCount']),
      feePerDoc: _asDouble(json['feePerDoc']),
      amount: _asDouble(json['amount']) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (docCount != null) 'docCount': docCount,
        if (feePerDoc != null) 'feePerDoc': feePerDoc,
        'amount': amount,
      };
}

class ErpPaymentTerm {
  final String id;
  final String? planId;
  final String name;
  final double percentPayment;
  final double lastDayMonths;
  final int sequence;
  final bool isActive;
  final double? amount;

  const ErpPaymentTerm({
    required this.id,
    this.planId,
    required this.name,
    required this.percentPayment,
    required this.lastDayMonths,
    this.sequence = 0,
    this.isActive = true,
    this.amount,
  });

  factory ErpPaymentTerm.fromJson(Map<String, dynamic> json) {
    return ErpPaymentTerm(
      id: json['id']?.toString() ?? '',
      planId: json['planId']?.toString() ?? json['plan_id']?.toString(),
      name: json['name']?.toString() ?? '',
      percentPayment: _asDouble(json['percentPayment']) ??
          _asDouble(json['percent_payment']) ??
          0.0,
      lastDayMonths: _asDouble(json['lastDayMonths']) ??
          _asDouble(json['last_day_months']) ??
          0.0,
      sequence: _asInt(json['sequence']) ?? 0,
      isActive: json['isActive'] != false && json['is_active'] != false,
      amount: _asDouble(json['amount']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (planId != null) 'planId': planId,
        'name': name,
        'percentPayment': percentPayment,
        'lastDayMonths': lastDayMonths,
        'sequence': sequence,
        'isActive': isActive,
        if (amount != null) 'amount': amount,
      };
}

class ErpPaymentPlan {
  final String id;
  final String name;
  final String code;
  final String? description;
  final bool isDefault;
  final bool isActive;
  final int sequence;
  final List<ErpPaymentTerm> terms;

  const ErpPaymentPlan({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.isDefault = false,
    this.isActive = true,
    this.sequence = 0,
    this.terms = const [],
  });

  double get totalPercent {
    double sum = 0.0;
    for (final t in terms) {
      if (t.isActive) sum += t.percentPayment;
    }
    return double.parse(sum.toStringAsFixed(2));
  }

  bool get isValid100 => (totalPercent - 100.0).abs() < 0.01;

  factory ErpPaymentPlan.fromJson(Map<String, dynamic> json) {
    final rawTerms = json['terms'];
    List<ErpPaymentTerm> termsList = [];
    if (rawTerms is List) {
      termsList = rawTerms
          .whereType<Map>()
          .map((m) => ErpPaymentTerm.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }

    return ErpPaymentPlan(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString(),
      isDefault: json['isDefault'] == true || json['is_default'] == true,
      isActive: json['isActive'] != false && json['is_active'] != false,
      sequence: _asInt(json['sequence']) ?? 0,
      terms: termsList,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        if (description != null) 'description': description,
        'isDefault': isDefault,
        'isActive': isActive,
        'sequence': sequence,
        'terms': terms.map((t) => t.toJson()).toList(),
      };
}

class ErpProjectUnit {
  const ErpProjectUnit({
    required this.id,
    required this.towerId,
    required this.unitNo,
    this.unitTypeCode,
    required this.floorNo,
    this.isDuplex = false,
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
    this.frc,
    this.developmentCharge,
    this.baseRate,
    this.totalValue,
    this.totalUnitValue,
    this.taxes = const [],
    this.maintenance = const [],
    this.otherCharges = const [],
    this.paymentTerms = const [],
    this.grandTotal,
    this.remarks,
    this.sortOrder = 0,
  });

  final String id;
  final String towerId;
  final String unitNo;
  final String? unitTypeCode;
  final int floorNo;
  final bool isDuplex;
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
  final double? frc;
  final double? developmentCharge;
  final double? baseRate;
  final double? totalValue;
  final double? totalUnitValue;
  final List<ErpUnitTax> taxes;
  final List<ErpUnitMaintenance> maintenance;
  final List<ErpUnitOtherCharge> otherCharges;
  final List<ErpPaymentTerm> paymentTerms;
  final double? grandTotal;
  final String? remarks;
  final int sortOrder;

  double get effectiveUnitValue => totalUnitValue ?? totalValue ?? 0.0;
  double get effectiveGrandTotal {
    final tv = totalValue ?? 0.0;
    final gt = grandTotal ?? 0.0;
    if (tv > 0 && tv >= gt) return tv;
    if (gt > 0) return gt;
    return effectiveUnitValue;
  }

  bool get isDuplexUpper =>
      isDuplex && (unitNo.endsWith('-2') || (remarks?.toLowerCase().contains('upper') ?? false));
  bool get isDuplexBase => isDuplex && !isDuplexUpper;

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
    List<ErpUnitTax> parseTaxes(dynamic v) {
      if (v is List) {
        return v
            .whereType<Map>()
            .map((m) => ErpUnitTax.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
      return const [];
    }

    List<ErpUnitMaintenance> parseMaintenance(dynamic v) {
      if (v is List) {
        return v
            .whereType<Map>()
            .map((m) => ErpUnitMaintenance.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
      return const [];
    }

    List<ErpUnitOtherCharge> parseOtherCharges(dynamic v) {
      if (v is List) {
        return v
            .whereType<Map>()
            .map((m) => ErpUnitOtherCharge.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
      return const [];
    }

    List<ErpPaymentTerm> parsePaymentTerms(dynamic v) {
      if (v is List) {
        return v
            .whereType<Map>()
            .map((m) => ErpPaymentTerm.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
      return const [];
    }

    return ErpProjectUnit(
      id: json['id']?.toString() ?? '',
      towerId: json['towerId']?.toString() ?? '',
      unitNo: json['unitNo']?.toString() ?? '',
      unitTypeCode: json['unitTypeCode']?.toString(),
      floorNo: _asInt(json['floorNo']) ?? 0,
      isDuplex: json['isDuplex'] == true || json['is_duplex'] == true,
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
      frc: _asDouble(json['frc']),
      developmentCharge: _asDouble(json['developmentCharge'] ?? json['development_charge']),
      baseRate: _asDouble(json['baseRate']),
      totalValue: _asDouble(json['totalValue']),
      totalUnitValue: _asDouble(json['totalUnitValue'] ?? json['total_unit_value']),
      taxes: parseTaxes(json['taxes']),
      maintenance: parseMaintenance(json['maintenance']),
      otherCharges: parseOtherCharges(json['otherCharges'] ?? json['other_charges']),
      paymentTerms: parsePaymentTerms(json['paymentTerms'] ?? json['payment_terms']),
      grandTotal: _asDouble(json['grandTotal'] ?? json['grand_total']),
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
  int get duplexBaseCount => units.where((u) => u.isDuplexBase).length;
  int get duplexUpperCount => units.where((u) => u.isDuplexUpper).length;
  int get duplexCount => duplexBaseCount;
  int get physicalUnitsCount => units.isNotEmpty ? units.length : plannedUnits;
  int get sellableUnitsCount => units.isNotEmpty
      ? (units.length - duplexUpperCount)
      : plannedUnits;

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

/// Floor numbers for a tower — from units when present, else from tower config (matches backend).
List<int> towerFloorNumbers(ErpProjectTower tower) {
  if (tower.units.isNotEmpty) {
    final floors = tower.units.map((u) => u.floorNo).toSet().toList();
    floors.sort();
    return floors;
  }
  if (tower.floorCount < 1) return [];
  if (tower.hasGround) {
    return List.generate(tower.floorCount, (i) => i);
  }
  return List.generate(tower.floorCount, (i) => i + 1);
}
