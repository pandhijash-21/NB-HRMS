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
import '../widgets/support_ticket_chat_widget.dart';
import 'remote_operator_screen.dart';

class SupportDetailScreen extends ConsumerStatefulWidget {
  const SupportDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<SupportDetailScreen> createState() =>
      _SupportDetailScreenState();
}

class _SupportDetailScreenState extends ConsumerState<SupportDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _refresh(WidgetRef ref, String id) {
    ref.invalidate(supportTicketDetailProvider(id));
    ref.invalidate(supportTicketMessagesProvider(id));
    ref.invalidate(supportActiveRemoteSessionProvider(id));
    ref.invalidate(mySupportTicketsProvider);
    ref.invalidate(supportQueueProvider);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final capsAsync = ref.watch(supportCapabilitiesProvider);
    final roleIsIt =
        Permissions.canAdminSupport(auth.permissions, auth.user?.role);
    final isIt = capsAsync.maybeWhen(
      data: (c) => c.isIt,
      orElse: () => roleIsIt,
    );
    final myEmployeeId = auth.user?.employeeId;
    final async = ref.watch(supportTicketDetailProvider(widget.ticketId));
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktopSplit = screenWidth >= 1024;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket detail'),
        leading: const AppBackButton(fallbackLocation: '/support'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _refresh(ref, widget.ticketId),
          ),
        ],
        bottom: isDesktopSplit
            ? null
            : TabBar(
                controller: _tabCtrl,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.info_outline_rounded, size: 20),
                    text: 'Details & History',
                  ),
                  Tab(
                    icon: Icon(Icons.forum_outlined, size: 20),
                    text: 'Live Chat',
                  ),
                ],
              ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (ticket) {
          final isOwner =
              myEmployeeId != null && myEmployeeId == ticket.employeeId;

          if (isDesktopSplit) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: (screenWidth * 0.42).clamp(420.0, 540.0),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                    child: _buildDetailsList(
                      ticket: ticket,
                      isIt: isIt,
                      isOwner: isOwner,
                    ),
                  ),
                ),
                Expanded(
                  child: SupportTicketChatWidget(
                    ticketId: widget.ticketId,
                    ticket: ticket,
                  ),
                ),
              ],
            );
          }

          return TabBarView(
            controller: _tabCtrl,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: _buildDetailsList(
                    ticket: ticket,
                    isIt: isIt,
                    isOwner: isOwner,
                  ),
                ),
              ),

              // TAB 2: LIVE CHAT
              SupportTicketChatWidget(
                ticketId: widget.ticketId,
                ticket: ticket,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailsList({
    required SupportTicket ticket,
    required bool isIt,
    required bool isOwner,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Waiting Queue Notice (if queued)
        if (ticket.isQueued) ...[
          _WaitingQueueBanner(position: ticket.queuePosition ?? 1),
          const SizedBox(height: 16),
        ],

        // Transfer Pending Notice & Action Card
        if (ticket.isTransferPending) ...[
          _TransferApprovalCard(
            ticket: ticket,
            isTargetHandler: isIt,
            onAccept: () => _respondTransfer(context, ref, ticket, true),
            onReject: () => _respondTransfer(context, ref, ticket, false),
          ),
          const SizedBox(height: 16),
        ],

        // Remote Access Session Banner (if requested or active)
        if (ticket.activeRemoteSession != null) ...[
          _RemoteAccessBanner(
            session: ticket.activeRemoteSession!,
            isIt: isIt,
            isOwner: isOwner,
            onAccept: () => _respondRemote(
              context,
              ref,
              ticket.activeRemoteSession!.id,
              true,
            ),
            onReject: () => _respondRemote(
              context,
              ref,
              ticket.activeRemoteSession!.id,
              false,
            ),
            onOpenConsole: () => _openRemoteConsole(
              context,
              ticket.activeRemoteSession!,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Header with Title & Status Chip
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                ticket.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(status: ticket.status),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          ticket.ticketNo,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),

        if (ticket.employeeName != null) ...[
          const SizedBox(height: 8),
          Text(
            '${ticket.employeeName}${ticket.employeeCode != null ? ' (${ticket.employeeCode})' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (ticket.designation != null || ticket.department != null)
            Text(
              [ticket.designation, ticket.department]
                  .whereType<String>()
                  .join(' · '),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
        ],

        const SizedBox(height: 16),
        Text(
          ticket.description,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),

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

        if (ticket.resolveRemarks != null &&
            ticket.resolveRemarks!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Resolve remarks',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(ticket.resolveRemarks!),
        ],

        if (ticket.denyRemarks != null &&
            ticket.denyRemarks!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Deny note',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
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
        const Text(
          'Timeline',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 8),
        ...ticket.events.map((e) => _EventTile(event: e)),

        const SizedBox(height: 24),

        // Actions
        ..._actions(
          context: context,
          ref: ref,
          ticket: ticket,
          isIt: isIt,
          isOwner: isOwner,
        ),
      ],
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

    // IT Handlers Actions
    if (isIt &&
        (ticket.status == SupportTicketStatus.open ||
            ticket.status == SupportTicketStatus.inReview)) {
      // Review & ETA
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

      // Resolve
      widgets.add(
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.teal),
          onPressed: () => _resolve(context, ref, ticket),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Mark resolved'),
        ),
      );
      widgets.add(const SizedBox(height: 8));

      // Transfer Ticket Button
      widgets.add(
        OutlinedButton.icon(
          onPressed: () => _transferTicketDialog(context, ref, ticket),
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Transfer Ticket to another handler'),
        ),
      );
      widgets.add(const SizedBox(height: 8));

      // Request Remote Desktop Operator
      widgets.add(
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
          onPressed: () => _requestRemoteOperator(context, ref, ticket),
          icon: const Icon(Icons.desktop_windows_rounded),
          label: const Text('Request Remote PC Access (UAC Full Control)'),
        ),
      );
      widgets.add(const SizedBox(height: 8));
    }

    // Owner Confirmation / Denial
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

    // Force Close
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

  // Action Dialogs
  Future<void> _setEta(
      BuildContext context, WidgetRef ref, SupportTicket ticket) async {
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
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 1)),
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
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save ETA'),
                ),
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
            note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
          );
      _refresh(ref, ticket.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _resolve(
      BuildContext context, WidgetRef ref, SupportTicket ticket) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark resolved'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Resolution remarks *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(supportRepositoryProvider)
          .resolve(ticket.id, remarks: ctrl.text.trim());
      _refresh(ref, ticket.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _confirm(
      BuildContext context, WidgetRef ref, SupportTicket ticket) async {
    try {
      await ref.read(supportRepositoryProvider).confirm(ticket.id);
      _refresh(ref, ticket.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _deny(
      BuildContext context, WidgetRef ref, SupportTicket ticket) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send back to IT'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'What is still pending / not working? *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(supportRepositoryProvider)
          .deny(ticket.id, note: ctrl.text.trim());
      _refresh(ref, ticket.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _forceClose(
      BuildContext context, WidgetRef ref, SupportTicket ticket) async {
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
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
      await ref
          .read(supportRepositoryProvider)
          .forceClose(ticket.id, remarks: ctrl.text.trim());
      _refresh(ref, ticket.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  // Transfer Ticket Dialog
  Future<void> _transferTicketDialog(
      BuildContext context, WidgetRef ref, SupportTicket ticket) async {
    final handlersAsync = await ref.read(supportHandlersProvider.future);
    final otherHandlers = handlersAsync
        .where((h) => h.employeeId != ticket.assignedHandlerId)
        .toList();

    if (!context.mounted) return;
    if (otherHandlers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other IT handlers available to transfer to')),
      );
      return;
    }

    int? selectedEmpId = otherHandlers.first.employeeId;
    final reasonCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Transfer Ticket to Handler'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select the IT team member who should take over this ticket:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: selectedEmpId,
                items: otherHandlers.map((h) {
                  return DropdownMenuItem<int>(
                    value: h.employeeId,
                    child: Text(h.displayName),
                  );
                }).toList(),
                onChanged: (val) => setLocal(() => selectedEmpId = val),
                decoration: const InputDecoration(
                  labelText: 'Target Handler',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Transfer Reason / Escalation Note *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send Transfer Request'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || selectedEmpId == null) return;
    try {
      await ref.read(supportRepositoryProvider).requestTransfer(
            ticket.id,
            targetHandlerEmployeeId: selectedEmpId!,
            reason: reasonCtrl.text.trim(),
          );
      _refresh(ref, ticket.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfer request sent to handler')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _respondTransfer(
      BuildContext context, WidgetRef ref, SupportTicket ticket, bool accept) async {
    String? remarks;
    if (!accept) {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Decline Transfer'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Decline Reason',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm Decline'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      remarks = ctrl.text.trim();
    }

    try {
      await ref.read(supportRepositoryProvider).respondTransfer(
            ticket.id,
            accept: accept,
            remarks: remarks,
          );
      _refresh(ref, ticket.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  // Remote Access Actions
  Future<void> _requestRemoteOperator(
      BuildContext context, WidgetRef ref, SupportTicket ticket) async {
    try {
      final session = await ref.read(supportRepositoryProvider).requestRemoteSession(
            ticket.id,
            accessLevel: 'FULL_CONTROL',
            uacEnabled: true,
          );
      _refresh(ref, ticket.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Remote session requested (${session.roomName}). Waiting for employee confirmation...')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _respondRemote(
      BuildContext context, WidgetRef ref, String sessionId, bool accept) async {
    try {
      await ref.read(supportRepositoryProvider).respondRemoteSession(
            sessionId: sessionId,
            accept: accept,
          );
      _refresh(ref, widget.ticketId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _openRemoteConsole(BuildContext context, SupportRemoteSession session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RemoteOperatorScreen(
          ticketId: widget.ticketId,
          sessionId: session.id,
          roomName: session.roomName,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SupportTicketStatus status;

  Color get _color {
    switch (status) {
      case SupportTicketStatus.queued:
        return const Color(0xFFD97706);
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
        style: TextStyle(
          color: _color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
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

class _WaitingQueueBanner extends StatelessWidget {
  const _WaitingQueueBanner({required this.position});

  final int position;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFD97706).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD97706).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'In Waiting Queue · Position #$position',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD97706),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'All IT support specialists are currently assisting other employees. Your ticket is queued and will be automatically assigned to the next available handler.',
                  style: TextStyle(fontSize: 12.5, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferApprovalCard extends StatelessWidget {
  const _TransferApprovalCard({
    required this.ticket,
    required this.isTargetHandler,
    required this.onAccept,
    required this.onReject,
  });

  final SupportTicket ticket;
  final bool isTargetHandler;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.swap_horiz_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text(
                'Transfer Request Pending',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2563EB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Reason: ${ticket.transferReason ?? "Escalation to specialized handler"}',
            style: const TextStyle(fontSize: 13),
          ),
          if (isTargetHandler) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Accept Transfer'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Decline'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RemoteAccessBanner extends StatelessWidget {
  const _RemoteAccessBanner({
    required this.session,
    required this.isIt,
    required this.isOwner,
    required this.onAccept,
    required this.onReject,
    required this.onOpenConsole,
  });

  final SupportRemoteSession session;
  final bool isIt;
  final bool isOwner;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onOpenConsole;

  @override
  Widget build(BuildContext context) {
    final isRequested = session.isRequested;
    final isActive = session.isActive;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (isActive ? const Color(0xFF10B981) : const Color(0xFF6366F1))
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isActive ? const Color(0xFF10B981) : const Color(0xFF6366F1))
              .withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.desktop_windows_rounded,
                color: isActive ? const Color(0xFF10B981) : const Color(0xFF6366F1),
              ),
              const SizedBox(width: 8),
              Text(
                isActive
                    ? 'Remote Desktop Session Active'
                    : 'Remote Access Requested by IT',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isActive
                      ? const Color(0xFF10B981)
                      : const Color(0xFF6366F1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isActive
                ? 'IT Support is connected with Administrative Privileges (UAC/ADB Prompts Allowed).'
                : 'The IT specialist requested remote control of your computer to configure services / permissions.',
            style: const TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          if (isOwner && isRequested) ...[
            Row(
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                  ),
                  onPressed: onAccept,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Grant Full Control'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Decline'),
                ),
              ],
            ),
          ] else if (isIt && isActive) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
              ),
              onPressed: onOpenConsole,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open Remote Operator Console'),
            ),
          ],
        ],
      ),
    );
  }
}
