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

class TenderApplicationsScreen extends StatelessWidget {
  const TenderApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ErpTendersBloc(tenderRepository: ctx.read<TenderRepository>())
        ..add(const ErpTenderApplicationsRequested()),
      child: const _TenderApplicationsView(),
    );
  }
}

class _TenderApplicationsView extends StatelessWidget {
  const _TenderApplicationsView();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final canWrite = Permissions.canWriteTenderApplications(auth.permissions, auth.user?.role);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final df = DateFormat('dd MMM yyyy');

    return BlocConsumer<ErpTendersBloc, ErpTendersState>(
      listener: (context, state) {
        if (state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.actionMessage!)),
          );
        }
        if (state.errorMessage != null && state.applications.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
          appBar: AppBar(
            title: const Text('Tender Applications'),
            leading: const AppBackButton(fallbackLocation: '/erp/home'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => context.read<ErpTendersBloc>().add(const ErpTenderApplicationsRequested()),
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
          body: Builder(
            builder: (context) {
              if (state.status == LoadStatus.loading && state.applications.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.status == LoadStatus.failure && state.applications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.errorMessage ?? 'Failed to load tender applications'),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () => context.read<ErpTendersBloc>().add(const ErpTenderApplicationsRequested()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              final items = state.applications;
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
              return RepaintBoundary(
                child: ListView.separated(
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
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                      ),
                                      const SizedBox(width: 8),
                                      _statusBadge(context, a.status),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    [
                                      if (a.contractorName != null || a.vendorName.isNotEmpty)
                                        a.contractorName ?? a.vendorName,
                                      if (a.tenderNo != null) 'Tender: ${a.tenderNo}',
                                      if (a.projectName != null) a.projectName!,
                                      if (a.activityName != null) a.activityName!,
                                      df.format(a.applicationDate),
                                    ].join(' · '),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context).hintColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (canWrite) ...[
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                tooltip: 'Change Status',
                                onSelected: (newStatus) {
                                  context.read<ErpTendersBloc>().add(
                                        ErpTenderApplicationStatusUpdated(id: a.id, status: newStatus),
                                      );
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'APPROVED', child: Text('Mark Approved')),
                                  const PopupMenuItem(value: 'UNDER_REVIEW', child: Text('Mark Under Review')),
                                  const PopupMenuItem(value: 'ACCEPTED', child: Text('Mark Accepted')),
                                  const PopupMenuItem(value: 'REJECTED', child: Text('Mark Rejected')),
                                  const PopupMenuItem(value: 'SUBMITTED', child: Text('Mark Submitted')),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  context.read<ErpTendersBloc>().add(ErpTenderApplicationDeleted(a.id));
                                },
                              ),
                            ],
                          ],
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

  Widget _statusBadge(BuildContext context, String status) {
    final s = status.toUpperCase();
    Color bg;
    Color fg;
    if (s == 'APPROVED' || s == 'ACCEPTED') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
    } else if (s == 'REJECTED') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
    } else if (s == 'UNDER_REVIEW') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
    } else {
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF075985);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        s,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
