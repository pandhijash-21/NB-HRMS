import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../domain/earth_models.dart';

class EarthRepository {
  const EarthRepository({required DioClient dioClient}) : _dio = dioClient;

  final DioClient _dio;

  Future<List<EarthProperty>> list({
    String? kind,
    String? status,
    String? q,
  }) {
    return _dio.getEnvelope<List<EarthProperty>>(
      'earth/properties',
      queryParameters: {
        if (kind != null && kind.isNotEmpty) 'kind': kind,
        if (status != null && status.isNotEmpty) 'status': status,
        if (q != null && q.isNotEmpty) 'q': q,
      },
      parse: (raw) {
        if (raw is! List) throw const FormatException('Invalid earth properties');
        return raw
            .map((e) => EarthProperty.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<EarthProperty> getById(String id) {
    return _dio.getEnvelope(
      'earth/properties/$id',
      parse: (raw) => EarthProperty.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<EarthProperty> create(Map<String, dynamic> body) {
    return _dio.postEnvelope(
      'earth/properties',
      data: body,
      parse: (raw) => EarthProperty.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<EarthProperty> update(String id, Map<String, dynamic> body) {
    return _dio.patchEnvelope(
      'earth/properties/$id',
      data: body,
      parse: (raw) => EarthProperty.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> remove(String id) async {
    await _dio.deleteEnvelope('earth/properties/$id', parse: (_) => true);
  }

  Future<EarthProperty> addPrice(String id, Map<String, dynamic> body) {
    return _dio.postEnvelope(
      'earth/properties/$id/prices',
      data: body,
      parse: (raw) => EarthProperty.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<EarthDashboard> dashboard() {
    return _dio.getEnvelope(
      'earth/dashboard',
      parse: (raw) => EarthDashboard.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<List<EarthGeocodeHit>> geocode(String query) {
    return _dio.getEnvelope(
      'earth/geocode',
      queryParameters: {'q': query},
      parse: (raw) {
        if (raw is! List) return <EarthGeocodeHit>[];
        return raw
            .map((e) => EarthGeocodeHit.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<EarthGeocodeHit> reverse(double lat, double lng) {
    return _dio.getEnvelope(
      'earth/reverse',
      queryParameters: {'lat': lat, 'lng': lng},
      parse: (raw) => EarthGeocodeHit.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<({String url, String? fileName})> uploadImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    final multipart = MultipartFile.fromBytes(bytes, filename: filename);
    final response = await _dio.dio.post<Map<String, dynamic>>(
      'earth/upload',
      data: FormData.fromMap({'file': multipart}),
    );
    final body = response.data;
    if (body == null || body['success'] != true) {
      throw Exception(body?['error'] ?? 'Upload failed');
    }
    final data = Map<String, dynamic>.from(body['data'] as Map);
    return (
      url: data['url'] as String,
      fileName: data['fileName']?.toString(),
    );
  }
}
