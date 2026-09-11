import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/bloc/load_status.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/tender_repository.dart';
import '../bloc/erp_tenders_bloc.dart';

class TenderListScreen extends StatelessWidget {
  const TenderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ErpTendersBloc(tenderRepository: ctx.read<TenderRepository>())
        ..add(const ErpTendersListRequested()),
      child: const _TenderListView(),
    );
  }
}

class _TenderListView extends StatelessWidget {
  const _TenderListView();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final canWrite = Permissions.canWriteTenders(auth.permissions, auth.user?.role);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final df = DateFormat('dd MMM yyyy');

    return BlocConsumer<ErpTendersBloc, ErpTendersState>(
      listener: (context, state) {
        if (state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.actionMessage!)),
          );
        }
        if (state.errorMessage != null && state.tenders.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
          appBar: AppBar(
            title: const Text('Tenders'),
            leading: const AppBackButton(fallbackLocation: '/erp/home'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => context.read<ErpTendersBloc>().add(const ErpTendersListRequested()),
              ),
            ],
          ),
          floatingActionButton: canWrite
              ? FloatingActionButton.extended(
                  onPressed: () => context.go('/erp/tenders/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('New Tender'),
                  backgroundColor: const Color(0xFF1e3a5f),
                )
              : null,
          body: Builder(
            builder: (context) {
              if (state.status == LoadStatus.loading && state.tenders.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.status == LoadStatus.failure && state.tenders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.errorMessage ?? 'Failed to load tenders'),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () => context.read<ErpTendersBloc>().add(const ErpTendersListRequested()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              final items = state.tenders;
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.gavel_outlined, size: 40, color: Theme.of(context).hintColor),
                      const SizedBox(height: 10),
                      Text('No tenders yet', style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).hintColor)),
                      const SizedBox(height: 4),
                      Text('Create a tender against a project or BOQ', style: TextStyle(color: Theme.of(context).hintColor)),
                    ],
                  ),
                );
              }
              return RepaintBoundary(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final t = items[i];
                    return Material(
                      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => context.go('/erp/tenders/${t.id}/edit'),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      t.tenderNo,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563eb).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      t.status,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2563eb),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                t.project?.name ?? 'Project',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${df.format(t.startDate)}  →  ${df.format(t.endDate)}',
                                style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (t.boq != null) _chip(Icons.receipt_long_outlined, t.boq!.boqNo),
                                  _chip(Icons.table_rows_outlined, '${t.lineCount ?? t.lines.length} lines'),
                                  _chip(Icons.handshake_outlined, '${t.applicationCount ?? 0} apps'),
                                  if (t.createdByName != null) _chip(Icons.person_outline, t.createdByName!),
                                ],
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
      },
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
        ],
      ),
    );
  }
}
