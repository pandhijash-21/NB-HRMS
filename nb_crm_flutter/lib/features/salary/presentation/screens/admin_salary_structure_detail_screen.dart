import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Structure Rules',
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
          onPressed: () => context.go('/admin/salary/structures'),
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
        child: SalaryAsyncBody<SalaryTemplateBundle>(
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                Text(
                  '${bundle.payCommission?.name ?? widget.commission.toUpperCase()} — '
                  '${bundle.designation?.name ?? bundle.template?.designation?.name ?? '…'}',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                  ),
                ),
                if (!ruleEditorEnabled) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        border: Border.all(color: Colors.orange, width: 1.2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'FIXED AMOUNTS ONLY',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.orange, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ],
                if (templateId == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(
                      child: Text(
                        'No template found. Go back and click Configure.',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey),
                      ),
                    ),
                  )
                else ...[
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1B18) : const Color(0xFFF0F4F8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFFC5A059).withOpacity(0.15)
                            : const Color(0xFFCFD8DC),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const ColoredBox(
                            color: Color(0xFFC5A059),
                            child: SizedBox(width: 4),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded, color: Color(0xFFC5A059), size: 18),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Employee view toggles show/hide columns on the employee salary tab. Cut on leave / absent toggles control attendance-based salary proration for that column.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white70 : const Color(0xFF607D8B),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _RulesTable(
                    title: 'Earnings',
                    titleColor: Colors.green,
                    columns: earnings,
                    ruleMap: ruleMap,
                    computedMap: computedMap,
                    computing: _computing,
                    columnVisibility: _columnVisibility,
                    canWrite: canWrite,
                    onToggleVisibility: (key, visible) =>
                        _toggleVisibility(templateId, key, visible),
                    onToggleCut: (col, {required bool? cutOnLeave, required bool? cutOnAbsent}) =>
                        _toggleCutFlags(col, cutOnLeave: cutOnLeave, cutOnAbsent: cutOnAbsent),
                    onEdit: (col) => _editRule(
                      col,
                      ruleMap[col.visibilityKey],
                      bundle.columnDefinitions,
                      ruleEditorEnabled,
                      templateId,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _RulesTable(
                    title: 'Deductions',
                    titleColor: Colors.red,
                    columns: deductions,
                    ruleMap: ruleMap,
                    computedMap: computedMap,
                    computing: _computing,
                    columnVisibility: _columnVisibility,
                    canWrite: canWrite,
                    onToggleVisibility: (key, visible) =>
                        _toggleVisibility(templateId, key, visible),
                    onToggleCut: (col, {required bool? cutOnLeave, required bool? cutOnAbsent}) =>
                        _toggleCutFlags(col, cutOnLeave: cutOnLeave, cutOnAbsent: cutOnAbsent),
                    onEdit: (col) => _editRule(
                      col,
                      ruleMap[col.visibilityKey],
                      bundle.columnDefinitions,
                      ruleEditorEnabled,
                      templateId,
                    ),
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
                            children: [
                              const Icon(Icons.analytics_rounded, color: Color(0xFFC5A059), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Pay Summary Preview',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_computing)
                            const Center(child: CircularProgressIndicator(color: Color(0xFFC5A059)))
                          else if (_computeError != null)
                            Text(_computeError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                          else if (_computed != null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Gross Pay Preview', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text(formatInr(_computed!.grossPay), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Deductions Preview', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text(formatInr(_computed!.totalDeductions), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Divider(),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Net Payout Preview', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                Text(formatInr(_computed!.netPay), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF212F3D))),
                              ],
                            ),
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
      ref.invalidate(salaryTemplateProvider(_key));
    } catch (_) {
      if (mounted) setState(() => _columnVisibility = _columnVisibility);
    }
  }

  Future<void> _toggleCutFlags(
    PayCommissionColumn col, {
    bool? cutOnLeave,
    bool? cutOnAbsent,
  }) async {
    try {
      await ref.read(salaryRepositoryProvider).updatePayCommissionColumn(col.id, {
        if (cutOnLeave != null) 'cutOnLeave': cutOnLeave,
        if (cutOnAbsent != null) 'cutOnAbsent': cutOnAbsent,
      });
      ref.invalidate(salaryTemplateProvider(_key));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
        ref.invalidate(salaryTemplateProvider(_key));
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
    required this.onToggleCut,
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
  final void Function(
    PayCommissionColumn col, {
    required bool? cutOnLeave,
    required bool? cutOnAbsent,
  }) onToggleCut;
  final void Function(PayCommissionColumn col) onEdit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return salarySectionCard(
      title: title,
      titleColor: titleColor,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121212).withOpacity(0.4) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.12) : const Color(0xFFCFD8DC),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              isDark ? const Color(0xFF121212).withOpacity(0.8) : const Color(0xFFECEFF1),
            ),
            columns: [
              DataColumn(
                label: Text(
                  'Column',
                  style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF212F3D)),
                ),
              ),
              DataColumn(
                label: Text(
                  'Rule',
                  style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF212F3D)),
                ),
              ),
              DataColumn(
                label: Text(
                  'Formula',
                  style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF212F3D)),
                ),
              ),
              DataColumn(
                label: Text(
                  'Amount',
                  style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF212F3D)),
                ),
              ),
              DataColumn(
                label: Text(
                  'Employee View',
                  style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF212F3D)),
                ),
              ),
              DataColumn(
                label: Text(
                  'Cut Leave',
                  style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF212F3D)),
                ),
              ),
              DataColumn(
                label: Text(
                  'Cut Absent',
                  style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF212F3D)),
                ),
              ),
              const DataColumn(label: Text('')),
            ],
            rows: columns.map((col) {
              final key = col.visibilityKey;
              final rule = ruleMap[key];
              final computed = computedMap[key];
              final isTotal = {'gross_pay', 'total_deductions', 'net_pay'}
                  .contains(col.columnIdentifier);
              final visible = columnVisibility[key] != false;
              return DataRow(cells: [
                DataCell(
                  Text(
                    col.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF263238),
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: rule != null
                          ? Colors.green.withOpacity(0.12)
                          : isTotal
                              ? Colors.blue.withOpacity(0.12)
                              : Colors.grey.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: rule != null
                            ? Colors.green.withOpacity(0.2)
                            : isTotal
                                ? Colors.blue.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      rule != null
                          ? rule.ruleType.name.toUpperCase()
                          : isTotal
                              ? 'AUTO'
                              : col.isRuleConfigurable
                                  ? 'NOT SET'
                                  : 'COMPUTED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: rule != null
                            ? Colors.green
                            : isTotal
                                ? Colors.blue
                                : Colors.grey,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    rule?.formulaPreview ?? computed?.formulaPreview ?? '—',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    computing ? '…' : formatInr(computed?.ruleComputedValue ?? 0),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF263238),
                    ),
                  ),
                ),
                DataCell(
                  Switch(
                    value: visible,
                    activeColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                    onChanged: canWrite ? (v) => onToggleVisibility(key, v) : null,
                  ),
                ),
                DataCell(
                  Switch(
                    value: col.cutOnLeave,
                    activeColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                    onChanged: canWrite && !isTotal
                        ? (v) => onToggleCut(col, cutOnLeave: v, cutOnAbsent: null)
                        : null,
                  ),
                ),
                DataCell(
                  Switch(
                    value: col.cutOnAbsent,
                    activeColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                    onChanged: canWrite && !isTotal
                        ? (v) => onToggleCut(col, cutOnLeave: null, cutOnAbsent: v)
                        : null,
                  ),
                ),
                DataCell(
                  col.isRuleConfigurable && canWrite
                      ? TextButton(
                          onPressed: () => onEdit(col),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFFC5A059)),
                          child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w800)),
                        )
                      : const SizedBox.shrink(),
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
