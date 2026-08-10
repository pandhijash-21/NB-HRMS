import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/salary_models.dart';
import '../salary_providers.dart';
import '../widgets/salary_shared_widgets.dart';

class AdminSalaryCommissionsScreen extends ConsumerWidget {
  const AdminSalaryCommissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final canWrite = Permissions.canWriteSalary(auth.permissions);
    final commissionsAsync = ref.watch(payCommissionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Pay Commissions',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            letterSpacing: -0.5,
          ),
        ),
        leading: const AppBackButton(fallbackLocation: '/admin/salary/records'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/admin/salary/structures'),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
            icon: const Icon(Icons.account_tree_outlined, size: 14, color: Color(0xFFC5A059)),
            label: const Text('Structures'),
          ),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
            height: 1.5,
          ),
        ),
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context, ref),
              backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
              foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Commission', style: TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
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
        child: SalaryAsyncBody<List<PayCommission>>(
          value: commissionsAsync,
          emptyMessage: 'No pay commissions yet.',
          onRetry: () => ref.invalidate(payCommissionsProvider),
          builder: (commissions) => ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            itemCount: commissions.length,
            itemBuilder: (ctx, i) {
              final pc = commissions[i];
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 16),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pc.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: isDark ? Colors.white : const Color(0xFF212F3D),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                          if (!pc.isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.12),
                                border: Border.all(color: Colors.grey, width: 1.2),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: const Text(
                                'INACTIVE',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (pc.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Text(
                          pc.description!, 
                          style: TextStyle(
                            color: isDark ? Colors.white54 : const Color(0xFF607D8B), 
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '${pc.counts?.columnDefinitions ?? pc.columnDefinitions.length} columns · '
                        '${pc.counts?.salaryStructureTemplates ?? 0} templates',
                        style: TextStyle(
                          color: isDark ? Colors.white30 : const Color(0xFF607D8B).withOpacity(0.6), 
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (canWrite)
                            Row(
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: pc.isActive,
                                      activeColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                                      onChanged: (v) => _toggleActive(ref, pc.id, v),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text('Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: pc.ruleEditorEnabled,
                                      activeColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                                      onChanged: (v) => _toggleRuleEditor(ref, pc.id, v),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text('Rule Editor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            )
                          else
                            const SizedBox.shrink(),
                          SizedBox(
                            height: 36,
                            child: OutlinedButton.icon(
                              onPressed: () => context.go('/admin/salary/commissions/${pc.id}'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                                side: BorderSide(
                                  color: isDark ? const Color(0xFFC5A059).withOpacity(0.4) : const Color(0xFFCFD8DC),
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                              ),
                              icon: const Icon(Icons.settings_outlined, size: 14, color: Color(0xFFC5A059)),
                              label: const Text('Manage Columns', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _toggleActive(WidgetRef ref, String id, bool value) async {
    final repo = ref.read(salaryRepositoryProvider);
    await repo.updatePayCommission(id, {'isActive': value});
    ref.invalidate(payCommissionsProvider);
  }

  Future<void> _toggleRuleEditor(WidgetRef ref, String id, bool value) async {
    final repo = ref.read(salaryRepositoryProvider);
    await repo.updatePayCommission(id, {'ruleEditorEnabled': value});
    ref.invalidate(payCommissionsProvider);
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final commissions = ref.read(payCommissionsProvider).value ?? [];
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var ruleEditor = true;
    String? cloneFrom;

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
            'Add Pay Commission',
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
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      if (codeCtrl.text.isEmpty || codeCtrl.text == slugCommissionCode(nameCtrl.text)) {
                        codeCtrl.text = slugCommissionCode(v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: cloneFrom,
                    dropdownColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF212F3D), fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      labelText: 'Clone columns from',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Start empty')),
                      ...commissions.map(
                        (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ),
                    ],
                    onChanged: (v) => setLocal(() => cloneFrom = v),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable rule editor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    value: ruleEditor,
                    activeColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                    onChanged: (v) => setLocal(() => ruleEditor = v),
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
                final repo = ref.read(salaryRepositoryProvider);
                await repo.createPayCommission({
                  'name': nameCtrl.text.trim(),
                  'code': codeCtrl.text.trim(),
                  'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  'ruleEditorEnabled': ruleEditor,
                  'cloneFromCommissionId': cloneFrom,
                });
                ref.invalidate(payCommissionsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Create Commission', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
