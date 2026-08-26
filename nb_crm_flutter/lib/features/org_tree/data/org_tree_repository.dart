import '../../../core/network/dio_client.dart';
import '../domain/org_tree_models.dart';

class OrgTreeRepository {
  const OrgTreeRepository({required DioClient dioClient}) : _dio = dioClient;

  final DioClient _dio;

  Future<List<OrgTreeSummary>> list() {
    return _dio.getEnvelope<List<OrgTreeSummary>>(
      'org-tree',
      parse: (raw) {
        if (raw is! List) throw const FormatException('Invalid org tree list');
        return raw
            .whereType<Map>()
            .map((e) => OrgTreeSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
    );
  }

  Future<OrgTreeSummary?> active() {
    return _dio.getEnvelope<OrgTreeSummary?>(
      'org-tree/active',
      parse: (raw) {
        if (raw == null) return null;
        if (raw is! Map) throw const FormatException('Invalid active org tree');
        return OrgTreeSummary.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<OrgTreeSummary> getById(String id) {
    return _dio.getEnvelope<OrgTreeSummary>(
      'org-tree/$id',
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid org tree');
        return OrgTreeSummary.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<OrgTreeSnapshot> preview({String grouping = 'DEPARTMENT_LEAD'}) {
    return _dio.getEnvelope<OrgTreeSnapshot>(
      'org-tree/preview',
      queryParameters: {'grouping': grouping},
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid preview');
        return OrgTreeSnapshot.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<OrgTreeSummary> create({
    required String name,
    String? description,
    String grouping = 'DEPARTMENT_LEAD',
    bool publish = true,
  }) {
    return _dio.postEnvelope<OrgTreeSummary>(
      'org-tree',
      data: {
        'name': name,
        if (description != null) 'description': description,
        'grouping': grouping,
        'publish': publish,
      },
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid create response');
        return OrgTreeSummary.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<OrgTreeSummary> regenerate(String id, {String? grouping}) {
    return _dio.postEnvelope<OrgTreeSummary>(
      'org-tree/$id/regenerate',
      data: {if (grouping != null) 'grouping': grouping},
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid regenerate response');
        return OrgTreeSummary.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<OrgTreeSummary> update(
    String id, {
    String? name,
    String? description,
    bool? isActive,
  }) {
    return _dio.patchEnvelope<OrgTreeSummary>(
      'org-tree/$id',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (isActive != null) 'isActive': isActive,
      },
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid update response');
        return OrgTreeSummary.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }

  Future<void> delete(String id) {
    return _dio.deleteEnvelope<void>(
      'org-tree/$id',
      parse: (_) {},
    );
  }

  Future<OrgTreeSummary> setContacts(
    String id,
    List<Map<String, dynamic>> contacts,
  ) {
    return _dio.putEnvelope<OrgTreeSummary>(
      'org-tree/$id/contacts',
      data: {'contacts': contacts},
      parse: (raw) {
        if (raw is! Map) throw const FormatException('Invalid contacts response');
        return OrgTreeSummary.fromJson(Map<String, dynamic>.from(raw));
      },
    );
  }
}
