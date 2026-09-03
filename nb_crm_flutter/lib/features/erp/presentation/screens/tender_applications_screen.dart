import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../tender_providers.dart';

class TenderApplicationsScreen extends ConsumerWidget {
  const TenderApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final canWrite = Permissions.canWriteWorkOrders(auth.permissions, auth.user?.role);
    final async = ref.watch(tenderApplicationListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final df = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Tender Applications'),
        leading: const AppBackButton(fallbackLocation: '/erp/home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(tenderApplicationListProvider),
          ),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/erp/tender-applications/new'),
              icon: const Icon(Icons.add),
              label: const Text('New Application'),
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
                  Icon(Icons.description_outlined, size: 40, color: Theme.of(context).hintColor),
                  const SizedBox(height: 10),
                  Text(
                    'No tender applications yet',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).hintColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Submit an application against a project tender',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final a = items[i];
              final title = a.applicationNo.isNotEmpty ? a.applicationNo : (a.contractorName ?? a.vendorName);
              return Material(
                color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 6),
                            Text(
                              [
                                if (a.contractorName != null || a.vendorName.isNotEmpty)
                                  a.contractorName ?? a.vendorName,
                                if (a.tenderNo != null) 'Tender: ${a.tenderNo}',
                                if (a.projectName != null) a.projectName!,
                                if (a.activityName != null) a.activityName!,
                                df.format(a.applicationDate),
                                a.status,
                              ].join(' · '),
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canWrite)
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await ref.read(tenderRepositoryProvider).removeApplication(a.id);
                            ref.invalidate(tenderApplicationListProvider);
                          },
                        ),
                    ],
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
