import 'dart:convert';

class ErpTenderLine {
  const ErpTenderLine({
    this.id,
    this.activityId,
    required this.activityName,
    this.boqTaskId,
    this.taskId,
    required this.taskName,
    this.taskDescription,
    this.towerIds = const [],
    this.floorNos = const [],
    this.unitIds = const [],
    this.quantity,
    this.unitCode,
    this.rate,
    this.amount,
    this.sortOrder = 0,
  });

  final String? id;
  final String? activityId;
  final String activityName;
  final String? boqTaskId;
  final String? taskId;
  final String taskName;
  final String? taskDescription;
  final List<String> towerIds;
  final List<int> floorNos;
  final List<String> unitIds;
  final double? quantity;
  final String? unitCode;
  final double? rate;
  final double? amount;
  final int sortOrder;

  double get computedAmount {
    if (amount != null) return amount!;
    if (quantity != null && rate != null) return quantity! * rate!;
    return 0;
  }

  factory ErpTenderLine.fromJson(Map<String, dynamic> json) => ErpTenderLine(
        id: json['id']?.toString(),
        activityId: json['activityId']?.toString(),
        activityName: json['activityName']?.toString() ?? '',
        boqTaskId: json['boqTaskId']?.toString(),
        taskId: json['taskId']?.toString(),
        taskName: json['taskName']?.toString() ?? '',
        taskDescription: json['taskDescription']?.toString(),
        towerIds: _parseStrList(json['towerIds']),
        floorNos: _parseIntList(json['floorNos']),
        unitIds: _parseStrList(json['unitIds']),
        quantity: json['quantity'] != null ? _d(json['quantity']) : null,
        unitCode: json['unitCode']?.toString(),
        rate: json['rate'] != null ? _d(json['rate']) : null,
        amount: json['amount'] != null ? _d(json['amount']) : null,
        sortOrder: int.tryParse('${json['sortOrder']}') ?? 0,
      );

  Map<String, dynamic> toJson() => {
        if (id != null && id!.isNotEmpty) 'id': id,
        if (activityId != null) 'activityId': activityId,
        'activityName': activityName,
        if (boqTaskId != null) 'boqTaskId': boqTaskId,
        if (taskId != null) 'taskId': taskId,
        'taskName': taskName,
        if (taskDescription != null) 'taskDescription': taskDescription,
        'towerIds': towerIds,
        'floorNos': floorNos,
        'unitIds': unitIds,
        if (quantity != null) 'quantity': quantity,
        if (unitCode != null) 'unitCode': unitCode,
        if (rate != null) 'rate': rate,
        if (amount != null) 'amount': amount,
        'sortOrder': sortOrder,
      };

  ErpTenderLine copyWith({
    double? quantity,
    double? rate,
    double? amount,
    String? unitCode,
  }) =>
      ErpTenderLine(
        id: id,
        activityId: activityId,
        activityName: activityName,
        boqTaskId: boqTaskId,
        taskId: taskId,
        taskName: taskName,
        taskDescription: taskDescription,
        towerIds: towerIds,
        floorNos: floorNos,
        unitIds: unitIds,
        quantity: quantity ?? this.quantity,
        unitCode: unitCode ?? this.unitCode,
        rate: rate ?? this.rate,
        amount: amount ?? this.amount,
        sortOrder: sortOrder,
      );
}

class ErpTenderRef {
  const ErpTenderRef({required this.id, required this.name, this.projectNo});
  final String id;
  final String name;
  final int? projectNo;

  factory ErpTenderRef.fromJson(Map<String, dynamic> json) => ErpTenderRef(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        projectNo: int.tryParse('${json['projectNo']}'),
      );
}

class ErpTenderBoqRef {
  const ErpTenderBoqRef({required this.id, required this.boqNo, required this.title});
  final String id;
  final String boqNo;
  final String title;

  factory ErpTenderBoqRef.fromJson(Map<String, dynamic> json) => ErpTenderBoqRef(
        id: json['id']?.toString() ?? '',
        boqNo: json['boqNo']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
      );
}

class ErpTender {
  const ErpTender({
    required this.id,
    required this.tenderNo,
    required this.tenderDate,
    this.createdByName,
    required this.projectId,
    this.boqId,
    required this.startDate,
    required this.endDate,
    this.status = 'OPEN',
    this.remarks,
    this.isActive = true,
    this.project,
    this.boq,
    this.lines = const [],
    this.lineCount,
    this.applicationCount,
  });

  final String id;
  final String tenderNo;
  final DateTime tenderDate;
  final String? createdByName;
  final String projectId;
  final String? boqId;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String? remarks;
  final bool isActive;
  final ErpTenderRef? project;
  final ErpTenderBoqRef? boq;
  final List<ErpTenderLine> lines;
  final int? lineCount;
  final int? applicationCount;

  double get totalAmount => lines.fold(0.0, (s, l) => s + l.computedAmount);

