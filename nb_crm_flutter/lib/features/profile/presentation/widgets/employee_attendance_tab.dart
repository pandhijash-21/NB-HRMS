import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../attendance/domain/attendance_models.dart';
import '../../../attendance/presentation/attendance_providers.dart';
import '../../../leave/presentation/widgets/employee_leave_tab.dart';

const _monthLabels = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatIstTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '—';
  final local = dt.toLocal();
  final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final m = local.minute.toString().padLeft(2, '0');
  final ampm = local.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $ampm';
}

String _formatHours(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

class EmployeeAttendanceTab extends ConsumerStatefulWidget {
  const EmployeeAttendanceTab({
    super.key,
    required this.employeeId,
    this.canManageSettings = false,
  });

  final int employeeId;
  final bool canManageSettings;

  @override
  ConsumerState<EmployeeAttendanceTab> createState() => _EmployeeAttendanceTabState();
}

class _EmployeeAttendanceTabState extends ConsumerState<EmployeeAttendanceTab> {
  bool _showLeavePanel = false;

  @override
  Widget build(BuildContext context) {
    final monthFilter = ref.watch(profileAttendanceMonthProvider);
    final settingsAsync = ref.watch(employeeAttendanceSettingsProvider(widget.employeeId));
    final summaryAsync = ref.watch(
      employeeMonthlyAttendanceProvider((
        employeeId: widget.employeeId,
        year: monthFilter.year,
        month: monthFilter.month,
      )),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        settingsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Could not load punch timings: $e'),
          data: (settings) => _PolicyCard(
            settings: settings,
            canEdit: widget.canManageSettings,
            onEdit: () => _showEditSettings(context, settings),
            onResetBiometrics: () => _showResetBiometrics(context),
          ),
        ),
        const SizedBox(height: 16),
        summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Could not load attendance: $e'),
          data: (summary) => _StatsCard(summary: summary.stats),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() => _showLeavePanel = !_showLeavePanel),
          icon: Icon(_showLeavePanel ? Icons.expand_less : Icons.expand_more),
          label: Text(_showLeavePanel ? 'Hide leave' : 'Manage leave'),
        ),
        if (_showLeavePanel) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 420,
            child: EmployeeLeaveTab(employeeId: widget.employeeId),
          ),
        ],
        const SizedBox(height: 16),
        _MonthPicker(
          year: monthFilter.year,
          month: monthFilter.month,
          onYearChanged: (y) => ref
              .read(profileAttendanceMonthProvider.notifier)
              .setMonth(y, monthFilter.month),
          onMonthChanged: (m) => ref
              .read(profileAttendanceMonthProvider.notifier)
              .setMonth(monthFilter.year, m),
        ),
        const SizedBox(height: 12),
        summaryAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (summary) => _DailyLogList(days: summary.days),
        ),
      ],
    );
  }

  Future<void> _showEditSettings(BuildContext context, EmployeeAttendanceSettings settings) async {
    var useGlobal = settings.useGlobalPolicy;
    final inCtrl = TextEditingController(text: settings.punchInTime ?? settings.effective['punchInTime']?.toString() ?? '09:00');
    final outCtrl = TextEditingController(text: settings.punchOutTime ?? settings.effective['punchOutTime']?.toString() ?? '15:30');
    final inBufCtrl = TextEditingController(
      text: '${settings.punchInBufferMinutes ?? settings.effective['punchInBufferMinutes'] ?? 10}',
    );
    final outBufCtrl = TextEditingController(
      text: '${settings.punchOutBufferMinutes ?? settings.effective['punchOutBufferMinutes'] ?? 10}',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Punch timings'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use global policy'),
                    subtitle: const Text(
                      'Off = this employee’s punch in/out and buffers override global policy for late / half-day.',
                    ),
                    value: useGlobal,
                    onChanged: (v) => setLocal(() => useGlobal = v),
                  ),
                  if (!useGlobal) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Personal timings apply only to this employee.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(ctx).textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: inCtrl,
                      decoration: const InputDecoration(labelText: 'Punch in (HH:MM)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: outCtrl,
                      decoration: const InputDecoration(labelText: 'Punch out (HH:MM)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: inBufCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'In buffer (minutes)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: outBufCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Out buffer (minutes)', border: OutlineInputBorder()),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;

    try {
      await ref.read(attendanceRepositoryProvider).updateEmployeeSettings(
        widget.employeeId,
        {
          'useGlobalPolicy': useGlobal,
          if (!useGlobal) ...{
            'punchInTime': inCtrl.text.trim(),
            'punchOutTime': outCtrl.text.trim(),
            'punchInBufferMinutes': int.tryParse(inBufCtrl.text.trim()) ?? 10,
            'punchOutBufferMinutes': int.tryParse(outBufCtrl.text.trim()) ?? 10,
          },
        },
      );
      ref.invalidate(employeeAttendanceSettingsProvider(widget.employeeId));
      ref.invalidate(employeeMonthlyAttendanceProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Punch timings updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showResetBiometrics(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Biometric Registration'),
        content: const Text(
          'Are you sure you want to reset this employee\'s registered fingerprint/Face ID? '
          'Once reset, they will need to register it again from their mobile app to punch.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await ref.read(attendanceRepositoryProvider).resetEmployeeBiometrics(widget.employeeId);
      ref.invalidate(employeeAttendanceSettingsProvider(widget.employeeId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fingerprint registration reset successfully.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.settings,
    required this.canEdit,
    required this.onEdit,
    required this.onResetBiometrics,
  });

  final EmployeeAttendanceSettings settings;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onResetBiometrics;

  @override
  Widget build(BuildContext context) {
    final effective = settings.effective;
    final source = effective['source']?.toString() ?? 'GLOBAL';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule_rounded, color: Color(0xFFC5A059)),
                const SizedBox(width: 8),
                Text(
                  'Punch window',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (canEdit)
                  IconButton(tooltip: 'Edit timings', onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              source == 'EMPLOYEE' ? 'Custom timings for this employee' : 'Using global policy',
              style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
            ),
            const SizedBox(height: 12),
            _timingRow('Punch in', effective['punchInTime']?.toString() ?? '—', effective['punchInBufferMinutes']),
            _timingRow('Punch out', effective['punchOutTime']?.toString() ?? '—', effective['punchOutBufferMinutes']),
            if (_lateAfterLabel(effective) != null) ...[
              const SizedBox(height: 4),
              Text(
                'Late only after ${_lateAfterLabel(effective)} (punch-in + buffer)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.fingerprint_rounded, color: Color(0xFFC5A059), size: 20),
                const SizedBox(width: 8),
                const Text('Biometrics (Fingerprint/Face ID)', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  settings.biometricToken != null && settings.biometricToken!.isNotEmpty
                      ? 'Registered'
                      : 'Not Registered',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: settings.biometricToken != null && settings.biometricToken!.isNotEmpty
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ],
            ),
            if (canEdit && settings.biometricToken != null && settings.biometricToken!.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onResetBiometrics,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Reset Fingerprint/Face ID Registration'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _timingRow(String label, String time, Object? buffer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text('$time  (+${buffer ?? 0}m buffer)', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  static String? _lateAfterLabel(Map<String, dynamic> effective) {
    final punchIn = effective['punchInTime']?.toString();
    if (punchIn == null || punchIn.isEmpty) return null;
    final parts = punchIn.split(':');
    if (parts.length < 2) return null;
    final hh = int.tryParse(parts[0]);
    final mm = int.tryParse(parts[1]);
    if (hh == null || mm == null) return null;
    final buf = int.tryParse('${effective['punchInBufferMinutes'] ?? 0}') ?? 0;
    final total = hh * 60 + mm + buf;
    final h24 = (total ~/ 60) % 24;
    final m = total % 60;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final ampm = h24 >= 12 ? 'PM' : 'AM';
    return '$h12:${m.toString().padLeft(2, '0')} $ampm';
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.summary});

  final AttendanceMonthlyStats summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This month',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _chip(context, 'Present', '${summary.presentDays} days'),
                _chip(context, 'Working hours', '${summary.totalWorkingHours}h'),
                _chip(context, 'Late', '${summary.lateDays}'),
                _chip(context, 'Approved leave', '${summary.leaveDays > 0 ? summary.leaveDays : summary.leaveDaysInMonth}'),
                _chip(context, 'Holiday', '${summary.holidayDays}'),
                _chip(context, 'Absent*', '${summary.absentDays}'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '* Absent = no punch, and not holiday / approved leave',
              style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Chip(
      label: Text(
        '$label: $value',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF374151),
        ),
      ),
      backgroundColor: isDark 
          ? const Color(0xFF2E2E2E)
          : const Color(0xFFF3F4F6),
      side: BorderSide(
        color: isDark 
            ? const Color(0xFF3E3E3E)
            : const Color(0xFFE5E7EB),
        width: 1,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({
    required this.year,
    required this.month,
    required this.onYearChanged,
    required this.onMonthChanged,
  });

  final int year;
  final int month;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => onYearChanged(year - 1),
              icon: const Icon(Icons.chevron_left),
            ),
            Text('$year', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            IconButton(
              onPressed: year >= now.year ? null : () => onYearChanged(year + 1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(12, (i) {
            final m = i + 1;
            final selected = m == month;
            final isFuture = year > now.year || (year == now.year && m > now.month);
            return ChoiceChip(
              label: Text(
                _monthLabels[i],
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              selected: selected,
              selectedColor: isDark ? const Color(0xFFC5A059) : Colors.black,
              checkmarkColor: Colors.white,
              onSelected: isFuture ? null : (_) => onMonthChanged(m),
            );
          }),
        ),
      ],
    );
  }
}

class _DailyLogList extends StatelessWidget {
  const _DailyLogList({required this.days});

  final List<AdminAttendanceHistoryDay> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const Text('No days in range.');
    }
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text('Daily log', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            subtitle: const Text('Punch in · punch out · working hours'),
          ),
          const Divider(height: 1),
          ...days.map((day) {
            final hasPunch = day.firstIn != null;
            final status = (day.dayStatus ?? (hasPunch ? 'PRESENT' : 'ABSENT')).toUpperCase();
            final isLeave = status == 'LEAVE';
            final isHoliday = status == 'HOLIDAY';
            final isAbsent = !hasPunch && !isHoliday && !isLeave;
            final subtitle = hasPunch
                ? '${_formatIstTime(day.firstIn)} → ${_formatIstTime(day.lastOut)} · ${_formatHours(day.totalMinutes)}'
                : isHoliday
                    ? 'Holiday (weekly off / public holiday)'
                    : isLeave
                        ? 'On approved leave'
                        : 'Absent (no punch)';
            final trailing = hasPunch
                ? (day.isLate == true
                    ? const Tooltip(
                        message: 'Late (after punch-in + buffer)',
                        child: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                      )
                    : const Icon(Icons.check_circle_outline, color: Colors.green, size: 18))
                : isHoliday
                    ? const Tooltip(
                        message: 'Holiday',
                        child: Icon(Icons.celebration_rounded, color: Colors.purple, size: 18),
                      )
                    : isLeave
                        ? const Icon(Icons.beach_access, color: Colors.blue, size: 18)
                        : Icon(
                            Icons.remove_circle_outline,
                            color: isAbsent ? Colors.grey : Colors.grey,
                            size: 18,
                          );
            return ListTile(
              dense: true,
              title: Text(day.date, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              subtitle: Text(subtitle),
              trailing: trailing,
            );
          }),
        ],
      ),
    );
  }
}
