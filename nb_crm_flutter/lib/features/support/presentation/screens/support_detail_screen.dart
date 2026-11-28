import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/zoomable_photo.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/support_models.dart';
import '../support_providers.dart';
import '../widgets/support_ticket_chat_widget.dart';

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

  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    // Realtime background poll every 2.5 seconds for instant ticket and session updates
    _autoRefreshTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (mounted) {
        ref.invalidate(supportTicketDetailProvider(widget.ticketId));
        ref.invalidate(supportTicketMessagesProvider(widget.ticketId));
        ref.invalidate(supportActiveRemoteSessionProvider(widget.ticketId));
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
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
    final myEmployeeId = auth.user?.employeeId;
    final async = ref.watch(supportTicketDetailProvider(widget.ticketId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorWeight: 3,
          indicatorColor: AppColors.primaryBlue,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          tabs: const [
            Tab(
              icon: Icon(Icons.assignment_outlined, size: 20),
              text: 'Query & Actions',
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
          final userRole = auth.user?.role.toUpperCase();
          final isAdmin = userRole == 'ADMIN' ||
              userRole == 'SUPERADMIN' ||
              userRole == 'SYSTEMADMIN' ||
              userRole == 'SYSTEM_ADMIN' ||
              Permissions.canAdminSupport(auth.permissions, auth.user?.role);
          final isAssignedHandler = myEmployeeId != null &&
              (ticket.assignedHandlerId == myEmployeeId ||
                  ticket.transferTargetHandlerId == myEmployeeId);
          // Only the assigned IT handler or admin can manage or take remote access
          final canManageThisTicket = isAdmin || isAssignedHandler;

          return TabBarView(
            controller: _tabCtrl,
            children: [
              // TAB 1: TICKET QUERY DETAILS & ACTIONS (Full Width)
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: _buildDetailsList(
                    ticket: ticket,
                    isIt: canManageThisTicket,
                    isOwner: isOwner,
                  ),
                ),
              ),

              // TAB 2: LIVE CHAT (Full Width)
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: SupportTicketChatWidget(
                    ticketId: widget.ticketId,
                    ticket: ticket,
                  ),
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // 1. Header with Title & Status Chip
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white10
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ticket.ticketNo,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      if (ticket.employeeName != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          'by ${ticket.employeeName}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _StatusChip(status: ticket.status),
          ],
        ),

        const SizedBox(height: 16),

        // 2. ALL OPTIONS & ACTIONS ON TOP (Prominent card on top of the query page)
        _buildActionOptionsCard(
          context: context,
          ref: ref,
          ticket: ticket,
          isIt: isIt,
          isOwner: isOwner,
          isDark: isDark,
        ),

        const SizedBox(height: 16),

        // 3. Waiting Queue Notice (if queued)
        if (ticket.isQueued) ...[
          _WaitingQueueBanner(position: ticket.queuePosition ?? 1),
          const SizedBox(height: 16),
        ],

        // 4. Transfer Pending Notice & Action Card
        if (ticket.isTransferPending) ...[
          _TransferApprovalCard(
            ticket: ticket,
            isTargetHandler: isIt,
            onAccept: () => _respondTransfer(context, ref, ticket, true),
            onReject: () => _respondTransfer(context, ref, ticket, false),
          ),
          const SizedBox(height: 16),
        ],

        // 5. Remote Access Session Banner (if requested or active)
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
            onEndSession: () => _endRemoteSession(
              context,
              ref,
              ticket.activeRemoteSession!.id,
            ),
            onShareCredentials: (deskId, pw) => _shareRemoteCredentials(
              context,
              ref,
              deskId,
              pw,
            ),
            onOpenConsole: () => _openRemoteConsole(
              context,
              ticket.activeRemoteSession!,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 6. Requester Profile Details
        if (ticket.employeeName != null) ...[
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
          const SizedBox(height: 12),
        ],

        // 7. Problem Description
        const Text(
          'Problem Description',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Text(
          ticket.description,
          style: const TextStyle(fontSize: 14, height: 1.45),
        ),

        // Photo (if attached)
        if (ticket.photoUrl != null && ticket.photoUrl!.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Attached Photo', style: TextStyle(fontWeight: FontWeight.w700)),
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

        const SizedBox(height: 24),
        const Text(
          'Activity Timeline',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 8),
        ...ticket.events.map((e) => _EventTile(event: e)),
      ],
    );
  }

  Widget _buildActionOptionsCard({
    required BuildContext context,
    required WidgetRef ref,
    required SupportTicket ticket,
    required bool isIt,
    required bool isOwner,
    required bool isDark,
  }) {
    final actions = _actions(
      context: context,
      ref: ref,
      ticket: ticket,
      isIt: isIt,
      isOwner: isOwner,
    );

    if (actions.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      color: isDark ? const Color(0xFF161E2E) : const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 20, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  'Options & Actions',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...actions,
          ],
        ),
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

      // Reassign Ticket (Direct Handler Reassignment)
      widgets.add(
        OutlinedButton.icon(
          onPressed: () => _reassignTicketDialog(context, ref, ticket),
          icon: const Icon(Icons.assignment_ind_outlined),
          label: const Text('Reassign Ticket to another handler'),
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

  // Direct Reassign Ticket Dialog
  Future<void> _reassignTicketDialog(
      BuildContext context, WidgetRef ref, SupportTicket ticket) async {
    final handlersAsync = await ref.read(supportHandlersProvider.future);
    final eligibleHandlers = handlersAsync
        .where((h) => h.employeeId != ticket.assignedHandlerId && h.employeeId != ticket.employeeId)
        .toList();

    if (!context.mounted) return;
    if (eligibleHandlers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other eligible IT handlers available')),
      );
      return;
    }

    int? selectedEmpId = eligibleHandlers.first.employeeId;
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Reassign Ticket Handler'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select the IT team member to reassign this ticket to (ticket creator is excluded):',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: selectedEmpId,
                items: eligibleHandlers.map((h) {
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
                controller: noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reassignment note (optional)',
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
              child: const Text('Reassign Now'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || selectedEmpId == null) return;
    try {
      await ref.read(supportRepositoryProvider).reassignTicket(
            ticket.id,
            handlerId: selectedEmpId!,
            note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
          );
      _refresh(ref, ticket.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket successfully reassigned')),
        );
      }
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

  Future<void> _shareRemoteCredentials(
      BuildContext context, WidgetRef ref, String deskId, String? password) async {
    try {
      await ref.read(supportRepositoryProvider).updateRemoteCredentials(
            ticketId: widget.ticketId,
            deskId: deskId,
            password: password,
          );
      _refresh(ref, widget.ticketId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Desk credentials shared with IT Specialist!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share credentials: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _endRemoteSession(
      BuildContext context, WidgetRef ref, String sessionId) async {
    try {
      await ref.read(supportRepositoryProvider).endRemoteSession(sessionId);
      _refresh(ref, widget.ticketId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Remote desktop session ended')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to end session: $e')),
        );
      }
    }
  }

  Future<void> _openRemoteConsole(
      BuildContext context, SupportRemoteSession session) async {
    try {
      final tokenData = await ref
          .read(supportRepositoryProvider)
          .getRemoteToken(widget.ticketId);
      if (!context.mounted) return;
      context.push(
        '/support/${widget.ticketId}/remote',
        extra: {
          'sessionId': session.id,
          'roomName': session.roomName,
          'token': tokenData['token'],
          'livekitUrl': tokenData['livekitUrl'],
        },
      );
    } catch (_) {
      if (!context.mounted) return;
      context.push(
        '/support/${widget.ticketId}/remote',
        extra: {
          'sessionId': session.id,
          'roomName': session.roomName,
          'token': session.token,
          'livekitUrl': session.livekitUrl,
        },
      );
    }
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

class _RemoteAccessBanner extends StatefulWidget {
  const _RemoteAccessBanner({
    required this.session,
    required this.isIt,
    required this.isOwner,
    required this.onAccept,
    required this.onReject,
    required this.onEndSession,
    required this.onShareCredentials,
    required this.onOpenConsole,
  });

  final SupportRemoteSession session;
  final bool isIt;
  final bool isOwner;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onEndSession;
  final Future<void> Function(String deskId, String? password) onShareCredentials;
  final VoidCallback onOpenConsole;

  @override
  State<_RemoteAccessBanner> createState() => _RemoteAccessBannerState();
}

class _RemoteAccessBannerState extends State<_RemoteAccessBanner> {
  final _deskIdCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.session.remoteDeskId != null) {
      _deskIdCtrl.text = widget.session.remoteDeskId!;
    }
    if (widget.session.remoteDeskPassword != null) {
      _passwordCtrl.text = widget.session.remoteDeskPassword!;
    }
  }

  @override
  void didUpdateWidget(covariant _RemoteAccessBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session.remoteDeskId != null &&
        widget.session.remoteDeskId != oldWidget.session.remoteDeskId &&
        _deskIdCtrl.text.isEmpty) {
      _deskIdCtrl.text = widget.session.remoteDeskId!;
    }
    if (widget.session.remoteDeskPassword != null &&
        widget.session.remoteDeskPassword != oldWidget.session.remoteDeskPassword &&
        _passwordCtrl.text.isEmpty) {
      _passwordCtrl.text = widget.session.remoteDeskPassword!;
    }
  }

  @override
  void dispose() {
    _deskIdCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitCredentials() async {
    final deskId = _deskIdCtrl.text.trim();
    if (deskId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Desk ID from NB-RemoteSupport.exe')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await widget.onShareCredentials(deskId, _passwordCtrl.text.trim());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _downloadSoftware() async {
    final uri = Uri.parse('https://crm.nbsince1946.com/api/support/agent.exe');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launchNativeRustDesk(String deskId, String? password) async {
    final pwText = (password != null && password.isNotEmpty) ? '\nPassword: $password' : '';
    Clipboard.setData(ClipboardData(text: 'Desk ID: $deskId$pwText'));

    final query = (password != null && password.isNotEmpty)
        ? '?password=${Uri.encodeComponent(password)}'
        : '';
    final uri = Uri.parse('rustdesk://$deskId$query');

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Credentials copied (Desk ID: $deskId)! Please open NB-RemoteSupport.exe to connect.'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opening NB Remote Support! Desk credentials copied to clipboard.'),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Desk ID $deskId copied! Open NB-RemoteSupport.exe and paste to connect.'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDeskId = widget.session.remoteDeskId != null && widget.session.remoteDeskId!.isNotEmpty;
    final isActive = widget.session.isActive || hasDeskId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryColor = isActive ? const Color(0xFF10B981) : const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.desktop_windows_rounded,
                  size: 20,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasDeskId
                          ? '🖥️ Standalone Remote Desktop Ready'
                          : (widget.isOwner
                              ? '🖥️ IT Support Requested Remote Access'
                              : '🖥️ Standalone Remote Support Initiated'),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: primaryColor,
                      ),
                    ),
                    Text(
                      hasDeskId
                          ? 'Host Desk ID is ready for native 60 FPS remote connection.'
                          : 'Zero web streaming. Powered by portable NB-RemoteSupport.exe.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasDeskId)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: const Text(
                    'ONLINE',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // If Host Desk ID has already been shared:
          if (hasDeskId) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Your Desk ID: ',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      SelectableText(
                        widget.session.remoteDeskId!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Copy Desk ID',
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.session.remoteDeskId!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Desk ID copied!'), duration: Duration(seconds: 2)),
                          );
                        },
                      ),
                    ],
                  ),
                  if (widget.session.remoteDeskPassword != null &&
                      widget.session.remoteDeskPassword!.isNotEmpty) ...[
                    const Divider(height: 16),
                    Row(
                      children: [
                        const Text(
                          'One-Time Password: ',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        SelectableText(
                          _obscurePassword ? '••••••••' : widget.session.remoteDeskPassword!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Copy Password',
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: widget.session.remoteDeskPassword!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password copied!'), duration: Duration(seconds: 2)),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Action Buttons
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (widget.isIt) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () => _launchNativeRustDesk(
                      widget.session.remoteDeskId!,
                      widget.session.remoteDeskPassword,
                    ),
                    icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                    label: const Text(
                      '🚀 1-Click Launch & Connect',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onOpenConsole,
                    icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                    label: const Text('Open Remote Console (Option 1)'),
                  ),
                ],
                OutlinedButton.icon(
                  onPressed: _downloadSoftware,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Download NB-RemoteSupport.exe'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse('https://crm.nbsince1946.com/api/support/${widget.session.ticketId}/remote/agent.bat');
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.terminal_rounded, size: 16),
                  label: const Text('Download Agent (.bat)'),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  onPressed: widget.onEndSession,
                  icon: const Icon(Icons.stop_circle_outlined, size: 16),
                  label: const Text('End Remote Session'),
                ),
              ],
            ),
          ] else if (widget.isOwner) ...[
            // Employee view when Desk ID hasn't been submitted yet
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Follow these 3 quick steps:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  const Text('1. Download and run NB-RemoteSupport.exe (portable, no install needed).'),
                  const Text('2. Copy your 9-digit Desk ID & Password shown in the app.'),
                  const Text('3. Enter them below and share with IT Support:'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _downloadSoftware,
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Download NB-RemoteSupport.exe'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _deskIdCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Your Desk ID (9 digits)',
                            hintText: 'e.g. 123 456 789',
                            prefixIcon: Icon(Icons.badge_outlined, size: 18),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _passwordCtrl,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Password',
                            hintText: 'Optional',
                            prefixIcon: Icon(Icons.lock_outline, size: 18),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                        ),
                        onPressed: _isSubmitting ? null : _submitCredentials,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Share Credentials with IT'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: widget.onReject,
                        child: const Text('Decline Request'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            // IT specialist waiting for employee
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Waiting for employee to launch app & share Desk ID...',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The employee has been prompted to run NB-RemoteSupport.exe. When they submit their 9-digit Desk ID, connection credentials will appear here instantly.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                        ),
                        onPressed: widget.onOpenConsole,
                        icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                        label: const Text('Open Remote Console (Option 1)'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse('https://crm.nbsince1946.com/api/support/${widget.session.ticketId}/remote/agent.bat');
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        icon: const Icon(Icons.terminal_rounded, size: 16),
                        label: const Text('Download Agent (.bat)'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _downloadSoftware,
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download NB-RemoteSupport.exe'),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                        onPressed: widget.onEndSession,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Cancel Request'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