  factory ErpTender.fromJson(Map<String, dynamic> json) {
    final linesRaw = json['lines'];
    final count = json['_count'];
    return ErpTender(
      id: json['id']?.toString() ?? '',
      tenderNo: json['tenderNo']?.toString() ?? '',
      tenderDate: _date(json['tenderDate']) ?? DateTime.now(),
      createdByName: json['createdByName']?.toString(),
      projectId: json['projectId']?.toString() ?? '',
      boqId: json['boqId']?.toString(),
      startDate: _date(json['startDate']) ?? DateTime.now(),
      endDate: _date(json['endDate']) ?? DateTime.now(),
      status: json['status']?.toString() ?? 'OPEN',
      remarks: json['remarks']?.toString(),
      isActive: json['isActive'] != false,
      project: json['project'] is Map
          ? ErpTenderRef.fromJson(Map<String, dynamic>.from(json['project'] as Map))
          : null,
      boq: json['boq'] is Map
          ? ErpTenderBoqRef.fromJson(Map<String, dynamic>.from(json['boq'] as Map))
          : null,
      lines: linesRaw is List
          ? linesRaw
              .map((e) => ErpTenderLine.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
      lineCount: count is Map ? int.tryParse('${count['lines']}') : null,
      applicationCount: count is Map ? int.tryParse('${count['applications']}') : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'tenderNo': tenderNo,
        'tenderDate': tenderDate.toIso8601String(),
        if (createdByName != null) 'createdByName': createdByName,
        'projectId': projectId,
        if (boqId != null) 'boqId': boqId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'status': status,
        if (remarks != null) 'remarks': remarks,
        'lines': lines.map((l) => l.toJson()).toList(),
      };
}

class ErpTenderApplication {
  const ErpTenderApplication({
    required this.id,
    required this.applicationNo,
    required this.tenderId,
    this.projectId,
    this.activityId,
    this.activityName,
    this.contractorId,
    required this.vendorName,
    this.vendorContact,
    required this.applicationDate,
    this.quotedAmount,
    this.status = 'SUBMITTED',
    this.remarks,
    this.createdByName,
    this.tenderNo,
    this.projectName,
    this.contractorName,
  });

  final String id;
  final String applicationNo;
  final String tenderId;
  final String? projectId;
  final String? activityId;
  final String? activityName;
  final String? contractorId;
  final String vendorName;
  final String? vendorContact;
  final DateTime applicationDate;
  final double? quotedAmount;
  final String status;
  final String? remarks;
  final String? createdByName;
  final String? tenderNo;
  final String? projectName;
  final String? contractorName;

  factory ErpTenderApplication.fromJson(Map<String, dynamic> json) {
    final tender = json['tender'];
    final contractor = json['contractor'];
    return ErpTenderApplication(
      id: json['id']?.toString() ?? '',
      applicationNo: json['applicationNo']?.toString() ?? '',
      tenderId: json['tenderId']?.toString() ?? '',
      projectId: json['projectId']?.toString(),
      activityId: json['activityId']?.toString(),
      activityName: json['activityName']?.toString(),
      contractorId: json['contractorId']?.toString(),
      vendorName: json['vendorName']?.toString() ?? '',
      vendorContact: json['vendorContact']?.toString(),
      applicationDate: _date(json['applicationDate']) ?? DateTime.now(),
      quotedAmount: json['quotedAmount'] != null ? _d(json['quotedAmount']) : null,
      status: json['status']?.toString() ?? 'SUBMITTED',
      remarks: json['remarks']?.toString(),
      createdByName: json['createdByName']?.toString(),
      tenderNo: tender is Map ? tender['tenderNo']?.toString() : null,
      projectName: tender is Map && tender['project'] is Map
          ? (tender['project'] as Map)['name']?.toString()
          : null,
      contractorName: contractor is Map
          ? contractor['name']?.toString()
          : null,
    );
  }
}

class TenderActivityOption {
  const TenderActivityOption({this.id, required this.name});
  final String? id;
  final String name;

  factory TenderActivityOption.fromJson(Map<String, dynamic> json) => TenderActivityOption(
        id: json['id']?.toString(),
        name: json['name']?.toString() ?? '',
      );
}

double _d(dynamic v) => double.tryParse('$v') ?? 0;

DateTime? _date(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

List<String> _parseStrList(dynamic v) {
  if (v == null) return const [];
  if (v is List) return v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  if (v is String && v.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(v);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      }
    } catch (_) {}
  }
  return const [];
}

List<int> _parseIntList(dynamic v) {
  if (v == null) return const [];
  if (v is List) {
    return v.map((e) => int.tryParse('$e')).whereType<int>().toList();
  }
  if (v is String && v.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(v);
      if (decoded is List) {
        return decoded.map((e) => int.tryParse('$e')).whereType<int>().toList();
      }
    } catch (_) {}
  }
  return const [];
}
