import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/salary_models.dart';
import '../salary_providers.dart';
import '../widgets/salary_shared_widgets.dart';

class AdminSalaryEntryScreen extends ConsumerStatefulWidget {
  const AdminSalaryEntryScreen({super.key});

  @override
  ConsumerState<AdminSalaryEntryScreen> createState() => _AdminSalaryEntryScreenState();
}

class _AdminSalaryEntryScreenState extends ConsumerState<AdminSalaryEntryScreen> {
  int? _employeeId;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  String? _recordId;
  final Map<String, num> _overrides = {};
  ComputedSalaryResult? _computed;
  bool _computing = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canWrite = Permissions.canWriteSalary(auth.permissions);
    final employeesAsync = ref.watch(salaryEmployeesProvider);

    final profileAsync = _employeeId == null
        ? const AsyncValue<EmployeeSalaryProfileResponse>.data(
            EmployeeSalaryProfileResponse(),
          )
        : ref.watch(employeeSalaryProfileProvider(_employeeId!));

    final payCode = profileAsync.value?.profile?.payCommissionRef?.code;
    final designationId = profileAsync.value?.profile?.designationId ??
        employeesAsync.value
            ?.where((e) => e.id == _employeeId)
            .map((e) => e.designationId)
            .firstOrNull;

    final templateKey = designationId != null && payCode != null
        ? (designationId: designationId, commissionCode: payCode)
        : null;

    final tplAsync = templateKey == null
        ? const AsyncValue<SalaryTemplateBundle>.data(SalaryTemplateBundle())
        : ref.watch(salaryTemplateProvider(templateKey));

    final templateId = tplAsync.value?.template?.id;

    final entryPeriod = _employeeId == null
        ? null
        : (employeeId: _employeeId!, month: _month, year: _year);

    if (entryPeriod != null) {
      ref.watch(salaryEntryRecordsProvider(entryPeriod));
      ref.listen(salaryEntryRecordsProvider(entryPeriod), (prev, next) {
        next.whenData((records) {
          final rec = records
                  .where((r) => r.status == SalaryRecordStatus.draft)
                  .firstOrNull ??
              records.firstOrNull;
          if (rec != null && rec.id != _recordId) {
            setState(() {
              _recordId = rec.id;
              _overrides.clear();
              for (final cv in rec.columnValues) {
                if (cv.overrideValue != null) {
                  _overrides[cv.key] = num.tryParse(cv.overrideValue!) ?? 0;
                }
              }
            });
          } else if (records.isEmpty && _recordId != null) {
            setState(() {
              _recordId = null;
              _overrides.clear();
            });
          }
        });
      });
    }

