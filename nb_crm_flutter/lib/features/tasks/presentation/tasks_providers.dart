import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/tasks_repository.dart';
import '../domain/task_models.dart';

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository(dioClient: ref.watch(dioClientProvider));
});

final taskSummaryProvider = FutureProvider.autoDispose<TaskSummary>((ref) {
  return ref.watch(tasksRepositoryProvider).summary();
});

final taskReporteesProvider = FutureProvider.autoDispose<List<TaskReportee>>((ref) {
  return ref.watch(tasksRepositoryProvider).listReportees();
});

final myTasksProvider = FutureProvider.autoDispose<List<WorkTask>>((ref) {
  return ref.watch(tasksRepositoryProvider).list(filter: 'all');
});
