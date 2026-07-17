import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Attendance',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF212F3D),
          ),
          onPressed: () => context.go('/attendance'),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
            height: 1.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pick a date to see all employees and their punch logs.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
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
                    ref.read(adminAttendanceDateProvider.notifier).set(formatDateYmd(picked));
                  }
                },
                icon: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFFC5A059)),
                label: Text(date, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          policyAsync.when(
            loading: () => const _SectionCard(
              child: Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Color(0xFFC5A059)),
              )),
            ),
            error: (e, _) => _SectionCard(
              child: Column(
                children: [
                  Text('$e', style: const TextStyle(color: Colors.red)),
                  TextButton(
                    onPressed: () => ref.invalidate(adminAttendancePolicyProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (policy) => _PolicyCard(policy: policy),
          ),
          const SizedBox(height: 16),
          _ManualPunchCard(selectedDate: date),
          const SizedBox(height: 24),
          Text(
            'Employees',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: isDark ? Colors.white : const Color(0xFF212F3D),
            ),
          ),
          const SizedBox(height: 12),
          dayAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: Color(0xFFC5A059)),
              ),
            ),
            error: (e, _) => Column(
              children: [
                Text('$e', style: const TextStyle(color: Colors.red)),
                FilledButton(
                  onPressed: () => ref.invalidate(adminAttendanceDayProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return Text(
                  'No active employees found.',
                  style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF607D8B)),
                );
              }
              return Column(
                children: rows
                    .map(
                      (row) => _EmployeeDayTile(
                        row: row,
                        onOpen: () => context.push('/admin/attendance/employee/${row.employeeId}'),
                        onAddPunch: () => showAdminPunchDialog(
                          context,
                          ref,
                          employeeId: row.employeeId,
                          dateYmd: date,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _PolicyCard extends ConsumerStatefulWidget {
  const _PolicyCard({required this.policy});

  final AttendancePolicy policy;

  @override
  ConsumerState<_PolicyCard> createState() => _PolicyCardState();
}

class _PolicyCardState extends ConsumerState<_PolicyCard> {
  late TextEditingController _inCtrl;
  late TextEditingController _outCtrl;
  late TextEditingController _inBufCtrl;
  late TextEditingController _outBufCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _inCtrl = TextEditingController(text: widget.policy.defaultPunchInTime);
    _outCtrl = TextEditingController(text: widget.policy.defaultPunchOutTime);
    _inBufCtrl = TextEditingController(text: '${widget.policy.punchInBufferMinutes}');
    _outBufCtrl = TextEditingController(text: '${widget.policy.punchOutBufferMinutes}');
  }

  @override
  void didUpdateWidget(covariant _PolicyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.policy.updatedAt != widget.policy.updatedAt) {
      _inCtrl.text = widget.policy.defaultPunchInTime;
      _outCtrl.text = widget.policy.defaultPunchOutTime;
      _inBufCtrl.text = '${widget.policy.punchInBufferMinutes}';
      _outBufCtrl.text = '${widget.policy.punchOutBufferMinutes}';
    }
  }

  @override
  void dispose() {
    _inCtrl.dispose();
    _outCtrl.dispose();
    _inBufCtrl.dispose();
    _outBufCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(TextEditingController ctrl) async {
    final parts = ctrl.text.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    ctrl.text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {});
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(attendanceRepositoryProvider).updateAdminPolicy({
        'defaultPunchInTime': _inCtrl.text.trim(),
        'defaultPunchOutTime': _outCtrl.text.trim(),
        'punchInBufferMinutes': int.parse(_inBufCtrl.text.trim()),
        'punchOutBufferMinutes': int.parse(_outBufCtrl.text.trim()),
      });
      invalidateAttendanceAdminData(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Policy saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Punch timing policy',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Late if punch-in is after Punch In + buffer. Eligible if punch-out is after Punch Out − buffer.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                  foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Policy', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _inCtrl,
                  readOnly: true,
                  onTap: () => _pickTime(_inCtrl),
                  decoration: const InputDecoration(
                    labelText: 'Default Punch In',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _inBufCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'In Buffer (mins)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _outCtrl,
                  readOnly: true,
                  onTap: () => _pickTime(_outCtrl),
                  decoration: const InputDecoration(
                    labelText: 'Default Punch Out',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _outBufCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Out Buffer (mins)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManualPunchCard extends ConsumerStatefulWidget {
  const _ManualPunchCard({required this.selectedDate});

  final String selectedDate;

  @override
  ConsumerState<_ManualPunchCard> createState() => _ManualPunchCardState();
}

class _ManualPunchCardState extends ConsumerState<_ManualPunchCard> {
  final _employeeCtrl = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  String _punchType = 'IN';
  bool _submitting = false;

  @override
  void dispose() {
    _employeeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final employeeId = int.tryParse(_employeeCtrl.text.trim());
    if (employeeId == null || employeeId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid employee ID.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final hh = _time.hour.toString().padLeft(2, '0');
      final mm = _time.minute.toString().padLeft(2, '0');
      await ref.read(attendanceRepositoryProvider).createAdminPunch({
        'employeeId': employeeId,
        'punchAt': '${widget.selectedDate}T$hh:$mm:00+05:30',
        'punchType': _punchType,
        'terminalId': 'MANUAL',
      });
      invalidateAttendanceAdminData(ref);
      _employeeCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Punch added.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin controls: add manual punch',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF212F3D),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _employeeCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Employee ID',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showTimePicker(context: context, initialTime: _time);
                  if (picked != null) setState(() => _time = picked);
                },
                child: Text(
                  '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                width: 100,
                child: DropdownButtonFormField<String>(
                  initialValue: _punchType,
                  decoration: const InputDecoration(
                    labelText: 'Punch Type',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'IN', child: Text('IN')),
                    DropdownMenuItem(value: 'OUT', child: Text('OUT')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _punchType = v);
                  },
                ),
              ),
              Chip(
                label: const Text('MANUAL', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                backgroundColor: isDark ? const Color(0xFF2B2722) : const Color(0xFFECEFF1),
              ),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                  foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add Punch', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmployeeDayTile extends StatelessWidget {
  const _EmployeeDayTile({
    required this.row,
    required this.onOpen,
    required this.onAddPunch,
  });

  final AdminAttendanceEmployeeRow row;
  final VoidCallback onOpen;
  final VoidCallback onAddPunch;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inTime = row.firstIn != null ? formatIsoTime(row.firstIn) : '—';
    final outTime = row.lastOut != null ? formatIsoTime(row.lastOut) : '—';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.fullName,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (row.employeeCode != null && row.employeeCode!.isNotEmpty)
                          'Code ${row.employeeCode}'
                        else
                          'ID ${row.employeeId}',
                        if (row.department != null && row.department!.isNotEmpty) row.department!,
                      ].join(' • '),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'In $inTime',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                    ),
                  ),
                  Text(
                    'Out $outTime',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                    ),
                  ),
                  Text(
                    '${row.punches.length} punches',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : const Color(0xFF90A4AE),
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Add punch',
                onPressed: onAddPunch,
                icon: const Icon(Icons.add_rounded, color: Color(0xFFC5A059)),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white38 : const Color(0xFF90A4AE),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showAdminPunchDialog(
  BuildContext context,
  WidgetRef ref, {
  int? employeeId,
  AttendancePunch? existing,
  String? dateYmd,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final employeeController = TextEditingController(
    text: employeeId?.toString() ?? existing?.employeeId?.toString() ?? '',
  );
  final punchTypeController = TextEditingController(text: existing?.punchType ?? 'IN');
  final terminalController = TextEditingController(text: existing?.terminalId ?? 'MANUAL');
  DateTime punchAt = existing != null
      ? DateTime.parse(existing.punchAt).toLocal()
      : () {
          if (dateYmd != null) {
            final parts = dateYmd.split('-');
            final now = DateTime.now();
            return DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
              now.hour,
              now.minute,
            );
          }
          return DateTime.now();
        }();

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          existing == null ? 'Add Punch' : 'Edit Punch',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (existing == null)
                TextField(
                  controller: employeeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Employee ID',
                    border: OutlineInputBorder(),
                  ),
                ),
              if (existing == null) const SizedBox(height: 12),
              OutlinedButton.icon(
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
                icon: const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFFC5A059)),
                label: Text('Time: ${formatIsoTime(punchAt.toIso8601String())}'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: punchTypeController,
                decoration: const InputDecoration(
                  labelText: 'Punch Type (IN/OUT)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: terminalController,
                decoration: const InputDecoration(
                  labelText: 'Method / Terminal',
                  border: OutlineInputBorder(),
                ),
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
                final ymd =
                    '${punchAt.year}-${punchAt.month.toString().padLeft(2, '0')}-${punchAt.day.toString().padLeft(2, '0')}';
                final hh = punchAt.hour.toString().padLeft(2, '0');
                final mm = punchAt.minute.toString().padLeft(2, '0');
                final body = {
                  'punchAt': '${ymd}T$hh:$mm:00+05:30',
                  'punchType': punchTypeController.text.trim().isEmpty
                      ? 'MANUAL'
                      : punchTypeController.text.trim(),
                  'terminalId': terminalController.text.trim().isEmpty
                      ? 'MANUAL'
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