    if (templateId != null && !_computing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _compute(templateId);
      });
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Salary Entry',
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
          onPressed: () => context.go('/admin/salary/records'),
        ),
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
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            Card(
              elevation: 0,
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
                    Text(
                      'Select Employee & Payroll Period',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    employeesAsync.when(
                      loading: () => const LinearProgressIndicator(color: Color(0xFFC5A059)),
                      error: (e, _) => Text('$e', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      data: (employees) => DropdownButtonFormField<int>(
                        initialValue: _employeeId,
                        dropdownColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF212F3D),
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Employee',
                          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                          prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFFC5A059)),
                          border: const OutlineInputBorder(),
                        ),
                        items: employees
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.id,
                                child: Text('${e.fullName} (#${e.id})'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() {
                          _employeeId = v;
                          _recordId = null;
                          _overrides.clear();
                          _computed = null;
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: '$_month',
                            decoration: const InputDecoration(
                              labelText: 'Month',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_month_rounded, color: Color(0xFFC5A059)),
                            ),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => setState(() {
                              _month = int.tryParse(v) ?? _month;
                              _recordId = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            initialValue: '$_year',
                            decoration: const InputDecoration(
                              labelText: 'Year',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.date_range_rounded, color: Color(0xFFC5A059)),
                            ),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => setState(() {
                              _year = int.tryParse(v) ?? _year;
                              _recordId = null;
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFFC5A059), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Pay Commission: ${tplAsync.value?.payCommission?.name ?? payCode ?? '—'}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : const Color(0xFF607D8B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_employeeId != null && payCode == null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Set pay commission on employee salary profile first.',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_recordId != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note_rounded, color: Colors.orange, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Editing existing draft record.',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF607D8B),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (templateId != null && _computed != null) ...[
              const SizedBox(height: 20),
              _OverrideSection(
                title: 'Earnings',
                titleColor: Colors.green,
                columns: _computed!.columns
                    .where((c) =>
                        c.category == 'EARNING' && c.columnIdentifier != 'gross_pay')
                    .toList(),
                overrides: _overrides,
                onChanged: (key, val) => setState(() => _overrides[key] = val),
                onReset: (key) => setState(() => _overrides.remove(key)),
              ),
              const SizedBox(height: 20),
              _OverrideSection(
                title: 'Deductions',
                titleColor: Colors.red,
                columns: _computed!.columns
                    .where((c) =>
                        c.category == 'DEDUCTION' &&
                        c.columnIdentifier != 'net_pay' &&
                        c.columnIdentifier != 'total_deductions')
                    .toList(),
                overrides: _overrides,
                onChanged: (key, val) => setState(() => _overrides[key] = val),
                onReset: (key) => setState(() => _overrides.remove(key)),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 0,
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Gross Pay', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(formatInr(_computed!.grossPay), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.blue)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Deductions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(formatInr(_computed!.totalDeductions), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.red)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Net Salary Payout', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text(formatInr(_computed!.netPay), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.green)),
                        ],
                      ),
                      if (canWrite) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: OutlinedButton.icon(
                                  onPressed: _saving ? null : () => _saveDraft(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                                    side: BorderSide(
                                      color: isDark ? const Color(0xFFC5A059).withOpacity(0.4) : const Color(0xFFCFD8DC),
                                      width: 1.2,
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: _saving
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.save_rounded, size: 16),
                                  label: Text(_saving ? 'Saving…' : 'Save Draft', style: const TextStyle(fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: FilledButton.icon(
                                  onPressed: _saving ? null : () => _finalize(),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                                    foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                                  label: const Text('Finalize', style: TextStyle(fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ] else if (templateId != null && _computing)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: Color(0xFFC5A059))),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _compute(String templateId) async {
    if (_computing) return;
    setState(() => _computing = true);
    try {
      final result = await ref.read(salaryRepositoryProvider).computeSalary(
            templateId: templateId,
            overrides: _overrides.isEmpty ? null : _overrides,
          );
      if (mounted) setState(() => _computed = result);
    } finally {
      if (mounted) setState(() => _computing = false);
    }
  }

  Future<void> _saveDraft() async {
    if (_employeeId == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(salaryRepositoryProvider);
      var id = _recordId;
      if (id == null) {
        final rec = await repo.createRecord(
          employeeId: _employeeId!,
          salaryMonth: _month,
          salaryYear: _year,
        );
        id = rec.id;
        setState(() => _recordId = id);
      }
      if (_overrides.isNotEmpty) {
        await repo.updateRecord(id, overrides: _overrides);
      }
      invalidateSalaryRecords(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft saved')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finalize() async {
    await _saveDraft();
    final id = _recordId;
    if (id == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(salaryRepositoryProvider).finalizeRecord(id);
      invalidateSalaryRecords(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salary finalized')),
        );
        context.go('/admin/salary/records');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _OverrideSection extends StatelessWidget {
  const _OverrideSection({
    required this.title,
    required this.titleColor,
    required this.columns,
    required this.overrides,
    required this.onChanged,
    required this.onReset,
  });

  final String title;
  final Color titleColor;
  final List<ComputedSalaryColumn> columns;
  final Map<String, num> overrides;
  final void Function(String key, num value) onChanged;
  final void Function(String key) onReset;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return salarySectionCard(
      title: title,
      titleColor: titleColor,
      child: Column(
        children: columns.map((col) {
          final key = col.key;
          final overridden = overrides.containsKey(key);
          final val = overrides[key] ?? col.effectiveValue;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      columnDisplayLabel(col.columnIdentifier),
                      style: TextStyle(
                        fontWeight: FontWeight.w800, 
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (overridden)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.withOpacity(0.2)),
                        ),
                        child: const Text(
                          'OVERRIDDEN',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.orange),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  col.formulaPreview,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.white30 : const Color(0xFF607D8B)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: '$val',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (v) => onChanged(key, num.tryParse(v) ?? 0),
                      ),
                    ),
                    if (overridden) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Reset to default formula value',
                        icon: const Icon(Icons.refresh_rounded, color: Colors.orange, size: 20),
                        onPressed: () => onReset(key),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
