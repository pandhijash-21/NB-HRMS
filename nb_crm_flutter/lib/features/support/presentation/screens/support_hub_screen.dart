import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/header_action_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/support_models.dart';
import '../support_providers.dart';

class SupportHubScreen extends ConsumerStatefulWidget {
  const SupportHubScreen({super.key});

  @override
  ConsumerState<SupportHubScreen> createState() => _SupportHubScreenState();
}

class _SupportHubScreenState extends ConsumerState<SupportHubScreen> {
  int _tab = 0;
  bool _includeClosed = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final capsAsync = ref.watch(supportCapabilitiesProvider);
    final roleIsIt = Permissions.canAdminSupport(auth.permissions, auth.user?.role);
    final canManage = Permissions.canManageSupportHandlers(
      auth.user?.role,
      companyAdminGranted: auth.user?.companyAdminGranted ?? false,
    );
    final isIt = capsAsync.maybeWhen(
      data: (c) => c.isIt,
      orElse: () => roleIsIt,
    );
    final canWrite = Permissions.canWriteSupport(auth.permissions, auth.user?.role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
        leading: const AppBackButton(),
        actions: [
          if (canManage)
            HeaderActionButton(
              tooltip: 'Assign IT handlers',
              label: 'Assignees',
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              onPressed: () => context.push('/support/handlers'),
            ),
          HeaderActionButton(
            tooltip: 'Refresh',
            label: 'Refresh',
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: () {
              ref.invalidate(mySupportTicketsProvider);
              ref.invalidate(supportQueueProvider);
              ref.invalidate(supportCapabilitiesProvider);
              ref.invalidate(supportHandlersProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/support/new'),
              icon: const Icon(Icons.add),
              label: const Text('Raise ticket'),
              backgroundColor: AppColors.bronze,
            )
          : null,
      body: Column(
        children: [
          if (isIt)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('My tickets')),
                  ButtonSegment(value: 1, label: Text('IT queue')),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
          Expanded(
            child: !isIt || _tab == 0
                ? const _MyTicketsList()
                : _QueueList(
                    includeClosed: _includeClosed,
                    onToggleClosed: (v) => setState(() => _includeClosed = v),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MyTicketsList extends ConsumerWidget {
  const _MyTicketsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mySupportTicketsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (tickets) {
        if (tickets.isEmpty) {
          return const Center(
            child: Text('No support tickets yet. Tap Raise ticket to start.'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: tickets.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _TicketCard(ticket: tickets[i]),
        );
      },
    );
  }
}

class _QueueList extends ConsumerWidget {
  const _QueueList({
    required this.includeClosed,
    required this.onToggleClosed,
  });

  final bool includeClosed;
  final ValueChanged<bool> onToggleClosed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(supportQueueProvider(includeClosed));
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Show closed'),
          value: includeClosed,
          onChanged: onToggleClosed,
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (tickets) {
              if (tickets.isEmpty) {
                return const Center(child: Text('No tickets in the queue'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                itemCount: tickets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _TicketCard(ticket: tickets[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final SupportTicket ticket;

  Color _statusColor() {
    switch (ticket.status) {
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
    final eta = ticket.etaAt;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/support/${ticket.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor().withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ticket.status.label,
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
                  ticket.ticketNo,
                  if (ticket.employeeName != null) ticket.employeeName!,
                ].join(' · '),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (eta != null) ...[
                const SizedBox(height: 6),
                Text(
                  'ETA: ${DateFormat('dd MMM yyyy, HH:mm').format(eta.toLocal())}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                ticket.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
