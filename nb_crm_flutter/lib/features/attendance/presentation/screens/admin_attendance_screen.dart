import 'package:flutter/material.dart';
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            'Admin Attendance',
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
            onPressed: () => context.go('/home'),
          ),
          bottom: TabBar(
            indicatorColor: const Color(0xFFC5A059),
            indicatorWeight: 3,
            labelColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
            unselectedLabelColor: isDark ? Colors.white54 : const Color(0xFF607D8B),
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.3),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(text: 'Day Punches'),
              Tab(text: 'Policy Settings'),
            ],
          ),
        ),
        body: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0.0, 30.0 * (1.0 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: TabBarView(
            children: [
              // Tab 1: Day punches
              Column(
                children: [
                  Container(
                    color: isDark ? const Color(0xFF1A1816) : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
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
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                              side: BorderSide(
                                color: isDark ? const Color(0xFFC5A059).withOpacity(0.4) : const Color(0xFF263238).withOpacity(0.5),
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFFC5A059)),
                            label: Text(
                              date,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          height: 44,
                          child: FilledButton.icon(
                            onPressed: () => _showPunchDialog(context, ref),
                            style: FilledButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                              foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add Punch', style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: dayAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: Color(0xFFC5A059)),
                      ),
                      error: (e, _) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$e', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
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
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.fingerprint_rounded,
                                  size: 48,
                                  color: isDark ? Colors.white10 : Colors.black12,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No punches for this date.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white30 : const Color(0xFF607D8B).withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
              // Tab 2: Policy editor
              policyAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFC5A059)),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$e', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
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
      ),
    );
  }

  Future<void> _showPunchDialog(
    BuildContext context,
    WidgetRef ref, {
    int? employeeId,
    AttendancePunch? existing,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
              width: 1.5,
            ),
          ),
          title: Text(
            existing == null ? 'Add Punch Event' : 'Edit Punch Event',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF212F3D),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (existing == null) ...[
                  TextField(
                    controller: employeeController,
                    decoration: const InputDecoration(
                      labelText: 'Employee ID',
                      labelStyle: TextStyle(fontWeight: FontWeight.w600),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                ],
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
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                    side: BorderSide(
                      color: isDark ? const Color(0xFFC5A059).withOpacity(0.4) : const Color(0xFFCFD8DC),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                  icon: const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFFC5A059)),
                  label: Text('Time: ${formatIsoTime(punchAt.toIso8601String())}'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: punchTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Punch Type (e.g. IN, OUT)',
                    labelStyle: TextStyle(fontWeight: FontWeight.w600),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: terminalController,
                  decoration: const InputDecoration(
                    labelText: 'Terminal ID',
                    labelStyle: TextStyle(fontWeight: FontWeight.w600),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(existing == null ? 'Add' : 'Save', style: const TextStyle(fontWeight: FontWeight.w800)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                        row.fullName,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF212F3D),
                        ),
                      ),
                      if (row.employeeCode != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            row.employeeCode!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white30 : const Color(0xFF607D8B),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2B2722) : const Color(0xFFECEFF1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${row.punches.length} punches',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 12),
            ...row.punches.map(
              (p) {
                final type = p.punchType?.toUpperCase() ?? 'IN';
                final isOut = type == 'OUT';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF151311) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: BorderSide(
                        color: isOut ? const Color(0xFFC5A059) : Colors.green,
                        width: 4,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.fingerprint_rounded,
                        color: isOut ? const Color(0xFFC5A059) : Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatIsoTime(p.punchAt),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: isDark ? Colors.white : const Color(0xFF212F3D),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              [p.punchType, p.terminalId].whereType<String>().join(' · '),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white30 : const Color(0xFF607D8B).withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Color(0xFFC5A059), size: 18),
                        onPressed: () => onEdit(p),
                      ),
                    ],
                  ),
                );
              },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPolicyCard(
            title: 'Shift Timings',
            subtitle: 'Configure the default business shift working windows.',
            icon: Icons.access_time_filled_rounded,
            children: [
              TextField(
                controller: _inController,
                decoration: const InputDecoration(
                  labelText: 'Default Punch-In (HH:MM)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _outController,
                decoration: const InputDecoration(
                  labelText: 'Default Punch-Out (HH:MM)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildPolicyCard(
            title: 'Tolerance Buffers',
            subtitle: 'Define standard buffer limits in minutes.',
            icon: Icons.av_timer_rounded,
            children: [
              TextField(
                controller: _inBufferController,
                decoration: const InputDecoration(
                  labelText: 'Punch-In Buffer (Minutes)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _outBufferController,
                decoration: const InputDecoration(
                  labelText: 'Punch-Out Buffer (Minutes)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 48,
            child: FilledButton(
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
                            const SnackBar(content: Text('Policy updated successfully.')),
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
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Policy Settings', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFFC5A059), size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white30 : const Color(0xFF607D8B),
              ),
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}
