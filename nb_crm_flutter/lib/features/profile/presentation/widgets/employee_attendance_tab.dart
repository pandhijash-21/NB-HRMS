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
                    value: useGlobal,
                    onChanged: (v) => setLocal(() => useGlobal = v),
                  ),
                  if (!useGlobal) ...[
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
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.settings,
    required this.canEdit,
    required this.onEdit,
  });

  final EmployeeAttendanceSettings settings;
  final bool canEdit;
  final VoidCallback onEdit;

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
                _chip('Present', '${summary.presentDays} days'),
                _chip('Working hours', '${summary.totalWorkingHours}h'),
                _chip('Late', '${summary.lateDays}'),
                _chip('Leave days', '${summary.leaveDaysInMonth}'),
                _chip('Absent*', '${summary.absentDays}'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '* Days in month with no punch recorded',
              style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Chip(
      label: Text('$label: $value', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
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
            return ListTile(
              dense: true,
              title: Text(day.date, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              subtitle: Text(
                hasPunch
                    ? '${_formatIstTime(day.firstIn)} → ${_formatIstTime(day.lastOut)} · ${_formatHours(day.totalMinutes)}'
                    : 'No punch',
              ),
              trailing: hasPunch
                  ? (day.isLate == true
                      ? const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18)
                      : const Icon(Icons.check_circle_outline, color: Colors.green, size: 18))
                  : const Icon(Icons.remove_circle_outline, color: Colors.grey, size: 18),
            );
          }),
        ],
      ),
    );
  }
}
