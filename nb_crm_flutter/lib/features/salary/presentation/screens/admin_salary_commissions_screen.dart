import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
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

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Pay Commissions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/salary/records'),
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/admin/salary/structures'),
            child: const Text('Structures', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context, ref),
              label: const Text('Add Commission'),
              icon: const Icon(Icons.add),
            )
          : null,
      body: SalaryAsyncBody<List<PayCommission>>(
        value: commissionsAsync,
        emptyMessage: 'No pay commissions yet.',
        onRetry: () => ref.invalidate(payCommissionsProvider),
        builder: (commissions) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: commissions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final pc = commissions[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pc.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Chip(label: Text(pc.code, style: const TextStyle(fontSize: 11))),
                        if (!pc.isActive)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Chip(label: Text('Inactive')),
                          ),
                      ],
                    ),
                    if (pc.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(pc.description!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${pc.counts?.columnDefinitions ?? pc.columnDefinitions.length} columns · '
                      '${pc.counts?.salaryStructureTemplates ?? 0} templates',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (canWrite) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: pc.isActive,
                                onChanged: (v) => _toggleActive(ref, pc.id, v),
                              ),
                              const Text('Active', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: pc.ruleEditorEnabled,
                                onChanged: (v) => _toggleRuleEditor(ref, pc.id, v),
                              ),
                              const Text('Rule editor', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                        OutlinedButton(
                          onPressed: () => context.go('/admin/salary/commissions/${pc.id}'),
                          child: const Text('Manage Columns'),
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
    );
  }

  Future<void> _toggleActive(WidgetRef ref, String id, bool value) async {
    final repo = ref.read(salaryRepositoryProvider);
    await repo.updatePayCommission(id, {'isActive': value});
    invalidateSalaryCommissions(ref);
  }

  Future<void> _toggleRuleEditor(WidgetRef ref, String id, bool value) async {
    final repo = ref.read(salaryRepositoryProvider);
    await repo.updatePayCommission(id, {'ruleEditorEnabled': value});
    invalidateSalaryCommissions(ref);
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
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
          title: const Text('Add Pay Commission'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  onChanged: (v) {
                    if (codeCtrl.text.isEmpty || codeCtrl.text == slugCommissionCode(nameCtrl.text)) {
                      codeCtrl.text = slugCommissionCode(v);
                    }
                  },
                ),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Code'),
                  textCapitalization: TextCapitalization.characters,
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: cloneFrom,
                  decoration: const InputDecoration(labelText: 'Clone columns from'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Start empty')),
                    ...commissions.map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => cloneFrom = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable rule editor'),
                  value: ruleEditor,
                  onChanged: (v) => setLocal(() => ruleEditor = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
                invalidateSalaryCommissions(ref);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
