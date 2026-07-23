Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

class RepositoryDocument {
  const RepositoryDocument({
    required this.id,
    required this.title,
    this.description,
    this.category,
    required this.fileUrl,
    this.fileName,
    this.mimeType,
    this.fileSize,
    this.uploadedBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final String? category;
  final String fileUrl;
  final String? fileName;
  final String? mimeType;
  final int? fileSize;
  final String? uploadedBy;
  final String? createdAt;
  final String? updatedAt;

  factory RepositoryDocument.fromJson(Map<String, dynamic> json) {
    return RepositoryDocument(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description'] as String?,
      category: json['category'] as String?,
      fileUrl: json['fileUrl']?.toString() ?? '',
      fileName: json['fileName'] as String?,
      mimeType: json['mimeType'] as String?,
      fileSize: _asInt(json['fileSize']),
      uploadedBy: json['uploadedBy'] as String?,
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  String get categoryLabel {
    switch ((category ?? '').toUpperCase()) {
      case 'POLICY':
        return 'Policy';
      case 'HANDBOOK':
        return 'Handbook';
      case 'FORM':
        return 'Form';
      case 'OTHER':
        return 'Other';
      default:
        return category?.trim().isNotEmpty == true ? category! : 'Document';
    }
  }
}

/// Convenience for parsing list responses.
List<RepositoryDocument> repositoryDocumentsFromJson(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .map(_asMap)
      .whereType<Map<String, dynamic>>()
      .map(RepositoryDocument.fromJson)
      .toList();
}
