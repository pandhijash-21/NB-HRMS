import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/auth_providers.dart';
import '../../presentation/admin_notifier.dart';
import '../../domain/admin_models.dart';
import '../../../profile/presentation/profile_notifier.dart';

class AdminApprovalsScreen extends ConsumerWidget {
  const AdminApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Gate screen with Role Check (Admin/HR only)
    final role = authState.user?.role ?? '';
    final hasAccess = ['ADMIN', 'HR'].contains(role.toUpperCase());

    if (!hasAccess) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.gpp_bad_rounded, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.w800, 
                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Access Denied: Admin or HR permissions required.',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    final activeFilter = ref.watch(approvalsFilterProvider);
    final approvalsQueue = ref.watch(approvalsQueueProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Profile Update Approvals',
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
          onPressed: () => context.pop(),
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
            _buildFilterTabs(context, ref, activeFilter),
            Expanded(
              child: approvalsQueue.when(
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_turned_in_rounded,
                            size: 64,
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No change requests in this queue.',
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
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    itemCount: list.length,
                    itemBuilder: (ctx, i) {
                      final req = list[i];
                      return _buildRequestCard(context, ref, req);
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFC5A059)),
                ),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('Failed to load approvals: $err', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
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
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context, WidgetRef ref, String activeFilter) {
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildTabButton(context, ref, 'PENDING', activeFilter == 'PENDING'),
            const SizedBox(width: 8),
            _buildTabButton(context, ref, 'APPROVED', activeFilter == 'APPROVED'),
            const SizedBox(width: 8),
            _buildTabButton(context, ref, 'REJECTED', activeFilter == 'REJECTED'),
            const SizedBox(width: 8),
            _buildTabButton(context, ref, 'ALL', activeFilter == 'ALL'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(BuildContext context, WidgetRef ref, String label, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 36,
      child: TextButton(
        onPressed: () => ref.read(approvalsFilterProvider.notifier).set(label),
        style: TextButton.styleFrom(
          backgroundColor: isSelected
              ? (isDark ? const Color(0xFFC5A059) : const Color(0xFF263238))
              : Colors.transparent,
          foregroundColor: isSelected
              ? (isDark ? const Color(0xFF1A1816) : Colors.white)
              : (isDark ? Colors.white38 : const Color(0xFF607D8B)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected
                  ? Colors.transparent
                  : (isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC)),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, WidgetRef ref, ChangeRequest req) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(req.status);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  req.employee.generalInfo?.fullName ?? 'Employee #${req.employeeId}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800, 
                    fontSize: 15, 
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    border: Border.all(color: statusColor, width: 1.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    req.status,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Module: ${_moduleLabel(req.module)}  ·  Submitted: ${_formatDate(req.requestedAt)}',
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : const Color(0xFF607D8B),
              ),
            ),
            if (_changedFieldNames(req).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Changing: ${_changedFieldNames(req).take(6).join(', ')}${_changedFieldNames(req).length > 6 ? '…' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                ),
              ),
            ],
            Divider(
              height: 24,
              thickness: 1.2,
              color: isDark ? const Color(0xFFC5A059).withOpacity(0.12) : Colors.black.withOpacity(0.06),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showDiffDialog(context, req),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                    side: BorderSide(
                      color: isDark ? const Color(0xFFC5A059).withOpacity(0.4) : const Color(0xFFCFD8DC),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.difference_outlined, size: 14, color: Color(0xFFC5A059)),
                  label: const Text('View Changes Diff', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                ),
                if (req.status == 'PENDING')
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _confirmAction(context, ref, req, approve: false),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        icon: const Icon(Icons.close_rounded, size: 14),
                        label: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _confirmAction(context, ref, req, approve: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 14),
                        label: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final oldData = req.oldData;
    final newData = req.newData;

    // Filter keys that are in newData to compare them side by side
    final keys = newData.keys.where((k) => k != 'id' && k != 'employeeId' && k != 'updatedAt' && k != 'updatedBy').toList();

    showDialog(
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
          '${req.employee.generalInfo?.fullName ?? "Employee"} - ${req.module} Changes',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        content: SizedBox(
          width: 500,
          height: 350,
          child: keys.isEmpty
              ? const Center(child: Text('No explicit changes listed in request payload.', style: TextStyle(fontWeight: FontWeight.w600)))
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
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFFC5A059)),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                                  ),
                                  child: Text(
                                    'Old: $oldVal', 
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.redAccent),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                                  ),
                                  child: Text(
                                    'New: $newVal', 
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.green),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: isDark ? const Color(0xFFC5A059).withOpacity(0.1) : Colors.black.withOpacity(0.04),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: TextStyle(
                color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmAction(BuildContext context, WidgetRef ref, ChangeRequest req, {required bool approve}) {
    final actionName = approve ? 'Approve' : 'Reject';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
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
          '$actionName Request',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Are you sure you want to $actionName the change request for ${req.employee.generalInfo?.fullName ?? "this employee"}?',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF607D8B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FilledButton(
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
                    SnackBar(content: Text('Action failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: approve ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(actionName, style: const TextStyle(fontWeight: FontWeight.w800)),
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
        return Colors.red;
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

  String _moduleLabel(String module) {
    switch (module) {
      case 'PERSONAL':
        return 'Personal Info';
      case 'ADDRESS_LOCAL':
        return 'Local Address';
      case 'ADDRESS_PERMANENT':
        return 'Permanent Address';
      case 'ADDRESS':
        return 'Address';
      case 'OTHER':
        return 'Other Info';
      case 'BANK':
        return 'Bank Info';
      default:
        return module;
    }
  }

  List<String> _changedFieldNames(ChangeRequest req) {
    final skip = {'id', 'employeeId', 'updatedAt', 'updatedBy', 'createdAt', 'employee'};
    final keys = <String>{...req.oldData.keys, ...req.newData.keys};
    final changed = <String>[];
    for (final key in keys) {
      if (skip.contains(key)) continue;
      final oldVal = req.oldData[key];
      final newVal = req.newData[key];
      if ('$oldVal' != '$newVal') changed.add(_formatKeyName(key));
    }
    return changed;
  }
}
