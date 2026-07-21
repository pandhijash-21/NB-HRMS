import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
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
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                      items:
                          const [
                                'TEACHING',
                                'INDUSTRY',
                                'RESEARCH',
                                'ADMINISTRATIVE',
                                'CONSULTANCY',
                                'OTHER',
                              ]
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                      onChanged: (v) => setDialogState(() => type = v ?? type),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: designation,
                      decoration: const InputDecoration(
                        labelText: 'Designation *',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: organization,
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
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: fromDate,
                                firstDate: DateTime(1950),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null)
                                setDialogState(() => fromDate = picked);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: Text('To: ${_date(toDate)}'),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: toDate,
                                firstDate: fromDate,
                                lastDate: DateTime.now(),
                              );
                              if (picked != null)
                                setDialogState(() => toDate = picked);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: salary,
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
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Job description',
                      ),
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
                };
                final repo = ref.read(profileRepositoryProvider);
                try {
                  if (current == null) {
                    await repo.addExperience(widget.employeeId, data);
                  } else {
                    await repo.updateExperience(
                      widget.employeeId,
                      current.id,
                      data,
                    );
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not save experience: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
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
                          ],
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
