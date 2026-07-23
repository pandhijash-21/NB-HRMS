import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../domain/repository_models.dart';

class CompanyRepository {
  const CompanyRepository({required DioClient dioClient}) : _dio = dioClient;

  final DioClient _dio;

  Future<List<RepositoryDocument>> listDocuments() {
    return _dio.getEnvelope<List<RepositoryDocument>>(
      'repository',
      parse: repositoryDocumentsFromJson,
    );
  }

  Future<RepositoryDocument> uploadDocument({
    required String title,
    String? description,
    String? category,
    required Uint8List bytes,
    required String filename,
  }) async {
    final multipart = MultipartFile.fromBytes(bytes, filename: filename);
    final response = await _dio.dio.post<Map<String, dynamic>>(
      'repository',
      data: FormData.fromMap({
        'title': title,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (category != null && category.trim().isNotEmpty) 'category': category.trim(),
        'file': multipart,
      }),
      options: Options(
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    final body = response.data;
    if (body == null || body['success'] != true) {
      throw Exception(body?['error'] ?? 'Upload failed');
    }
    final data = body['data'];
    if (data is! Map) throw const FormatException('Invalid upload response');
    return RepositoryDocument.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> deleteDocument(String id) async {
    await _dio.deleteEnvelope<void>(
      'repository/$id',
      parse: (_) {},
    );
  }
}
