import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/leave_models.dart';
import '../leave_providers.dart';
import '../widgets/leave_shared_widgets.dart';

class LeaveApprovalsScreen extends ConsumerWidget {
  const LeaveApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(pendingApprovalsProvider);

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Leave Approvals'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/approvals/history'),
            child: const Text('History', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: LeaveAsyncBody<List<LeaveApplication>>(
        value: queue,
        emptyMessage: 'No pending leave approvals.',
        onRetry: () => ref.invalidate(pendingApprovalsProvider),
        builder: (items) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final app = items[i];
            return LeaveApplicationCard(
              application: app,
              subtitle: app.employee?.fullName,
              trailing: Row(
                children: [
                  TextButton(
                    onPressed: () => _act(context, ref, app, approve: false),
                    child: const Text('Reject'),
                  ),
                  FilledButton(
                    onPressed: () => _act(context, ref, app, approve: true),
                    child: const Text('Approve'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    LeaveApplication app, {
    required bool approve,
  }) async {
    final remarksController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Approve leave' : 'Reject leave'),
        content: TextField(
          controller: remarksController,
          decoration: const InputDecoration(
            labelText: 'Remarks',
            border: OutlineInputBorder(),
          ),
          minLines: 2,
          maxLines: 4,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(approve ? 'Approve' : 'Reject')),
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
          SnackBar(content: Text(approve ? 'Approved.' : 'Rejected.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      remarksController.dispose();
    }
  }
}
