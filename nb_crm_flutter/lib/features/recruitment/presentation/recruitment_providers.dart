import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/recruitment_repository.dart';
import '../domain/recruitment_models.dart';

final recruitmentRepositoryProvider = Provider<RecruitmentRepository>((ref) {
  return RecruitmentRepository(dioClient: ref.watch(dioClientProvider));
});

final vacanciesProvider = FutureProvider.autoDispose<List<JobRequirement>>((ref) async {
  return ref.watch(recruitmentRepositoryProvider).listVacancies();
});

final adminRequirementsProvider =
    FutureProvider.autoDispose<List<JobRequirement>>((ref) async {
  return ref.watch(recruitmentRepositoryProvider).listRequirements();
});

final candidatesProvider =
    FutureProvider.autoDispose.family<List<RecruitmentCandidate>, String?>((ref, requirementId) async {
  return ref.watch(recruitmentRepositoryProvider).listCandidates(
        requirementId: requirementId,
      );
});

final myInterviewsProvider = FutureProvider.autoDispose<List<MyInterviewItem>>((ref) async {
  return ref.watch(recruitmentRepositoryProvider).listMyInterviews();
});

final candidateDetailProvider =
    FutureProvider.autoDispose.family<RecruitmentCandidate, String>((ref, id) async {
  return ref.watch(recruitmentRepositoryProvider).getCandidate(id);
});
