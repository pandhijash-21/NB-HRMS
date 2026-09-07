import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/tender_repository.dart';
import '../domain/tender_models.dart';

final tenderRepositoryProvider = Provider<TenderRepository>((ref) {
  return TenderRepository(dioClient: ref.watch(dioClientProvider));
});

final tenderListProvider = FutureProvider.autoDispose<List<ErpTender>>((ref) async {
  return ref.watch(tenderRepositoryProvider).list();
});

final tenderDetailProvider = FutureProvider.autoDispose.family<ErpTender, String>((ref, id) async {
  return ref.watch(tenderRepositoryProvider).getById(id);
});

final tenderApplicationListProvider =
    FutureProvider.autoDispose<List<ErpTenderApplication>>((ref) async {
  return ref.watch(tenderRepositoryProvider).listApplications();
});

final approvedTenderApplicationsProvider =
    FutureProvider.autoDispose.family<List<ErpTenderApplication>, String?>((ref, projectId) async {
  return ref.watch(tenderRepositoryProvider).listApplications(
    projectId: projectId,
    status: 'APPROVED',
  );
});

final allApprovedTenderApplicationsProvider =
    FutureProvider.autoDispose<List<ErpTenderApplication>>((ref) async {
  return ref.watch(tenderRepositoryProvider).listApplications(
    status: 'APPROVED',
  );
});

