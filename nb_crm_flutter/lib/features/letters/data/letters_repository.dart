import '../../../core/network/dio_client.dart';
import '../domain/letter_models.dart';

class LettersRepository {
  const LettersRepository({required DioClient dioClient}) : _dio = dioClient;

  final DioClient _dio;

  Future<List<LetterTemplate>> listTemplates() async {
    return _dio.getEnvelope<List<LetterTemplate>>(
      'letters/templates',
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid templates response');
        }
        return raw
            .map((e) => LetterTemplate.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<List<LetterDocument>> getEmployeeDocuments(int employeeId) async {
    return _dio.getEnvelope<List<LetterDocument>>(
      'letters/employees/$employeeId/documents',
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid documents response');
        }
        return raw
            .map((e) => LetterDocument.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<LetterDocument> createOrUpdateDraft({
    required int employeeId,
    required String templateId,
  }) async {
    return _dio.postEnvelope<LetterDocument>(
      'letters/employees/$employeeId/templates/$templateId/draft',
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid draft response');
        return LetterDocument.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<LetterDocument> updateDraftContent({
    required String documentId,
    required String contentHtml,
  }) async {
    return _dio.patchEnvelope<LetterDocument>(
      'letters/documents/$documentId',
      data: {'contentHtml': contentHtml},
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid draft update response');
        return LetterDocument.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<LetterDocument> finalizeDraft({
    required String draftId,
  }) async {
    return _dio.postEnvelope<LetterDocument>(
      'letters/documents/$draftId/finalize',
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid finalize response');
        return LetterDocument.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<void> deleteDocument({required String documentId}) async {
    await _dio.postEnvelope<Map<String, dynamic>>(
      'letters/documents/$documentId/delete',
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid delete response');
        return Map<String, dynamic>.from(raw);
      },
    );
  }

  Future<LetterDocument> createCustomDraft({
    required int employeeId,
    String? title,
  }) async {
    return _dio.postEnvelope<LetterDocument>(
      'letters/employees/$employeeId/custom-draft',
      data: {'title': title ?? 'Custom Letter'},
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid custom draft response');
        return LetterDocument.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<LetterTemplate> upsertTemplate({
    String? id,
    required String key,
    required String name,
    String? description,
    required String templateHtml,
    String? logoUrl,
    dynamic placeholders,
  }) async {
    final payload = <String, dynamic>{
      'id': id,
      'key': key,
      'name': name,
      'description': description,
      'templateHtml': templateHtml,
      'logoUrl': logoUrl,
      'placeholders': placeholders,
    };
    final cleaned = payload..removeWhere((k, v) => v == null);

    return _dio.postEnvelope<LetterTemplate>(
      'letters/templates',
      data: cleaned,
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid template response');
        return LetterTemplate.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }
}

