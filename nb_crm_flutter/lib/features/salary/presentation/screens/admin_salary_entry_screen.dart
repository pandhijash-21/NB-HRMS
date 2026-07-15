import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
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
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Salary Entry'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/salary/records'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  employeesAsync.when(
                    loading: () => const LinearProgressIndicator(color: AppColors.bronze),
                    error: (e, _) => Text('$e'),
                    data: (employees) => DropdownButtonFormField<int>(
                      value: _employeeId,
                      decoration: const InputDecoration(labelText: 'Employee'),
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: '$_month',
                          decoration: const InputDecoration(labelText: 'Month'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => setState(() {
                            _month = int.tryParse(v) ?? _month;
                            _recordId = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: '$_year',
                          decoration: const InputDecoration(labelText: 'Year'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => setState(() {
                            _year = int.tryParse(v) ?? _year;
                            _recordId = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pay Commission: ${tplAsync.value?.payCommission?.name ?? payCode ?? '—'}',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_employeeId != null && payCode == null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Set pay commission on employee salary profile first.',
                style: TextStyle(color: AppColors.bronzeDark),
              ),
            ),
          if (_recordId != null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Editing existing draft record.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          if (templateId != null && _computed != null) ...[
            const SizedBox(height: 16),
            _OverrideSection(
              title: 'Earnings',
              titleColor: AppColors.success,
              columns: _computed!.columns
                  .where((c) =>
                      c.category == 'EARNING' && c.columnIdentifier != 'gross_pay')
                  .toList(),
              overrides: _overrides,
              onChanged: (key, val) => setState(() => _overrides[key] = val),
              onReset: (key) => setState(() => _overrides.remove(key)),
            ),
            const SizedBox(height: 16),
            _OverrideSection(
              title: 'Deductions',
              titleColor: AppColors.error,
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
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Gross: ${formatInr(_computed!.grossPay)}'),
                    Text('Deductions: ${formatInr(_computed!.totalDeductions)}'),
                    Text('Net: ${formatInr(_computed!.netPay)}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (canWrite) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: _saving ? null : () => _saveDraft(),
                            child: Text(_saving ? 'Saving…' : 'Save Draft'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _saving ? null : () => _finalize(),
                            child: const Text('Finalize'),
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
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: AppColors.bronze)),
            ),
        ],
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
    return salarySectionCard(
      title: title,
      titleColor: titleColor,
      child: Column(
        children: columns.map((col) {
          final key = col.key;
          final overridden = overrides.containsKey(key);
          final val = overrides[key] ?? col.effectiveValue;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(columnDisplayLabel(col.columnIdentifier),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                Text(col.formulaPreview,
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: '$val',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (v) => onChanged(key, num.tryParse(v) ?? 0),
                      ),
                    ),
                    if (overridden)
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => onReset(key),
                      ),
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
