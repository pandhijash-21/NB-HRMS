import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/org_repository.dart';
import '../domain/org_models.dart';

final orgRepositoryProvider = Provider<OrgRepository>((ref) {
  return OrgRepository(dioClient: ref.watch(dioClientProvider));
});

final institutesListProvider =
    FutureProvider.autoDispose<List<Institute>>((ref) async {
  return ref.watch(orgRepositoryProvider).listInstitutes(includeInactive: true);
});

final instituteMembersProvider = FutureProvider.autoDispose
    .family<InstituteMembersPayload, String>((ref, instituteId) async {
  return ref.watch(orgRepositoryProvider).getInstituteMembers(instituteId);
});

final jobDesignationsProvider =
    FutureProvider.autoDispose<List<Designation>>((ref) async {
  return ref
      .watch(orgRepositoryProvider)
      .listDesignations(isAlias: false, includeInactive: true);
});

final positionDesignationsProvider =
    FutureProvider.autoDispose<List<Designation>>((ref) async {
  return ref
      .watch(orgRepositoryProvider)
      .listDesignations(isAlias: true, includeInactive: true);
});

final positionsListProvider =
    FutureProvider.autoDispose<List<Position>>((ref) async {
  return ref.watch(orgRepositoryProvider).listPositions();
});

final positionSlotsProvider =
    FutureProvider.autoDispose<List<PositionSlot>>((ref) async {
  return ref.watch(orgRepositoryProvider).listPositionSlots();
});

final activeInstitutesProvider =
    FutureProvider.autoDispose<List<Institute>>((ref) async {
  final all = await ref.watch(orgRepositoryProvider).listInstitutes();
  return all.where((i) => i.isActive).toList();
});
