import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/tour/models/tour_models.dart';
import '../../../../core/tour/widgets/tour_target.dart';
import '../../domain/leave_models.dart';
import '../leave_providers.dart';
import '../widgets/leave_shared_widgets.dart';

class LeaveApprovalsScreen extends ConsumerWidget {
  const LeaveApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(pendingApprovalsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            'Approvals Queue',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: isDark ? Colors.white : const Color(0xFF212F3D),
              letterSpacing: -0.5,
            ),
          ),
          leading: const AppBackButton(fallbackLocation: '/leave'),
          actions: [
            TourTarget(
              id: TourIds.step('hrms.leave', 5),
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: TextButton.icon(
                  onPressed: () => context.go('/approvals/history'),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  icon: const Icon(Icons.history_rounded, size: 16, color: Color(0xFFC5A059)),
                  label: const Text('History'),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(49.5),
            child: Column(
              children: [
                TabBar(
                  indicatorColor: const Color(0xFFC5A059),
                  indicatorWeight: 3,
                  labelColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF212F3D),
                  unselectedLabelColor: isDark ? Colors.white54 : const Color(0xFF64748B),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.event_note_rounded, size: 16),
                          const SizedBox(width: 8),
                          queue.when(
                            data: (items) {
                              final leaveCount = items.where((a) => !a.isWfh).length;
                              return Text(
                                leaveCount > 0 ? 'Leave Requests ($leaveCount)' : 'Leave Requests',
                              );
                            },
                            loading: () => const Text('Leave Requests'),
                            error: (_, __) => const Text('Leave Requests'),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.home_work_rounded, size: 16),
                          const SizedBox(width: 8),
                          queue.when(
                            data: (items) {
                              final wfhCount = items.where((a) => a.isWfh).length;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    wfhCount > 0 ? 'Work From Home ($wfhCount)' : 'Work From Home',
                                  ),
                                  if (wfhCount > 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0D9488),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$wfhCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                            loading: () => const Text('Work From Home'),
                            error: (_, __) => const Text('Work From Home'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.15) : const Color(0xFFCFD8DC),
                  height: 1.5,
                ),
              ],
            ),
          ),
        ),
        body: LeaveAsyncBody<List<LeaveApplication>>(
          value: queue,
          emptyMessage: 'No pending requests.',
          onRetry: () => ref.invalidate(pendingApprovalsProvider),
          builder: (items) {
            final leaveItems = items.where((a) => !a.isWfh).toList();
            final wfhItems = items.where((a) => a.isWfh).toList();

            return TabBarView(
              children: [
                // ─── Section 1: Leave Requests ──────────────────────────────────
                _buildSectionList(
                  context,
                  ref,
                  items: leaveItems,
                  emptyMessage: 'No pending leave requests.',
                  emptyIcon: Icons.event_available_rounded,
                  isDark: isDark,
                ),
                // ─── Section 2: Work From Home (WFH) Requests ───────────────────
                _buildSectionList(
                  context,
                  ref,
                  items: wfhItems,
                  emptyMessage: 'No pending Work From Home (WFH) requests.',
                  emptyIcon: Icons.home_work_outlined,
                  isDark: isDark,
                  isWfhSection: true,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionList(
    BuildContext context,
    WidgetRef ref, {
    required List<LeaveApplication> items,
    required String emptyMessage,
    required IconData emptyIcon,
    required bool isDark,
    bool isWfhSection = false,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                emptyIcon,
                size: 56,
                color: isDark ? Colors.white24 : const Color(0xFFB0BEC5),
              ),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final app = items[i];
        final employeeDesc = [
          if (app.employee?.employeeCode != null && app.employee!.employeeCode!.isNotEmpty)
            'Code: ${app.employee!.employeeCode}'
          else if (app.employee?.id != null)
            'ID: ${app.employee!.id}',
          if (app.employee?.department != null && app.employee!.department!.isNotEmpty)
            app.employee!.department!,
          if (app.employee?.designation != null && app.employee!.designation!.isNotEmpty)
            app.employee!.designation!,
        ].join(' • ');

        return LeaveApplicationCard(
          application: app,
          subtitle: employeeDesc.isNotEmpty ? employeeDesc : null,
          trailing: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _act(context, ref, app, approve: false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.redAccent, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _act(context, ref, app, approve: true),
                style: FilledButton.styleFrom(
                  backgroundColor: isWfhSection
                      ? const Color(0xFF0D9488)
                      : (isDark ? const Color(0xFFC5A059) : const Color(0xFF263238)),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    LeaveApplication app, {
    required bool approve,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remarksController = TextEditingController();
    final isWfh = app.isWfh;
    final categoryName = isWfh ? 'Work From Home' : 'Leave';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.2) : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
        title: Text(
          approve ? 'Approve $categoryName Request' : 'Reject $categoryName Request',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add any comments or remarks for ${app.employee?.fullName ?? "the employee"}.',
                style: TextStyle(
                  color: isDark ? Colors.white60 : const Color(0xFF607D8B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks / Comments',
                  border: OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: approve ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              approve ? 'Approve' : 'Reject',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (ok != true) {
      remarksController.dispose();
      return;
    }

    try {
      final repo = ref.read(leaveRepositoryProvider);
      if (approve) {
        await repo.approveApplication(app.id, remarks: remarksController.text.trim());
      } else {
        await repo.rejectApplication(app.id, remarks: remarksController.text.trim());
      }
      invalidateLeaveApprovalData(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve ? '$categoryName request approved successfully.' : '$categoryName request rejected.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      remarksController.dispose();
    }
  }
}
