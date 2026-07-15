import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../presentation/admin_notifier.dart';
import '../../domain/admin_models.dart';
import '../../../profile/presentation/profile_notifier.dart';

class AdminApprovalsScreen extends ConsumerWidget {
  const AdminApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    // Gate screen with Role Check (Admin/HR only)
    final role = authState.user?.role ?? '';
    final hasAccess = const ['ADMIN', 'HR'].contains(role.toUpperCase());

    if (!hasAccess) {
      return const Scaffold(
        body: Center(child: Text('Access Denied: Admin or HR permissions required.')),
      );
    }

    final activeFilter = ref.watch(approvalsFilterProvider);
    final approvalsQueue = ref.watch(approvalsQueueProvider);

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Profile Update Approvals'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          _buildFilterTabs(ref, activeFilter),
          Expanded(
            child: approvalsQueue.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('No change requests in this queue.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) {
                    final req = list[i];
                    return _buildRequestCard(context, ref, req);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.bronze)),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Failed to load approvals: $err'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref.invalidate(approvalsQueueProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(WidgetRef ref, String activeFilter) {
    return Container(
      color: AppColors.midnight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTabButton(ref, 'PENDING', activeFilter == 'PENDING'),
          _buildTabButton(ref, 'APPROVED', activeFilter == 'APPROVED'),
          _buildTabButton(ref, 'REJECTED', activeFilter == 'REJECTED'),
          _buildTabButton(ref, 'ALL', activeFilter == 'ALL'),
        ],
      ),
    );
  }

  Widget _buildTabButton(WidgetRef ref, String label, bool isSelected) {
    return TextButton(
      onPressed: () => ref.read(approvalsFilterProvider.notifier).set(label),
      style: TextButton.styleFrom(
        foregroundColor: isSelected ? AppColors.bronze : Colors.white70,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, WidgetRef ref, ChangeRequest req) {
    final statusColor = _getStatusColor(req.status);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  req.employee.generalInfo?.fullName ?? 'Employee #${req.employeeId}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.midnight),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    req.status,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Module: ${req.module}  ·  Submitted: ${_formatDate(req.requestedAt)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showDiffDialog(context, req),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sand,
                    foregroundColor: AppColors.midnight,
                    elevation: 0,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.difference_outlined, size: 14),
                  label: const Text('View Changes Diff', style: TextStyle(fontSize: 11)),
                ),
                if (req.status == 'PENDING')
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _confirmAction(context, ref, req, approve: false),
                        style: TextButton.styleFrom(foregroundColor: AppColors.error),
                        icon: const Icon(Icons.close, size: 14),
                        label: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _confirmAction(context, ref, req, approve: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.check, size: 14),
                        label: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDiffDialog(BuildContext context, ChangeRequest req) {
    final oldData = req.oldData;
    final newData = req.newData;

    // Filter keys that are in newData to compare them side by side
    final keys = newData.keys.where((k) => k != 'id' && k != 'employeeId' && k != 'updatedAt' && k != 'updatedBy').toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${req.employee.generalInfo?.fullName ?? "Employee"} - ${req.module} Changes'),
        content: SizedBox(
          width: 500,
          height: 300,
          child: keys.isEmpty
              ? const Center(child: Text('No explicit changes listed in payload.'))
              : ListView.builder(
                  itemCount: keys.length,
                  itemBuilder: (context, index) {
                    final key = keys[index];
                    final oldVal = oldData[key]?.toString() ?? 'None';
                    final newVal = newData[key]?.toString() ?? 'None';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatKeyName(key),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.bronze),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  color: AppColors.errorSoft.withValues(alpha: 0.5),
                                  child: Text('Old: $oldVal', style: const TextStyle(fontSize: 11)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  color: AppColors.successSoft.withValues(alpha: 0.5),
                                  child: Text('New: $newVal', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _confirmAction(BuildContext context, WidgetRef ref, ChangeRequest req, {required bool approve}) {
    final actionName = approve ? 'Approve' : 'Reject';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionName Request'),
        content: Text('Are you sure you want to $actionName the change request for ${req.employee.generalInfo?.fullName ?? "this employee"}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = ref.read(adminRepositoryProvider);
                if (approve) {
                  await repo.approveRequest(req.id);
                  ref.invalidate(profileProvider);
                } else {
                  await repo.rejectRequest(req.id);
                }
                ref.invalidate(approvalsQueueProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Request successfully ${approve ? "approved" : "rejected"}')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Action failed: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: Text(actionName, style: TextStyle(color: approve ? Colors.green : AppColors.error)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return AppColors.error;
      case 'PENDING':
      default:
        return Colors.orange;
    }
  }

  String _formatKeyName(String key) {
    // Convert camelCase to Title Case
    final result = key.replaceAllMapped(RegExp(r'(^[a-z]|[A-Z])'), (Match m) {
      if (m.start == 0) return m[0]!.toUpperCase();
      return ' ${m[0]!}';
    });
    return result;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
