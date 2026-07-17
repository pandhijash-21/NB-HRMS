import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/salary_models.dart';
import '../salary_providers.dart';
import '../widgets/salary_shared_widgets.dart';

class AdminSalaryCommissionDetailScreen extends ConsumerWidget {
  const AdminSalaryCommissionDetailScreen({super.key, required this.commissionId});

  final String commissionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final canWrite = Permissions.canWriteSalary(auth.permissions);
    final pcAsync = ref.watch(payCommissionProvider(commissionId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Commission Columns',
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
          onPressed: () => context.go('/admin/salary/commissions'),
        ),
        actions: [
          if (canWrite)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                tooltip: 'Add Column',
                icon: const Icon(Icons.add_rounded, color: Color(0xFFC5A059)),
                onPressed: () => _showAddColumnDialog(context, ref, pcAsync.value),
              ),
            ),
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
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: SalaryAsyncBody<PayCommission>(
          value: pcAsync,
          emptyMessage: 'Commission not found.',
          onRetry: () => ref.invalidate(payCommissionProvider(commissionId)),
          builder: (pc) {
            final earnings = pc.columnDefinitions
                .where((c) => c.category == SalaryColumnCategory.earning)
                .toList();
            final deductions = pc.columnDefinitions
                .where((c) => c.category == SalaryColumnCategory.deduction)
                .toList();

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pc.name,
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF212F3D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                        ),
                      ),
                      child: Text(
                        pc.code,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFFC5A059).withOpacity(0.1) : const Color(0xFFECEFF1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
                        ),
                      ),
                      child: Text(
                        pc.ruleEditorEnabled ? 'Rule editor on' : 'Fixed amounts only',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFC5A059) : const Color(0xFF607D8B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1B18) : const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: const BorderSide(color: Color(0xFFC5A059), width: 4),
                      top: BorderSide(color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC)),
                      right: BorderSide(color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC)),
                      bottom: BorderSide(color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFC5A059), size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Order controls calculation sequence — lower numbers run first. Use gaps of 10 so you can insert columns without renumbering.',
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
                const SizedBox(height: 20),
                _ColumnTable(
                  title: 'Earnings',
                  titleColor: Colors.green,
                  columns: earnings,
                  canWrite: canWrite,
                  onDelete: (col) => _deleteColumn(context, ref, col),
                ),
                const SizedBox(height: 20),
                _ColumnTable(
                  title: 'Deductions',
                  titleColor: Colors.red,
                  columns: deductions,
                  canWrite: canWrite,
                  onDelete: (col) => _deleteColumn(context, ref, col),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _deleteColumn(
    BuildContext context,
    WidgetRef ref,
    PayCommissionColumn col,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
        title: Text(
          'Remove Column',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Are you sure you want to remove "${col.displayName}"? Rules using this column will be deleted.',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF607D8B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove Column', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(salaryRepositoryProvider).deletePayCommissionColumn(col.id);
    ref.invalidate(payCommissionProvider(commissionId));
  }

  Future<void> _showAddColumnDialog(
    BuildContext context,
    WidgetRef ref,
    PayCommission? pc,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    final orderCtrl = TextEditingController(
      text: '${((pc?.columnDefinitions.length ?? 0) + 1) * 10}',
    );
    var category = SalaryColumnCategory.earning;
    var configurable = true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
              width: 1.5,
            ),
          ),
          title: Text(
            'Add Salary Column',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF212F3D),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: displayCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: idCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Identifier (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<SalaryColumnCategory>(
                    initialValue: category,
                    dropdownColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF212F3D), fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: SalaryColumnCategory.earning, child: Text('Earning')),
                      DropdownMenuItem(value: SalaryColumnCategory.deduction, child: Text('Deduction')),
                    ],
                    onChanged: (v) => setLocal(() => category = v ?? category),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: orderCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Evaluation Order',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Allow rule configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    value: configurable,
                    activeColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                    onChanged: (v) => setLocal(() => configurable = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              onPressed: () async {
                final identifier = idCtrl.text.trim().isNotEmpty
                    ? idCtrl.text.trim()
                    : displayCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
                await ref.read(salaryRepositoryProvider).createPayCommissionColumn(
                  commissionId,
                  {
                    'columnIdentifier': identifier,
                    'displayName': displayCtrl.text.trim(),
                    'category': salaryColumnCategoryApi(category),
                    'evaluationOrder': int.tryParse(orderCtrl.text) ?? 100,
                    'isRuleConfigurable': configurable,
                  },
                );
                ref.invalidate(payCommissionProvider(commissionId));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Add Column', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColumnTable extends StatelessWidget {
  const _ColumnTable({
    required this.title,
    required this.titleColor,
    required this.columns,
    required this.canWrite,
    required this.onDelete,
  });

  final String title;
  final Color titleColor;
  final List<PayCommissionColumn> columns;
  final bool canWrite;
  final void Function(PayCommissionColumn col) onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return salarySectionCard(
      title: title,
      titleColor: titleColor,
      child: columns.isEmpty
          ? Text('No columns yet.', style: TextStyle(color: isDark ? Colors.white30 : const Color(0xFF607D8B)))
          : Container(
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
                        'Order', 
                        style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF212F3D)),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Display Name', 
                        style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF212F3D)),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Identifier', 
                        style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF212F3D)),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Configurable', 
                        style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF212F3D)),
                      ),
                    ),
                    const DataColumn(label: Text('')),
                  ],
                  rows: columns
                      .map(
                        (col) => DataRow(cells: [
                          DataCell(
                            Text(
                              '${col.evaluationOrder}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : const Color(0xFF263238),
                              ),
                            ),
                          ),
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
                            Text(
                              col.columnIdentifier, 
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: col.isRuleConfigurable
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: col.isRuleConfigurable ? Colors.blue.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                col.isRuleConfigurable ? 'YES' : 'AUTO',
                                style: TextStyle(
                                  fontSize: 9, 
                                  fontWeight: FontWeight.w800,
                                  color: col.isRuleConfigurable ? Colors.blue : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            canWrite
                                ? IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                    onPressed: () => onDelete(col),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ]),
                      )
                      .toList(),
                ),
              ),
            ),
    );
  }
}
