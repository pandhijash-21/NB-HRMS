import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/repository_repository.dart';
import '../domain/repository_models.dart';

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return CompanyRepository(dioClient: ref.watch(dioClientProvider));
});

final repositoryDocumentsProvider =
    FutureProvider.autoDispose<List<RepositoryDocument>>((ref) async {
  return ref.watch(companyRepositoryProvider).listDocuments();
});
