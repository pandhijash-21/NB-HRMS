import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/attendance_models.dart';
import '../../../leave/presentation/widgets/leave_shared_widgets.dart';
import '../attendance_providers.dart';

class AdminAttendanceScreen extends ConsumerWidget {
  const AdminAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(adminAttendanceDateProvider);
    final dayAsync = ref.watch(adminAttendanceDayProvider);
    final policyAsync = ref.watch(adminAttendancePolicyProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.sand,
        appBar: AppBar(
          title: const Text('Admin Attendance'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Day punches'),
              Tab(text: 'Policy'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final parts = date.split('-');
                            final initial = DateTime(
                              int.parse(parts[0]),
                              int.parse(parts[1]),
                              int.parse(parts[2]),
                            );
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: initial,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 30)),
                            );
                            if (picked != null) {
                              ref
                                  .read(adminAttendanceDateProvider.notifier)
                                  .set(formatDateYmd(picked));
                            }
                          },
                          child: Text(date),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Add punch',
                        icon: const Icon(Icons.add),
                        onPressed: () => _showPunchDialog(context, ref),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: dayAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.bronze),
                    ),
                    error: (e, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$e'),
                          FilledButton(
                            onPressed: () => ref.invalidate(adminAttendanceDayProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                    data: (rows) {
                      final withPunches = rows.where((r) => r.punches.isNotEmpty).toList();
                      if (withPunches.isEmpty) {
                        return const Center(child: Text('No punches for this date.'));
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: withPunches.length,
                        itemBuilder: (ctx, i) => _EmployeePunchCard(
                          row: withPunches[i],
                          onEdit: (punch) => _showPunchDialog(
                            context,
                            ref,
                            employeeId: withPunches[i].employeeId,
                            existing: punch,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            policyAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.bronze),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$e'),
                    FilledButton(
                      onPressed: () => ref.invalidate(adminAttendancePolicyProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (policy) => _PolicyEditor(policy: policy),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPunchDialog(
    BuildContext context,
    WidgetRef ref, {
    int? employeeId,
    AttendancePunch? existing,
  }) async {
    final employeeController = TextEditingController(
      text: employeeId?.toString() ?? existing?.employeeId?.toString() ?? '',
    );
    final punchTypeController = TextEditingController(text: existing?.punchType ?? '');
    final terminalController = TextEditingController(text: existing?.terminalId ?? '');
    DateTime punchAt = existing != null
        ? DateTime.parse(existing.punchAt).toLocal()
        : DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Add punch' : 'Edit punch'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (existing == null)
                  TextField(
                    controller: employeeController,
                    decoration: const InputDecoration(labelText: 'Employee ID'),
                    keyboardType: TextInputType.number,
                  ),
                OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(punchAt),
                    );
                    if (t != null) {
                      setLocal(() {
                        punchAt = DateTime(
                          punchAt.year,
                          punchAt.month,
                          punchAt.day,
                          t.hour,
                          t.minute,
                        );
                      });
                    }
                  },
                  child: Text('Time: ${formatIsoTime(punchAt.toIso8601String())}'),
                ),
                TextField(
                  controller: punchTypeController,
                  decoration: const InputDecoration(labelText: 'Punch type'),
                ),
                TextField(
                  controller: terminalController,
                  decoration: const InputDecoration(labelText: 'Terminal ID'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  final repo = ref.read(attendanceRepositoryProvider);
                  final body = {
                    'punchAt': punchAt.toUtc().toIso8601String(),
                    'punchType': punchTypeController.text.trim().isEmpty
                        ? null
                        : punchTypeController.text.trim(),
                    'terminalId': terminalController.text.trim().isEmpty
                        ? null
                        : terminalController.text.trim(),
                  };
                  if (existing != null) {
                    await repo.updateAdminPunch(existing.id, body);
                  } else {
                    await repo.createAdminPunch({
                      ...body,
                      'employeeId': int.parse(employeeController.text.trim()),
                    });
                  }
                  invalidateAttendanceAdminData(ref);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
    employeeController.dispose();
    punchTypeController.dispose();
    terminalController.dispose();
  }
}

class _EmployeePunchCard extends StatelessWidget {
  const _EmployeePunchCard({required this.row, required this.onEdit});

  final AdminAttendanceEmployeeRow row;
  final ValueChanged<AttendancePunch> onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.fullName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (row.employeeCode != null)
              Text(row.employeeCode!, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ...row.punches.map(
              (p) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(formatIsoTime(p.punchAt)),
                subtitle: Text([p.punchType, p.terminalId].whereType<String>().join(' · ')),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => onEdit(p),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyEditor extends ConsumerStatefulWidget {
  const _PolicyEditor({required this.policy});

  final AttendancePolicy policy;

  @override
  ConsumerState<_PolicyEditor> createState() => _PolicyEditorState();
}

class _PolicyEditorState extends ConsumerState<_PolicyEditor> {
  late final TextEditingController _inController;
  late final TextEditingController _outController;
  late final TextEditingController _inBufferController;
  late final TextEditingController _outBufferController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _inController = TextEditingController(text: widget.policy.defaultPunchInTime);
    _outController = TextEditingController(text: widget.policy.defaultPunchOutTime);
    _inBufferController =
        TextEditingController(text: '${widget.policy.punchInBufferMinutes}');
    _outBufferController =
        TextEditingController(text: '${widget.policy.punchOutBufferMinutes}');
  }

  @override
  void dispose() {
    _inController.dispose();
    _outController.dispose();
    _inBufferController.dispose();
    _outBufferController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _inController,
            decoration: const InputDecoration(
              labelText: 'Default punch-in (HH:MM)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _outController,
            decoration: const InputDecoration(
              labelText: 'Default punch-out (HH:MM)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _inBufferController,
            decoration: const InputDecoration(
              labelText: 'Punch-in buffer (minutes)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _outBufferController,
            decoration: const InputDecoration(
              labelText: 'Punch-out buffer (minutes)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await ref.read(attendanceRepositoryProvider).updateAdminPolicy({
                        'defaultPunchInTime': _inController.text.trim(),
                        'defaultPunchOutTime': _outController.text.trim(),
                        'punchInBufferMinutes':
                            int.tryParse(_inBufferController.text.trim()) ?? 0,
                        'punchOutBufferMinutes':
                            int.tryParse(_outBufferController.text.trim()) ?? 0,
                      });
                      invalidateAttendanceAdminData(ref);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Policy updated.')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save policy'),
          ),
        ],
      ),
    );
  }
}
