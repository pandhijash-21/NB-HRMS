import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/boq_models.dart';
import '../boq_providers.dart';
import '../project_providers.dart';
import '../widgets/boq_summary_panel.dart';

class BoqListScreen extends ConsumerStatefulWidget {
  const BoqListScreen({super.key});

  @override
  ConsumerState<BoqListScreen> createState() => _BoqListScreenState();
}

class _BoqListScreenState extends ConsumerState<BoqListScreen> {
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
    final auth = ref.watch(authNotifierProvider);
    final canWrite = Permissions.canWriteWorkOrders(auth.permissions, auth.user?.role);
    final async = ref.watch(boqListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('BOQ'),
        leading: const AppBackButton(fallbackLocation: '/erp/home'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(boqListProvider)),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/erp/boq/new'),
              icon: const Icon(Icons.add),
              label: const Text('New BOQ'),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
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

          return ListView.separated(
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
          );
        },
      ),
    );
  }
}

class _BoqListCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final rateLabel = boq.rateSource == 'CURRENT_RATE' ? 'Current Rate' : 'Estimated Rate';
    final towers = ref.watch(projectTowersProvider(boq.projectId)).asData?.value ?? const [];

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
                  child: BoqTasksSummaryTable(tasks: boq.tasks, towers: towers),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
