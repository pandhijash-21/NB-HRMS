import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/header_action_button.dart';

import '../../domain/leave_models.dart';
import '../leave_providers.dart';

class AdminLeavesSettingsScreen extends ConsumerWidget {
  const AdminLeavesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typesAsync = ref.watch(adminLeaveTypesProvider);
    final settingsAsync = ref.watch(adminLeaveSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Leave Settings',
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
          onPressed: () => context.go('/admin/leaves'),
        ),
        actions: [
          HeaderActionButton(
            tooltip: 'Add leave type',
            label: 'Add leave type',
            icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFFC5A059)),
            onPressed: () => _showTypeDialog(context, ref, isDark),
          ),
          HeaderActionButton(
            tooltip: 'Run year-end',
            label: 'Run year-end',
            icon: const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFFC5A059)),
            onPressed: () => _runYearEnd(context, ref, isDark),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
            height: 1.5,
          ),
        ),
      ),
      body: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0.0, 30.0 * (1.0 - value)),
            child: Opacity(opacity: value, child: child),
          );
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            Row(
              children: [
                const Icon(Icons.category_rounded, color: Color(0xFFC5A059), size: 20),
                const SizedBox(width: 10),
                Text(
                  'Leave Types',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            typesAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFFC5A059)))),
              error: (e, _) => _errorTile('$e', () => ref.invalidate(adminLeaveTypesProvider), isDark),
              data: (types) {
                if (types.isEmpty) {
                  return Text(
                    'No leave types configured.',
                    style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF607D8B)),
                  );
                }
                return Column(
                  children: types
                      .map(
                        (t) => _TypeTile(
                          type: t,
                          isDark: isDark,
                          onEdit: () => _showTypeDialog(context, ref, isDark, existing: t),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                const Icon(Icons.settings_applications_rounded, color: Color(0xFFC5A059), size: 20),
                const SizedBox(width: 10),
                Text(
                  'System Settings',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            settingsAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFFC5A059)))),
              error: (e, _) => _errorTile('$e', () => ref.invalidate(adminLeaveSettingsProvider), isDark),
              data: (settings) {
                if (settings.isEmpty) {
                  return Text(
                    'No settings found.',
                    style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF607D8B)),
                  );
                }
                return Column(
                  children: settings
                      .map((s) => _SettingTile(
                            setting: s,
                            isDark: isDark,
                            onSave: (value) async {
                              await ref
                                  .read(leaveRepositoryProvider)
                                  .patchAdminSetting(s.key, value);
                              invalidateLeaveAdminData(ref);
                            },
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorTile(String message, VoidCallback onRetry, bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(message, style: TextStyle(color: Colors.red)),
            TextButton(onPressed: onRetry, child: Text('Retry')),
          ],
        ),
      ),
    );
  }

  Future<void> _runYearEnd(BuildContext context, WidgetRef ref, bool isDark) async {
    final year = DateTime.now().year;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Run year-end processing?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
          ),
        ),
        content: Text(
          'Process carry-forward for year $year?',
          style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF607D8B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF607D8B))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
              foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Run', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(leaveRepositoryProvider).runYearEnd(year);
      invalidateLeaveAdminData(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Year-end processing completed.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  InputDecoration _styledInput(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFC5A059), width: 1.5),
      ),
    );
  }

  Future<void> _showTypeDialog(
    BuildContext context,
    WidgetRef ref,
    bool isDark, {
    LeaveType? existing,
  }) async {
    final codeController = TextEditingController(text: existing?.code ?? '');
    final nameController = TextEditingController(text: existing?.name ?? '');
    final daysController = TextEditingController(
      text: existing?.defaultDaysPerYear?.toString() ?? '',
    );
    var applicableTo = existing?.applicableTo ?? 'BOTH';
    if (applicableTo != 'TEACHING' && applicableTo != 'NON_TEACHING' && applicableTo != 'BOTH') {
      applicableTo = 'BOTH';
    }
    var isCarryForward = existing?.isCarryForward ?? false;
    var requiresDocument = existing?.requiresDocument ?? false;
    var employeeCanApply = existing?.employeeCanApply ?? true;
    var allowHalfDay = existing?.allowHalfDay ?? true;
    var isActive = existing?.isActive ?? true;
    var cutsSalary = existing?.cutsSalary ?? false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            existing == null ? 'Add leave type' : 'Edit leave type',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF212F3D),
            ),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeController,
                    decoration: _styledInput('Code *', isDark),
                    enabled: existing == null,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: _styledInput('Leave Type Name *', isDark),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: daysController,
                    keyboardType: TextInputType.number,
                    decoration: _styledInput('Days per Year (blank = unlimited)', isDark),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: applicableTo,
                    decoration: _styledInput('Applicable To', isDark),
                    items: const [
                      DropdownMenuItem(value: 'TEACHING', child: Text('Teaching only')),
                      DropdownMenuItem(value: 'NON_TEACHING', child: Text('Non-Teaching only')),
                      DropdownMenuItem(value: 'BOTH', child: Text('Teaching & Non-Teaching')),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocal(() => applicableTo = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<bool>(
                    initialValue: isCarryForward,
                    decoration: _styledInput('Carry Forward', isDark),
                    items: const [
                      DropdownMenuItem(value: false, child: Text('No')),
                      DropdownMenuItem(value: true, child: Text('Yes')),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocal(() => isCarryForward = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<bool>(
                    initialValue: requiresDocument,
                    decoration: _styledInput('Requires Document', isDark),
                    items: const [
                      DropdownMenuItem(value: false, child: Text('No')),
                      DropdownMenuItem(value: true, child: Text('Yes')),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocal(() => requiresDocument = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<bool>(
                    initialValue: employeeCanApply,
                    decoration: _styledInput('Employee Can Apply', isDark),
                    items: const [
                      DropdownMenuItem(value: true, child: Text('Yes — self-service')),
                      DropdownMenuItem(value: false, child: Text('No — admin only')),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocal(() => employeeCanApply = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFFC5A059).withOpacity(0.1) : const Color(0xFFCFD8DC),
                      ),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          title: Text(
                            'Allow half day',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isDark ? Colors.white : const Color(0xFF212F3D),
                            ),
                          ),
                          value: allowHalfDay,
                          activeColor: const Color(0xFFC5A059),
                          onChanged: (v) => setLocal(() => allowHalfDay = v),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          title: Text(
                            'Cut salary for this leave',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isDark ? Colors.white : const Color(0xFF212F3D),
                            ),
                          ),
                          subtitle: Text(
                            'If enabled, approved days reduce pay when salary columns allow cut-on-leave',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                            ),
                          ),
                          value: cutsSalary,
                          activeColor: const Color(0xFFC5A059),
                          onChanged: (v) => setLocal(() => cutsSalary = v),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          title: Text(
                            'Active',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isDark ? Colors.white : const Color(0xFF212F3D),
                            ),
                          ),
                          value: isActive,
                          activeColor: const Color(0xFFC5A059),
                          onChanged: (v) => setLocal(() => isActive = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF607D8B))),
            ),
            FilledButton(
              onPressed: () async {
                final daysText = daysController.text.trim();
                final days = daysText.isEmpty ? null : double.tryParse(daysText);
                try {
                  await ref.read(leaveRepositoryProvider).upsertAdminType({
                    'code': codeController.text.trim(),
                    'name': nameController.text.trim(),
                    'applicableTo': applicableTo,
                    'defaultDaysPerYear': days,
                    'isCarryForward': isCarryForward,
                    'requiresDocument': requiresDocument,
                    'employeeCanApply': employeeCanApply,
                    'allowHalfDay': allowHalfDay,
                    'cutsSalary': cutsSalary,
                    'isActive': isActive,
                  });
                  invalidateLeaveAdminData(ref);
                  ref.invalidate(leaveTypesProvider);
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    codeController.dispose();
    nameController.dispose();
    daysController.dispose();
  }
}

class _TypeTile extends ConsumerWidget {
  const _TypeTile({
    required this.type,
    required this.isDark,
    required this.onEdit,
  });

  final LeaveType type;
  final bool isDark;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminOnly = !type.employeeCanApply;
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
        onTap: onEdit,
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
                      type.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isDark ? const Color(0xFFC5A059).withOpacity(0.1) : const Color(0xFFCFD8DC),
                            ),
                          ),
                          child: Text(
                            type.code,
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: type.isActive
                                ? Colors.green.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            border: Border.all(
                              color: type.isActive ? Colors.green : Colors.grey,
                              width: 1.2,
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            type.isActive ? 'ACTIVE' : 'INACTIVE',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: type.isActive ? Colors.green : Colors.grey,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: adminOnly
                                ? Colors.orange.withOpacity(0.1)
                                : Colors.blue.withOpacity(0.08),
                            border: Border.all(
                              color: adminOnly ? Colors.orange : Colors.blue,
                              width: 1.2,
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            adminOnly ? 'ADMIN ONLY' : 'EMPLOYEE APPLY',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: adminOnly ? Colors.orange.shade800 : Colors.blue.shade800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: const Color(0xFFC5A059),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                color: isDark ? Colors.white38 : const Color(0xFF607D8B),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text(
                        'Delete leave type?',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF212F3D),
                        ),
                      ),
                      content: Text(
                        'Delete ${type.code}?',
                        style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF607D8B)),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF607D8B))),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  try {
                    await ref.read(leaveRepositoryProvider).deleteAdminType(type.code);
                    invalidateLeaveAdminData(ref);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingTile extends StatefulWidget {
  const _SettingTile({required this.setting, required this.onSave, required this.isDark});

  final LeaveSetting setting;
  final Future<void> Function(String value) onSave;
  final bool isDark;

  @override
  State<_SettingTile> createState() => _SettingTileState();
}

class _SettingTileState extends State<_SettingTile> {
  late final TextEditingController _controller;
  late String _value;
  bool _saving = false;

  static const _labels = <String, String>{
    'absence_window_hours': 'Absence window (hours)',
    'approver_window_hours': 'Approver fallback window (hours)',
    'hod_window_hours': '1st reporting window (hours)',
    'hoi_window_hours': '2nd reporting window (hours)',
    'global_window_hours': '3rd reporting window (hours)',
    'approver_timeout_action': 'On approver timeout',
    'yearend_processing_date': 'Year-end processing date',
    'new_year_credit_date': 'New-year credit date',
    'mid_year_credit_date': 'Mid-year credit date',
    'lwp_auto_apply': 'Auto-apply LWP after absence',
  };

  bool get _isHours => widget.setting.key.endsWith('_hours');
  bool get _isDate => widget.setting.key.endsWith('_date');
  bool get _isTimeout => widget.setting.key == 'approver_timeout_action';
  bool get _isBool => widget.setting.key == 'lwp_auto_apply';

  @override
  void initState() {
    super.initState();
    _value = widget.setting.value;
    _controller = TextEditingController(text: widget.setting.value);
  }

  @override
  void didUpdateWidget(covariant _SettingTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.setting.value != widget.setting.value) {
      _value = widget.setting.value;
      _controller.text = widget.setting.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(String next) async {
    setState(() => _saving = true);
    try {
      await widget.onSave(next);
      if (mounted) {
        setState(() => _value = next);
        _controller.text = next;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _editor(bool isDark) {
    if (_isTimeout) {
      final current = _value.toLowerCase() == 'reject' ? 'reject' : 'escalate';
      return DropdownButtonFormField<String>(
        initialValue: current,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true,
        ),
        items: const [
          DropdownMenuItem(value: 'escalate', child: Text('Escalate (auto-approve step)')),
          DropdownMenuItem(value: 'reject', child: Text('Reject application')),
        ],
        onChanged: _saving
            ? null
            : (v) {
                if (v != null) _save(v);
              },
      );
    }
    if (_isBool) {
      final on = _value.toLowerCase() == 'true';
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(on ? 'Enabled' : 'Disabled'),
        value: on,
        onChanged: _saving ? null : (v) => _save(v ? 'true' : 'false'),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: _isHours ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              hintText: _isDate
                  ? 'MM-DD (e.g. 01-01)'
                  : _isHours
                      ? 'Hours (blank = infinite)'
                      : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFC5A059), width: 1.5),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 44,
          child: FilledButton(
            onPressed: _saving ? null : () => _save(_controller.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
              foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
              disabledBackgroundColor:
                  isDark ? const Color(0xFFC5A059).withOpacity(0.3) : const Color(0xFFCFD8DC),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final title = _labels[widget.setting.key] ?? widget.setting.key;
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF212F3D),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.setting.key,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: isDark ? Colors.white38 : const Color(0xFF90A4AE),
              ),
            ),
            if (widget.setting.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.setting.description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _editor(isDark),
          ],
        ),
      ),
    );
  }
}


