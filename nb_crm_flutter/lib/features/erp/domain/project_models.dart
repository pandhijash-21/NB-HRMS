class ErpProjectDocument {
  const ErpProjectDocument({
    this.id,
    this.typeCode,
    required this.name,
    this.remarks,
    required this.fileUrl,
    this.fileName,
    this.mimeType,
    this.fileSize,
    this.sortOrder = 0,
  });

  final String? id;
  final String? typeCode;
  final String name;
  final String? remarks;
  final String fileUrl;
  final String? fileName;
  final String? mimeType;
  final int? fileSize;
  final int sortOrder;

  factory ErpProjectDocument.fromJson(Map<String, dynamic> json) {
    return ErpProjectDocument(
      id: json['id']?.toString(),
      typeCode: json['typeCode']?.toString(),
      name: json['name']?.toString() ?? 'Document',
      remarks: json['remarks']?.toString(),
      fileUrl: json['fileUrl']?.toString() ?? '',
      fileName: json['fileName']?.toString(),
      mimeType: json['mimeType']?.toString(),
      fileSize: _asInt(json['fileSize']),
      sortOrder: _asInt(json['sortOrder']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'typeCode': typeCode,
        'name': name,
        'remarks': remarks,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'mimeType': mimeType,
        'fileSize': fileSize,
        'sortOrder': sortOrder,
      };
}

class ErpProjectRef {
  const ErpProjectRef({required this.id, required this.code, required this.name});
  final String id;
  final String code;
  final String name;

  factory ErpProjectRef.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ErpProjectRef(id: '', code: '', name: '');
    }
    return ErpProjectRef(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class ErpProjectOwner {
  const ErpProjectOwner({required this.id, required this.fullName, this.designation});
  final int id;
  final String fullName;
  final String? designation;

  factory ErpProjectOwner.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ErpProjectOwner(id: 0, fullName: '');
    }
    final general = json['generalInfo'] is Map
        ? Map<String, dynamic>.from(json['generalInfo'] as Map)
        : json;
    return ErpProjectOwner(
      id: _asInt(json['id']) ?? 0,
      fullName: general['fullName']?.toString() ?? 'Employee #${json['id']}',
      designation: general['designation']?.toString(),
    );
  }
}

class ErpProject {
  const ErpProject({
    required this.id,
    required this.projectNo,
    required this.name,
    this.organizationId,
    this.instituteId,
    this.categoryCode,
    this.subCategoryCode,
    this.structureCode,
    this.segmentCode,
    this.reraNo,
    this.expectedCompletionDate,
    this.notes,
    this.statusCode,
    this.ownerEmployeeId,
    this.totalProjectArea,
    this.areaUnitCode,
    this.estimatedCost,
    this.imageUrl,
    this.address,
    this.landmark,
    this.countryCode,
    this.stateCode,
    this.cityCode,
    this.areaCode,
    this.pincode,
    this.totalPlotArea,
    this.amenitiesCode,
    this.livabilityCode,
    this.bankTieUpCode,
    this.developmentAuthorityCode,
    this.electricityProviderCode,
    this.specNotes,
    this.isActive = true,
    this.organization,
    this.institute,
    this.owner,
    this.documents = const [],
    this.towerCount = 0,
  });

  final String id;
  final int projectNo;
  final String name;
  final String? organizationId;
  final String? instituteId;
  final String? categoryCode;
  final String? subCategoryCode;
  final String? structureCode;
  final String? segmentCode;
  final String? reraNo;
  final DateTime? expectedCompletionDate;
  final String? notes;
  final String? statusCode;
  final int? ownerEmployeeId;
  final double? totalProjectArea;
  final String? areaUnitCode;
  final double? estimatedCost;
  final String? imageUrl;
  final String? address;
  final String? landmark;
  final String? countryCode;
  final String? stateCode;
  final String? cityCode;
  final String? areaCode;
  final String? pincode;
  final double? totalPlotArea;
  final String? amenitiesCode;
  final String? livabilityCode;
  final String? bankTieUpCode;
  final String? developmentAuthorityCode;
  final String? electricityProviderCode;
  final String? specNotes;
  final bool isActive;
  final ErpProjectRef? organization;
  final ErpProjectRef? institute;
  final ErpProjectOwner? owner;
  final List<ErpProjectDocument> documents;
  final int towerCount;

  String get displayId => projectNo.toString().padLeft(4, '0');

  List<String> get amenitiesCodes {
    if (amenitiesCode == null || amenitiesCode!.trim().isEmpty) return const [];
    return amenitiesCode!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  factory ErpProject.fromJson(Map<String, dynamic> json) {
    final docs = json['documents'];
    return ErpProject(
      id: json['id']?.toString() ?? '',
      projectNo: _asInt(json['projectNo']) ?? 0,
      name: json['name']?.toString() ?? '',
      organizationId: json['organizationId']?.toString(),
      instituteId: json['instituteId']?.toString(),
      categoryCode: json['categoryCode']?.toString(),
      subCategoryCode: json['subCategoryCode']?.toString(),
      structureCode: json['structureCode']?.toString(),
      segmentCode: json['segmentCode']?.toString(),
      reraNo: json['reraNo']?.toString(),
      expectedCompletionDate: _asDate(json['expectedCompletionDate']),
      notes: json['notes']?.toString(),
      statusCode: json['statusCode']?.toString(),
      ownerEmployeeId: _asInt(json['ownerEmployeeId']),
      totalProjectArea: _asDouble(json['totalProjectArea']),
      areaUnitCode: json['areaUnitCode']?.toString(),
      estimatedCost: _asDouble(json['estimatedCost']),
      imageUrl: json['imageUrl']?.toString(),
      address: json['address']?.toString(),
      landmark: json['landmark']?.toString(),
      countryCode: json['countryCode']?.toString(),
      stateCode: json['stateCode']?.toString(),
      cityCode: json['cityCode']?.toString(),
      areaCode: json['areaCode']?.toString(),
      pincode: json['pincode']?.toString(),
      totalPlotArea: _asDouble(json['totalPlotArea']),
      amenitiesCode: json['amenitiesCode']?.toString(),
      livabilityCode: json['livabilityCode']?.toString(),
      bankTieUpCode: json['bankTieUpCode']?.toString(),
      developmentAuthorityCode: json['developmentAuthorityCode']?.toString(),
      electricityProviderCode: json['electricityProviderCode']?.toString(),
      specNotes: json['specNotes']?.toString(),
      isActive: json['isActive'] != false,
      organization: json['organization'] is Map
          ? ErpProjectRef.fromJson(Map<String, dynamic>.from(json['organization'] as Map))
          : null,
      institute: json['institute'] is Map
          ? ErpProjectRef.fromJson(Map<String, dynamic>.from(json['institute'] as Map))
          : null,
      owner: json['owner'] is Map
          ? ErpProjectOwner.fromJson(Map<String, dynamic>.from(json['owner'] as Map))
          : null,
      documents: docs is List
          ? docs
              .map((e) => ErpProjectDocument.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
      towerCount: _asInt(
            json['towerCount'] ??
                (json['_count'] is Map ? (json['_count'] as Map)['towers'] : null),
          ) ??
          0,
    );
  }
}

class ProjectEmployeeOption {
  const ProjectEmployeeOption({required this.id, required this.fullName});
  final int id;
  final String fullName;
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

DateTime? _asDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
