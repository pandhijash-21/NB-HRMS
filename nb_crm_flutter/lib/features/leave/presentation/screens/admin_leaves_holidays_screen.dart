import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/leave_models.dart';
import '../leave_providers.dart';
import '../widgets/leave_shared_widgets.dart';

class AdminLeavesHolidaysScreen extends ConsumerWidget {
  const AdminLeavesHolidaysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(holidaysYearFilterProvider);
    final holidaysAsync = ref.watch(adminHolidaysProvider);

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Public Holidays'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/leaves'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, ref, year),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text('Year'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: year,
                  items: List.generate(5, (i) {
                    final y = DateTime.now().year - 1 + i;
                    return DropdownMenuItem(value: y, child: Text('$y'));
                  }),
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(holidaysYearFilterProvider.notifier).set(v);
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: holidaysAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.bronze),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$e'),
                    FilledButton(
                      onPressed: () => ref.invalidate(adminHolidaysProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (holidays) {
                if (holidays.isEmpty) {
                  return Center(child: Text('No holidays for $year.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: holidays.length,
                  itemBuilder: (ctx, i) => _HolidayTile(holiday: holidays[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog(
    BuildContext context,
    WidgetRef ref,
    int year,
  ) async {
    final nameController = TextEditingController();
    DateTime? date;
    var isOptional = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add holiday'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime(year, 1, 1),
                    firstDate: DateTime(year - 1),
                    lastDate: DateTime(year + 2),
                  );
                  if (d != null) setLocal(() => date = d);
                },
                child: Text(date == null ? 'Pick date' : formatDateYmd(date!)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Optional holiday'),
                value: isOptional,
                onChanged: (v) => setLocal(() => isOptional = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty || date == null) return;
                try {
                  await ref.read(leaveRepositoryProvider).addAdminHoliday({
                    'name': nameController.text.trim(),
                    'date': formatDateYmd(date!),
                    'year': date!.year,
                    'isOptional': isOptional,
                  });
                  invalidateLeaveAdminData(ref);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
  }
}

class _HolidayTile extends ConsumerWidget {
  const _HolidayTile({required this.holiday});

  final PublicHoliday holiday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(holiday.name),
        subtitle: Text('${holiday.date}${holiday.isOptional ? ' · Optional' : ''}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete holiday?'),
                content: Text('Remove ${holiday.name}?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                ],
              ),
            );
            if (ok != true) return;
            try {
              await ref.read(leaveRepositoryProvider).deleteAdminHoliday(holiday.id);
              invalidateLeaveAdminData(ref);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            }
          },
        ),
      ),
    );
  }
}
