import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../org/domain/org_models.dart';
import '../../../org/presentation/org_providers.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../admin_notifier.dart';

bool isAdminRole(String? role) => (role ?? '').toUpperCase() == 'ADMIN';

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

Future<void> showInstituteTransferDialog({
  required BuildContext context,
  required WidgetRef ref,
  required int employeeId,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  await ref.read(activeInstitutesProvider.future).catchError((_) => const <Institute>[]);
  final institutes = ref.read(activeInstitutesProvider).asData?.value ?? const <Institute>[];
  final profile = ref.read(profileProvider).asData?.value;
  final currentId = profile?.generalInfo?.instituteId;
  String? selectedId = institutes.any((i) => i.id == currentId) ? currentId : null;
  final reasonCtrl = TextEditingController();
  DateTime effectiveFrom = DateTime.now();

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        title: const Text('Institute Transfer', style: TextStyle(fontWeight: FontWeight.w800)),
        scrollable: true,
        content: SizedBox(
          width: 420,
          child: Column(
            children: [
              Text(
                'Current: ${profile?.generalInfo?.instituteName ?? profile?.generalInfo?.subOrganization ?? "—"}',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF607D8B)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: selectedId,
                decoration: const InputDecoration(
                  labelText: 'Transfer to institute *',
                  border: OutlineInputBorder(),
                  helperText: 'From Configurations → Institutes',
                ),
                items: [
                  for (final inst in institutes.where((i) => i.isActive))
                    DropdownMenuItem(value: inst.id, child: Text('${inst.name} (${inst.code})')),
                ],
                onChanged: (v) => setDialogState(() => selectedId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Reason for transfer', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('Effective from: ${_fmtDate(effectiveFrom)}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: effectiveFrom,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setDialogState(() => effectiveFrom = picked);
                    },
                    child: const Text('Select date'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (selectedId == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select the destination institute')));
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref.read(adminRepositoryProvider).instituteTransfer(employeeId, {
                  'instituteId': selectedId,
                  'effectiveFrom': effectiveFrom.toIso8601String().split('T').first,
                  'reason': reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
                });
                ref.invalidate(employeeAssignmentsProvider(employeeId));
                await ref.read(profileProvider.notifier).refresh();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Institute transfer completed')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Transfer'),
          ),
        ],
      ),
    ),
  );
  reasonCtrl.dispose();
}

Future<void> showDesignationUpgradeDialog({
  required BuildContext context,
  required WidgetRef ref,
  required int employeeId,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  await ref.read(jobDesignationsProvider.future).catchError((_) => const <Designation>[]);
  final designations = (ref.read(jobDesignationsProvider).asData?.value ?? const <Designation>[])
      .where((d) => d.isActive && !d.isAlias)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final profile = ref.read(profileProvider).asData?.value;
  final currentName = profile?.generalInfo?.designation ?? '';
  String? selectedName;
  final reasonCtrl = TextEditingController();
  DateTime effectiveFrom = DateTime.now();

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        title: const Text('Designation Upgrade', style: TextStyle(fontWeight: FontWeight.w800)),
        scrollable: true,
        content: SizedBox(
          width: 420,
          child: Column(
            children: [
              Text(
                'Current: ${currentName.isEmpty ? "—" : currentName}',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF607D8B)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: selectedName,
                decoration: const InputDecoration(
                  labelText: 'New designation *',
                  border: OutlineInputBorder(),
                  helperText: 'From Configurations → Designations',
                ),
                items: [
                  for (final d in designations)
                    DropdownMenuItem(
                      value: d.name,
                      child: Text(d.name == currentName ? '${d.name} (current)' : d.name),
                    ),
                ],
                onChanged: (v) => setDialogState(() => selectedName = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Reason for upgrade', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('Effective from: ${_fmtDate(effectiveFrom)}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: effectiveFrom,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setDialogState(() => effectiveFrom = picked);
                    },
                    child: const Text('Select date'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = selectedName?.trim() ?? '';
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select the new designation')));
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref.read(adminRepositoryProvider).designationUpgrade(employeeId, {
                  'newDesignation': name,
                  'effectiveFrom': effectiveFrom.toIso8601String().split('T').first,
                  'reason': reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
                });
                ref.invalidate(employeeAssignmentsProvider(employeeId));
                await ref.read(profileProvider.notifier).refresh();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Designation upgraded')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    ),
  );
  reasonCtrl.dispose();
}

Widget hrChangeActionButtons({
  required BuildContext context,
  required WidgetRef ref,
  required int employeeId,
  VoidCallback? onDone,
}) {
  Future<void> run(Future<void> Function() action) async {
    await action();
    onDone?.call();
  }

  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => run(() => showInstituteTransferDialog(context: context, ref: ref, employeeId: employeeId)),
          icon: const Icon(Icons.swap_horiz_rounded, size: 16),
          label: const Text('Institute transfer'),
        ),
        OutlinedButton.icon(
          onPressed: () => run(() => showDesignationUpgradeDialog(context: context, ref: ref, employeeId: employeeId)),
          icon: const Icon(Icons.trending_up_rounded, size: 16),
          label: const Text('Designation upgrade'),
        ),
      ],
    ),
  );
}
