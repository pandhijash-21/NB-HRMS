import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/header_action_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/reimbursement_models.dart';
import '../reimbursements_providers.dart';

class ReimbursementsHubScreen extends ConsumerWidget {
  const ReimbursementsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final role = auth.user?.role ?? '';
    final canAdmin = Permissions.canAdminReimbursements(auth.permissions, role);
    final myAsync = ref.watch(myReimbursementsProvider);
    final pendingAsync = ref.watch(pendingReimbursementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reimbursements'),
        leading: const AppBackButton(),
        actions: [
          HeaderActionButton(
            tooltip: 'Refresh',
            label: 'Refresh',
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: () {
              ref.invalidate(myReimbursementsProvider);
              ref.invalidate(pendingReimbursementsProvider);
              if (canAdmin) ref.invalidate(adminReimbursementsProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/reimbursements/apply'),
        icon: const Icon(Icons.add),
        label: const Text('Apply'),
        backgroundColor: AppColors.bronze,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          pendingAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (pending) {
              if (pending.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pending for your approval (${pending.length})',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  ...pending.map((c) => _ClaimCard(
                        claim: c,
                        showActions: true,
                        onApprove: () => _act(context, ref, c.id, approve: true),
                        onReject: () => _act(context, ref, c.id, approve: false),
                      )),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
          if (canAdmin)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: () => context.push('/reimbursements/admin'),
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('Admin — all claims'),
              ),
            ),
          const Text('My claims', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          myAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Failed to load: $e'),
            data: (claims) {
              if (claims.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No reimbursement claims yet. Tap Apply to submit one.'),
                );
              }
              return Column(
                children: claims
                    .map((c) => _ClaimCard(claim: c, showActions: false))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 72),
        ],
      ),
    );
  }

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    String id, {
    required bool approve,
  }) async {
    final remarksCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Approve claim' : 'Reject claim'),
        content: TextField(
          controller: remarksCtrl,
          decoration: const InputDecoration(
            labelText: 'Remarks (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(reimbursementsRepositoryProvider);
    try {
      if (approve) {
        await repo.approve(id, remarks: remarksCtrl.text.trim());
      } else {
        await repo.reject(id, remarks: remarksCtrl.text.trim());
      }
      ref.invalidate(myReimbursementsProvider);
      ref.invalidate(pendingReimbursementsProvider);
      ref.invalidate(adminReimbursementsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? 'Approved' : 'Rejected')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class ReimbursementsAdminScreen extends ConsumerWidget {
  const ReimbursementsAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminReimbursementsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Reimbursements'),
        leading: const AppBackButton(fallbackLocation: '/reimbursements'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(adminReimbursementsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (claims) {
          if (claims.isEmpty) {
            return const Center(child: Text('No claims'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: claims.length,
            itemBuilder: (context, i) {
              final c = claims[i];
              return _ClaimCard(
                claim: c,
                showActions: c.status == ReimbursementStatus.PENDING,
                onApprove: () async {
                  try {
                    await ref.read(reimbursementsRepositoryProvider).approve(c.id);
                    ref.invalidate(adminReimbursementsProvider);
                    ref.invalidate(pendingReimbursementsProvider);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
                onReject: () async {
                  try {
                    await ref.read(reimbursementsRepositoryProvider).reject(c.id);
                    ref.invalidate(adminReimbursementsProvider);
                    ref.invalidate(pendingReimbursementsProvider);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({
    required this.claim,
    required this.showActions,
    this.onApprove,
    this.onReject,
  });

  final ReimbursementClaim claim;
  final bool showActions;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  Color _statusColor() {
    switch (claim.status) {
      case ReimbursementStatus.APPROVED:
        return Colors.green;
      case ReimbursementStatus.REJECTED:
        return Colors.red;
      case ReimbursementStatus.CANCELLED:
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    claim.title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor().withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    claim.statusLabel,
                    style: TextStyle(
                      color: _statusColor(),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              claim.claimNo,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            if (claim.employeeName != null) ...[
              const SizedBox(height: 6),
              Text(
                '${claim.employeeName}${claim.employeeCode != null ? ' (${claim.employeeCode})' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              if (claim.designation != null || claim.department != null)
                Text(
                  [claim.designation, claim.department].whereType<String>().join(' · '),
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
            const SizedBox(height: 8),
            Text('₹${claim.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
            if (claim.openingKm != null || claim.closingKm != null)
              Text(
                'Km: ${claim.openingKm?.toStringAsFixed(1) ?? '—'} → ${claim.closingKm?.toStringAsFixed(1) ?? '—'}',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            const SizedBox(height: 6),
            Text(claim.description, style: const TextStyle(fontSize: 13)),
            if (claim.proofUrl != null && claim.proofUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: claim.proofUrl!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Proof URL copied: ${claim.proofUrl}')),
                  );
                },
                icon: const Icon(Icons.attach_file, size: 16),
                label: const Text('Copy proof link'),
              ),
            ],
            if (claim.status == ReimbursementStatus.APPROVED &&
                claim.salaryMonth != null &&
                claim.salaryYear != null) ...[
              const SizedBox(height: 6),
              Text(
                'Posted to salary: ${claim.salaryMonth}/${claim.salaryYear}',
                style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
              ),
            ],
            if (claim.currentStepNumber != null && claim.status == ReimbursementStatus.PENDING) ...[
              const SizedBox(height: 4),
              Text(
                'Current approval step: ${claim.currentStepNumber}',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            if (showActions) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton(onPressed: onApprove, child: const Text('Approve')),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: onReject,
                    child: const Text('Reject', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
