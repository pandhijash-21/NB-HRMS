import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/bloc/load_status.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/boq_repository.dart';
import '../../data/project_repository.dart';
import '../../domain/boq_models.dart';
import '../../domain/structure_models.dart';
import '../bloc/erp_boq_bloc.dart';
import '../widgets/boq_summary_panel.dart';

class BoqListScreen extends StatelessWidget {
  const BoqListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ErpBoqBloc>(
      create: (ctx) => ErpBoqBloc(
        boqRepository: ctx.read<BoqRepository>(),
      )..add(const ErpBoqListRequested()),
      child: const _BoqListView(),
    );
  }
}

class _BoqListView extends StatefulWidget {
  const _BoqListView();

  @override
  State<_BoqListView> createState() => _BoqListViewState();
}

class _BoqListViewState extends State<_BoqListView> {
  final Set<String> _expanded = {};
  bool _didInitExpand = false;

  void _toggleExpanded(String id) {
    setState(() {
      if (_expanded.contains(id)) {
        _expanded.remove(id);
      } else {
        _expanded.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final canWrite = Permissions.canWriteBoq(auth.permissions, auth.user?.role);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<ErpBoqBloc, ErpBoqState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
        if (state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.actionMessage!)),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('BOQ'),
            leading: const AppBackButton(fallbackLocation: '/erp/home'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => context
                    .read<ErpBoqBloc>()
                    .add(const ErpBoqListRequested()),
              ),
            ],
          ),
          floatingActionButton: canWrite
              ? FloatingActionButton.extended(
                  onPressed: () => context.go('/erp/boq/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('New BOQ'),
                )
              : null,
          body: () {
            if (state.status == LoadStatus.loading && state.boqs.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.status == LoadStatus.failure && state.boqs.isEmpty) {
              return Center(child: Text(state.errorMessage ?? 'Failed to load BOQs'));
            }
            final items = state.boqs;
            if (items.isEmpty) {
              return const Center(child: Text('No BOQ forms yet.'));
            }
            if (!_didInitExpand) {
              _didInitExpand = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() => _expanded.addAll(items.map((b) => b.id)));
              });
            }

            return RepaintBoundary(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _BoqListCard(
                  boq: items[i],
                  isDark: isDark,
                  expanded: _expanded.contains(items[i].id),
                  onToggleExpand: () => _toggleExpanded(items[i].id),
                  onEdit: () => context.go('/erp/boq/${items[i].id}/edit'),
                ),
              ),
            );
          }(),
        );
      },
    );
  }
}

class _BoqListCard extends StatelessWidget {
  const _BoqListCard({
    required this.boq,
    required this.isDark,
    required this.expanded,
    required this.onToggleExpand,
    required this.onEdit,
  });

  final ErpBoq boq;
  final bool isDark;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final rateLabel = boq.rateSource == 'CURRENT_RATE' ? 'Current Rate' : 'Estimated Rate';

    return Material(
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${boq.boqNo} — ${boq.title}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${boq.project?.name ?? 'Project'} · ${boq.tasks.length} tasks · $rateLabel',
                            style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor),
                          ),
                          if (boq.tasks.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Grand total: ${boq.grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563eb),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: expanded ? 'Hide task summary' : 'Show task summary',
                      onPressed: onToggleExpand,
                      icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                    ),
                  ],
                ),
              ),
              if (expanded) ...[
                Divider(height: 1, color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: FutureBuilder<List<ErpProjectTower>>(
                    future: context.read<ProjectRepository>().listTowers(boq.projectId),
                    builder: (context, snapshot) {
                      final towers = snapshot.data ?? const [];
                      return BoqTasksSummaryTable(tasks: boq.tasks, towers: towers);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
