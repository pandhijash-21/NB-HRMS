class ErpPricingComponent {
  const ErpPricingComponent({
    required this.id,
    required this.category,
    required this.code,
    required this.name,
    required this.formulaType,
    required this.formulaPreview,
    this.referenceBase,
    this.defaultRate,
    this.rateUnit = '₹/sq.ft',
    this.isRequired = false,
    this.isActive = true,
    this.sequence = 0,
    this.description,
  });

  final String id;
  final String category; // BASE_PRICE | TAX | MAINTENANCE | OTHER_CHARGE
  final String code;
  final String name;
  final String formulaType; // AREA_RATE | AREA_BSV | PERCENTAGE | FIXED | DOCS_MULTIPLIER
  final String formulaPreview;
  final String? referenceBase; // SUPER_BUILT_UP | TOTAL_UNIT_VALUE | BASE_PRICE
  final double? defaultRate;
  final String? rateUnit;
  final bool isRequired;
  final bool isActive;
  final int sequence;
  final String? description;

  String get categoryLabel {
    switch (category) {
      case 'BASE_PRICE':
        return 'Base Pricing & Charges';
      case 'TAX':
        return 'Taxes';
      case 'MAINTENANCE':
        return 'Maintenance Charges';
      case 'OTHER_CHARGE':
        return 'Other Charges';
      default:
        return category;
    }
  }

  String get formulaTypeLabel {
    switch (formulaType) {
      case 'AREA_RATE':
        return 'Area × Component Rate (₹/sq.ft)';
      case 'AREA_BSV':
        return 'Area × Base Rate (BSV)';
      case 'PERCENTAGE':
        return '% of Total Unit Value';
      case 'FIXED':
        return 'Fixed Amount (₹)';
      case 'DOCS_MULTIPLIER':
        return 'Document Count × Fee per Doc';
      default:
        return formulaType;
    }
  }

  factory ErpPricingComponent.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return ErpPricingComponent(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? 'BASE_PRICE',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      formulaType: json['formulaType']?.toString() ?? json['formula_type']?.toString() ?? 'AREA_RATE',
      formulaPreview: json['formulaPreview']?.toString() ?? json['formula_preview']?.toString() ?? '',
      referenceBase: json['referenceBase']?.toString() ?? json['reference_base']?.toString(),
      defaultRate: parseDouble(json['defaultRate'] ?? json['default_rate']),
      rateUnit: json['rateUnit']?.toString() ?? json['rate_unit']?.toString() ?? '₹/sq.ft',
      isRequired: json['isRequired'] == true || json['is_required'] == true,
      isActive: json['isActive'] != false && json['is_active'] != false,
      sequence: json['sequence'] is int ? json['sequence'] as int : int.tryParse(json['sequence']?.toString() ?? '') ?? 0,
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'code': code,
      'name': name,
      'formulaType': formulaType,
      'formulaPreview': formulaPreview,
      'referenceBase': referenceBase,
      'defaultRate': defaultRate,
      'rateUnit': rateUnit,
      'isRequired': isRequired,
      'isActive': isActive,
      'sequence': sequence,
      'description': description,
    };
  }
}
