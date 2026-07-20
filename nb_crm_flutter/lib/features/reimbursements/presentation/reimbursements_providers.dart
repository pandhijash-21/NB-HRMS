import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/reimbursements_repository.dart';
import '../domain/reimbursement_models.dart';

final reimbursementsRepositoryProvider = Provider<ReimbursementsRepository>((ref) {
  return ReimbursementsRepository(dioClient: ref.watch(dioClientProvider));
});

final myReimbursementsProvider = FutureProvider.autoDispose<List<ReimbursementClaim>>((ref) {
  return ref.watch(reimbursementsRepositoryProvider).listMine();
});

final pendingReimbursementsProvider = FutureProvider.autoDispose<List<ReimbursementClaim>>((ref) {
  return ref.watch(reimbursementsRepositoryProvider).listPending();
});

final adminReimbursementsProvider = FutureProvider.autoDispose<List<ReimbursementClaim>>((ref) {
  return ref.watch(reimbursementsRepositoryProvider).listAdmin();
});
