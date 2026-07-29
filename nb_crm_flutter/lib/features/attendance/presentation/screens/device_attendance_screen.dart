import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../leave/presentation/widgets/leave_shared_widgets.dart';
import '../../domain/attendance_models.dart';
import '../attendance_providers.dart';

class DeviceAttendanceScreen extends ConsumerStatefulWidget {
  const DeviceAttendanceScreen({super.key});

  @override
  ConsumerState<DeviceAttendanceScreen> createState() =>
      _DeviceAttendanceScreenState();
}

class _DeviceAttendanceScreenState extends ConsumerState<DeviceAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Device Attendance',
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
          preferredSize: const Size.fromHeight(49.5),
          child: Column(
            children: [
              TabBar(
                controller: _tabs,
                labelColor: const Color(0xFFC5A059),
                unselectedLabelColor:
                    isDark ? Colors.white54 : const Color(0xFF607D8B),
                indicatorColor: const Color(0xFFC5A059),
                tabs: const [
                  Tab(text: 'Raw machine data'),
                  Tab(text: 'Integrate'),
                ],
              ),
              Container(
                color: isDark
                    ? const Color(0xFFC5A059).withOpacity(0.15)
                    : const Color(0xFFCFD8DC),
                height: 1.5,
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _RawMachineTab(),
          _IntegrateTab(),
        ],
      ),
    );
  }
}

class _RawMachineTab extends ConsumerStatefulWidget {
  const _RawMachineTab();

  @override
  ConsumerState<_RawMachineTab> createState() => _RawMachineTabState();
}

