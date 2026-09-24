import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/tour/models/tour_models.dart';
import '../../../../core/tour/widgets/tour_target.dart';
import '../../../../core/widgets/header_action_button.dart';
import '../../../../core/widgets/zoomable_photo.dart';
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
      floatingActionButton: Permissions.canWriteReimbursements(auth.permissions, role)
          ? TourTarget(
              id: TourIds.step('hrms.reimbursements', 2),
              child: FloatingActionButton.extended(
                onPressed: () => context.push('/reimbursements/apply'),
                icon: const Icon(Icons.add),
                label: const Text('Apply'),
                backgroundColor: AppColors.bronze,
              ),
            )
          : null,
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
                  TourTarget(
                    id: TourIds.step('hrms.reimbursements', 3),
                    child: Text(
                    'Pending approval (${pending.length})',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  ),
                  const SizedBox(height: 8),
                  ...pending.map((c) => _ClaimCard(
                        claim: c,
                        showActions: true,
                        onApprove: () => _act(context, ref, c.id, approve: true),
                        onReject: () => _act(context, ref, c.id, approve: false),
                        onDelete: canAdmin
                            ? () => _deleteClaim(context, ref, c.id)
                            : null,
                      )),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
          if (canAdmin) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.push('/reimbursements/types'),
                    icon: const Icon(Icons.tune),
                    label: const Text('Configure types'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/reimbursements/apply-on-behalf'),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Apply on behalf'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/reimbursements/admin'),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('All claims'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
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
                    .map(
                      (c) => _ClaimCard(
                        claim: c,
                        showActions: false,
                        onCancel: c.status == ReimbursementStatus.PENDING
                            ? () => _cancelMine(context, ref, c.id)
                            : null,
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 72),
        ],
      ),
    );
  }

  Future<void> _cancelMine(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel claim?'),
        content: const Text('This will withdraw your pending reimbursement request.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel claim'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(reimbursementsRepositoryProvider).cancel(id);
      ref.invalidate(myReimbursementsProvider);
      ref.invalidate(pendingReimbursementsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim cancelled')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _deleteClaim(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete claim?'),
        content: const Text(
          'This permanently deletes the claim. If it was posted to an unpaid salary, that amount is reversed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(reimbursementsRepositoryProvider).deleteClaim(id);
      ref.invalidate(myReimbursementsProvider);
      ref.invalidate(pendingReimbursementsProvider);
      ref.invalidate(adminReimbursementsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
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
                onDelete: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete claim?'),
                      content: const Text(
                        'This permanently deletes the claim. If posted to unpaid salary, the amount is reversed.',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  try {
                    await ref.read(reimbursementsRepositoryProvider).deleteClaim(c.id);
                    ref.invalidate(adminReimbursementsProvider);
                    ref.invalidate(pendingReimbursementsProvider);
                    ref.invalidate(myReimbursementsProvider);
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
    this.onCancel,
    this.onDelete,
  });

  final ReimbursementClaim claim;
  final bool showActions;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;

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
                    color: _statusColor().withValues(alpha: 0.12),
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
              [
                claim.claimNo,
                if (claim.typeName != null && claim.typeName!.isNotEmpty) claim.typeName,
                if (claim.onBehalfBy != null) 'on behalf',
              ].join(' · '),
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
            const SizedBox(height: 8),
            Text('₹${claim.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
            if (claim.openingKm != null || claim.closingKm != null)
              Text(
                'Km: ${claim.openingKm?.toStringAsFixed(1) ?? '—'} → ${claim.closingKm?.toStringAsFixed(1) ?? '—'}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            const SizedBox(height: 6),
            Text(claim.description, style: const TextStyle(fontSize: 13)),
            ..._photoSection(context),
            if (claim.approvalSteps.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Approval: ${claim.approvalSteps.map((s) {
                  final role = s.approverRole
                      .replaceAll('_', ' ')
                      .toLowerCase()
                      .split(' ')
                      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
                      .join(' ');
                  final action = (s.action ?? 'PENDING').toUpperCase();
                  return 'Step ${s.stepNumber} $role ($action)';
                }).join(' → ')}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            if (showActions || onCancel != null || onDelete != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (showActions) ...[
                    FilledButton(onPressed: onApprove, child: const Text('Approve')),
                    OutlinedButton(
                      onPressed: onReject,
                      child: const Text('Reject', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                  if (onCancel != null)
                    OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Cancel request'),
                    ),
                  if (onDelete != null)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _photoSection(BuildContext context) {
    final items = <({String label, String url})>[];
    if (claim.openingKmPhotoUrl != null && claim.openingKmPhotoUrl!.trim().isNotEmpty) {
      items.add((label: 'Opening km', url: claim.openingKmPhotoUrl!.trim()));
    }
    if (claim.closingKmPhotoUrl != null && claim.closingKmPhotoUrl!.trim().isNotEmpty) {
      items.add((label: 'Closing km', url: claim.closingKmPhotoUrl!.trim()));
    }
    if (claim.proofUrl != null && claim.proofUrl!.trim().isNotEmpty) {
      items.add((label: 'Proof', url: claim.proofUrl!.trim()));
    }
    for (final v in claim.values) {
      final url = v.proofUrl?.trim();
      if (url == null || url.isEmpty) continue;
      if (items.any((e) => e.url == url)) continue;
      items.add((label: v.fieldLabel ?? 'Attachment', url: url));
    }
    if (items.isEmpty) return const [];

    return [
      const SizedBox(height: 10),
      const Text(
        'Photos',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items
            .map(
              (item) => _ProofThumb(
                label: item.label,
                url: item.url,
              ),
            )
            .toList(),
      ),
    ];
  }
}

class _ProofThumb extends StatelessWidget {
  const _ProofThumb({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        ZoomablePhoto(
          url: url,
          label: label,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 120,
              height: 90,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.black12,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
