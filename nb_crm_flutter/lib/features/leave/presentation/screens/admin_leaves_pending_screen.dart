import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/leave_models.dart';
import '../leave_providers.dart';
import '../widgets/leave_shared_widgets.dart';

class AdminLeavesPendingScreen extends ConsumerWidget {
  const AdminLeavesPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(pendingApprovalsProvider);

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Pending Leave Queue'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/leaves'),
        ),
      ),
      body: LeaveAsyncBody<List<LeaveApplication>>(
        value: queue,
        emptyMessage: 'No pending applications.',
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
        title: Text(approve ? 'Approve' : 'Reject'),
        content: TextField(
          controller: remarksController,
          decoration: const InputDecoration(labelText: 'Remarks'),
          minLines: 2,
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
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      remarksController.dispose();
    }
  }
}
