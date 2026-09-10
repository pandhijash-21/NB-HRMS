import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/platform_repository.dart';
import '../domain/platform_models.dart';

final platformRepositoryProvider = Provider<PlatformRepository>((ref) {
  return PlatformRepository(dioClient: ref.watch(dioClientProvider));
});

final platformStatsProvider = FutureProvider.autoDispose<PlatformStats>((ref) async {
  final repo = ref.watch(platformRepositoryProvider);
  return repo.getStats();
});

final platformCompaniesProvider = FutureProvider.autoDispose<List<ClientCompany>>((ref) async {
  final repo = ref.watch(platformRepositoryProvider);
  return repo.listCompanies();
});

final platformAdminsProvider = FutureProvider.autoDispose<List<PlatformAdminUser>>((ref) async {
  final repo = ref.watch(platformRepositoryProvider);
  return repo.listAdmins();
});

final platformTrashProvider = FutureProvider.autoDispose<PlatformTrashData>((ref) async {
  final repo = ref.watch(platformRepositoryProvider);
  return repo.getTrash();
});

