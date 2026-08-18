import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/open_stored_document.dart';
import '../../../admin/presentation/admin_notifier.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/task_models.dart';
import '../tasks_providers.dart';

Future<void> showTaskDetailSheet(BuildContext context, WorkTask task) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1A1816)
        : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => TaskDetailSheet(taskId: task.id, initial: task),
  );
}

class TaskDetailSheet extends ConsumerStatefulWidget {
  const TaskDetailSheet({super.key, required this.taskId, required this.initial});

  final String taskId;
  final WorkTask initial;

  @override
  ConsumerState<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<TaskDetailSheet> {
  late WorkTask _task;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _task = widget.initial;
  }

  String get _me => ref.read(authNotifierProvider).user?.id ?? '';

  Future<void> _run(Future<WorkTask> Function() action) async {
    setState(() => _busy = true);
    try {
      final next = await action();
      setState(() => _task = next);
      ref.invalidate(myTasksProvider);
      ref.invalidate(taskSummaryProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askRemarks({required String title, required String hint}) async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Continue')),
        ],
      ),
    );
    ctrl.dispose();
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final me = _me;
    final isAssignee = _task.assignee.id == me;
    final isAssigner = _task.assigner.id == me;
    final isExtra = _task.extraApprover?.id == me;
    final names = ref.watch(employeeNamesProvider).asData?.value ?? const [];

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(_task.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF212F3D))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(taskStatusLabel(_task.status), _statusColor(_task.status)),
                _chip('Due ${_fmt(_task.deadline)}', const Color(0xFFC5A059)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Assigned by ${_task.assigner.name}  →  ${_task.assignee.name}', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF607D8B))),
            if (_task.description != null && _task.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_task.description!, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF212F3D))),
            ],
            if (_task.attachmentUrl != null && _task.attachmentUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => openStoredDocument(
                  context,
                  url: _task.attachmentUrl!,
                  fileName: _task.attachmentName,
                  title: _task.attachmentName ?? 'Attachment',
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(_task.attachmentName ?? 'Open attachment'),
              ),
            ],
            if (_task.extraApprover != null) ...[
              const SizedBox(height: 12),
              Text(
                'Extra approval: ${_task.extraApprover!.name} (${_task.extraApprovalStatus ?? 'PENDING'})'
                '${_task.extraApprovalRemarks == null ? '' : ' — ${_task.extraApprovalRemarks}'}',
                style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF607D8B)),
              ),
            ],
            if (_task.status == 'CHANGES_REQUESTED') ...[
              const SizedBox(height: 12),
              Text(
                isAssignee
                    ? 'Changes requested. Resume work, then mark completed — it goes back to ${_task.assigner.name} for review. This repeats until they approve or reject.'
                    : 'Waiting on the assignee to complete the changes. When they mark it completed, it comes back here for another review.',
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700),
              ),
            ],
            if (_task.reviewRemarks != null && _task.reviewRemarks!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Review notes: ${_task.reviewRemarks!}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
            if (isAssignee && !_task.isClosed) ...[
              Wrap(
                spacing: 8,
                children: [
                  if (_task.status == 'ASSIGNED')
                    FilledButton(
                      onPressed: () => _run(() => ref.read(tasksRepositoryProvider).setStatus(_task.id, 'ONGOING')),
                      child: const Text('Start (Ongoing)'),
                    ),
                  if (_task.status == 'ONGOING' || _task.status == 'CHANGES_REQUESTED')
                    FilledButton(
                      onPressed: () => _run(() => ref.read(tasksRepositoryProvider).setStatus(_task.id, 'COMPLETED')),
                      child: Text(_task.status == 'CHANGES_REQUESTED'
                          ? 'Mark completed (send back for review)'
                          : 'Mark completed'),
                    ),
                  if (_task.status == 'CHANGES_REQUESTED') ...[
                    OutlinedButton(
                      onPressed: () => _run(() => ref.read(tasksRepositoryProvider).setStatus(_task.id, 'ONGOING')),
                      child: const Text('Resume work'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  String? picked;
                  await showDialog<void>(
                    context: context,
                    builder: (ctx) {
                      return AlertDialog(
                        title: const Text('Ask someone for approval'),
                        content: DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Person'),
                          items: [
                            for (final n in names)
                              if (n.userId.isNotEmpty && n.userId != me && n.userId != _task.assigner.id)
                                DropdownMenuItem(value: n.userId, child: Text(n.displayLabel)),
                          ],
                          onChanged: (v) => picked = v,
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Request'),
                          ),
                        ],
                      );
                    },
                  );
                  if (picked == null || picked!.isEmpty) return;
                  await _run(() => ref.read(tasksRepositoryProvider).requestExtraApproval(_task.id, picked!));
                },
                icon: const Icon(Icons.how_to_reg_outlined),
                label: const Text('Need approval from someone else'),
              ),
            ],
            if (isAssigner && _task.status == 'COMPLETED') ...[
              const SizedBox(height: 8),
              const Text(
                'Assignee marked this complete. Approve, reject, or ask for changes. If you ask for changes, they will send it back here again after they complete it.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: () async {
                      final remarks = await _askRemarks(title: 'Approve task', hint: 'Optional remarks');
                      if (remarks == null) return;
                      await _run(() => ref.read(tasksRepositoryProvider).review(_task.id, action: 'approve', remarks: remarks));
                    },
                    child: const Text('Approve & close'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final remarks = await _askRemarks(title: 'Ask for changes', hint: 'What needs to change?');
                      if (remarks == null || remarks.isEmpty) return;
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _task.deadline.isAfter(DateTime.now()) ? _task.deadline : DateTime.now().add(const Duration(days: 2)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (date == null || !mounted) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_task.deadline),
                      );
                      if (!mounted) return;
                      final deadline = DateTime(date.year, date.month, date.day, time?.hour ?? 18, time?.minute ?? 0);
                      await _run(() => ref.read(tasksRepositoryProvider).review(
                            _task.id,
                            action: 'changes',
                            remarks: remarks,
                            newDeadline: deadline,
                          ));
                    },
                    child: const Text('Ask for changes'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final remarks = await _askRemarks(title: 'Reject task', hint: 'Why is this rejected?');
                      if (remarks == null || remarks.isEmpty) return;
                      await _run(() => ref.read(tasksRepositoryProvider).review(_task.id, action: 'reject', remarks: remarks));
                    },
                    child: const Text('Reject', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
            if (isExtra && _task.extraApprovalStatus == 'PENDING') ...[
              const SizedBox(height: 8),
              const Text('Your extra approval is requested.', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton(
                    onPressed: () => _run(() => ref.read(tasksRepositoryProvider).decideExtraApproval(_task.id, approve: true)),
                    child: const Text('Approve'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final remarks = await _askRemarks(title: 'Decline extra approval', hint: 'Reason');
                      if (remarks == null) return;
                      await _run(() => ref.read(tasksRepositoryProvider).decideExtraApproval(_task.id, approve: false, remarks: remarks));
                    },
                    child: const Text('Decline'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Text('History', style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF212F3D))),
            const SizedBox(height: 8),
            for (final e in _task.events.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${_fmt(e.createdAt)}  ·  ${e.actor.name}  ·  ${e.type.replaceAll('_', ' ').toLowerCase()}'
                  '${e.remarks == null ? '' : '\n${e.remarks}'}',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF607D8B)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }
}

String _fmt(DateTime d) {
  final local = d.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

Color _statusColor(String status) {
  switch (status) {
    case 'ASSIGNED':
      return const Color(0xFF0284c7);
    case 'ONGOING':
      return const Color(0xFFd97706);
    case 'COMPLETED':
      return const Color(0xFF7c3aed);
    case 'CHANGES_REQUESTED':
      return const Color(0xFFea580c);
    case 'APPROVED':
      return const Color(0xFF16a34a);
    case 'REJECTED':
      return const Color(0xFFe11d48);
    default:
      return const Color(0xFF64748b);
  }
}