class _RawMachineTabState extends ConsumerState<_RawMachineTab> {
  late String _from;
  late String _to;
  final _empcodeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  List<DevicePunchPreviewRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = formatDateYmd(now.subtract(const Duration(days: 1)));
    _to = formatDateYmd(now);
  }

  @override
  void dispose() {
    _empcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFrom() async {
    final parts = _from.split('-');
    final initial = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _from = formatDateYmd(picked));
  }

  Future<void> _pickTo() async {
    final parts = _to.split('-');
    final initial = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _to = formatDateYmd(picked));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref.read(attendanceRepositoryProvider).getDevicePreview(
            from: _from,
            to: _to,
            empcode: _empcodeCtrl.text.trim().isEmpty
                ? null
                : _empcodeCtrl.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
        _rows = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final matched = _rows.where((r) => r.matchedEmployeeId != null).length;
    final unmatched = _rows.length - matched;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        Text(
          'Live punches from eTimeOffice. Matching uses Punch ID only (machine Empcode).',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : const Color(0xFF607D8B),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _pickFrom,
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: Text('From $_from'),
            ),
            OutlinedButton.icon(
              onPressed: _pickTo,
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: Text('To $_to'),
            ),
            SizedBox(
              width: 160,
              child: TextField(
                controller: _empcodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Empcode (optional)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _loading ? null : _load,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC5A059),
                foregroundColor: Colors.white,
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: const Text('Load preview'),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        if (_rows.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '${_rows.length} punches · $matched matched · $unmatched unmatched',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF212F3D),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (!_loading && _rows.isEmpty && _error == null)
          Text(
            'Pick a range and load preview to inspect raw machine punches.',
            style: TextStyle(
              color: isDark ? Colors.white38 : const Color(0xFF90A4AE),
            ),
          ),
        for (final row in _rows)
          _PreviewCard(row: row, isDark: isDark),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.row, required this.isDark});

  final DevicePunchPreviewRow row;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final matched = row.matchedEmployeeId != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFFC5A059).withOpacity(0.15)
              : const Color(0xFFCFD8DC),
        ),
      ),
      child: Row(
        children: [
          Icon(
            matched ? Icons.link_rounded : Icons.link_off_rounded,
            color: matched ? const Color(0xFF16a34a) : const Color(0xFFdc2626),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Empcode ${row.empcode}${row.name != null && row.name!.isNotEmpty ? ' · ${row.name}' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  row.punchDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                  ),
                ),
                if (row.mcid != null || row.mFlag != null)
                  Text(
                    [
                      if (row.mcid != null) 'MC ${row.mcid}',
                      if (row.mFlag != null) 'Flag ${row.mFlag}',
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : const Color(0xFF90A4AE),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            matched ? 'Emp #${row.matchedEmployeeId}' : 'No Punch ID',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: matched ? const Color(0xFF16a34a) : const Color(0xFFdc2626),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntegrateTab extends ConsumerStatefulWidget {
  const _IntegrateTab();

  @override
  ConsumerState<_IntegrateTab> createState() => _IntegrateTabState();
}

class _IntegrateTabState extends ConsumerState<_IntegrateTab> {
  late String _from;
  late String _to;
  final _empcodeCtrl = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = formatDateYmd(now.subtract(const Duration(days: 7)));
    _to = formatDateYmd(now);
  }

  @override
  void dispose() {
    _empcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFrom() async {
    final parts = _from.split('-');
    final initial = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _from = formatDateYmd(picked));
  }

  Future<void> _pickTo() async {
    final parts = _to.split('-');
    final initial = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _to = formatDateYmd(picked));
  }

  String _formatResult(DeviceSyncResult r) {
    final unmatched = r.unmatchedCodes.isEmpty
        ? ''
        : ' Unmatched codes: ${r.unmatchedCodes.take(12).join(', ')}'
            '${r.unmatchedCodes.length > 12 ? '…' : ''}';
    return 'Fetched ${r.fetched} · inserted ${r.inserted} · '
        'skipped unmatched ${r.skippedUnmatched}.$unmatched';
  }

  Future<void> _syncNow() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await ref.read(attendanceRepositoryProvider).syncDeviceNow();
      ref.invalidate(deviceAttendanceStatusProvider);
      invalidateAttendanceAdminData(ref);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = _formatResult(result);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = '$e';
      });
    }
  }

  Future<void> _backfill() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await ref.read(attendanceRepositoryProvider).backfillDevice(
            from: _from,
            to: _to,
            empcode: _empcodeCtrl.text.trim().isEmpty
                ? null
                : _empcodeCtrl.text.trim(),
          );
      ref.invalidate(deviceAttendanceStatusProvider);
      invalidateAttendanceAdminData(ref);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = _formatResult(result);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusAsync = ref.watch(deviceAttendanceStatusProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        Text(
          'Pull punches into HRMS attendance (calendar & admin day view). '
          'Employees need Punch ID set to the machine Empcode.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : const Color(0xFF607D8B),
          ),
        ),
        const SizedBox(height: 16),
        statusAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFC5A059)),
            ),
          ),
          error: (e, _) => Text('$e', style: const TextStyle(color: Colors.red)),
          data: (status) => _StatusCard(status: status, isDark: isDark),
        ),
        const SizedBox(height: 20),
        Text(
          'Incremental sync',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Uses DownloadLastPunchData from the last cursor.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : const Color(0xFF607D8B),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _busy ? null : _syncNow,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF16a34a),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.sync_rounded, size: 18),
          label: const Text('Sync now'),
        ),
        const SizedBox(height: 28),
        Text(
          'Backfill range',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickFrom,
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: Text('From $_from'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickTo,
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: Text('To $_to'),
            ),
            SizedBox(
              width: 160,
              child: TextField(
                controller: _empcodeCtrl,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Empcode (optional)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _backfill,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC5A059),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.history_rounded, size: 18),
              label: const Text('Backfill into attendance'),
            ),
          ],
        ),
        if (_busy) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(
            color: Color(0xFFC5A059),
            backgroundColor: Color(0x33C5A059),
          ),
        ],
        if (_message != null) ...[
          const SizedBox(height: 16),
          Text(
            _message!,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : const Color(0xFF37474F),
            ),
          ),
        ],
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: () => context.go('/admin/attendance'),
          icon: const Icon(Icons.calendar_view_day_rounded, size: 18),
          label: const Text('Open Manage Attendance'),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.isDark});

  final DeviceAttendanceStatus status;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final e = status.etimeoffice;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFFC5A059).withOpacity(0.15)
              : const Color(0xFFCFD8DC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                e.configured ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                color: e.configured
                    ? const Color(0xFF16a34a)
                    : const Color(0xFFdc2626),
              ),
              const SizedBox(width: 10),
              Text(
                'eTimeOffice ${e.configured ? 'configured' : 'not configured'}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Last sync: ${e.lastSyncedAt ?? 'never'}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : const Color(0xFF607D8B),
            ),
          ),
          Text(
            'Cursor: ${e.cursor ?? '—'}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : const Color(0xFF607D8B),
            ),
          ),
          Text(
            'Employees with Punch ID: ${status.employeesWithPunchId}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : const Color(0xFF607D8B),
            ),
          ),
          if (status.esslMssql.note != null) ...[
            const SizedBox(height: 8),
            Text(
              'MSSQL stub: ${status.esslMssql.note}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : const Color(0xFF90A4AE),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
