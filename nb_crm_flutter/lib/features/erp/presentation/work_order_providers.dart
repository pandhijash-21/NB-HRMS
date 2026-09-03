import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/work_order_repository.dart';
import '../domain/work_order_models.dart';

final workOrderRepositoryProvider = Provider<WorkOrderRepository>((ref) {
  return WorkOrderRepository(dioClient: ref.watch(dioClientProvider));
});

final workOrdersListProvider = FutureProvider.autoDispose<List<ErpWorkOrder>>((ref) {
  return ref.watch(workOrderRepositoryProvider).list();
});

final workOrderDetailProvider =
    FutureProvider.autoDispose.family<ErpWorkOrder, String>((ref, id) {
  return ref.watch(workOrderRepositoryProvider).getById(id);
});

final erpActivitiesProvider = FutureProvider.autoDispose<List<ErpActivity>>((ref) {
  return ref.watch(workOrderRepositoryProvider).listActivities();
});

final erpActivitiesAdminProvider = FutureProvider.autoDispose<List<ErpActivity>>((ref) {
  return ref.watch(workOrderRepositoryProvider).listActivitiesAdmin();
});

final erpContractorsProvider = FutureProvider.autoDispose<List<ErpContractor>>((ref) {
  return ref.watch(workOrderRepositoryProvider).listContractors();
});

final erpContractorsAdminProvider = FutureProvider.autoDispose<List<ErpContractor>>((ref) {
  return ref.watch(workOrderRepositoryProvider).listContractors(includeInactive: true);
});

final erpContractorDetailProvider =
    FutureProvider.autoDispose.family<ErpContractor, String>((ref, id) {
  return ref.watch(workOrderRepositoryProvider).getContractor(id);
});
