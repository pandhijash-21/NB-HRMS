import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/leave_models.dart';
import '../leave_providers.dart';
import '../widgets/leave_shared_widgets.dart';

class LeaveApprovalsHistoryScreen extends ConsumerWidget {
  const LeaveApprovalsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(adminApplicationsFilterProvider);
    final appsAsync = ref.watch(adminApplicationsProvider);
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
      body: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0.0, 30.0 * (1.0 - value)),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Column(
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
                        value: filters.status.isEmpty ? 'APPROVED' : filters.status,
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
                        onChanged: (v) => ref
                            .read(adminApplicationsFilterProvider.notifier)
                            .setStatus(v ?? ''),
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
                onRetry: () => ref.invalidate(adminApplicationsProvider),
                builder: (page) => ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  itemCount: page.items.length,
                  itemBuilder: (ctx, i) => LeaveApplicationCard(
                    application: page.items[i],
                    subtitle: page.items[i].employee?.fullName,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
