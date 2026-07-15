import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../admin/presentation/admin_notifier.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../leave/presentation/leave_providers.dart';
import '../../../profile/domain/profile_models.dart';

final _dashboardEmployeesProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.read(adminRepositoryProvider).listEmployees(limit: 1000, offset: 0);
});

final _recentEmployeesProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.read(adminRepositoryProvider).listEmployees(limit: 5, offset: 0);
});

final _pendingApprovalsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final list = await ref.read(adminRepositoryProvider).listApprovals(status: 'PENDING');
  return list.length;
});

final _pendingLeaveCountProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final page = await ref.read(leaveRepositoryProvider).getAdminApplications(
          status: 'PENDING',
          limit: 1,
          page: 0,
        );
    return page.total;
  } catch (_) {
    return 0;
  }
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final hasAccess = Permissions.canAccessAdminPortal(
      auth.permissions,
      auth.user?.employeeViewScope,
    );

    if (!hasAccess) {
      return const Scaffold(
        body: Center(child: Text('Access Denied')),
      );
    }

    final employeesAsync = ref.watch(_dashboardEmployeesProvider);
    final recentAsync = ref.watch(_recentEmployeesProvider);
    final pendingAsync = ref.watch(_pendingApprovalsCountProvider);
    final leavePendingAsync = ref.watch(_pendingLeaveCountProvider);

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(_dashboardEmployeesProvider);
              ref.invalidate(_recentEmployeesProvider);
              ref.invalidate(_pendingApprovalsCountProvider);
              ref.invalidate(_pendingLeaveCountProvider);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Overview of the HR system',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          employeesAsync.when(
            data: (data) {
              final items = data['items'] as List<EmployeeProfile>;
              final total = data['total'] as int;
              final activeCount =
                  items.where((e) => e.status.toUpperCase() == 'ACTIVE').length;
              final departments = items
                  .map((e) => e.generalInfo?.department)
                  .whereType<String>()
                  .where((d) => d.isNotEmpty)
                  .toSet()
                  .length;

              return Column(
                children: [
                  GridView.count(
                    crossAxisCount: MediaQuery.sizeOf(context).width >= 720 ? 2 : 1,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.2,
                    children: [
                      _KpiCard(
                        label: 'Total Employees',
                        value: '$total',
                        icon: Icons.people_outline,
                        onTap: () => context.push('/admin/employees'),
                      ),
                      _KpiCard(
                        label: 'Active',
                        value: '$activeCount',
                        icon: Icons.check_circle_outline,
                        accent: AppColors.success,
                      ),
                      _KpiCard(
                        label: 'Departments',
                        value: departments == 0 ? '—' : '$departments',
                        icon: Icons.business_center_outlined,
                      ),
                      pendingAsync.when(
                        data: (count) => _KpiCard(
                          label: 'Pending Actions',
                          value: '$count',
                          icon: Icons.pending_actions_outlined,
                          accent: AppColors.bronzeDark,
                          onTap: () => context.push('/admin/approvals'),
                        ),
                        loading: () => const _KpiCard.loading(label: 'Pending Actions'),
                        error: (_, __) => const _KpiCard(
                          label: 'Pending Actions',
                          value: '—',
                          icon: Icons.pending_actions_outlined,
                        ),
                      ),
                      leavePendingAsync.when(
                        data: (count) => _KpiCard(
                          label: 'Pending Leave',
                          value: count == 0 ? '—' : '$count',
                          icon: Icons.event_busy_outlined,
                          onTap: count > 0 ? () => context.push('/admin/leaves/pending') : null,
                        ),
                        loading: () => const _KpiCard.loading(label: 'Pending Leave'),
                        error: (_, __) => const _KpiCard(
                          label: 'Pending Leave',
                          value: '—',
                          icon: Icons.event_busy_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.bronze),
              ),
            ),
            error: (err, _) => _ErrorPanel(
              message: 'Failed to load dashboard',
              detail: '$err',
              onRetry: () => ref.invalidate(_dashboardEmployeesProvider),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Employees',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.midnight),
                      ),
                      TextButton(
                        onPressed: () => context.push('/admin/employees'),
                        child: const Text('View all →'),
                      ),
                    ],
                  ),
                  recentAsync.when(
                    data: (data) {
                      final list = data['items'] as List<EmployeeProfile>;
                      if (list.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No employees yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        );
                      }
                      return Column(
                        children: list.map((emp) => _recentRow(context, emp)).toList(),
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator(color: AppColors.bronze)),
                    ),
                    error: (err, _) => _ErrorPanel(
                      message: 'Failed to load recent employees',
                      detail: '$err',
                      onRetry: () => ref.invalidate(_recentEmployeesProvider),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentRow(BuildContext context, EmployeeProfile emp) {
    return InkWell(
      onTap: () => context.push('/admin/employees/${emp.id}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emp.generalInfo?.fullName ?? 'Employee #${emp.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.midnight,
                    ),
                  ),
                  Text(
                    '${emp.generalInfo?.employeeCode ?? '—'} · ${emp.generalInfo?.designation ?? '—'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
    this.onTap,
  });

  const _KpiCard.loading({required this.label})
      : value = '…',
        icon = Icons.hourglass_empty,
        accent = null,
        onTap = null;

  final String label;
  final String value;
  final IconData icon;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      elevation: 0,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: accent ?? AppColors.midnight,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.midnight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.bronze, size: 22),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: card,
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(detail, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
