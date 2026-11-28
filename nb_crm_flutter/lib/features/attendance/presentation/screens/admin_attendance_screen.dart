import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/bloc/load_status.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../../core/tour/models/tour_models.dart';
import '../../../../core/tour/widgets/tour_target.dart';
import '../../../../core/widgets/header_action_button.dart';
import '../../data/attendance_repository.dart';
import '../../domain/attendance_models.dart';
import '../../../leave/presentation/widgets/leave_shared_widgets.dart';
import '../attendance_providers.dart';
import '../bloc/admin_attendance_bloc.dart';

class AdminAttendanceScreen extends StatelessWidget {
  const AdminAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AdminAttendanceBloc(
        attendanceRepository: context.read<AttendanceRepository>(),
      )..add(const AdminAttendanceLoadRequested()),
      child: const _AdminAttendanceView(),
    );
  }
}

class _AdminAttendanceView extends StatelessWidget {
  const _AdminAttendanceView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminAttendanceBloc>().state;
    final date = state.date;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<AdminAttendanceBloc, AdminAttendanceState>(
      listenWhen: (previous, current) =>
          previous.actionMessage != current.actionMessage ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.actionMessage!), backgroundColor: Colors.green),
          );
        } else if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
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
          actions: [
            IconButton(
              tooltip: 'Attendance Report',
              icon: const Icon(Icons.summarize_rounded),
              onPressed: () => context.push('/admin/attendance/report'),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.5),
            child: Container(
              color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.15) : const Color(0xFFCFD8DC),
              height: 1.5,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            TourTarget(
              id: TourIds.step('hrms.attendance', 3),
              child: Row(
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
                    if (date.isEmpty) return;
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
                    if (picked != null && context.mounted) {
                      context
                          .read<AdminAttendanceBloc>()
                          .add(AdminAttendanceDateChanged(formatDateYmd(picked)));
                    }
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFFC5A059)),
                  label: Text(date, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            ),
            const SizedBox(height: 16),
            if (state.policy != null)
              _PolicyCard(
                policy: state.policy!,
                onSave: (body) => context
                    .read<AdminAttendanceBloc>()
                    .add(AdminAttendancePolicyUpdated(body)),
              )
            else if (state.status == LoadStatus.loading)
              const _SectionCard(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: Color(0xFFC5A059)),
                  ),
                ),
              )
            else
              _SectionCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Failed to load policy'),
                    TextButton(
                      onPressed: () => context
                          .read<AdminAttendanceBloc>()
                          .add(const AdminAttendanceRefreshRequested()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            if (state.policy != null && date.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DayOverrideCard(date: date, globalPolicy: state.policy!),
            ],
            const SizedBox(height: 12),
            const _ResetAllBiometricsCard(),
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
            if (state.status == LoadStatus.loading && state.rows.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: Color(0xFFC5A059)),
                ),
              )
            else if (state.status == LoadStatus.failure && state.rows.isEmpty)
              Center(
                child: Column(
                  children: [
                    Text(
                      state.errorMessage ?? 'Failed to load employees',
                      style: const TextStyle(color: Colors.red),
                    ),
                    FilledButton(
                      onPressed: () => context
                          .read<AdminAttendanceBloc>()
                          .add(const AdminAttendanceRefreshRequested()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (state.rows.isEmpty)
              Text(
                'No active employees found.',
                style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF607D8B)),
              )
            else
              Column(
                children: state.rows
                    .map(
                      (row) => _EmployeeDayTile(
                        row: row,
                        onOpen: () => context.push('/admin/attendance/employee/${row.employeeId}'),
                        onAddPunch: () => showAdminPunchDialog(
                          context,
                          bloc: context.read<AdminAttendanceBloc>(),
                          employeeId: row.employeeId,
                          dateYmd: date,
                        ),
                        onEditPunchIn: () => showAdminPunchDialog(
                          context,
                          bloc: context.read<AdminAttendanceBloc>(),
                          employeeId: row.employeeId,
                          existing: row.firstPunch,
                          defaultType: 'IN',
                          dateYmd: date,
                        ),
                        onEditPunchOut: () => showAdminPunchDialog(
                          context,
                          bloc: context.read<AdminAttendanceBloc>(),
                          employeeId: row.employeeId,
                          existing: row.lastPunch,
                          defaultType: 'OUT',
                          dateYmd: date,
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResetAllBiometricsCard extends StatefulWidget {
  const _ResetAllBiometricsCard();

  @override
  State<_ResetAllBiometricsCard> createState() => _ResetAllBiometricsCardState();
}

class _ResetAllBiometricsCardState extends State<_ResetAllBiometricsCard> {
  bool _busy = false;

  Future<void> _confirmAndReset() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Reset all fingerprints?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'This clears Fingerprint / Face ID / Safari registration for every employee.\n\n'
            'Everyone must register again on their phone (or Safari) before they can punch.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset all'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final count = await context.read<AttendanceRepository>().resetAllEmployeeBiometrics();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? 'Reset $count fingerprint registration${count == 1 ? '' : 's'}.'
                : 'No fingerprint registrations were active.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
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
              Icon(
                Icons.fingerprint_rounded,
                color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFFC5A059),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'App fingerprints',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Force every employee to re-register Fingerprint / Face ID / Safari on their device.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: isDark ? Colors.white54 : const Color(0xFF607D8B),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _confirmAndReset,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red.withValues(alpha: _busy ? 0.4 : 1)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                    )
                  : const Icon(Icons.lock_reset_rounded, size: 18),
              label: Text(
                _busy ? 'Resetting…' : 'Reset all fingerprints',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
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
          color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _PolicyCard extends StatefulWidget {
  const _PolicyCard({required this.policy, required this.onSave});

  final AttendancePolicy policy;
  final ValueChanged<Map<String, dynamic>> onSave;

  @override
  State<_PolicyCard> createState() => _PolicyCardState();
}

class _PolicyCardState extends State<_PolicyCard> {
  late TextEditingController _inCtrl;
  late TextEditingController _outCtrl;
  late TextEditingController _inBufCtrl;
  late TextEditingController _outBufCtrl;
  late TextEditingController _maxBufDaysCtrl;
  late List<HalfDayWindow> _halfWindows;

  @override
  void initState() {
    super.initState();
    _inCtrl = TextEditingController(text: widget.policy.defaultPunchInTime);
    _outCtrl = TextEditingController(text: widget.policy.defaultPunchOutTime);
    _inBufCtrl = TextEditingController(text: '${widget.policy.punchInBufferMinutes}');
    _outBufCtrl = TextEditingController(text: '${widget.policy.punchOutBufferMinutes}');
    _maxBufDaysCtrl = TextEditingController(text: '${widget.policy.maxBufferDaysPerMonth}');
    _halfWindows = List<HalfDayWindow>.from(widget.policy.halfDayWindows);
  }

  @override
  void didUpdateWidget(covariant _PolicyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.policy.updatedAt != widget.policy.updatedAt) {
      _inCtrl.text = widget.policy.defaultPunchInTime;
      _outCtrl.text = widget.policy.defaultPunchOutTime;
      _inBufCtrl.text = '${widget.policy.punchInBufferMinutes}';
      _outBufCtrl.text = '${widget.policy.punchOutBufferMinutes}';
      _maxBufDaysCtrl.text = '${widget.policy.maxBufferDaysPerMonth}';
      _halfWindows = List<HalfDayWindow>.from(widget.policy.halfDayWindows);
    }
  }

  @override
  void dispose() {
    _inCtrl.dispose();
    _outCtrl.dispose();
    _inBufCtrl.dispose();
    _outBufCtrl.dispose();
    _maxBufDaysCtrl.dispose();
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

  Future<void> _editHalfWindow(int? index) async {
    final existing = index != null ? _halfWindows[index] : null;
    final inCtrl = TextEditingController(text: existing?.punchIn ?? '10:00');
    final outCtrl = TextEditingController(text: existing?.punchOut ?? '14:30');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(index == null ? 'Add half-day window' : 'Edit half-day window'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: inCtrl,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Check-in (HH:MM)', border: OutlineInputBorder()),
              onTap: () async {
                final parts = inCtrl.text.split(':');
                final picked = await showTimePicker(
                  context: ctx,
                  initialTime: TimeOfDay(
                    hour: int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 10,
                    minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
                  ),
                );
                if (picked == null) return;
                inCtrl.text =
                    '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: outCtrl,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Check-out (HH:MM)', border: OutlineInputBorder()),
              onTap: () async {
                final parts = outCtrl.text.split(':');
                final picked = await showTimePicker(
                  context: ctx,
                  initialTime: TimeOfDay(
                    hour: int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 14,
                    minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 30,
                  ),
                );
                if (picked == null) return;
                outCtrl.text =
                    '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final window = HalfDayWindow(punchIn: inCtrl.text.trim(), punchOut: outCtrl.text.trim());
    setState(() {
      if (index == null) {
        _halfWindows.add(window);
      } else {
        _halfWindows[index] = window;
      }
    });
  }

  void _save() {
    widget.onSave({
      'defaultPunchInTime': _inCtrl.text.trim(),
      'defaultPunchOutTime': _outCtrl.text.trim(),
      'punchInBufferMinutes': int.tryParse(_inBufCtrl.text.trim()) ?? widget.policy.punchInBufferMinutes,
      'punchOutBufferMinutes': int.tryParse(_outBufCtrl.text.trim()) ?? widget.policy.punchOutBufferMinutes,
      'maxBufferDaysPerMonth':
          int.tryParse(_maxBufDaysCtrl.text.trim()) ?? widget.policy.maxBufferDaysPerMonth,
      'halfDayWindows': _halfWindows.map((w) => w.toJson()).toList(),
    });
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
                      'Late if punch-in is after Punch In + buffer. Buffer grace applies only for N days/month; after that (or outside buffer) = half day + salary cut.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                  foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                ),
                child: const Text('Save Policy', style: TextStyle(fontWeight: FontWeight.w800)),
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
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _maxBufDaysCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Buffer days / month',
                    border: OutlineInputBorder(),
                    isDense: true,
                    helperText: 'e.g. 2',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Half-day windows',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _editHalfWindow(null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          Text(
            'If check-in and check-out fall entirely inside a window (e.g. 10:00–14:30), that day is half day.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : const Color(0xFF607D8B),
            ),
          ),
          const SizedBox(height: 8),
          if (_halfWindows.isEmpty)
            Text(
              'No half-day windows configured.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            )
          else
            ...List.generate(_halfWindows.length, (i) {
              final w = _halfWindows[i];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${w.punchIn} → ${w.punchOut}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Half day if punches stay in this window'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _editHalfWindow(i),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => setState(() => _halfWindows.removeAt(i)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _DayOverrideCard extends ConsumerStatefulWidget {
  const _DayOverrideCard({required this.date, required this.globalPolicy});

  final String date;
  final AttendancePolicy globalPolicy;

  @override
  ConsumerState<_DayOverrideCard> createState() => _DayOverrideCardState();
}

class _DayOverrideCardState extends ConsumerState<_DayOverrideCard> {
  late TextEditingController _inCtrl;
  late TextEditingController _outCtrl;
  late TextEditingController _inBufCtrl;
  late TextEditingController _outBufCtrl;
  AttendancePolicyDayOverride? _override;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _inCtrl = TextEditingController(text: widget.globalPolicy.defaultPunchInTime);
    _outCtrl = TextEditingController(text: widget.globalPolicy.defaultPunchOutTime);
    _inBufCtrl = TextEditingController(text: '${widget.globalPolicy.punchInBufferMinutes}');
    _outBufCtrl = TextEditingController(text: '${widget.globalPolicy.punchOutBufferMinutes}');
    _load();
  }

  @override
  void didUpdateWidget(covariant _DayOverrideCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date) _load();
  }

  @override
  void dispose() {
    _inCtrl.dispose();
    _outCtrl.dispose();
    _inBufCtrl.dispose();
    _outBufCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final ov = await repo.getAdminPolicyDayOverride(widget.date);
      if (!mounted) return;
      setState(() {
        _override = ov;
        _inCtrl.text = ov?.defaultPunchInTime ?? widget.globalPolicy.defaultPunchInTime;
        _outCtrl.text = ov?.defaultPunchOutTime ?? widget.globalPolicy.defaultPunchOutTime;
        _inBufCtrl.text = '${ov?.punchInBufferMinutes ?? widget.globalPolicy.punchInBufferMinutes}';
        _outBufCtrl.text = '${ov?.punchOutBufferMinutes ?? widget.globalPolicy.punchOutBufferMinutes}';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
      final repo = ref.read(attendanceRepositoryProvider);
      final saved = await repo.upsertAdminPolicyDayOverride({
        'date': widget.date,
        'defaultPunchInTime': _inCtrl.text.trim(),
        'defaultPunchOutTime': _outCtrl.text.trim(),
        'punchInBufferMinutes': int.tryParse(_inBufCtrl.text.trim()),
        'punchOutBufferMinutes': int.tryParse(_outBufCtrl.text.trim()),
      });
      if (!mounted) return;
      setState(() {
        _override = saved;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Day policy saved for ${widget.date}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _clear() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      await repo.deleteAdminPolicyDayOverride(widget.date);
      if (!mounted) return;
      setState(() {
        _override = null;
        _inCtrl.text = widget.globalPolicy.defaultPunchInTime;
        _outCtrl.text = widget.globalPolicy.defaultPunchOutTime;
        _inBufCtrl.text = '${widget.globalPolicy.punchInBufferMinutes}';
        _outBufCtrl.text = '${widget.globalPolicy.punchOutBufferMinutes}';
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Day override cleared — using global policy')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
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
                      'Policy for ${widget.date}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _override == null
                          ? 'Using global policy. Save to override punch times for this day only.'
                          : 'Custom override active for this day.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                      ),
                    ),
                  ],
                ),
              ),
              if (_override != null)
                TextButton(onPressed: _saving ? null : _clear, child: const Text('Clear')),
              FilledButton(
                onPressed: _saving || _loading ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                  foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                ),
                child: Text(_saving ? 'Saving…' : 'Save Day Policy'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const LinearProgressIndicator()
          else
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
                      labelText: 'Punch In',
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
                      labelText: 'In Buffer',
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
                      labelText: 'Punch Out',
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
                      labelText: 'Out Buffer',
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
    this.onEditPunchIn,
    this.onEditPunchOut,
  });

  final AdminAttendanceEmployeeRow row;
  final VoidCallback onOpen;
  final VoidCallback onAddPunch;
  final VoidCallback? onEditPunchIn;
  final VoidCallback? onEditPunchOut;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inTime = row.firstIn != null ? formatIsoTime(row.firstIn) : '—';
    final outTime = row.lastOut != null ? formatIsoTime(row.lastOut) : '—';
    final firstPunch = row.firstPunch;
    final lastPunch = row.lastPunch;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.15) : const Color(0xFFCFD8DC),
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
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Tooltip(
                    message: firstPunch != null
                        ? 'Edit Punch In (${firstPunch.source ?? 'Biometric'})'
                        : 'Add Punch In',
                    child: InkWell(
                      onTap: onEditPunchIn ?? onAddPunch,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: firstPunch != null
                              ? (isDark ? Colors.teal.withValues(alpha: 0.15) : Colors.teal.shade50)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: firstPunch != null
                                ? (isDark ? Colors.teal.shade700 : Colors.teal.shade200)
                                : Colors.transparent,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'In $inTime',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.edit_outlined,
                              size: 13,
                              color: isDark ? const Color(0xFFC5A059) : const Color(0xFF0F766E),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Tooltip(
                    message: lastPunch != null
                        ? 'Edit Punch Out (${lastPunch.source ?? 'Biometric'})'
                        : 'Add Punch Out',
                    child: InkWell(
                      onTap: onEditPunchOut ?? onAddPunch,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: lastPunch != null
                              ? (isDark ? Colors.amber.withValues(alpha: 0.15) : Colors.amber.shade50)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: lastPunch != null
                                ? (isDark ? Colors.amber.shade700 : Colors.amber.shade200)
                                : Colors.transparent,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Out $outTime',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.edit_outlined,
                              size: 13,
                              color: isDark ? const Color(0xFFC5A059) : const Color(0xFF0F766E),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${row.punches.length} punches',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : const Color(0xFF90A4AE),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
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
  BuildContext context, {
  WidgetRef? ref,
  AdminAttendanceBloc? bloc,
  int? employeeId,
  AttendancePunch? existing,
  String? dateYmd,
  String? defaultType,
}) async {
  final targetEmployeeId = employeeId ?? existing?.employeeId;
  if (targetEmployeeId == null && existing == null) return;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  DateTime selectedDate;
  if (existing != null) {
    selectedDate = DateTime.parse(existing.punchAt).toLocal();
  } else if (dateYmd != null && dateYmd.length >= 10) {
    final parts = dateYmd.split('-');
    selectedDate = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  } else {
    selectedDate = DateTime.now();
  }

  String time = (defaultType?.toUpperCase() == 'OUT') ? '18:30' : '09:30';
  String type = defaultType?.toUpperCase() ?? 'IN';
  String terminal = 'MANUAL';
  String reason = '';

  if (existing != null) {
    final d = DateTime.parse(existing.punchAt).toLocal();
    time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    type = existing.punchType ?? (defaultType?.toUpperCase() ?? 'IN');
    terminal = existing.terminalId ?? 'MANUAL';
    reason = existing.reason ?? '';
  }

  final timeController = TextEditingController(text: time);
  bool saving = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isBiometric = existing != null &&
              (existing.source == 'ESSL' || existing.source == 'ETIMEOFFICE');
          final isApp = existing != null && existing.source == 'MOBILE_APP';

          final dialogTitle = existing == null
              ? 'Add Punch (${type == 'OUT' ? 'Punch Out' : 'Punch In'})'
              : isBiometric
                  ? 'Edit Biometric Punch (${existing.source})'
                  : isApp
                      ? 'Edit Mobile App Punch'
                      : 'Edit Attendance Punch';

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              dialogTitle,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: isDark ? Colors.white : const Color(0xFF212F3D),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (existing != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isBiometric
                            ? Colors.teal.withValues(alpha: 0.12)
                            : isDark
                                ? Colors.white10
                                : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isBiometric
                              ? Colors.teal.withValues(alpha: 0.3)
                              : (isDark ? Colors.white12 : Colors.black12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isBiometric
                                ? Icons.fingerprint_rounded
                                : isApp
                                    ? Icons.phone_android_rounded
                                    : Icons.access_time_filled_rounded,
                            size: 22,
                            color: isBiometric
                                ? Colors.teal
                                : (isDark ? const Color(0xFFC5A059) : const Color(0xFF0F766E)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isBiometric
                                      ? 'Biometric Machine Record (${existing.source})'
                                      : 'Source: ${existing.source ?? 'MANUAL'}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                ),
                                Text(
                                  'Original: ${formatIsoTime(existing.punchAt)} IST${existing.terminalId != null ? ' • Terminal: ${existing.terminalId}' : ''}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  // Date
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked == null) return;
                      setDialogState(() => selectedDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date *',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                      ),
                      child: Text(
                        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Time with picker
                  TextFormField(
                    controller: timeController,
                    decoration: InputDecoration(
                      labelText: 'Time (HH:MM) *',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.access_time_rounded, size: 20),
                        tooltip: 'Select Time',
                        onPressed: () async {
                          final parts = timeController.text.split(':');
                          final initial = TimeOfDay(
                            hour: int.tryParse(parts.isNotEmpty ? parts[0] : '9') ?? 9,
                            minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
                          );
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: initial,
                          );
                          if (picked == null) return;
                          final h = picked.hour.toString().padLeft(2, '0');
                          final m = picked.minute.toString().padLeft(2, '0');
                          timeController.text = '$h:$m';
                          setDialogState(() => time = '$h:$m');
                        },
                      ),
                    ),
                    onChanged: (v) => time = v.trim(),
                  ),
                  const SizedBox(height: 14),
                  // Punch Type Segmented Selector
                  Text(
                    'Punch Type',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'IN',
                          label: Text('Punch In'),
                          icon: Icon(Icons.login_rounded, size: 16),
                        ),
                        ButtonSegment(
                          value: 'OUT',
                          label: Text('Punch Out'),
                          icon: Icon(Icons.logout_rounded, size: 16),
                        ),
                        ButtonSegment(
                          value: 'MANUAL',
                          label: Text('Other'),
                          icon: Icon(Icons.fingerprint_rounded, size: 16),
                        ),
                      ],
                      selected: {
                        type.toUpperCase() == 'OUT'
                            ? 'OUT'
                            : type.toUpperCase() == 'IN'
                                ? 'IN'
                                : 'MANUAL'
                      },
                      onSelectionChanged: (val) {
                        setDialogState(() => type = val.first);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Terminal
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Terminal / Device ID',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: terminal,
                    onChanged: (v) => terminal = v.trim(),
                  ),
                  const SizedBox(height: 12),
                  // Reason (Optional)
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Reason / Admin Note (Optional)',
                      hintText: 'e.g. Biometric device issue, corrected punch time',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: reason,
                    onChanged: (v) => reason = v.trim(),
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
                onPressed: saving
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        try {
                          final currentTime = timeController.text.trim();
                          final ymd =
                              '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                          final punchAt = '${ymd}T$currentTime:00+05:30';
                          if (bloc != null) {
                            if (existing == null) {
                              bloc.add(AdminAttendancePunchAdded(
                                employeeId: targetEmployeeId!,
                                punchAt: punchAt,
                                punchType: type,
                                terminalId: terminal,
                              ));
                            } else {
                              bloc.add(AdminAttendancePunchUpdated(
                                punchId: existing.id,
                                punchAt: punchAt,
                                punchType: type,
                                terminalId: terminal,
                                reason: reason,
                              ));
                            }
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                          } else if (ref != null) {
                            if (existing == null) {
                              await ref.read(attendanceRepositoryProvider).adminAddPunch(
                                    employeeId: targetEmployeeId!,
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
                                    reason: reason,
                                  );
                            }
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Punch saved successfully.')),
                              );
                            }
                            invalidateAttendanceAdminData(ref);
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                            setDialogState(() => saving = false);
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

