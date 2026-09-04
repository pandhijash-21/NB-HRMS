import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../dpr_providers.dart';

class DprListScreen extends ConsumerWidget {
  const DprListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final canWrite = Permissions.canWriteWorkOrders(auth.permissions, auth.user?.role);
    final async = ref.watch(dprListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final df = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Daily Progress Report'),
        leading: const AppBackButton(fallbackLocation: '/erp/home'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(dprListProvider)),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/erp/dpr/new'),
              icon: const Icon(Icons.add),
              label: const Text('New DPR'),
              backgroundColor: const Color(0xFF1e3a5f),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment_turned_in_outlined, size: 40, color: Theme.of(context).hintColor),
                  const SizedBox(height: 10),
                  Text('No DPRs yet', style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).hintColor)),
                  const SizedBox(height: 4),
                  Text('Create a daily progress report for a project', style: TextStyle(color: Theme.of(context).hintColor)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final d = items[i];
              return Material(
                color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.go('/erp/dpr/${d.id}'),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.dprNo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              const SizedBox(height: 6),
                              Text(
                                [
                                  d.project?.name ?? d.projectId,
                                  df.format(d.reportDate),
                                  if (d.createdByName != null) d.createdByName!,
                                  '${d.lineCount ?? d.lines.length} task(s)',
                                ].join(' · '),
                                style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor),
                              ),
                            ],
                          ),
                        ),
                        if (canWrite)
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await ref.read(dprRepositoryProvider).remove(d.id);
                              ref.invalidate(dprListProvider);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
