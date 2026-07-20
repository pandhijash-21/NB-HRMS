import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../attendance/domain/attendance_models.dart';
import '../../../attendance/presentation/attendance_providers.dart';

class EditAttendanceSettingsTab extends ConsumerStatefulWidget {
  const EditAttendanceSettingsTab({super.key, required this.employeeId});

  final int employeeId;

  @override
  ConsumerState<EditAttendanceSettingsTab> createState() => _EditAttendanceSettingsTabState();
}

class _EditAttendanceSettingsTabState extends ConsumerState<EditAttendanceSettingsTab> {
  bool _useGlobal = true;
  bool _dirty = false;
  bool _loaded = false;
  late final TextEditingController _inCtrl;
  late final TextEditingController _outCtrl;
  late final TextEditingController _inBufCtrl;
  late final TextEditingController _outBufCtrl;

  @override
  void initState() {
    super.initState();
    _inCtrl = TextEditingController(text: '09:00');
    _outCtrl = TextEditingController(text: '15:30');
    _inBufCtrl = TextEditingController(text: '10');
    _outBufCtrl = TextEditingController(text: '10');
  }

  @override
  void dispose() {
    _inCtrl.dispose();
    _outCtrl.dispose();
    _inBufCtrl.dispose();
    _outBufCtrl.dispose();
    super.dispose();
  }

  void _loadFromSettings(EmployeeAttendanceSettings settings) {
    _useGlobal = settings.useGlobalPolicy;
    _inCtrl.text = settings.punchInTime ?? settings.effective['punchInTime']?.toString() ?? '09:00';
    _outCtrl.text = settings.punchOutTime ?? settings.effective['punchOutTime']?.toString() ?? '15:30';
    _inBufCtrl.text = '${settings.punchInBufferMinutes ?? settings.effective['punchInBufferMinutes'] ?? 10}';
    _outBufCtrl.text = '${settings.punchOutBufferMinutes ?? settings.effective['punchOutBufferMinutes'] ?? 10}';
    _dirty = false;
    _loaded = true;
  }

  Future<void> _save() async {
    try {
      await ref.read(attendanceRepositoryProvider).updateEmployeeSettings(
        widget.employeeId,
        {
          'useGlobalPolicy': _useGlobal,
          if (!_useGlobal) ...{
            'punchInTime': _inCtrl.text.trim(),
            'punchOutTime': _outCtrl.text.trim(),
            'punchInBufferMinutes': int.tryParse(_inBufCtrl.text.trim()) ?? 10,
            'punchOutBufferMinutes': int.tryParse(_outBufCtrl.text.trim()) ?? 10,
          },
        },
      );
      ref.invalidate(employeeAttendanceSettingsProvider(widget.employeeId));
      ref.invalidate(employeeMonthlyAttendanceProvider);
      if (mounted) {
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Punch settings saved')),
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

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(employeeAttendanceSettingsProvider(widget.employeeId));

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load settings: $e')),
      data: (settings) {
        if (!_loaded) {
          _loadFromSettings(settings);
        }

        final effective = settings.effective;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
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
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Override global policy for this employee. Affects late/half-day rules and salary.',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Currently applied',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'In: ${effective['punchInTime']} (+${effective['punchInBufferMinutes']}m)',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Out: ${effective['punchOutTime']} (+${effective['punchOutBufferMinutes']}m)',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            effective['source'] == 'EMPLOYEE' ? 'Custom for this employee' : 'Global policy',
                            style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Use global policy'),
                      subtitle: const Text('Institution default punch times'),
                      value: _useGlobal,
                      onChanged: (v) => setState(() {
                        _useGlobal = v;
                        _dirty = true;
                      }),
                    ),
                    if (!_useGlobal) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _inCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Punch in (HH:MM)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _outCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Punch out (HH:MM)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _inBufCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'In buffer (minutes)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _outBufCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Out buffer (minutes)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _dirty ? _save : null,
                        child: const Text('Save punch settings'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
