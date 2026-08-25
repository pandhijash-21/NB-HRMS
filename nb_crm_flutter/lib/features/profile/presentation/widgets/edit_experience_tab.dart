import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/platform_file_picker.dart';
import '../../domain/experience_models.dart';
import '../profile_notifier.dart';

class EditExperienceTab extends ConsumerStatefulWidget {
  const EditExperienceTab({
    super.key,
    required this.employeeId,
    this.canEdit = true,
  });

  final int employeeId;
  final bool canEdit;

  @override
  ConsumerState<EditExperienceTab> createState() => _EditExperienceTabState();
}

class _EditExperienceTabState extends ConsumerState<EditExperienceTab> {
  late Future<List<EmployeeExperience>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref
        .read(profileRepositoryProvider)
        .listExperiences(widget.employeeId);
  }

  void _refresh() => setState(_reload);

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  Future<void> _edit([EmployeeExperience? current]) async {
    final designation = TextEditingController(text: current?.designation);
    final organization = TextEditingController(text: current?.organizationName);
    final description = TextEditingController(text: current?.jobDescription);
    final salary = TextEditingController(
      text: current?.lastSalary?.toStringAsFixed(2) ?? '',
    );
    var type = current?.type ?? 'INDUSTRY';
    var fromDate = current?.fromDate ?? DateTime.now();
    var toDate = current?.toDate ?? DateTime.now();
    var letterUrl = current?.experienceLetterUrl;
    var paycheckUrl = current?.lastPaycheckUrl;
    var recommendations =
        List<String>.from(current?.recommendationLetters ?? const []);
    PickedFileData? pendingLetter;
    PickedFileData? pendingPaycheck;
    final pendingRecommendations = <PickedFileData>[];
    final formKey = GlobalKey<FormState>();

    Future<String> uploadDoc({
      required String kebabType,
      required String experienceId,
      required PickedFileData file,
    }) {
      return ref.read(profileRepositoryProvider).uploadFile(
            employeeId: widget.employeeId,
            kebabType: kebabType,
            bytes: file.bytes,
            filename: file.name,
            experienceId: experienceId,
          );
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickDoc({
            required void Function(PickedFileData file) onPicked,
          }) async {
            try {
              final picked = await pickFileFromDevice(
                imagesOnly: false,
                extensions: const ['pdf', 'jpg', 'jpeg', 'png'],
              );
              if (picked != null) onPicked(picked);
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not open file picker: $e'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }

          Future<void> attachExisting({
            required String kebabType,
            required void Function(String url) onUrl,
          }) async {
            if (current == null) return;
            await pickDoc(
              onPicked: (file) async {
                try {
                  final url = await uploadDoc(
                    kebabType: kebabType,
                    experienceId: current.id,
                    file: file,
                  );
                  final patch = <String, dynamic>{};
                  if (kebabType == 'experience-letter') {
                    patch['experienceLetterUrl'] = url;
                  } else if (kebabType == 'last-paycheck') {
                    patch['lastPaycheckUrl'] = url;
                  } else if (kebabType == 'recommendation') {
                    patch['recommendationLetters'] = [...recommendations, url];
                  }
                  await ref.read(profileRepositoryProvider).updateExperience(
                        widget.employeeId,
                        current.id,
                        patch,
                      );
                  onUrl(url);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Upload failed: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
            );
          }

          Widget docTile({
            required String label,
            required bool filled,
            required String? subtitle,
            required VoidCallback onTap,
          }) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: widget.canEdit ? onTap : null,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: filled
                          ? AppColors.border
                          : Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        filled
                            ? Icons.check_circle
                            : Icons.cloud_upload_outlined,
                        color: filled
                            ? Colors.green
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              filled
                                  ? (subtitle ?? 'Uploaded — tap to replace')
                                  : (widget.canEdit
                                      ? 'Click to upload (PDF/Image)'
                                      : 'Not uploaded'),
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return AlertDialog(
            title: Text(current == null ? 'Add Experience' : 'Edit Experience'),
            content: SizedBox(
              width: 560,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: const [
                          'TEACHING',
                          'INDUSTRY',
                          'RESEARCH',
                          'ADMINISTRATIVE',
                          'CONSULTANCY',
                          'OTHER',
                        ]
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: widget.canEdit
                            ? (v) => setDialogState(() => type = v ?? type)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: designation,
                        readOnly: !widget.canEdit,
                        decoration: const InputDecoration(
                          labelText: 'Designation *',
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: organization,
                        readOnly: !widget.canEdit,
                        decoration: const InputDecoration(
                          labelText: 'Organization *',
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_month_outlined),
                              label: Text('From: ${_date(fromDate)}'),
                              onPressed: !widget.canEdit
                                  ? null
                                  : () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: fromDate,
                                        firstDate: DateTime(1950),
                                        lastDate: DateTime.now(),
                                      );
                                      if (picked != null) {
                                        setDialogState(() => fromDate = picked);
                                      }
                                    },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_month_outlined),
                              label: Text('To: ${_date(toDate)}'),
                              onPressed: !widget.canEdit
                                  ? null
                                  : () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: toDate,
                                        firstDate: fromDate,
                                        lastDate: DateTime.now(),
                                      );
                                      if (picked != null) {
                                        setDialogState(() => toDate = picked);
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: salary,
                        readOnly: !widget.canEdit,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Last salary',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: description,
                        readOnly: !widget.canEdit,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Job description',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Documents',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      docTile(
                        label: 'Experience Letter',
                        filled: letterUrl != null || pendingLetter != null,
                        subtitle: pendingLetter?.name,
                        onTap: () async {
                          if (current != null) {
                            await attachExisting(
                              kebabType: 'experience-letter',
                              onUrl: (url) =>
                                  setDialogState(() => letterUrl = url),
                            );
                          } else {
                            await pickDoc(
                              onPicked: (file) =>
                                  setDialogState(() => pendingLetter = file),
                            );
                          }
                        },
                      ),
                      docTile(
                        label: 'Last Paycheck',
                        filled: paycheckUrl != null || pendingPaycheck != null,
                        subtitle: pendingPaycheck?.name,
                        onTap: () async {
                          if (current != null) {
                            await attachExisting(
                              kebabType: 'last-paycheck',
                              onUrl: (url) =>
                                  setDialogState(() => paycheckUrl = url),
                            );
                          } else {
                            await pickDoc(
                              onPicked: (file) =>
                                  setDialogState(() => pendingPaycheck = file),
                            );
                          }
                        },
                      ),
                      docTile(
                        label: 'Recommendation Letters',
                        filled: recommendations.isNotEmpty ||
                            pendingRecommendations.isNotEmpty,
                        subtitle: recommendations.isNotEmpty
                            ? '${recommendations.length} file(s)'
                            : pendingRecommendations.isNotEmpty
                                ? '${pendingRecommendations.length} selected'
                                : null,
                        onTap: () async {
                          if (current != null) {
                            await attachExisting(
                              kebabType: 'recommendation',
                              onUrl: (url) => setDialogState(
                                () => recommendations = [...recommendations, url],
                              ),
                            );
                          } else {
                            await pickDoc(
                              onPicked: (file) => setDialogState(
                                () => pendingRecommendations.add(file),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              if (widget.canEdit)
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    if (toDate.isBefore(fromDate)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('To date cannot be before from date'),
                        ),
                      );
                      return;
                    }
                    final data = <String, dynamic>{
                      'type': type,
                      'designation': designation.text.trim(),
                      'organizationName': organization.text.trim(),
                      'fromDate': fromDate.toIso8601String(),
                      'toDate': toDate.toIso8601String(),
                      'jobDescription': description.text.trim().isEmpty
                          ? null
                          : description.text.trim(),
                      'lastSalary': salary.text.trim().isEmpty
                          ? null
                          : double.tryParse(salary.text.trim()),
                      if (letterUrl != null) 'experienceLetterUrl': letterUrl,
                      if (paycheckUrl != null) 'lastPaycheckUrl': paycheckUrl,
                      if (recommendations.isNotEmpty)
                        'recommendationLetters': recommendations,
                    };
                    final repo = ref.read(profileRepositoryProvider);
                    try {
                      EmployeeExperience savedItem;
                      if (current == null) {
                        savedItem =
                            await repo.addExperience(widget.employeeId, data);
                        final patch = <String, dynamic>{};
                        if (pendingLetter != null) {
                          patch['experienceLetterUrl'] = await uploadDoc(
                            kebabType: 'experience-letter',
                            experienceId: savedItem.id,
                            file: pendingLetter!,
                          );
                        }
                        if (pendingPaycheck != null) {
                          patch['lastPaycheckUrl'] = await uploadDoc(
                            kebabType: 'last-paycheck',
                            experienceId: savedItem.id,
                            file: pendingPaycheck!,
                          );
                        }
                        if (pendingRecommendations.isNotEmpty) {
                          final urls = <String>[];
                          for (final file in pendingRecommendations) {
                            urls.add(
                              await uploadDoc(
                                kebabType: 'recommendation',
                                experienceId: savedItem.id,
                                file: file,
                              ),
                            );
                          }
                          patch['recommendationLetters'] = urls;
                        }
                        if (patch.isNotEmpty) {
                          await repo.updateExperience(
                            widget.employeeId,
                            savedItem.id,
                            patch,
                          );
                        }
                      } else {
                        await repo.updateExperience(
                          widget.employeeId,
                          current.id,
                          data,
                        );
                      }
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not save experience: $e'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
            ],
          );
        },
      ),
    );
    designation.dispose();
    organization.dispose();
    description.dispose();
    salary.dispose();
    if (saved == true) _refresh();
  }

  Future<void> _remove(EmployeeExperience item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete experience?'),
        content: Text('${item.designation} at ${item.organizationName}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(profileRepositoryProvider)
          .deleteExperience(widget.employeeId, item.id);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete experience: $e')),
        );
      }
    }
  }

  Widget _docChip(String label, bool has) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        has ? Icons.check_circle : Icons.upload_file_outlined,
        size: 16,
        color: has ? Colors.green : AppColors.textSecondary,
      ),
      label: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EmployeeExperience>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not load experience: ${snapshot.error}'),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          );
        }
        final items = snapshot.data ?? const [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.canEdit)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add experience'),
                ),
              ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: Text('No work experience added yet.')),
              ),
            for (final item in items)
              Card(
                margin: const EdgeInsets.only(top: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.work_history_outlined,
                            color: AppColors.bronze,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.designation,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (widget.canEdit) ...[
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: () => _edit(item),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => _remove(item),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                            ),
                          ] else
                            IconButton(
                              tooltip: 'View details',
                              onPressed: () => _edit(item),
                              icon: const Icon(Icons.visibility_outlined),
                            ),
                        ],
                      ),
                      Text(item.organizationName),
                      const SizedBox(height: 8),
                      Text(
                        '${item.type.replaceAll('_', ' ')} • ${_date(item.fromDate)} – ${_date(item.toDate)}',
                      ),
                      if (item.lastSalary != null)
                        Text(
                          'Last salary: ₹${item.lastSalary!.toStringAsFixed(2)}',
                        ),
                      if ((item.jobDescription ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(item.jobDescription!),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _docChip(
                            'Experience Letter',
                            (item.experienceLetterUrl ?? '').isNotEmpty,
                          ),
                          _docChip(
                            'Last Paycheck',
                            (item.lastPaycheckUrl ?? '').isNotEmpty,
                          ),
                          _docChip(
                            'Recommendations',
                            item.recommendationLetters.isNotEmpty,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
