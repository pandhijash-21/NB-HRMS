import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/platform_file_picker.dart';
import '../../../admin/presentation/admin_notifier.dart';
import '../../domain/task_models.dart';
import '../tasks_providers.dart';
import 'searchable_dropdown.dart';

class _SubtaskDraft {
  _SubtaskDraft({String title = ''}) : title = TextEditingController(text: title);

  final TextEditingController title;
  PickedFileData? file;

  String get titleText => title.text.trim();

  void dispose() => title.dispose();
}

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
  final _subtasks = <_SubtaskDraft>[];

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final s in _subtasks) {
      s.dispose();
    }
    super.dispose();
  }

  void _addSubtaskRow() {
    setState(() => _subtasks.add(_SubtaskDraft()));
  }

  void _removeSubtask(int index) {
    setState(() {
      _subtasks[index].dispose();
      _subtasks.removeAt(index);
    });
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
    if (_subtasks.any((s) => s.titleText.isEmpty && s.file != null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Each subtask with a file needs a title')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(tasksRepositoryProvider);
      var task = await repo.create(
        assigneeUserId: _assigneeUserId!,
        title: title,
        description: _description.text.trim(),
        deadline: _deadline,
        extraApproverUserId: _extraApproverUserId,
        fileBytes: _file?.bytes,
        fileName: _file?.name,
      );
      for (var i = 0; i < _subtasks.length; i++) {
        final draft = _subtasks[i];
        final st = draft.titleText;
        if (st.isEmpty) continue;
        task = await repo.addSubtask(
          task.id,
          title: st,
          fileBytes: draft.file?.bytes,
          fileName: draft.file?.name,
        );
      }
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
    final approverOptions = [
      for (final n in names)
        if (n.userId.isNotEmpty && n.userId != _assigneeUserId) n,
    ];

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
      title: const Text('Assign task', style: TextStyle(fontWeight: FontWeight.w800)),
      scrollable: true,
      content: SizedBox(
        width: 460,
        child: Column(
          children: [
            SearchableDropdown<TaskReportee>(
              label: 'Assign to *',
              value: _assigneeUserId,
              helperText: 'Only people whose 1st reporting is you',
              hint: 'Search reportees…',
              items: reportees,
              itemLabel: (r) => r.displayLabel,
              itemValue: (r) => r.userId,
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
            const SizedBox(height: 8),
            SearchableDropdown(
              label: 'Extra approval (optional)',
              value: _extraApproverUserId,
              helperText: 'If this task needs a sign-off from someone else',
              hint: 'Search employees…',
              allowClear: true,
              clearLabel: 'No extra approval',
              items: approverOptions,
              itemLabel: (n) => n.displayLabel,
              itemValue: (n) => n.userId,
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
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Subtasks', style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF212F3D))),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addSubtaskRow,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add subtask'),
                ),
              ],
            ),
            if (_subtasks.isEmpty)
              Text(
                'Optional checklist items for the assignee. No separate deadline — parent task deadline applies.',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF607D8B)),
              ),
            for (var i = 0; i < _subtasks.length; i++) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subtasks[i].title,
                      decoration: InputDecoration(
                        labelText: 'Subtask ${i + 1}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: () => _removeSubtask(i),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final picked = await pickFileFromDevice(
                      imagesOnly: false,
                      extensions: const ['pdf', 'ppt', 'pptx'],
                    );
                    if (picked != null) setState(() => _subtasks[i].file = picked);
                  },
                  icon: const Icon(Icons.attach_file_outlined, size: 18),
                  label: Text(_subtasks[i].file?.name ?? 'Attach doc (optional)'),
                ),
              ),
            ],
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
