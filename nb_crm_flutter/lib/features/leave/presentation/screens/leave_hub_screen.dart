import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/leave_models.dart';
import '../leave_providers.dart';
import '../widgets/leave_shared_widgets.dart';

class LeaveHubScreen extends ConsumerWidget {
  const LeaveHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(leaveYearFilterProvider);
    final balances = ref.watch(leaveBalancesProvider);
    final recentApps = ref.watch(myApplicationsProvider);

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Leave'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(leaveBalancesProvider);
              ref.invalidate(myApplicationsProvider);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Text('Year', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: year,
                items: List.generate(5, (i) {
                  final y = DateTime.now().year - 2 + i;
                  return DropdownMenuItem(value: y, child: Text('$y'));
                }),
                onChanged: (v) {
                  if (v != null) ref.read(leaveYearFilterProvider.notifier).set(v);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.go('/leave/apply'),
                  icon: const Icon(Icons.add),
                  label: const Text('Apply Leave'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/leave/history'),
                  icon: const Icon(Icons.history),
                  label: const Text('History'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Balances',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.midnight,
                ),
          ),
          const SizedBox(height: 12),
          LeaveAsyncBody<List<LeaveBalance>>(
            value: balances,
            emptyMessage: 'No leave balances for $year.',
            onRetry: () => ref.invalidate(leaveBalancesProvider),
            builder: (items) => Column(
              children: items.map((b) => _BalanceCard(balance: b)).toList(),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Recent Applications',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.midnight,
                ),
          ),
          const SizedBox(height: 12),
          LeaveAsyncBody<LeaveApplicationsPage>(
            value: recentApps,
            emptyMessage: 'No recent applications.',
            onRetry: () => ref.invalidate(myApplicationsProvider),
            builder: (page) {
              final items = page.items.take(5).toList();
              if (items.isEmpty) {
                return const Center(child: Text('No recent applications.'));
              }
              return Column(
                children: items
                    .map((a) => LeaveApplicationCard(application: a))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final LeaveBalance balance;

  @override
  Widget build(BuildContext context) {
    final name = balance.leaveType?.name ?? balance.leaveTypeId;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.midnight,
                    ),
                  ),
                  if (balance.leaveType?.code != null)
                    Text(
                      balance.leaveType!.code,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  balance.displayAvailable.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.midnight,
                  ),
                ),
                const Text('Available', style: TextStyle(fontSize: 12)),
                if (balance.pending > 0)
                  Text(
                    '${balance.pending.toStringAsFixed(1)} pending',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.bronzeDark,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
