class OrgTreeNode {
  const OrgTreeNode({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    this.employeeId,
    this.role,
    this.designation,
    this.department,
    this.photoUrl,
    this.children = const [],
  });

  final String id;
  final String kind;
  final String title;
  final String? subtitle;
  final int? employeeId;
  final String? role;
  final String? designation;
  final String? department;
  final String? photoUrl;
  final List<OrgTreeNode> children;

  bool get isPerson => kind == 'employee' || kind == 'lead';

  OrgTreeNode copyWith({List<OrgTreeNode>? children}) {
    return OrgTreeNode(
      id: id,
      kind: kind,
      title: title,
      subtitle: subtitle,
      employeeId: employeeId,
      role: role,
      designation: designation,
      department: department,
      photoUrl: photoUrl,
      children: children ?? this.children,
    );
  }

  factory OrgTreeNode.fromJson(Map<String, dynamic> json) {
    final kids = json['children'];
    return OrgTreeNode(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'employee',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      employeeId: json['employeeId'] is int
          ? json['employeeId'] as int
          : int.tryParse('${json['employeeId'] ?? ''}'),
      role: json['role']?.toString(),
      designation: json['designation']?.toString(),
      department: json['department']?.toString(),
      photoUrl: json['photoUrl']?.toString(),
      children: kids is List
          ? kids
              .whereType<Map>()
              .map((e) => OrgTreeNode.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

class OrgTreeSnapshot {
  const OrgTreeSnapshot({
    required this.grouping,
    required this.generatedAt,
    required this.stats,
    required this.root,
  });

  final String grouping;
  final DateTime? generatedAt;
  final Map<String, int> stats;
  final OrgTreeNode root;

  factory OrgTreeSnapshot.fromJson(Map<String, dynamic> json) {
    final statsRaw = json['stats'];
    final stats = <String, int>{};
    if (statsRaw is Map) {
      for (final e in statsRaw.entries) {
        final n = e.value;
        stats[e.key.toString()] = n is int ? n : int.tryParse('$n') ?? 0;
      }
    }
    final rootRaw = json['root'];
    return OrgTreeSnapshot(
      grouping: json['grouping']?.toString() ?? 'DEPARTMENT_LEAD',
      generatedAt: json['generatedAt'] != null
          ? DateTime.tryParse(json['generatedAt'].toString())
          : null,
      stats: stats,
      root: rootRaw is Map
          ? OrgTreeNode.fromJson(Map<String, dynamic>.from(rootRaw))
          : const OrgTreeNode(id: 'org:root', kind: 'organization', title: 'Organization'),
    );
  }
}

class OrgTreeContact {
  const OrgTreeContact({
    required this.id,
    required this.moduleKey,
    required this.moduleName,
    this.employeeId,
    this.note,
    this.sortOrder = 0,
    this.employeeName,
    this.designation,
    this.department,
    this.photoUrl,
  });

  final String id;
  final String moduleKey;
  final String moduleName;
  final int? employeeId;
  final String? note;
  final int sortOrder;
  final String? employeeName;
  final String? designation;
  final String? department;
  final String? photoUrl;

  factory OrgTreeContact.fromJson(Map<String, dynamic> json) {
    return OrgTreeContact(
      id: json['id']?.toString() ?? '',
      moduleKey: json['moduleKey']?.toString() ?? '',
      moduleName: json['moduleName']?.toString() ?? '',
      employeeId: json['employeeId'] is int
          ? json['employeeId'] as int
          : int.tryParse('${json['employeeId'] ?? ''}'),
      note: json['note']?.toString(),
      sortOrder: json['sortOrder'] is int ? json['sortOrder'] as int : 0,
      employeeName: json['employeeName']?.toString(),
      designation: json['designation']?.toString(),
      department: json['department']?.toString(),
      photoUrl: json['photoUrl']?.toString(),
    );
  }
}

class OrgTreeSummary {
  const OrgTreeSummary({
    required this.id,
    required this.name,
    this.description,
    required this.grouping,
    required this.isActive,
    required this.snapshot,
    this.createdByName,
    this.createdAt,
    this.updatedAt,
    this.contacts = const [],
  });

  final String id;
  final String name;
  final String? description;
  final String grouping;
  final bool isActive;
  final OrgTreeSnapshot snapshot;
  final String? createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<OrgTreeContact> contacts;

  String get groupingLabel => grouping == 'REPORTING_CHAIN'
      ? 'Reporting chain'
      : 'Department → lead → team';

  factory OrgTreeSummary.fromJson(Map<String, dynamic> json) {
    final snap = json['snapshot'];
    return OrgTreeSummary(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Employee tree',
      description: json['description']?.toString(),
      grouping: json['grouping']?.toString() ?? 'DEPARTMENT_LEAD',
      isActive: json['isActive'] == true,
      snapshot: snap is Map
          ? OrgTreeSnapshot.fromJson(Map<String, dynamic>.from(snap))
          : OrgTreeSnapshot.fromJson(const {}),
      createdByName: json['createdByName']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      contacts: json['contacts'] is List
          ? (json['contacts'] as List)
              .whereType<Map>()
              .map((e) => OrgTreeContact.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}
