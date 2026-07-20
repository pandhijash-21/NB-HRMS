import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/letters_repository.dart';
import '../domain/letter_models.dart';

class CreateDraftArgs {
  const CreateDraftArgs({required this.employeeId, required this.templateId});
  final int employeeId;
  final String templateId;
}

class UpdateDraftArgs {
  const UpdateDraftArgs({required this.documentId, required this.contentHtml});
  final String documentId;
  final String contentHtml;
}

class FinalizeDraftArgs {
  const FinalizeDraftArgs({required this.draftId});
  final String draftId;
}

class UpsertLetterTemplateArgs {
  const UpsertLetterTemplateArgs({
    this.id,
    required this.key,
    required this.name,
    this.description,
    required this.templateHtml,
    this.logoUrl,
    this.placeholders,
  });

  final String? id;
  final String key;
  final String name;
  final String? description;
  final String templateHtml;
  final String? logoUrl;
  final dynamic placeholders;
}

final lettersRepositoryProvider = Provider<LettersRepository>((ref) {
  return LettersRepository(dioClient: ref.watch(dioClientProvider));
});

final letterTemplatesProvider =
    FutureProvider.autoDispose<List<LetterTemplate>>((ref) async {
  return ref.watch(lettersRepositoryProvider).listTemplates();
});

final employeeLetterDocumentsProvider =
    FutureProvider.family.autoDispose<List<LetterDocument>, int>(
  (ref, employeeId) async {
    return ref.watch(lettersRepositoryProvider).getEmployeeDocuments(employeeId);
  },
);

final createDraftLetterProvider =
    FutureProvider.family.autoDispose<LetterDocument, CreateDraftArgs>(
  (ref, args) async {
    final repo = ref.watch(lettersRepositoryProvider);
    return repo.createOrUpdateDraft(employeeId: args.employeeId, templateId: args.templateId);
  },
);

final updateDraftLetterContentProvider =
    FutureProvider.family.autoDispose<LetterDocument, UpdateDraftArgs>(
  (ref, args) async {
    final repo = ref.watch(lettersRepositoryProvider);
    return repo.updateDraftContent(documentId: args.documentId, contentHtml: args.contentHtml);
  },
);

final finalizeDraftLetterProvider =
    FutureProvider.family.autoDispose<LetterDocument, FinalizeDraftArgs>(
  (ref, args) async {
    final repo = ref.watch(lettersRepositoryProvider);
    return repo.finalizeDraft(draftId: args.draftId);
  },
);

final upsertLetterTemplateProvider =
    FutureProvider.family.autoDispose<LetterTemplate, UpsertLetterTemplateArgs>((ref, args) async {
  final repo = ref.watch(lettersRepositoryProvider);
  return repo.upsertTemplate(
    id: args.id,
    key: args.key,
    name: args.name,
    description: args.description,
    templateHtml: args.templateHtml,
    logoUrl: args.logoUrl,
    placeholders: args.placeholders,
  );
});

