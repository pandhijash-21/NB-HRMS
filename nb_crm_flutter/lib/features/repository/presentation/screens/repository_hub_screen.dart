import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/utils/open_stored_document.dart';
import '../../../../core/utils/platform_file_picker.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/repository_models.dart';
import '../repository_providers.dart';

const _categories = [
  ('POLICY', 'Policy'),
  ('HANDBOOK', 'Handbook'),
  ('FORM', 'Form'),
  ('OTHER', 'Other'),
];

class RepositoryHubScreen extends ConsumerWidget {
  const RepositoryHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final canManage = Permissions.canManageRepository(
      auth.permissions,
      auth.user?.role,
    );
    final docsAsync = ref.watch(repositoryDocumentsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Repository',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            letterSpacing: -0.5,
          ),
        ),
        leading: const AppBackButton(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
            height: 1.5,
          ),
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showUploadDialog(context, ref),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Upload'),
              backgroundColor: const Color(0xFF0369a1),
              foregroundColor: Colors.white,
            )
          : null,
      body: docsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF0369a1)),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(repositoryDocumentsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (docs) {
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 56,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No documents yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : const Color(0xFF212F3D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      canManage
                          ? 'Upload company policies, handbooks, and forms for everyone.'
                          : 'Company policies and documents will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(repositoryDocumentsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final doc = docs[index];
                return _DocumentCard(
                  doc: doc,
                  canManage: canManage,
                  onOpen: () => openStoredDocument(
                    context,
                    url: doc.fileUrl,
                    fileName: doc.fileName,
                    title: doc.title,
                  ),
                  onDelete: () => _confirmDelete(context, ref, doc),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    RepositoryDocument doc,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove document?'),
        content: Text('“${doc.title}” will be hidden from the repository.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await ref.read(companyRepositoryProvider).deleteDocument(doc.id);
      ref.invalidate(repositoryDocumentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document removed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showUploadDialog(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'POLICY';
    PickedFileData? picked;
    var uploading = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Upload document'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final c in _categories)
                        DropdownMenuItem(value: c.$1, child: Text(c.$2)),
                    ],
                    onChanged: uploading
                        ? null
                        : (v) {
                            if (v != null) setLocal(() => category = v);
                          },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: uploading
                        ? null
                        : () async {
                            final file = await pickFileFromDevice(
                              imagesOnly: false,
                              extensions: const ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
                            );
                            if (file != null) setLocal(() => picked = file);
                          },
                    icon: const Icon(Icons.attach_file_rounded),
                    label: Text(
                      picked == null
                          ? 'Choose file (PDF, Word, image)'
                          : picked!.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: uploading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: uploading
                  ? null
                  : () async {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Title is required')),
                        );
                        return;
                      }
                      if (picked == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please choose a file')),
                        );
                        return;
                      }
                      setLocal(() => uploading = true);
                      try {
                        await ref.read(companyRepositoryProvider).uploadDocument(
                              title: title,
                              description: descCtrl.text.trim(),
                              category: category,
                              bytes: picked!.bytes,
                              filename: picked!.name,
                            );
                        ref.invalidate(repositoryDocumentsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Document uploaded')),
                          );
                        }
                      } catch (e) {
                        setLocal(() => uploading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Upload failed: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Upload'),
            ),
          ],
        ),
      ),
    );

    titleCtrl.dispose();
    descCtrl.dispose();
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.doc,
    required this.canManage,
    required this.onOpen,
    required this.onDelete,
  });

  final RepositoryDocument doc;
  final bool canManage;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? const Color(0xFFC5A059).withOpacity(0.15)
                  : const Color(0xFFCFD8DC),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0369a1).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _iconFor(doc),
                  color: const Color(0xFF0369a1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0369a1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            doc.categoryLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0369a1),
                            ),
                          ),
                        ),
                        if (doc.fileName != null && doc.fileName!.isNotEmpty)
                          Text(
                            doc.fileName!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                      ],
                    ),
                    if (doc.description != null && doc.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        doc.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (canManage)
                IconButton(
                  tooltip: 'Remove',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(RepositoryDocument doc) {
    final name = (doc.fileName ?? doc.mimeType ?? '').toLowerCase();
    if (name.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (name.contains('doc')) return Icons.description_rounded;
    if (name.contains('png') || name.contains('jpg') || name.contains('jpeg') || name.contains('image')) {
      return Icons.image_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }
}
