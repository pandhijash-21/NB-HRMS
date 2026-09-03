import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../work_order_providers.dart';

class ContractorsConfigScreen extends ConsumerWidget {
  const ContractorsConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(erpContractorsAdminProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Contractors'),
        leading: const AppBackButton(fallbackLocation: '/erp/configurations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(erpContractorsAdminProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/erp/configurations/contractors/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add Contractor'),
        backgroundColor: const Color(0xFF1e3a5f),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No contractors yet. Add one to get started.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final c = items[i];
              return Material(
                color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.go('/erp/configurations/contractors/${c.id}/edit'),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if (c.mobileNo != null || c.phone != null) c.mobileNo ?? c.phone!,
                                  if (c.email != null) c.email!,
                                  if (c.contractorTypeCode != null) c.contractorTypeCode!,
                                ].join(' · '),
                                style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${c.locationCount ?? c.locations.length} locations · '
                                '${c.contactCount ?? c.contacts.length} contacts · '
                                '${c.documentCount ?? c.documents.length} docs',
                                style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: c.isActive,
                          onChanged: (_) async {
                            await ref.read(workOrderRepositoryProvider).toggleContractor(c.id);
                            ref.invalidate(erpContractorsAdminProvider);
                            ref.invalidate(erpContractorsProvider);
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
