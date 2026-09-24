import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/zoomable_photo.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/support_models.dart';
import '../support_providers.dart';

class SupportDetailScreen extends ConsumerWidget {
  const SupportDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final capsAsync = ref.watch(supportCapabilitiesProvider);
    final roleIsIt = Permissions.canAdminSupport(auth.permissions, auth.user?.role);
    final isIt = capsAsync.maybeWhen(
      data: (c) => c.isIt,
      orElse: () => roleIsIt,
    );
    final myEmployeeId = auth.user?.employeeId;
    final async = ref.watch(supportTicketDetailProvider(ticketId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket detail'),
        leading: const AppBackButton(fallbackLocation: '/support'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (ticket) {
          final isOwner = myEmployeeId != null && myEmployeeId == ticket.employeeId;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ),
                  _StatusChip(status: ticket.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                ticket.ticketNo,
                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
              if (ticket.employeeName != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${ticket.employeeName}${ticket.employeeCode != null ? ' (${ticket.employeeCode})' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (ticket.designation != null || ticket.department != null)
                  Text(
                    [ticket.designation, ticket.department].whereType<String>().join(' · '),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
              ],
              const SizedBox(height: 16),
              Text(ticket.description, style: const TextStyle(fontSize: 14, height: 1.4)),
              if (ticket.photoUrl != null && ticket.photoUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Photo', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ZoomablePhoto(
                  url: ticket.photoUrl,
                  label: 'Support photo',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      ticket.photoUrl!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
              if (ticket.etaAt != null) ...[
                const SizedBox(height: 16),
                Text(
                  'ETA: ${DateFormat('dd MMM yyyy, HH:mm').format(ticket.etaAt!.toLocal())}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
              if (ticket.resolveRemarks != null && ticket.resolveRemarks!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Resolve remarks', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                Text(ticket.resolveRemarks!),
              ],
              if (ticket.denyRemarks != null && ticket.denyRemarks!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Deny note', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                Text(ticket.denyRemarks!),
              ],
              if (ticket.forceClosed) ...[
                const SizedBox(height: 8),
                const Text(
                  'Force-closed by IT',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                ),
              ],
              const SizedBox(height: 20),
              const Text('Timeline', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 8),
              ...ticket.events.map((e) => _EventTile(event: e)),
              const SizedBox(height: 20),
              ..._actions(
                context: context,
                ref: ref,
                ticket: ticket,
                isIt: isIt,
                isOwner: isOwner,
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _actions({
    required BuildContext context,
    required WidgetRef ref,
    required SupportTicket ticket,
    required bool isIt,
    required bool isOwner,
  }) {
    final widgets = <Widget>[];

    if (isIt &&
        (ticket.status == SupportTicketStatus.open ||
            ticket.status == SupportTicketStatus.inReview)) {
      widgets.add(
        FilledButton.icon(
          onPressed: () => _setEta(context, ref, ticket),
          icon: const Icon(Icons.schedule),
          label: Text(
            ticket.status == SupportTicketStatus.open
                ? 'Start review & set ETA'
                : 'Update ETA',
          ),
        ),
      );
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.teal),
          onPressed: () => _resolve(context, ref, ticket),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Mark resolved'),
        ),
      );
      widgets.add(const SizedBox(height: 8));
    }

    if (isOwner && ticket.status == SupportTicketStatus.resolved) {
      widgets.add(
        FilledButton.icon(
          onPressed: () => _confirm(context, ref, ticket),
          icon: const Icon(Icons.thumb_up_outlined),
          label: const Text('Confirm — close ticket'),
        ),
      );
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        OutlinedButton.icon(
          onPressed: () => _deny(context, ref, ticket),
          icon: const Icon(Icons.thumb_down_outlined, color: Colors.red),
          label: const Text('Deny — send back to IT', style: TextStyle(color: Colors.red)),
        ),
      );
      widgets.add(const SizedBox(height: 8));
    }

    if (isIt && ticket.status != SupportTicketStatus.closed) {
      widgets.add(
        OutlinedButton.icon(
          onPressed: () => _forceClose(context, ref, ticket),
          icon: const Icon(Icons.gavel, color: Colors.red),
          label: const Text('Force close', style: TextStyle(color: Colors.red)),
        ),
      );
    }

    return widgets;
  }

  Future<void> _setEta(BuildContext context, WidgetRef ref, SupportTicket ticket) async {
    DateTime eta = ticket.etaAt?.toLocal() ??
        DateTime.now().add(const Duration(days: 1));
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Set resolution ETA'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date & time'),
                    subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(eta)),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: eta,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d == null) return;
                      if (!ctx.mounted) return;
                      final t = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(eta),
                      );
                      setLocal(() {
                        eta = DateTime(
                          d.year,
                          d.month,
                          d.day,
                          t?.hour ?? eta.hour,
                          t?.minute ?? eta.minute,
                        );
                      });
                    },
                  ),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
              ],
            );
          },
        );
      },
    );
    if (ok != true) return;
    try {
      await ref.read(supportRepositoryProvider).setInReview(
            ticket.id,
            etaAt: eta,
            note: noteCtrl.text.trim(),
          );
      _refresh(ref, ticket.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _resolve(BuildContext context, WidgetRef ref, SupportTicket ticket) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark resolved'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Remarks *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Resolve')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(supportRepositoryProvider).resolve(ticket.id, remarks: ctrl.text.trim());
      _refresh(ref, ticket.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref, SupportTicket ticket) async {
    try {
      await ref.read(supportRepositoryProvider).confirm(ticket.id);
      _refresh(ref, ticket.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket closed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _deny(BuildContext context, WidgetRef ref, SupportTicket ticket) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deny resolution'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'What is still wrong?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send back')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(supportRepositoryProvider).deny(ticket.id, note: ctrl.text.trim());
      _refresh(ref, ticket.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _forceClose(BuildContext context, WidgetRef ref, SupportTicket ticket) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Force close ticket'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Remarks *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Force close'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(supportRepositoryProvider).forceClose(ticket.id, remarks: ctrl.text.trim());
      _refresh(ref, ticket.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _refresh(WidgetRef ref, String id) {
    ref.invalidate(supportTicketDetailProvider(id));
    ref.invalidate(mySupportTicketsProvider);
    ref.invalidate(supportQueueProvider);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SupportTicketStatus status;

  Color get _color {
    switch (status) {
      case SupportTicketStatus.open:
        return Colors.orange;
      case SupportTicketStatus.inReview:
        return Colors.blue;
      case SupportTicketStatus.resolved:
        return Colors.teal;
      case SupportTicketStatus.closed:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: _color, fontWeight: FontWeight.w800, fontSize: 11),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final SupportTicketEvent event;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.circle, size: 10, color: AppColors.bronze),
      title: Text(
        [
          if (event.fromStatus != null) '${event.fromStatus!.label} → ',
          event.toStatus.label,
        ].join(),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      subtitle: Text(
        [
          DateFormat('dd MMM, HH:mm').format(event.createdAt.toLocal()),
          if (event.note != null && event.note!.isNotEmpty) event.note!,
        ].join(' · '),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
