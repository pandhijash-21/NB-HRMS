int? earthAsInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? earthAsDouble(Object? value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime? earthAsDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

class EarthGeocodeHit {
  const EarthGeocodeHit({
    required this.label,
    required this.latitude,
    required this.longitude,
    this.type,
    this.address,
    this.locality,
    this.city,
    this.state,
    this.country,
    this.pincode,
  });

  final String label;
  final double latitude;
  final double longitude;
  final String? type;
  final String? address;
  final String? locality;
  final String? city;
  final String? state;
  final String? country;
  final String? pincode;

  factory EarthGeocodeHit.fromJson(Map<String, dynamic> json) {
    return EarthGeocodeHit(
      label: json['label']?.toString() ?? json['address']?.toString() ?? '',
      latitude: earthAsDouble(json['latitude']) ?? 0,
      longitude: earthAsDouble(json['longitude']) ?? 0,
      type: json['type']?.toString(),
      address: json['address']?.toString(),
      locality: json['locality']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      country: json['country']?.toString(),
      pincode: json['pincode']?.toString(),
    );
  }
}

class EarthPropertyPrice {
  const EarthPropertyPrice({
    required this.id,
    required this.propertyId,
    required this.amount,
    this.currency = 'INR',
    this.pricePerArea,
    required this.effectiveFrom,
    this.effectiveTo,
    this.notes,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String propertyId;
  final double amount;
  final String currency;
  final double? pricePerArea;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;

  bool get isCurrent => effectiveTo == null;

  factory EarthPropertyPrice.fromJson(Map<String, dynamic> json) {
    return EarthPropertyPrice(
      id: json['id']?.toString() ?? '',
      propertyId: json['propertyId']?.toString() ?? '',
      amount: earthAsDouble(json['amount']) ?? 0,
      currency: json['currency']?.toString() ?? 'INR',
      pricePerArea: earthAsDouble(json['pricePerArea']),
      effectiveFrom: earthAsDate(json['effectiveFrom']) ?? DateTime.now(),
      effectiveTo: earthAsDate(json['effectiveTo']),
      notes: json['notes']?.toString(),
      createdBy: json['createdBy']?.toString(),
      createdAt: earthAsDate(json['createdAt']),
    );
  }
}

class EarthPropertyMedia {
  const EarthPropertyMedia({
    required this.id,
    required this.url,
    this.kind = 'PHOTO',
    this.isPrimary = false,
    this.fileName,
  });

  final String id;
  final String url;
  final String kind;
  final bool isPrimary;
  final String? fileName;

  factory EarthPropertyMedia.fromJson(Map<String, dynamic> json) {
    return EarthPropertyMedia(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'PHOTO',
      isPrimary: json['isPrimary'] == true,
      fileName: json['fileName']?.toString(),
    );
  }
}

class EarthProperty {
  const EarthProperty({
    required this.id,
    required this.name,
    required this.kind,
    this.customKind,
    this.status = 'AVAILABLE',
    required this.latitude,
    required this.longitude,
    this.altitudeM,
    this.address,
    this.locality,
    this.city,
    this.state,
    this.country,
    this.pincode,
    this.imageUrl,
    this.specs = const {},
    this.carpetArea,
    this.builtUpArea,
    this.plotArea,
    this.areaUnit = 'SQFT',
    this.bedrooms,
    this.bathrooms,
    this.floorNo,
    this.totalFloors,
    this.currentPrice,
    this.currency = 'INR',
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.prices = const [],
    this.media = const [],
  });

  final String id;
  final String name;
  final String kind;
  final String? customKind;
  final String status;
  final double latitude;
  final double longitude;
  final double? altitudeM;
  final String? address;
  final String? locality;
  final String? city;
  final String? state;
  final String? country;
  final String? pincode;
  final String? imageUrl;
  final Map<String, dynamic> specs;
  final double? carpetArea;
  final double? builtUpArea;
  final double? plotArea;
  final String areaUnit;
  final int? bedrooms;
  final int? bathrooms;
  final int? floorNo;
  final int? totalFloors;
  final double? currentPrice;
  final String currency;
  final String? notes;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<EarthPropertyPrice> prices;
  final List<EarthPropertyMedia> media;

  String get pinImage => imageUrl ?? (media.isNotEmpty ? media.first.url : '');

  double? get displayArea => carpetArea ?? builtUpArea ?? plotArea;

  String get locationLabel {
    final parts = [locality, city, state].where((e) => (e ?? '').trim().isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(', ');
    return address ?? '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }

  factory EarthProperty.fromJson(Map<String, dynamic> json) {
    final specsRaw = json['specs'];
    return EarthProperty(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Untitled',
      kind: json['kind']?.toString() ?? 'OTHER',
      customKind: json['customKind']?.toString(),
      status: json['status']?.toString() ?? 'AVAILABLE',
      latitude: earthAsDouble(json['latitude']) ?? 0,
      longitude: earthAsDouble(json['longitude']) ?? 0,
      altitudeM: earthAsDouble(json['altitudeM']),
      address: json['address']?.toString(),
      locality: json['locality']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      country: json['country']?.toString(),
      pincode: json['pincode']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      specs: specsRaw is Map ? Map<String, dynamic>.from(specsRaw) : const {},
      carpetArea: earthAsDouble(json['carpetArea']),
      builtUpArea: earthAsDouble(json['builtUpArea']),
      plotArea: earthAsDouble(json['plotArea']),
      areaUnit: json['areaUnit']?.toString() ?? 'SQFT',
      bedrooms: earthAsInt(json['bedrooms']),
      bathrooms: earthAsInt(json['bathrooms']),
      floorNo: earthAsInt(json['floorNo']),
      totalFloors: earthAsInt(json['totalFloors']),
      currentPrice: earthAsDouble(json['currentPrice']),
      currency: json['currency']?.toString() ?? 'INR',
      notes: json['notes']?.toString(),
      isActive: json['isActive'] != false,
      createdAt: earthAsDate(json['createdAt']),
      updatedAt: earthAsDate(json['updatedAt']),
      prices: (json['prices'] as List? ?? [])
          .map((e) => EarthPropertyPrice.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      media: (json['media'] as List? ?? [])
          .map((e) => EarthPropertyMedia.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class EarthKindStat {
  const EarthKindStat({
    required this.kind,
    required this.count,
    required this.avgPrice,
    required this.totalValue,
  });

  final String kind;
  final int count;
  final double avgPrice;
  final double totalValue;

  factory EarthKindStat.fromJson(Map<String, dynamic> json) {
    return EarthKindStat(
      kind: json['kind']?.toString() ?? '',
      count: earthAsInt(json['count']) ?? 0,
      avgPrice: earthAsDouble(json['avgPrice']) ?? 0,
      totalValue: earthAsDouble(json['totalValue']) ?? 0,
    );
  }
}

class EarthStatusStat {
  const EarthStatusStat({required this.status, required this.count});
  final String status;
  final int count;
  factory EarthStatusStat.fromJson(Map<String, dynamic> json) {
    return EarthStatusStat(
      status: json['status']?.toString() ?? '',
      count: earthAsInt(json['count']) ?? 0,
    );
  }
}

class EarthCityStat {
  const EarthCityStat({
    required this.city,
    required this.count,
    required this.avgPrice,
    required this.totalValue,
    this.avgAppreciationPct,
  });

  final String city;
  final int count;
  final double avgPrice;
  final double totalValue;
  final double? avgAppreciationPct;

  factory EarthCityStat.fromJson(Map<String, dynamic> json) {
    return EarthCityStat(
      city: json['city']?.toString() ?? '',
      count: earthAsInt(json['count']) ?? 0,
      avgPrice: earthAsDouble(json['avgPrice']) ?? 0,
      totalValue: earthAsDouble(json['totalValue']) ?? 0,
      avgAppreciationPct: earthAsDouble(json['avgAppreciationPct']),
    );
  }
}

class EarthMonthPoint {
  const EarthMonthPoint({
    required this.month,
    required this.avgPrice,
    required this.count,
    this.avgPricePerArea,
  });

  final String month;
  final double avgPrice;
  final int count;
  final double? avgPricePerArea;

  factory EarthMonthPoint.fromJson(Map<String, dynamic> json) {
    return EarthMonthPoint(
      month: json['month']?.toString() ?? '',
      avgPrice: earthAsDouble(json['avgPrice']) ?? 0,
      count: earthAsInt(json['count']) ?? 0,
      avgPricePerArea: earthAsDouble(json['avgPricePerArea']),
    );
  }
}

class EarthAppreciationRow {
  const EarthAppreciationRow({
    required this.id,
    required this.name,
    required this.kind,
    this.city,
    this.imageUrl,
    required this.firstPrice,
    required this.latestPrice,
    required this.appreciationPct,
  });

  final String id;
  final String name;
  final String kind;
  final String? city;
  final String? imageUrl;
  final double firstPrice;
  final double latestPrice;
  final double appreciationPct;

  factory EarthAppreciationRow.fromJson(Map<String, dynamic> json) {
    return EarthAppreciationRow(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      city: json['city']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      firstPrice: earthAsDouble(json['firstPrice']) ?? 0,
      latestPrice: earthAsDouble(json['latestPrice']) ?? 0,
      appreciationPct: earthAsDouble(json['appreciationPct']) ?? 0,
    );
  }
}

class EarthPriceChangeRow {
  const EarthPriceChangeRow({
    required this.propertyId,
    required this.name,
    required this.kind,
    required this.amount,
    this.previousAmount,
    this.changePct,
    required this.effectiveFrom,
    this.imageUrl,
  });

  final String propertyId;
  final String name;
  final String kind;
  final double amount;
  final double? previousAmount;
  final double? changePct;
  final DateTime effectiveFrom;
  final String? imageUrl;

  factory EarthPriceChangeRow.fromJson(Map<String, dynamic> json) {
    return EarthPriceChangeRow(
      propertyId: json['propertyId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      amount: earthAsDouble(json['amount']) ?? 0,
      previousAmount: earthAsDouble(json['previousAmount']),
      changePct: earthAsDouble(json['changePct']),
      effectiveFrom: earthAsDate(json['effectiveFrom']) ?? DateTime.now(),
      imageUrl: json['imageUrl']?.toString(),
    );
  }
}

class EarthStaleRow {
  const EarthStaleRow({
    required this.id,
    required this.name,
    required this.kind,
    this.currentPrice,
    required this.daysSinceUpdate,
  });

  final String id;
  final String name;
  final String kind;
  final double? currentPrice;
  final int daysSinceUpdate;

  factory EarthStaleRow.fromJson(Map<String, dynamic> json) {
    return EarthStaleRow(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      currentPrice: earthAsDouble(json['currentPrice']),
      daysSinceUpdate: earthAsInt(json['daysSinceUpdate']) ?? 0,
    );
  }
}

class EarthDashboard {
  const EarthDashboard({
    required this.properties,
    required this.available,
    required this.sold,
    required this.reserved,
    required this.underConstruction,
    required this.rented,
    required this.totalValue,
    required this.avgPrice,
    this.avgPricePerArea,
    this.avgAppreciationPct,
    required this.pricedCount,
    this.momChangePct,
    this.yoyChangePct,
    this.byKind = const [],
    this.byStatus = const [],
    this.byCity = const [],
    this.monthlyTrend = const [],
    this.topAppreciation = const [],
    this.recentPriceChanges = const [],
    this.stalePricing = const [],
  });

  final int properties;
  final int available;
  final int sold;
  final int reserved;
  final int underConstruction;
  final int rented;
  final double totalValue;
  final double avgPrice;
  final double? avgPricePerArea;
  final double? avgAppreciationPct;
  final int pricedCount;
  final double? momChangePct;
  final double? yoyChangePct;
  final List<EarthKindStat> byKind;
  final List<EarthStatusStat> byStatus;
  final List<EarthCityStat> byCity;
  final List<EarthMonthPoint> monthlyTrend;
  final List<EarthAppreciationRow> topAppreciation;
  final List<EarthPriceChangeRow> recentPriceChanges;
  final List<EarthStaleRow> stalePricing;

  factory EarthDashboard.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] is Map
        ? Map<String, dynamic>.from(json['totals'] as Map)
        : json;
    return EarthDashboard(
      properties: earthAsInt(totals['properties']) ?? 0,
      available: earthAsInt(totals['available']) ?? 0,
      sold: earthAsInt(totals['sold']) ?? 0,
      reserved: earthAsInt(totals['reserved']) ?? 0,
      underConstruction: earthAsInt(totals['underConstruction']) ?? 0,
      rented: earthAsInt(totals['rented']) ?? 0,
      totalValue: earthAsDouble(totals['totalValue']) ?? 0,
      avgPrice: earthAsDouble(totals['avgPrice']) ?? 0,
      avgPricePerArea: earthAsDouble(totals['avgPricePerArea']),
      avgAppreciationPct: earthAsDouble(totals['avgAppreciationPct']),
      pricedCount: earthAsInt(totals['pricedCount']) ?? 0,
      momChangePct: earthAsDouble(totals['momChangePct']),
      yoyChangePct: earthAsDouble(totals['yoyChangePct']),
      byKind: (json['byKind'] as List? ?? [])
          .map((e) => EarthKindStat.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      byStatus: (json['byStatus'] as List? ?? [])
          .map((e) => EarthStatusStat.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      byCity: (json['byCity'] as List? ?? [])
          .map((e) => EarthCityStat.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      monthlyTrend: (json['monthlyTrend'] as List? ?? [])
          .map((e) => EarthMonthPoint.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      topAppreciation: (json['topAppreciation'] as List? ?? [])
          .map((e) => EarthAppreciationRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      recentPriceChanges: (json['recentPriceChanges'] as List? ?? [])
          .map((e) => EarthPriceChangeRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      stalePricing: (json['stalePricing'] as List? ?? [])
          .map((e) => EarthStaleRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
