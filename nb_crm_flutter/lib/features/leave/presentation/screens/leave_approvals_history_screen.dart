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

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Leave Approval History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/approvals'),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              children: [
                DropdownButton<String>(
                  value: filters.status.isEmpty ? 'APPROVED' : filters.status,
                  items: const [
                    DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                    DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
                    DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                    DropdownMenuItem(value: '', child: Text('All')),
                  ],
                  onChanged: (v) => ref
                      .read(adminApplicationsFilterProvider.notifier)
                      .setStatus(v ?? ''),
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
                padding: const EdgeInsets.all(16),
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
    );
  }
}
