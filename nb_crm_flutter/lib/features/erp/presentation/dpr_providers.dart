import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/dpr_repository.dart';
import '../domain/dpr_models.dart';

final dprRepositoryProvider = Provider<DprRepository>((ref) {
  return DprRepository(dioClient: ref.watch(dioClientProvider));
});

final dprListProvider = FutureProvider.autoDispose<List<ErpDpr>>((ref) async {
  return ref.watch(dprRepositoryProvider).list();
});

final dprDetailProvider = FutureProvider.autoDispose.family<ErpDpr, String>((ref, id) async {
  return ref.watch(dprRepositoryProvider).getById(id);
});
