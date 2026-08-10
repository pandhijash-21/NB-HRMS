import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/widgets/header_action_button.dart';
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
        leading: const AppBackButton(fallbackLocation: '/attendance'),
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
              HeaderActionButton(
                tooltip: 'Add punch',
                label: 'Add punch',
                icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFFC5A059)),
                onPressed: onAddPunch,
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
  if (employeeId == null && existing == null) return;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  
  String time = '09:00';
  String type = 'IN';
  String terminal = 'MANUAL';
  
  if (existing != null) {
    final d = DateTime.parse(existing.punchAt).toLocal();
    time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    type = existing.punchType ?? 'IN';
    terminal = existing.terminalId ?? 'MANUAL';
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          bool saving = false;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              existing == null ? 'Add Manual Punch' : 'Edit Manual Punch',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF212F3D),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Time (HH:MM)'),
                    initialValue: time,
                    onChanged: (v) => time = v,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Type (IN/OUT)'),
                    initialValue: type,
                    onChanged: (v) => type = v,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Terminal'),
                    initialValue: terminal,
                    onChanged: (v) => terminal = v,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving ? null : () async {
                  setState(() => saving = true);
                  try {
                    // Use the timezone from dateYmd if possible, here defaulting to +05:30.
                    final punchAt = '${dateYmd}T$time:00+05:30';
                    if (existing == null) {
                      await ref.read(attendanceRepositoryProvider).adminAddPunch(
                        employeeId: employeeId!,
                        punchAt: punchAt,
                        punchType: type,
                        terminalId: terminal,
                      );
                    } else {
                      await ref.read(attendanceRepositoryProvider).adminUpdatePunch(
                        punchId: existing.id,
                        punchAt: punchAt,
                        punchType: type,
                        terminalId: terminal,
                      );
                    }
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Punch saved successfully.')));
                    }
                    invalidateAttendanceAdminData(ref);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      setState(() => saving = false);
                    }
                  }
                },
                child: saving 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                  : const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

