import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/leave_models.dart';
import '../leave_providers.dart';
import '../widgets/leave_shared_widgets.dart';

class LeaveHistoryScreen extends ConsumerWidget {
  const LeaveHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(myApplicationsFilterProvider);
    final appsAsync = ref.watch(myApplicationsProvider);

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Leave History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/leave'),
        ),
      ),
      body: Column(
        children: [
          _FiltersBar(filters: filters),
          Expanded(
            child: LeaveAsyncBody<LeaveApplicationsPage>(
              value: appsAsync,
              emptyMessage: 'No leave applications found.',
              onRetry: () => ref.invalidate(myApplicationsProvider),
              builder: (page) {
                if (page.items.isEmpty) {
                  return const Center(child: Text('No leave applications found.'));
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: page.items.length,
                        itemBuilder: (ctx, i) {
                          final app = page.items[i];
                          return LeaveApplicationCard(
                            application: app,
                            trailing: app.status.toUpperCase() == 'PENDING'
                                ? TextButton(
                                    onPressed: () =>
                                        _confirmCancel(context, ref, app),
                                    child: const Text('Cancel'),
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                    _Pagination(
                      page: filters.page,
                      limit: filters.limit,
                      total: page.total,
                      onPage: (p) =>
                          ref.read(myApplicationsFilterProvider.notifier).setPage(p),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    LeaveApplication app,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel application?'),
        content: Text('Cancel ${app.applicationNo}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, cancel')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(leaveRepositoryProvider).cancelApplication(app.id);
      invalidateLeaveSelfData(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application cancelled.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _FiltersBar extends ConsumerWidget {
  const _FiltersBar({required this.filters});

  final MyApplicationsFilter filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButton<String>(
            value: filters.status.isEmpty ? '' : filters.status,
            items: const [
              DropdownMenuItem(value: '', child: Text('All statuses')),
              DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
              DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
              DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
              DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
            ],
            onChanged: (v) =>
                ref.read(myApplicationsFilterProvider.notifier).setStatus(v ?? ''),
          ),
          DropdownButton<int?>(
            value: filters.year,
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('All years')),
              ...List.generate(5, (i) {
                final y = DateTime.now().year - 2 + i;
                return DropdownMenuItem<int?>(value: y, child: Text('$y'));
              }),
            ],
            onChanged: (v) =>
                ref.read(myApplicationsFilterProvider.notifier).setYear(v),
          ),
        ],
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.onPage,
  });

  final int page;
  final int limit;
  final int total;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final totalPages = total == 0 ? 1 : ((total - 1) / limit).floor() + 1;
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: page > 0 ? () => onPage(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Page ${page + 1} of $totalPages ($total total)'),
          IconButton(
            onPressed: page + 1 < totalPages ? () => onPage(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
