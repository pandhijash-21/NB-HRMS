import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/bloc/load_status.dart';
import '../../../../core/router/app_back_button.dart';
import '../bloc/erp_work_orders_bloc.dart';

class ContractorsConfigScreen extends StatefulWidget {
  const ContractorsConfigScreen({super.key});

  @override
  State<ContractorsConfigScreen> createState() => _ContractorsConfigScreenState();
}

class _ContractorsConfigScreenState extends State<ContractorsConfigScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ErpWorkOrdersBloc>().add(const ErpContractorsRequested(includeInactive: true));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Contractors'),
        leading: const AppBackButton(fallbackLocation: '/erp/configurations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ErpWorkOrdersBloc>().add(
                  const ErpContractorsRequested(includeInactive: true),
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/erp/configurations/contractors/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add Contractor'),
        backgroundColor: const Color(0xFF1e3a5f),
      ),
      body: BlocBuilder<ErpWorkOrdersBloc, ErpWorkOrdersState>(
        builder: (context, state) {
          if (state.status == LoadStatus.loading && state.contractors.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == LoadStatus.failure && state.contractors.isEmpty) {
            return Center(child: Text(state.errorMessage ?? 'Error loading contractors'));
          }
          final items = state.contractors;
          if (items.isEmpty) {
            return const Center(child: Text('No contractors yet. Add one to get started.'));
          }
          return RepaintBoundary(
            child: ListView.separated(
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
                            onChanged: (_) {
                              context.read<ErpWorkOrdersBloc>().add(ErpContractorToggled(c.id));
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
