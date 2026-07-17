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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Leave History',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF212F3D),
          ),
          onPressed: () => context.go('/leave'),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
            height: 1.5,
          ),
        ),
      ),
      body: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0.0, 35.0 * (1.0 - value)),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Column(
          children: [
            _FiltersBar(filters: filters),
            Expanded(
              child: LeaveAsyncBody<LeaveApplicationsPage>(
                value: appsAsync,
                emptyMessage: 'No leave applications found.',
                onRetry: () => ref.invalidate(myApplicationsProvider),
                builder: (page) {
                  if (page.items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_toggle_off_rounded,
                            size: 64,
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No leave applications found.',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white30 : const Color(0xFF607D8B).withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          itemCount: page.items.length,
                          itemBuilder: (ctx, i) {
                            final app = page.items[i];
                            final isPending = app.status.toUpperCase() == 'PENDING';
                            return LeaveApplicationCard(
                              application: app,
                              trailing: isPending
                                  ? OutlinedButton.icon(
                                      onPressed: () => _confirmCancel(context, ref, app),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                      ),
                                      icon: const Icon(Icons.cancel_outlined, size: 14),
                                      label: const Text('Cancel Request'),
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
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    LeaveApplication app,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
        title: Text(
          'Cancel Application?',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Are you sure you want to cancel application ${app.applicationNo}?',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF607D8B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'No',
              style: TextStyle(
                color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Yes, Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.12) : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Text(
            'Filters',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white54 : const Color(0xFF607D8B),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                // Status Filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.filter_list_rounded, size: 14, color: Color(0xFFC5A059)),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: filters.status.isEmpty ? '' : filters.status,
                        dropdownColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFFC5A059)),
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF212F3D),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('All Statuses')),
                          DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                          DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                          DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
                          DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                        ],
                        onChanged: (v) =>
                            ref.read(myApplicationsFilterProvider.notifier).setStatus(v ?? ''),
                      ),
                    ],
                  ),
                ),
                // Year Filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFFC5A059)),
                      const SizedBox(width: 8),
                      DropdownButton<int?>(
                        value: filters.year,
                        dropdownColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFFC5A059)),
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF212F3D),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('All Years')),
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
                ),
              ],
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalPages = total == 0 ? 1 : ((total - 1) / limit).floor() + 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.12) : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: page > 0 ? () => onPage(page - 1) : null,
            icon: Icon(
              Icons.chevron_left_rounded,
              color: page > 0 
                  ? (isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238)) 
                  : Colors.grey.withOpacity(0.4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Page ${page + 1} of $totalPages (${total} total)',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: isDark ? Colors.white70 : const Color(0xFF263238),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: page + 1 < totalPages ? () => onPage(page + 1) : null,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: page + 1 < totalPages 
                  ? (isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238)) 
                  : Colors.grey.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}


