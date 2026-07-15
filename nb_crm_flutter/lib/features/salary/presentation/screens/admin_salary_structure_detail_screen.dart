import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/salary_models.dart';
import '../salary_providers.dart';
import '../widgets/salary_rule_editor_sheet.dart';
import '../widgets/salary_shared_widgets.dart';

class AdminSalaryStructureDetailScreen extends ConsumerStatefulWidget {
  const AdminSalaryStructureDetailScreen({
    super.key,
    required this.designationId,
    required this.commission,
    this.templateId,
  });

  final String designationId;
  final String commission;
  final String? templateId;

  @override
  ConsumerState<AdminSalaryStructureDetailScreen> createState() =>
      _AdminSalaryStructureDetailScreenState();
}

class _AdminSalaryStructureDetailScreenState
    extends ConsumerState<AdminSalaryStructureDetailScreen> {
  Map<String, bool> _columnVisibility = {};
  ComputedSalaryResult? _computed;
  bool _computing = false;
  String? _computeError;

  SalaryTemplateKey get _key => (
        designationId: widget.designationId,
        commissionCode: widget.commission.toUpperCase(),
      );

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final canWrite = Permissions.canWriteSalary(auth.permissions);
    final tplAsync = ref.watch(salaryTemplateProvider(_key));
    final templateId = tplAsync.value?.template?.id ?? widget.templateId;
    final rulesAsync = templateId == null
        ? const AsyncValue<List<SalaryRule>>.data([])
        : ref.watch(salaryTemplateRulesProvider(templateId));

    ref.listen(salaryTemplateProvider(_key), (prev, next) {
      final vis = next.value?.template?.columnVisibility;
      if (vis != null) {
        setState(() => _columnVisibility = Map<String, bool>.from(vis));
      }
    });

    if (templateId != null &&
        rulesAsync.hasValue &&
        _computed == null &&
        !_computing &&
        _computeError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runCompute(templateId));
    }

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Structure Rules'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/salary/structures'),
        ),
      ),
      body: SalaryAsyncBody<SalaryTemplateBundle>(
        value: tplAsync,
        emptyMessage: 'Template not found.',
        onRetry: () => invalidateSalaryTemplate(ref, _key),
        builder: (bundle) {
          final templateId = bundle.template?.id ?? widget.templateId;
          final ruleEditorEnabled = bundle.payCommission?.ruleEditorEnabled ?? true;
          final rules = rulesAsync.value ?? [];
          final ruleMap = {for (final r in rules) r.mapKey: r};
          final computedMap = <String, ComputedSalaryColumn>{
            for (final c in _computed?.columns ?? []) c.key: c,
          };

          final earnings = bundle.columnDefinitions
              .where((c) => c.category == SalaryColumnCategory.earning)
              .toList();
          final deductions = bundle.columnDefinitions
              .where((c) => c.category == SalaryColumnCategory.deduction)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${bundle.payCommission?.name ?? widget.commission.toUpperCase()} — '
                '${bundle.designation?.name ?? bundle.template?.designation?.name ?? '…'}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              if (!ruleEditorEnabled)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Chip(label: Text('Fixed amounts only')),
                ),
              if (templateId == null)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('No template found. Go back and click Configure.'),
                )
              else ...[
                const SizedBox(height: 12),
                Card(
                  color: AppColors.mist,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Employee view toggles show/hide columns on the employee salary tab. '
                      'Hidden columns are still included in gross and net pay.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _RulesTable(
                  title: 'Earnings',
                  titleColor: AppColors.success,
                  columns: earnings,
                  ruleMap: ruleMap,
                  computedMap: computedMap,
                  computing: _computing,
                  columnVisibility: _columnVisibility,
                  canWrite: canWrite,
                  onToggleVisibility: (key, visible) =>
                      _toggleVisibility(templateId, key, visible),
                  onEdit: (col) => _editRule(
                    col,
                    ruleMap[col.visibilityKey],
                    bundle.columnDefinitions,
                    ruleEditorEnabled,
                    templateId,
                  ),
                ),
                const SizedBox(height: 16),
                _RulesTable(
                  title: 'Deductions',
                  titleColor: AppColors.error,
                  columns: deductions,
                  ruleMap: ruleMap,
                  computedMap: computedMap,
                  computing: _computing,
                  columnVisibility: _columnVisibility,
                  canWrite: canWrite,
                  onToggleVisibility: (key, visible) =>
                      _toggleVisibility(templateId, key, visible),
                  onEdit: (col) => _editRule(
                    col,
                    ruleMap[col.visibilityKey],
                    bundle.columnDefinitions,
                    ruleEditorEnabled,
                    templateId,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pay Summary Preview',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        if (_computing)
                          const Text('Calculating…', style: TextStyle(color: AppColors.textSecondary))
                        else if (_computeError != null)
                          Text(_computeError!, style: const TextStyle(color: AppColors.error))
                        else if (_computed != null) ...[
                          Text('Gross: ${formatInr(_computed!.grossPay)}',
                              style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                          Text('Deductions: ${formatInr(_computed!.totalDeductions)}',
                              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                          Text('Net: ${formatInr(_computed!.netPay)}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _runCompute(String templateId) async {
    setState(() {
      _computing = true;
      _computeError = null;
    });
    try {
      final result = await ref.read(salaryRepositoryProvider).computeSalary(
            templateId: templateId,
          );
      if (mounted) setState(() => _computed = result);
    } catch (e) {
      if (mounted) setState(() => _computeError = '$e');
    } finally {
      if (mounted) setState(() => _computing = false);
    }
  }

  Future<void> _toggleVisibility(String templateId, String key, bool visible) async {
    final next = {..._columnVisibility, key: visible};
    setState(() => _columnVisibility = next);
    try {
      await ref.read(salaryRepositoryProvider).updateTemplateColumnVisibility(
            templateId,
            next,
          );
      invalidateSalaryTemplate(ref, _key);
    } catch (_) {
      if (mounted) setState(() => _columnVisibility = _columnVisibility);
    }
  }

  Future<void> _editRule(
    PayCommissionColumn column,
    SalaryRule? existing,
    List<PayCommissionColumn> allColumns,
    bool ruleEditorEnabled,
    String templateId,
  ) async {
    final computed = _computed?.columns
        .where((c) => c.key == column.visibilityKey)
        .map((c) => c.ruleComputedValue)
        .firstOrNull;

    await SalaryRuleEditorSheet.show(
      context,
      column: column,
      existingRule: existing,
      allColumns: allColumns,
      ruleEditorEnabled: ruleEditorEnabled,
      defaultFixedValue: computed,
      onSave: (body) async {
        await ref.read(salaryRepositoryProvider).upsertColumnRule(
              templateId: templateId,
              columnIdentifier: column.columnIdentifier,
              category: column.categoryKey,
              body: body,
            );
        invalidateSalaryTemplate(ref, _key);
        await _runCompute(templateId);
      },
    );
  }
}

class _RulesTable extends StatelessWidget {
  const _RulesTable({
    required this.title,
    required this.titleColor,
    required this.columns,
    required this.ruleMap,
    required this.computedMap,
    required this.computing,
    required this.columnVisibility,
    required this.canWrite,
    required this.onToggleVisibility,
    required this.onEdit,
  });

  final String title;
  final Color titleColor;
  final List<PayCommissionColumn> columns;
  final Map<String, SalaryRule> ruleMap;
  final Map<String, ComputedSalaryColumn> computedMap;
  final bool computing;
  final Map<String, bool> columnVisibility;
  final bool canWrite;
  final void Function(String key, bool visible) onToggleVisibility;
  final void Function(PayCommissionColumn col) onEdit;

  @override
  Widget build(BuildContext context) {
    return salarySectionCard(
      title: title,
      titleColor: titleColor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Column')),
            DataColumn(label: Text('Rule')),
            DataColumn(label: Text('Formula')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Employee view')),
            DataColumn(label: Text('')),
          ],
          rows: columns.map((col) {
            final key = col.visibilityKey;
            final rule = ruleMap[key];
            final computed = computedMap[key];
            final isTotal = {'gross_pay', 'total_deductions', 'net_pay'}
                .contains(col.columnIdentifier);
            final visible = columnVisibility[key] != false;
            return DataRow(cells: [
              DataCell(Text(col.displayName)),
              DataCell(Text(
                rule != null
                    ? rule.ruleType.name.toUpperCase()
                    : isTotal
                        ? 'Auto'
                        : col.isRuleConfigurable
                            ? 'Not set'
                            : 'Computed',
              )),
              DataCell(Text(
                rule?.formulaPreview ?? computed?.formulaPreview ?? '—',
                style: const TextStyle(fontSize: 11),
              )),
              DataCell(Text(
                computing ? '…' : formatInr(computed?.ruleComputedValue ?? 0),
              )),
              DataCell(
                Switch(
                  value: visible,
                  onChanged: canWrite ? (v) => onToggleVisibility(key, v) : null,
                ),
              ),
              DataCell(
                col.isRuleConfigurable && canWrite
                    ? TextButton(onPressed: () => onEdit(col), child: const Text('Edit'))
                    : const SizedBox.shrink(),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
