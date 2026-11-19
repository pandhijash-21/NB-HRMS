import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../../core/utils/open_url.dart';
import '../../data/attendance_repository.dart';
import '../../domain/attendance_models.dart';

class AdminAttendanceReportScreen extends StatefulWidget {
  const AdminAttendanceReportScreen({super.key});

  @override
  State<AdminAttendanceReportScreen> createState() =>
      _AdminAttendanceReportScreenState();
}

class _AdminAttendanceReportScreenState extends State<AdminAttendanceReportScreen> {
  AttendanceReportMeta? _meta;
  String? _loadError;
  bool _loadingMeta = true;
  bool _exporting = false;

  /// DAY_WISE_MONTHLY | EMPLOYEE_WISE
  String _mode = 'DAY_WISE_MONTHLY';
  late int _year;
  late int _month;
  final Set<String> _selectedFields = {};
  final Set<int> _selectedEmployeeIds = {};
  String _employeeQuery = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loadingMeta = true;
      _loadError = null;
    });
    try {
      final meta = await context.read<AttendanceRepository>().getAttendanceReportMeta();
      if (!mounted) return;
      setState(() {
        _meta = meta;
        _selectedFields
          ..clear()
          ..addAll(meta.defaultFields);
        _loadingMeta = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMeta = false;
        _loadError = e is ApiException ? e.message : e.toString();
      });
    }
  }

  Future<void> _export() async {
    final fields = _selectedFields.toList();
    if (fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one field'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_mode == 'EMPLOYEE_WISE' && _selectedEmployeeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one employee for Employee Wise report'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _exporting = true);
    try {
      final bytes = await context.read<AttendanceRepository>().exportAttendanceReport(
            mode: _mode,
            year: _year,
            month: _month,
            fields: fields,
            employeeIds: _mode == 'EMPLOYEE_WISE' ? _selectedEmployeeIds.toList() : null,
          );
      if (!mounted) return;
      final tag = '$_year-${_month.toString().padLeft(2, '0')}';
      final name = _mode == 'DAY_WISE_MONTHLY'
          ? 'attendance_daywise_$tag.xlsx'
          : 'attendance_employee_$tag.xlsx';
      await downloadBytes(
        bytes,
        name,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded $name'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final border = isDark
        ? const Color(0xFFC5A059).withValues(alpha: 0.18)
        : const Color(0xFFE2E8F0);
    final muted = isDark ? Colors.white54 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        title: const Text('Attendance Report', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: const AppBackButton(fallbackLocation: '/admin/attendance'),
      ),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _loadMeta, child: const Text('Retry')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    Text(
                      'Admins / HR only. Choose report type, month, and columns, then download Excel.',
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                    const SizedBox(height: 16),
                    _sectionCard(
                      cardBg: cardBg,
                      border: border,
                      title: 'Report type',
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            value: 'DAY_WISE_MONTHLY',
                            groupValue: _mode,
                            title: const Text('Day Wise (Monthly)'),
                            subtitle: Text(
                              'All active employees × every day in the month',
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                            onChanged: _exporting
                                ? null
                                : (v) => setState(() => _mode = v ?? _mode),
                          ),
                          RadioListTile<String>(
                            value: 'EMPLOYEE_WISE',
                            groupValue: _mode,
                            title: const Text('Employee Wise'),
                            subtitle: Text(
                              'Selected employee(s) for the month',
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                            onChanged: _exporting
                                ? null
                                : (v) => setState(() => _mode = v ?? _mode),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(
                      cardBg: cardBg,
                      border: border,
                      title: 'Month',
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _month,
                              decoration: const InputDecoration(
                                labelText: 'Month',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: List.generate(12, (i) {
                                final m = i + 1;
                                return DropdownMenuItem(
                                  value: m,
                                  child: Text(_monthName(m)),
                                );
                              }),
                              onChanged: _exporting
                                  ? null
                                  : (v) {
                                      if (v != null) setState(() => _month = v);
                                    },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _year,
                              decoration: const InputDecoration(
                                labelText: 'Year',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: List.generate(6, (i) {
                                final y = DateTime.now().year - 3 + i;
                                return DropdownMenuItem(value: y, child: Text('$y'));
                              }),
                              onChanged: _exporting
                                  ? null
                                  : (v) {
                                      if (v != null) setState(() => _year = v);
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_mode == 'EMPLOYEE_WISE') ...[
                      const SizedBox(height: 12),
                      _sectionCard(
                        cardBg: cardBg,
                        border: border,
                        title: 'Employees (${_selectedEmployeeIds.length} selected)',
                        trailing: TextButton(
                          onPressed: _exporting
                              ? null
                              : () {
                                  final all = _meta?.employees.map((e) => e.employeeId) ?? [];
                                  setState(() {
                                    if (_selectedEmployeeIds.length == (_meta?.employees.length ?? 0)) {
                                      _selectedEmployeeIds.clear();
                                    } else {
                                      _selectedEmployeeIds
                                        ..clear()
                                        ..addAll(all);
                                    }
                                  });
                                },
                          child: Text(
                            _selectedEmployeeIds.length == (_meta?.employees.length ?? 0)
                                ? 'Clear'
                                : 'Select all',
                          ),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              decoration: const InputDecoration(
                                hintText: 'Search name / code',
                                prefixIcon: Icon(Icons.search, size: 18),
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) => setState(() => _employeeQuery = v.trim().toLowerCase()),
                            ),
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 260),
                              child: ListView(
                                shrinkWrap: true,
                                children: [
                                  for (final e in _filteredEmployees)
                                    CheckboxListTile(
                                      dense: true,
                                      value: _selectedEmployeeIds.contains(e.employeeId),
                                      title: Text(
                                        e.fullName,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      subtitle: Text(
                                        [
                                          if (e.employeeCode != null && e.employeeCode!.isNotEmpty) e.employeeCode,
                                          if (e.department != null && e.department!.isNotEmpty) e.department,
                                        ].join(' · '),
                                        style: TextStyle(fontSize: 11, color: muted),
                                      ),
                                      onChanged: _exporting
                                          ? null
                                          : (v) {
                                              setState(() {
                                                if (v == true) {
                                                  _selectedEmployeeIds.add(e.employeeId);
                                                } else {
                                                  _selectedEmployeeIds.remove(e.employeeId);
                                                }
                                              });
                                            },
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _sectionCard(
                      cardBg: cardBg,
                      border: border,
                      title: 'Fields (${_selectedFields.length} selected)',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: _exporting
                                ? null
                                : () => setState(() {
                                      _selectedFields
                                        ..clear()
                                        ..addAll(_meta?.fields.map((f) => f.key) ?? []);
                                    }),
                            child: const Text('All'),
                          ),
                          TextButton(
                            onPressed: _exporting
                                ? null
                                : () => setState(() {
                                      _selectedFields
                                        ..clear()
                                        ..addAll(_meta?.defaultFields ?? []);
                                    }),
                            child: const Text('Defaults'),
                          ),
                          TextButton(
                            onPressed: _exporting ? null : () => setState(_selectedFields.clear),
                            child: const Text('None'),
                          ),
                        ],
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final f in _meta?.fields ?? const <AttendanceReportField>[])
                            FilterChip(
                              label: Text(f.label, style: const TextStyle(fontSize: 12)),
                              selected: _selectedFields.contains(f.key),
                              tooltip: f.description,
                              onSelected: _exporting
                                  ? null
                                  : (sel) {
                                      setState(() {
                                        if (sel) {
                                          _selectedFields.add(f.key);
                                        } else {
                                          _selectedFields.remove(f.key);
                                        }
                                      });
                                    },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _exporting ? null : _export,
                        icon: _exporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.download_rounded),
                        label: Text(_exporting ? 'Generating…' : 'Download Excel'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  List<AttendanceReportEmployee> get _filteredEmployees {
    final list = _meta?.employees ?? const <AttendanceReportEmployee>[];
    if (_employeeQuery.isEmpty) return list;
    return list.where((e) {
      final hay = '${e.fullName} ${e.employeeCode ?? ''} ${e.department ?? ''}'.toLowerCase();
      return hay.contains(_employeeQuery);
    }).toList();
  }

  String _monthName(int m) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[m - 1];
  }

  Widget _sectionCard({
    required Color cardBg,
    required Color border,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
