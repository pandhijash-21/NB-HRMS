import 'dart:async';
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
  // For IT members: Tab 0 = "Tickets raised by others" (Assigned Queue), Tab 1 = "My tickets"
  int _tab = 0;
  bool _includeClosed = false;
  String _searchQuery = '';
  SupportTicketStatus? _selectedStatusFilter;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh support tickets list every 3.5 seconds
    _pollTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (mounted) {
        ref.invalidate(mySupportTicketsProvider);
        ref.invalidate(supportQueueProvider);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        title: Text(isIt ? 'IT Support Operations' : 'Support & Help Desk'),
        leading: const AppBackButton(),
        actions: [
          if (canManage)
            HeaderActionButton(
              tooltip: 'Manage IT Assignees',
              label: 'Assignees',
              icon: const Icon(Icons.people_outline_rounded, size: 18),
              onPressed: () => context.push('/support/handlers'),
            ),
          HeaderActionButton(
            tooltip: 'Refresh',
            label: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, size: 18),
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
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Raise ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: AppColors.primaryBlue,
            )
          : null,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            children: [
              // Tab Switcher for IT Members:
              // Tab 0: Tickets raised by others (Assigned Queue)
              // Tab 1: My tickets
              if (isIt)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TabButton(
                            label: 'Tickets raised by others',
                            icon: Icons.assignment_outlined,
                            isSelected: _tab == 0,
                            onTap: () => setState(() => _tab = 0),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _TabButton(
                            label: 'My tickets',
                            icon: Icons.person_outline_rounded,
                            isSelected: _tab == 1,
                            onTap: () => setState(() => _tab = 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Search & Filter Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search by title, ticket #, or employee...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () => setState(() => _searchQuery = ''),
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                          ),
                        ),
                      ),
                    ),
                    if (isIt && _tab == 0) ...[
                      const SizedBox(width: 12),
                      FilterChip(
                        label: Text(
                          'Show closed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _includeClosed ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selected: _includeClosed,
                        onSelected: (val) => setState(() => _includeClosed = val),
                        showCheckmark: false,
                        avatar: Icon(
                          _includeClosed ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                          size: 16,
                          color: _includeClosed ? AppColors.primaryBlue : (isDark ? Colors.white54 : Colors.black45),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Status Filter Pills
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterPill(
                        label: 'All',
                        isSelected: _selectedStatusFilter == null,
                        onTap: () => setState(() => _selectedStatusFilter = null),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Open',
                        isSelected: _selectedStatusFilter == SupportTicketStatus.open,
                        onTap: () => setState(() => _selectedStatusFilter = SupportTicketStatus.open),
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'In Review',
                        isSelected: _selectedStatusFilter == SupportTicketStatus.inReview,
                        onTap: () => setState(() => _selectedStatusFilter = SupportTicketStatus.inReview),
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'In Queue',
                        isSelected: _selectedStatusFilter == SupportTicketStatus.queued,
                        onTap: () => setState(() => _selectedStatusFilter = SupportTicketStatus.queued),
                        color: Colors.amber.shade800,
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Resolved',
                        isSelected: _selectedStatusFilter == SupportTicketStatus.resolved,
                        onTap: () => setState(() => _selectedStatusFilter = SupportTicketStatus.resolved),
                        color: Colors.teal,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // Ticket Content Area
              Expanded(
                child: (!isIt || _tab == 1)
                    ? _MyTicketsList(
                        searchQuery: _searchQuery,
                        statusFilter: _selectedStatusFilter,
                      )
                    : _QueueList(
                        includeClosed: _includeClosed,
                        searchQuery: _searchQuery,
                        statusFilter: _selectedStatusFilter,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isSelected
          ? (isDark ? const Color(0xFF2563EB) : Colors.white)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      elevation: isSelected ? 1 : 0,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: isSelected
                    ? (isDark ? Colors.white : AppColors.primaryBlue)
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : AppColors.primaryBlue)
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillColor = color ?? AppColors.primaryBlue;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? pillColor.withValues(alpha: 0.15)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? pillColor : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? pillColor
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyTicketsList extends ConsumerWidget {
  const _MyTicketsList({
    this.searchQuery = '',
    this.statusFilter,
  });

  final String searchQuery;
  final SupportTicketStatus? statusFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mySupportTicketsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tickets) {
        var filtered = tickets;
        if (statusFilter != null) {
          filtered = filtered.where((t) => t.status == statusFilter).toList();
        }
        if (searchQuery.isNotEmpty) {
          filtered = filtered.where((t) {
            final tNo = t.ticketNo.toLowerCase();
            final title = t.title.toLowerCase();
            final desc = t.description.toLowerCase();
            final emp = (t.employeeName ?? '').toLowerCase();
            return tNo.contains(searchQuery) ||
                title.contains(searchQuery) ||
                desc.contains(searchQuery) ||
                emp.contains(searchQuery);
          }).toList();
        }

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 54, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  'No tickets found',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap "Raise ticket" below to request help from IT support.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _TicketCard(ticket: filtered[i]),
        );
      },
    );
  }
}

class _QueueList extends ConsumerWidget {
  const _QueueList({
    required this.includeClosed,
    this.searchQuery = '',
    this.statusFilter,
  });

  final bool includeClosed;
  final String searchQuery;
  final SupportTicketStatus? statusFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(supportQueueProvider(includeClosed));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading queue: $e')),
      data: (tickets) {
        var filtered = tickets;
        if (statusFilter != null) {
          filtered = filtered.where((t) => t.status == statusFilter).toList();
        }
        if (searchQuery.isNotEmpty) {
          filtered = filtered.where((t) {
            final tNo = t.ticketNo.toLowerCase();
            final title = t.title.toLowerCase();
            final desc = t.description.toLowerCase();
            final emp = (t.employeeName ?? '').toLowerCase();
            return tNo.contains(searchQuery) ||
                title.contains(searchQuery) ||
                desc.contains(searchQuery) ||
                emp.contains(searchQuery);
          }).toList();
        }

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.assignment_turned_in_outlined, size: 54, color: Colors.teal.shade300),
                const SizedBox(height: 12),
                const Text(
                  'No tickets in your queue',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Assigned or transferred tickets raised by others will appear here.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _TicketCard(ticket: filtered[i]),
        );
      },
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final SupportTicket ticket;

  Color _statusColor() {
    switch (ticket.status) {
      case SupportTicketStatus.queued:
        return Colors.amber.shade800;
      case SupportTicketStatus.open:
        return Colors.orange.shade700;
      case SupportTicketStatus.inReview:
        return AppColors.primaryBlue;
      case SupportTicketStatus.resolved:
        return Colors.teal.shade700;
      case SupportTicketStatus.closed:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _statusColor();
    final eta = ticket.etaAt;
    final empName = ticket.employeeName ?? 'Employee #${ticket.employeeId}';

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/support/${ticket.id}'),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: statusColor, width: 4),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Ticket ID, Creator, Status badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ticket.ticketNo,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: statusColor.withValues(alpha: 0.15),
                          child: Text(
                            empName.isNotEmpty ? empName[0].toUpperCase() : 'U',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            empName,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ticket.status.label,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                ticket.title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
              ),

              // Description preview
              if (ticket.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  ticket.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],

              // Badges row: Queue Position, Pending Transfer, Remote Session, ETA, Time
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (ticket.status == SupportTicketStatus.queued && (ticket.queuePosition ?? 0) > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_top, size: 12, color: Colors.amber.shade900),
                          const SizedBox(width: 4),
                          Text(
                            'Queue #${ticket.queuePosition}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (ticket.transferStatus == 'PENDING')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horiz, size: 13, color: Colors.blue.shade800),
                          const SizedBox(width: 4),
                          Text(
                            'Transfer Pending',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (eta != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.alarm_rounded, size: 13, color: isDark ? Colors.white54 : Colors.black54),
                        const SizedBox(width: 4),
                        Text(
                          'ETA: ${DateFormat('dd MMM, HH:mm').format(eta.toLocal())}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: isDark ? Colors.white38 : Colors.black38),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM, HH:mm').format(ticket.createdAt.toLocal()),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
