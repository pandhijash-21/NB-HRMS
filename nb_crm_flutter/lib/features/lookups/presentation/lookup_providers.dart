import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/lookup_repository.dart';
import '../domain/lookup_models.dart';

final lookupRepositoryProvider = Provider<LookupRepository>((ref) {
  return LookupRepository(dioClient: ref.watch(dioClientProvider));
});

final lookupGroupsProvider =
    FutureProvider.autoDispose<List<LookupCategoryGroup>>((ref) async {
  return ref.watch(lookupRepositoryProvider).listGrouped(includeInactive: true);
});

final activeLookupsByCategoryProvider = FutureProvider.autoDispose
    .family<List<LookupOption>, String>((ref, category) async {
  return ref.watch(lookupRepositoryProvider).listByCategory(category);
});
