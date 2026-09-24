import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/support_repository.dart';
import '../domain/support_models.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(dioClient: ref.watch(dioClientProvider));
});

final supportCapabilitiesProvider =
    FutureProvider.autoDispose<SupportCapabilities>((ref) {
  return ref.watch(supportRepositoryProvider).capabilities();
});

final supportHandlersProvider =
    FutureProvider.autoDispose<List<SupportHandler>>((ref) {
  return ref.watch(supportRepositoryProvider).listHandlers();
});

final mySupportTicketsProvider =
    FutureProvider.autoDispose<List<SupportTicket>>((ref) {
  return ref.watch(supportRepositoryProvider).listMine();
});

final supportQueueProvider =
    FutureProvider.autoDispose.family<List<SupportTicket>, bool>((ref, includeClosed) {
  return ref.watch(supportRepositoryProvider).listQueue(includeClosed: includeClosed);
});

final supportTicketDetailProvider =
    FutureProvider.autoDispose.family<SupportTicket, String>((ref, id) {
  return ref.watch(supportRepositoryProvider).getById(id);
});
