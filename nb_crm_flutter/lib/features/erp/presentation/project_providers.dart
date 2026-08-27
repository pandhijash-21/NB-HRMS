import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/project_repository.dart';
import '../domain/project_models.dart';
import '../domain/structure_models.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(dioClient: ref.watch(dioClientProvider));
});

final projectsListProvider = FutureProvider.autoDispose<List<ErpProject>>((ref) {
  return ref.watch(projectRepositoryProvider).list();
});

final projectDetailProvider =
    FutureProvider.autoDispose.family<ErpProject, String>((ref, id) {
  return ref.watch(projectRepositoryProvider).getById(id);
});

final projectEmployeesProvider =
    FutureProvider.autoDispose<List<ProjectEmployeeOption>>((ref) {
  return ref.watch(projectRepositoryProvider).listEmployees();
});

final projectNextNumberProvider = FutureProvider.autoDispose<String>((ref) async {
  final next = await ref.watch(projectRepositoryProvider).nextNumber();
  return next.displayId;
});

final projectTowersProvider =
    FutureProvider.autoDispose.family<List<ErpProjectTower>, String>((ref, projectId) {
  return ref.watch(projectRepositoryProvider).listTowers(projectId);
});

final projectTowerDetailProvider = FutureProvider.autoDispose
    .family<ErpProjectTower, ({String projectId, String towerId})>((ref, ids) {
  return ref.watch(projectRepositoryProvider).getTower(ids.projectId, ids.towerId);
});
