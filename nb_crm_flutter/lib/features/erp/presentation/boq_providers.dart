import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/boq_repository.dart';
import '../domain/boq_models.dart';
import '../domain/resource_models.dart';

final boqRepositoryProvider = Provider<BoqRepository>((ref) {
  return BoqRepository(dioClient: ref.watch(dioClientProvider));
});

final boqListProvider = FutureProvider.autoDispose<List<ErpBoq>>((ref) async {
  return ref.watch(boqRepositoryProvider).list();
});

final boqDetailProvider = FutureProvider.autoDispose.family<ErpBoq, String>((ref, id) async {
  return ref.watch(boqRepositoryProvider).getById(id);
});

final erpMaterialsProvider = FutureProvider.autoDispose<List<ErpMaterial>>((ref) async {
  return ref.watch(boqRepositoryProvider).listMaterials();
});

final erpMachinesProvider = FutureProvider.autoDispose<List<ErpMachine>>((ref) async {
  return ref.watch(boqRepositoryProvider).listMachines();
});

final erpLabourProvider = FutureProvider.autoDispose<List<ErpLabour>>((ref) async {
  return ref.watch(boqRepositoryProvider).listLabour();
});
