import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/picked_file_data.dart';
import '../../../../core/utils/platform_file_picker.dart';
import '../../../admin/presentation/admin_notifier.dart';
import '../../domain/task_models.dart';
import '../tasks_providers.dart';

Future<void> showAssignTaskDialog(BuildContext context, WidgetRef ref) async {
  await showDialog<void>(
    context: context,
    builder: (_) => const _AssignTaskDialog(),
  );
}

class _AssignTaskDialog extends ConsumerStatefulWidget {
  const _AssignTaskDialog();

  @override
  ConsumerState<_AssignTaskDialog> createState() => _AssignTaskDialogState();
}

class _AssignTaskDialogState extends ConsumerState<_AssignTaskDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  String? _assigneeUserId;
  String? _extraApproverUserId;
  DateTime _deadline = DateTime.now().add(const Duration(days: 3));
  PickedFileData? _file;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline),
    );
    if (!mounted) return;
    setState(() {
      _deadline = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 18,
        time?.minute ?? 0,
      );
    });
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty || _assigneeUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and assignee are required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(tasksRepositoryProvider).create(
            assigneeUserId: _assigneeUserId!,
            title: title,
            description: _description.text.trim(),
            deadline: _deadline,
            extraApproverUserId: _extraApproverUserId,
            fileBytes: _file?.bytes,
            fileName: _file?.name,
          );
      ref.invalidate(myTasksProvider);
      ref.invalidate(taskSummaryProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reportees = ref.watch(taskReporteesProvider).asData?.value ?? const <TaskReportee>[];
    final names = ref.watch(employeeNamesProvider).asData?.value ?? const [];

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
      title: const Text('Assign task', style: TextStyle(fontWeight: FontWeight.w800)),
      scrollable: true,
      content: SizedBox(
        width: 460,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _assigneeUserId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Assign to *',
                border: OutlineInputBorder(),
                helperText: 'Only people whose 1st reporting is you',
              ),
              items: [
                for (final r in reportees)
                  DropdownMenuItem(value: r.userId, child: Text(r.displayLabel, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() {
                _assigneeUserId = v;
                if (_extraApproverUserId == v) _extraApproverUserId = null;
              }),
            ),
            if (reportees.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Nobody has you as 1st reporting yet. Set that on their profile first.',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Task title *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Details', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Deadline: ${_deadline.day.toString().padLeft(2, '0')}/${_deadline.month.toString().padLeft(2, '0')}/${_deadline.year}  ${_deadline.hour.toString().padLeft(2, '0')}:${_deadline.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: TextButton(onPressed: _pickDeadline, child: const Text('Change')),
            ),
            DropdownButtonFormField<String?>(
              value: _extraApproverUserId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Extra approval (optional)',
                border: OutlineInputBorder(),
                helperText: 'If this task needs a sign-off from someone else',
              ),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('No extra approval')),
                for (final n in names)
                  if (n.userId.isNotEmpty && n.userId != _assigneeUserId)
                    DropdownMenuItem<String?>(
                      value: n.userId,
                      child: Text(n.displayLabel, overflow: TextOverflow.ellipsis),
                    ),
              ],
              onChanged: (v) => setState(() => _extraApproverUserId = v),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await pickFileFromDevice(
                  imagesOnly: false,
                  extensions: const ['pdf', 'ppt', 'pptx'],
                );
                if (picked != null) setState(() => _file = picked);
              },
              icon: const Icon(Icons.attach_file_rounded),
              label: Text(_file == null ? 'Attach PDF / PPT' : _file!.name),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving || reportees.isEmpty ? null : _submit,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Assign'),
        ),
      ],
    );
  }
}
