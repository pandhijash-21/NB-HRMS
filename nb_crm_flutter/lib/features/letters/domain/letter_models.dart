class LetterTemplate {
  const LetterTemplate({
    required this.id,
    required this.key,
    required this.name,
    this.description,
    required this.templateHtml,
    this.logoUrl,
    this.placeholders,
    required this.isActive,
  });

  final String id;
  final String key;
  final String name;
  final String? description;
  final String templateHtml;
  final String? logoUrl;
  final dynamic placeholders;
  final bool isActive;

  factory LetterTemplate.fromJson(Map<String, dynamic> json) {
    return LetterTemplate(
      id: json['id']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      templateHtml: json['templateHtml']?.toString() ?? json['template_html']?.toString() ?? '',
      logoUrl: json['logoUrl']?.toString() ?? json['logo_url']?.toString(),
      placeholders: json['placeholders'],
      isActive: json['isActive'] == true || json['is_active'] == true,
    );
  }
}

enum LetterDocumentStatus {
  DRAFT,
  FINAL;

  static LetterDocumentStatus fromString(String? s) {
    final v = (s ?? '').toUpperCase();
    return v == 'FINAL' ? LetterDocumentStatus.FINAL : LetterDocumentStatus.DRAFT;
  }
}

class LetterDocument {
  const LetterDocument({
    required this.id,
    required this.employeeId,
    required this.templateId,
    required this.status,
    required this.contentHtml,
    this.template,
  });

  final String id;
  final int employeeId;
  final String templateId;
  final LetterDocumentStatus status;
  final String contentHtml;
  final LetterTemplate? template;

  factory LetterDocument.fromJson(Map<String, dynamic> json) {
    return LetterDocument(
      id: json['id']?.toString() ?? '',
      employeeId: json['employeeId'] is int
          ? json['employeeId'] as int
          : int.tryParse(json['employeeId']?.toString() ?? '') ?? 0,
      templateId: json['templateId']?.toString() ?? json['template_id']?.toString() ?? '',
      status: LetterDocumentStatus.fromString(json['status']?.toString()),
      contentHtml: json['contentHtml']?.toString() ?? json['content_html']?.toString() ?? '',
      template: json['template'] is Map
          ? LetterTemplate.fromJson(Map<String, dynamic>.from(json['template'] as Map))
          : null,
    );
  }
}

