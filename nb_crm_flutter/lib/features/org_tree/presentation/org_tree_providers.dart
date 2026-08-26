import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/org_tree_repository.dart';
import '../domain/org_tree_models.dart';

final orgTreeRepositoryProvider = Provider<OrgTreeRepository>((ref) {
  return OrgTreeRepository(dioClient: ref.watch(dioClientProvider));
});

final orgTreeListProvider =
    FutureProvider.autoDispose<List<OrgTreeSummary>>((ref) {
  return ref.watch(orgTreeRepositoryProvider).list();
});

final activeOrgTreeProvider =
    FutureProvider.autoDispose<OrgTreeSummary?>((ref) {
  return ref.watch(orgTreeRepositoryProvider).active();
});

class SelectedOrgTreeId extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

final selectedOrgTreeIdProvider =
    NotifierProvider<SelectedOrgTreeId, String?>(SelectedOrgTreeId.new);

final selectedOrgTreeProvider =
    FutureProvider.autoDispose<OrgTreeSummary?>((ref) async {
  final id = ref.watch(selectedOrgTreeIdProvider);
  final repo = ref.watch(orgTreeRepositoryProvider);
  if (id != null && id.isNotEmpty) {
    return repo.getById(id);
  }
  return repo.active();
});
