import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/bloc/load_status.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../../core/tour/models/tour_models.dart';
import '../../../../core/tour/widgets/tour_target.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/dpr_repository.dart';
import '../bloc/erp_dpr_bloc.dart';

class DprListScreen extends StatelessWidget {
  const DprListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ErpDprBloc(dprRepository: ctx.read<DprRepository>())
        ..add(const ErpDprListRequested()),
      child: const _DprListView(),
    );
  }
}

class _DprListView extends StatelessWidget {
  const _DprListView();

  Future<void> _showEditWindowSettings(BuildContext context) async {
    final repo = context.read<DprRepository>();
    try {
      final settings = await repo.getSettings();
      if (!context.mounted) return;
      final ctrl = TextEditingController(text: '${settings.editWindowDays}');
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('DPR edit window'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Editable for how many days after report date?',
              helperText: 'Default 10. Example: report on 28th stays editable until day 10.',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      final days = int.tryParse(ctrl.text.trim());
      if (days == null || days < 0 || days > 365) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a number between 0 and 365')),
        );
        return;
      }
      await repo.updateSettings(editWindowDays: days);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('DPR edit window set to $days day(s)')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final canWrite = Permissions.canWriteDpr(auth.permissions, auth.user?.role);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final df = DateFormat('dd MMM yyyy');

    return BlocConsumer<ErpDprBloc, ErpDprState>(
      listener: (context, state) {
        if (state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.actionMessage!)),
          );
        }
        if (state.errorMessage != null && state.dprs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
          appBar: AppBar(
            title: const Text('Daily Progress Report'),
            leading: const AppBackButton(fallbackLocation: '/erp/home'),
            actions: [
              if (canWrite)
                IconButton(
                  tooltip: 'DPR edit window (days)',
                  icon: const Icon(Icons.tune),
                  onPressed: () => _showEditWindowSettings(context),
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => context.read<ErpDprBloc>().add(const ErpDprListRequested()),
              ),
            ],
          ),
          floatingActionButton: canWrite
              ? TourTarget(
                  id: TourIds.step('erp.dpr', 2),
                  child: FloatingActionButton.extended(
                  onPressed: () => context.go('/erp/dpr/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('New DPR'),
                  backgroundColor: const Color(0xFF1e3a5f),
                ),
                )
              : null,
          body: Builder(
            builder: (context) {
              if (state.status == LoadStatus.loading && state.dprs.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.status == LoadStatus.failure && state.dprs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.errorMessage ?? 'Failed to load DPRs'),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () => context.read<ErpDprBloc>().add(const ErpDprListRequested()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              final items = state.dprs;
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
              return RepaintBoundary(
                child: ListView.separated(
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
                                  onPressed: () {
                                    context.read<ErpDprBloc>().add(ErpDprDeleted(d.id));
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
      },
    );
  }
}
