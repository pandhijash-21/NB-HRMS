class LookupOption {
  const LookupOption({
    required this.id,
    required this.category,
    required this.code,
    required this.label,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String category;
  final String code;
  final String label;
  final bool isActive;
  final int sortOrder;

  factory LookupOption.fromJson(Map<String, dynamic> json) {
    return LookupOption(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      isActive: json['isActive'] ?? json['is_active'] ?? true,
      sortOrder: (json['sortOrder'] ?? json['sort_order'] ?? 0) is int
          ? (json['sortOrder'] ?? json['sort_order'] ?? 0) as int
          : int.tryParse('${json['sortOrder'] ?? json['sort_order']}') ?? 0,
    );
  }
}

class LookupCategoryGroup {
  const LookupCategoryGroup({
    required this.key,
    required this.label,
    this.description,
    this.options = const [],
  });

  final String key;
  final String label;
  final String? description;
  final List<LookupOption> options;

  factory LookupCategoryGroup.fromJson(Map<String, dynamic> json) {
    final opts = json['options'];
    return LookupCategoryGroup(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString(),
      options: opts is List
          ? opts
              .map((e) => LookupOption.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
    );
  }
}
