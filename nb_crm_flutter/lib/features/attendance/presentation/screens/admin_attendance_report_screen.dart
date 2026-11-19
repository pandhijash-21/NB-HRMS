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
  static const _accent = Color(0xFF0F766E);
  static const _ink = Color(0xFF0F172A);

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
        SnackBar(content: Text('Downloaded $name'), backgroundColor: Colors.green.shade700),
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
        ? const Color(0xFFC5A059).withValues(alpha: 0.2)
        : const Color(0xFFE2E8F0);
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final titleColor = isDark ? Colors.white : _ink;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Attendance Report',
          style: TextStyle(fontWeight: FontWeight.w700, color: titleColor),
        ),
        leading: const AppBackButton(fallbackLocation: '/admin/attendance'),
      ),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 14),
                        FilledButton(onPressed: _loadMeta, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                        children: [
                          Text(
                            'Pick report type, month, and Excel columns. Admins / HR only.',
                            style: TextStyle(fontSize: 13.5, height: 1.35, color: muted),
                          ),
                          const SizedBox(height: 18),

                          // Report type
                          Text('Report type', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: muted)),
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 640;
                              final cards = [
                                _ModeCard(
                                  selected: _mode == 'DAY_WISE_MONTHLY',
                                  icon: Icons.calendar_view_month_rounded,
                                  title: 'Day Wise (Monthly)',
                                  subtitle: 'All employees × each day in the month',
                                  enabled: !_exporting,
                                  onTap: () => setState(() => _mode = 'DAY_WISE_MONTHLY'),
                                  isDark: isDark,
                                ),
                                _ModeCard(
                                  selected: _mode == 'EMPLOYEE_WISE',
                                  icon: Icons.person_search_rounded,
                                  title: 'Employee Wise',
                                  subtitle: 'Only the employees you select',
                                  enabled: !_exporting,
                                  onTap: () => setState(() => _mode = 'EMPLOYEE_WISE'),
                                  isDark: isDark,
                                ),
                              ];
                              if (wide) {
                                return Row(
                                  children: [
                                    Expanded(child: cards[0]),
                                    const SizedBox(width: 12),
                                    Expanded(child: cards[1]),
                                  ],
                                );
                              }
                              return Column(
                                children: [
                                  cards[0],
                                  const SizedBox(height: 10),
                                  cards[1],
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 18),
                          _CardShell(
                            cardBg: cardBg,
                            border: border,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Period',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: titleColor),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: DropdownButtonFormField<int>(
                                        value: _month,
                                        decoration: _inputDeco('Month', isDark),
                                        items: List.generate(12, (i) {
                                          final m = i + 1;
                                          return DropdownMenuItem(value: m, child: Text(_monthName(m)));
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
                                      flex: 2,
                                      child: DropdownButtonFormField<int>(
                                        value: _year,
                                        decoration: _inputDeco('Year', isDark),
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
                              ],
                            ),
                          ),

                          if (_mode == 'EMPLOYEE_WISE') ...[
                            const SizedBox(height: 14),
                            _CardShell(
                              cardBg: cardBg,
                              border: border,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Employees',
                                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: titleColor),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _accent.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${_selectedEmployeeIds.length} selected',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: _accent,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      TextButton(
                                        onPressed: _exporting
                                            ? null
                                            : () {
                                                final all = _meta?.employees.map((e) => e.employeeId) ?? [];
                                                setState(() {
                                                  if (_selectedEmployeeIds.length ==
                                                      (_meta?.employees.length ?? 0)) {
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
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    decoration: _inputDeco('Search name / code', isDark).copyWith(
                                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                                    ),
                                    onChanged: (v) =>
                                        setState(() => _employeeQuery = v.trim().toLowerCase()),
                                  ),
                                  const SizedBox(height: 10),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 240),
                                    child: Material(
                                      color: isDark ? const Color(0xFF161412) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        itemCount: _filteredEmployees.length,
                                        separatorBuilder: (_, __) => Divider(
                                          height: 1,
                                          color: border,
                                        ),
                                        itemBuilder: (context, index) {
                                          final e = _filteredEmployees[index];
                                          final selected = _selectedEmployeeIds.contains(e.employeeId);
                                          return CheckboxListTile(
                                            dense: true,
                                            value: selected,
                                            activeColor: _accent,
                                            controlAffinity: ListTileControlAffinity.leading,
                                            title: Text(
                                              e.fullName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13.5,
                                                color: titleColor,
                                              ),
                                            ),
                                            subtitle: Text(
                                              [
                                                if ((e.employeeCode ?? '').isNotEmpty) e.employeeCode,
                                                if ((e.department ?? '').isNotEmpty) e.department,
                                              ].join(' · '),
                                              style: TextStyle(fontSize: 11.5, color: muted),
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
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),
                          _CardShell(
                            cardBg: cardBg,
                            border: border,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: 'Columns',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: titleColor,
                                              ),
                                            ),
                                            TextSpan(
                                              text: '  ·  ${_selectedFields.length} selected',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12.5,
                                                color: muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    _LinkAction(
                                      label: 'All',
                                      onTap: _exporting
                                          ? null
                                          : () => setState(() {
                                                _selectedFields
                                                  ..clear()
                                                  ..addAll(_meta?.fields.map((f) => f.key) ?? []);
                                              }),
                                    ),
                                    _LinkAction(
                                      label: 'Defaults',
                                      onTap: _exporting
                                          ? null
                                          : () => setState(() {
                                                _selectedFields
                                                  ..clear()
                                                  ..addAll(_meta?.defaultFields ?? []);
                                              }),
                                    ),
                                    _LinkAction(
                                      label: 'None',
                                      onTap: _exporting
                                          ? null
                                          : () => setState(_selectedFields.clear),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Only selected columns appear in the Excel file.',
                                  style: TextStyle(fontSize: 12, color: muted),
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 10,
                                  children: [
                                    for (final f in _meta?.fields ?? const <AttendanceReportField>[])
                                      _FieldChip(
                                        label: f.label,
                                        description: f.description,
                                        selected: _selectedFields.contains(f.key),
                                        enabled: !_exporting,
                                        isDark: isDark,
                                        onTap: () {
                                          setState(() {
                                            if (_selectedFields.contains(f.key)) {
                                              _selectedFields.remove(f.key);
                                            } else {
                                              _selectedFields.add(f.key);
                                            }
                                          });
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 88),
                        ],
                      ),
                    ),
                    // Sticky download bar
                    Material(
                      elevation: 8,
                      color: isDark ? const Color(0xFF1A1816) : Colors.white,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                          child: SizedBox(
                            height: 50,
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _exporting ? null : _export,
                              icon: _exporting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.download_rounded, size: 20),
                              label: Text(
                                _exporting ? 'Generating Excel…' : 'Download Excel',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: _accent.withValues(alpha: 0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
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

  InputDecoration _inputDeco(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: isDark ? const Color(0xFF161412) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _accent, width: 1.4),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.cardBg,
    required this.border,
    required this.child,
  });

  final Color cardBg;
  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
    required this.isDark,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? (isDark ? const Color(0xFF0F766E).withValues(alpha: 0.22) : const Color(0xFFCCFBF1))
        : (isDark ? const Color(0xFF1E1B18) : Colors.white);
    final border = selected
        ? const Color(0xFF0F766E)
        : (isDark ? const Color(0xFFC5A059).withValues(alpha: 0.2) : const Color(0xFFE2E8F0));
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: selected ? 1.6 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF0F766E)
                      : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, height: 1.3, color: muted),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF0F766E), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkAction extends StatelessWidget {
  const _LinkAction({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF0F766E),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
    );
  }
}

class _FieldChip extends StatelessWidget {
  const _FieldChip({
    required this.label,
    required this.description,
    required this.selected,
    required this.enabled,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool selected;
  final bool enabled;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? const Color(0xFF0F766E)
        : (isDark ? const Color(0xFF2A2622) : const Color(0xFFF8FAFC));
    final fg = selected
        ? Colors.white
        : (isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF334155));
    final border = selected
        ? const Color(0xFF0F766E)
        : (isDark ? Colors.white24 : const Color(0xFFCBD5E1));

    return Tooltip(
      message: description,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 15,
                  color: selected ? Colors.white : fg.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
