import '../../../core/network/dio_client.dart';
import '../domain/lookup_models.dart';

class LookupRepository {
  LookupRepository({required DioClient dioClient}) : _dio = dioClient;

  final DioClient _dio;
  final Map<String, List<LookupOption>> _cache = {};

  List<LookupOption> getCached(String category) => _cache[category] ?? const [];
  void clearCache() => _cache.clear();

  Future<List<LookupCategoryGroup>> listGrouped({bool includeInactive = false}) async {
    return _dio.getEnvelope<List<LookupCategoryGroup>>(
      includeInactive ? 'admin/lookups' : 'lookups',
      queryParameters: includeInactive ? {'includeInactive': 'true'} : null,
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid lookups response');
        }
        return raw
            .map((e) => LookupCategoryGroup.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<List<LookupOption>> listByCategory(
    String category, {
    bool includeInactive = false,
  }) async {
    if (!includeInactive && _cache.containsKey(category)) {
      return _cache[category]!;
    }
    final result = await _dio.getEnvelope<List<LookupOption>>(
      includeInactive ? 'admin/lookups' : 'lookups',
      queryParameters: {
        'category': category,
        if (includeInactive) 'includeInactive': 'true',
      },
      parse: (raw) {
        if (raw is! List) {
          throw const FormatException('Invalid lookup options response');
        }
        return raw
            .map((e) => LookupOption.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
    if (!includeInactive) {
      _cache[category] = result;
    }
    return result;
  }

  Future<LookupOption> create({
    required String category,
    required String code,
    required String label,
    int? sortOrder,
  }) async {
    return _dio.postEnvelope<LookupOption>(
      'admin/lookups',
      data: {
        'category': category,
        'code': code,
        'label': label,
        if (sortOrder != null) 'sortOrder': sortOrder,
      },
      parse: (raw) => LookupOption.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<LookupOption> update(
    String id, {
    String? code,
    String? label,
    bool? isActive,
    int? sortOrder,
  }) async {
    return _dio.patchEnvelope<LookupOption>(
      'admin/lookups/$id',
      data: {
        if (code != null) 'code': code,
        if (label != null) 'label': label,
        if (isActive != null) 'isActive': isActive,
        if (sortOrder != null) 'sortOrder': sortOrder,
      },
      parse: (raw) => LookupOption.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> delete(String id) async {
    await _dio.deleteEnvelope<void>(
      'admin/lookups/$id',
      parse: (_) {},
    );
  }
}
