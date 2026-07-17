import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/leave_models.dart';
import '../leave_providers.dart';
import '../widgets/leave_shared_widgets.dart';

/// Dedicated history filter — must not share Leave Admin's "All" status or PENDING
/// rows get labelled as "Approved".
class _HistoryStatusFilter extends Notifier<String> {
  @override
  String build() => 'APPROVED';

  void set(String status) => state = status;
}

final _historyStatusFilterProvider =
    NotifierProvider.autoDispose<_HistoryStatusFilter, String>(
  _HistoryStatusFilter.new,
);

final _approvalHistoryProvider =
    FutureProvider.autoDispose<LeaveApplicationsPage>((ref) async {
  final status = ref.watch(_historyStatusFilterProvider);
  return ref.watch(leaveRepositoryProvider).getAdminApplications(
        status: status.isEmpty ? null : status,
        year: DateTime.now().year,
        page: 0,
        limit: 50,
      );
});

class LeaveApprovalsHistoryScreen extends ConsumerWidget {
  const LeaveApprovalsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(_historyStatusFilterProvider);
    final appsAsync = ref.watch(_approvalHistoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Leave Approval History',
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
          onPressed: () => context.go('/approvals'),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
            height: 1.5,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                      width: 1.2,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: status,
                      dropdownColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFFC5A059)),
                      items: const [
                        DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                        DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
                        DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                        DropdownMenuItem(value: '', child: Text('All Statuses')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        ref.read(_historyStatusFilterProvider.notifier).set(v);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LeaveAsyncBody<LeaveApplicationsPage>(
              value: appsAsync,
              emptyMessage: 'No records in this history.',
              onRetry: () => ref.invalidate(_approvalHistoryProvider),
              builder: (page) {
                if (page.items.isEmpty) {
                  return Center(
                    child: Text(
                      'No records for this filter.',
                      style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF607D8B)),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  itemCount: page.items.length,
                  itemBuilder: (ctx, i) => LeaveApplicationCard(
                    application: page.items[i],
                    subtitle: page.items[i].employee?.fullName,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
