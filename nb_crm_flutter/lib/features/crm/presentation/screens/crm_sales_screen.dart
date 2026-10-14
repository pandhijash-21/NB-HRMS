import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/network/app_config.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/crm_repository.dart';
import '../../domain/crm_models.dart';
import '../bloc/crm_leads_bloc.dart';
import '../widgets/crm_scope_selector.dart';
import '../../../erp/presentation/project_providers.dart';
import '../../../erp/domain/project_models.dart';
import '../../../erp/domain/structure_models.dart';
import '../utils/proposal_print.dart';

class CrmSalesScreen extends ConsumerWidget {
  const CrmSalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocProvider<CrmLeadsBloc>(
      create: (ctx) => CrmLeadsBloc(
        crmRepository: ctx.read<CrmRepository>(),
      )..add(const CrmLeadsLoadRequested()),
      child: const _CrmSalesView(),
    );
  }
}

class _CrmSalesView extends ConsumerStatefulWidget {
  const _CrmSalesView();

  @override
  ConsumerState<_CrmSalesView> createState() => _CrmSalesViewState();
}

class _CrmSalesViewState extends ConsumerState<_CrmSalesView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quotationSearchController = TextEditingController();

  String _statusFilter = 'ALL';
  int? _selectedSalesManagerId;
  bool _filterOnlyMyLeads = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    CrmRepository.crmScopeNotifier.addListener(_onScopeChanged);
  }

  void _onScopeChanged() {
    if (mounted) {
      setState(() {});
      context.read<CrmLeadsBloc>().add(const CrmLeadsLoadRequested());
    }
  }

  @override
  void dispose() {
    CrmRepository.crmScopeNotifier.removeListener(_onScopeChanged);
    _tabController.dispose();
    _searchController.dispose();
    _quotationSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFFC5A059).withValues(alpha: 0.22)
        : const Color(0xFFE2E8F0);
    final textMuted = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF64748B);
    const primaryColor = Color(0xFF2563EB); // Royal Blue for Sales
    const goldColor = Color(0xFFC5A059);

    final crmRepo = context.read<CrmRepository>();
    final isFinserve = crmRepo.scope == 'NB_FINSERVE';

    final authState = context.watch<AuthBloc>().state;
    final currentUser = authState.user;
    final userEmployeeId = currentUser?.employeeId;
    final userRole = currentUser?.role.toUpperCase() ?? '';
    final isSuperAdmin = userRole == 'SUPERADMIN' || userRole == 'ADMIN';

    return BlocConsumer<CrmLeadsBloc, CrmLeadsState>(
      listener: (context, state) {
        if (state.actionSuccessMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.actionSuccessMessage!),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        // Collect all leads
        final allLeads = state.leads;

        // Sales users map
        final salesUsers = state.salesUsers;

        // Active scope
        final currentScope = CrmRepository.crmScopeNotifier.value;

        // Filter leads based on sales assignment & search & status & active scope
        final filteredLeads = allLeads.where((lead) {
          // Strictly segregate by active scope
          if (lead.scope != currentScope) return false;

          // Sales Management ONLY shows leads that have been assigned to a sales manager!
          if (lead.assignedToId == null) return false;

          if (_filterOnlyMyLeads && !isSuperAdmin && userEmployeeId != null) {
            if (lead.assignedToId != userEmployeeId) return false;
          } else if (_selectedSalesManagerId != null) {
            if (lead.assignedToId != _selectedSalesManagerId) return false;
          }

          if (_statusFilter != 'ALL') {
            if (lead.status.backendValue != _statusFilter) return false;
          }

          final q = _searchController.text.trim().toLowerCase();
          if (q.isNotEmpty) {
            final nameMatch = lead.name.toLowerCase().contains(q);
            final phoneMatch = lead.phone.toLowerCase().contains(q);
            final unitMatch = (lead.unitShown?['unitNo']?.toString().toLowerCase().contains(q) ?? false);
            final projMatch = (lead.unitShown?['projectName']?.toString().toLowerCase().contains(q) ?? false);
            final loanMatch = (lead.customFields['Loan_Type']?.toString().toLowerCase().contains(q) ?? false);
            if (!nameMatch && !phoneMatch && !unitMatch && !projMatch && !loanMatch) return false;
          }

          return true;
        }).toList();

        // Clients with quotations
        final leadsWithProposals = allLeads.where((l) => l.scope == currentScope && l.assignedToId != null && l.proposals.isNotEmpty).toList();
        final filteredQuotationLeads = leadsWithProposals.where((lead) {
          final q = _quotationSearchController.text.trim().toLowerCase();
          if (q.isEmpty) return true;
          return lead.name.toLowerCase().contains(q) ||
              lead.phone.toLowerCase().contains(q) ||
              lead.proposals.any((p) => p.unitNo.toLowerCase().contains(q) || p.id.toLowerCase().contains(q));
        }).toList();

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF141210) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sales Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
                Text(
                  isSuperAdmin
                      ? 'All Assigned Leads, Site Visits & Quotations'
                      : 'Assigned Customers & Quotation Lifecycle',
                  style: TextStyle(fontSize: 12, color: textMuted, fontWeight: FontWeight.normal),
                ),
              ],
            ),
            leading: const AppBackButton(fallbackLocation: '/crm/dashboard'),
            backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: TabBar(
                controller: _tabController,
                indicatorColor: goldColor,
                labelColor: isDark ? goldColor : primaryColor,
                unselectedLabelColor: textMuted,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.people_alt_rounded, size: 20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Assigned Customers'),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isDark ? goldColor : primaryColor).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${filteredLeads.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? goldColor : primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    icon: Icon(isFinserve ? Icons.assignment_turned_in_rounded : Icons.request_quote_rounded, size: 20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(isFinserve ? 'Applications' : 'Quotations'),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isFinserve
                                ? '${allLeads.where((l) => l.status == CrmStatus.interested || l.status.backendValue == "INTERESTED" || l.customFields["applicationDetails"] != null).length}'
                                : '${leadsWithProposals.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              CrmScopeSelectorWidget(
                onScopeChanged: () {
                  setState(() {});
                  context.read<CrmLeadsBloc>().add(const CrmLeadsLoadRequested());
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  context.read<CrmLeadsBloc>().add(const CrmLeadsRefreshRequested());
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildCustomersTab(
                context,
                filteredLeads,
                salesUsers,
                state,
                isDark,
                cardBg,
                borderColor,
                textMuted,
                primaryColor,
                userEmployeeId,
                isSuperAdmin,
              ),
              if (isFinserve)
                _buildFinserveApplicationsTab(
                  context,
                  allLeads,
                  isDark,
                  cardBg,
                  borderColor,
                  textMuted,
                  primaryColor,
                  goldColor,
                )
              else
                _buildQuotationsTab(
                  context,
                  filteredQuotationLeads,
                  allLeads,
                  isDark,
                  cardBg,
                  borderColor,
                  textMuted,
                  primaryColor,
                  goldColor,
                  userEmployeeId,
                  currentUser?.name,
                ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // TAB 1: Assigned Customers
  // ===========================================================================
  Widget _buildCustomersTab(
    BuildContext context,
    List<CrmLead> leads,
    List<CrmSalesUser> salesUsers,
    CrmLeadsState state,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
    Color primaryColor,
    int? userEmployeeId,
    bool isSuperAdmin,
  ) {
    // KPI metrics
    final isFinserve = CrmRepository.crmScopeNotifier.value == 'NB_FINSERVE';
    final totalAssigned = leads.length;
    final unitsShownCount = leads.where((l) => l.unitShown != null).length;
    final proposalsCount = leads.where((l) => l.proposals.isNotEmpty).length;
    final siteDoneCount = leads.where((l) => l.status == CrmStatus.siteVisitDone).length;
    final visitScheduledCount = leads.where((l) => l.status == CrmStatus.scheduledVisit).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Metric Cards
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildMetricCard(
                title: 'Assigned Leads',
                value: '$totalAssigned',
                icon: Icons.assignment_ind_rounded,
                color: const Color(0xFF3B82F6),
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
              ),
              if (isFinserve) ...[
                _buildMetricCard(
                  title: 'Visits Scheduled',
                  value: '$visitScheduledCount',
                  icon: Icons.calendar_month_rounded,
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                ),
                _buildMetricCard(
                  title: 'Visits Done',
                  value: '$siteDoneCount',
                  icon: Icons.verified_rounded,
                  color: const Color(0xFF8B5CF6),
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                ),
                _buildMetricCard(
                  title: 'Quotations / Sanctions',
                  value: '$proposalsCount',
                  icon: Icons.description_rounded,
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                ),
              ] else ...[
                _buildMetricCard(
                  title: 'Units Shown',
                  value: '$unitsShownCount',
                  icon: Icons.apartment_rounded,
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                ),
                _buildMetricCard(
                  title: 'Proposals Active',
                  value: '$proposalsCount',
                  icon: Icons.description_rounded,
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                ),
                _buildMetricCard(
                  title: 'Site Visits Done',
                  value: '$siteDoneCount',
                  icon: Icons.verified_rounded,
                  color: const Color(0xFF8B5CF6),
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // Filters & Search Row
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by client name, phone, or unit shown...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Status filter dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _statusFilter,
                          isDense: true,
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                            DropdownMenuItem(value: 'ASSIGNED', child: Text('Assigned')),
                            DropdownMenuItem(value: 'CNR', child: Text('CNR')),
                            DropdownMenuItem(value: 'FOLLOW_UP', child: Text('Follow Up')),
                            DropdownMenuItem(value: 'SCHEDULED_VISIT', child: Text('Visit Scheduled')),
                            DropdownMenuItem(value: 'SITE_VISIT_DONE', child: Text('Visit Done')),
                            DropdownMenuItem(value: 'NOT_INTERESTED', child: Text('Not Interested')),
                            DropdownMenuItem(value: 'INTERESTED', child: Text('Interested')),
                            DropdownMenuItem(value: 'NOT_STARTED', child: Text('Not Started')),
                            DropdownMenuItem(value: 'PROPOSAL_SENT', child: Text('Proposal Sent')),
                            DropdownMenuItem(value: 'BOOKING_CONFIRMED', child: Text('Booking Confirmed')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _statusFilter = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Sales Manager Scope Toggle
                Row(
                  children: [
                    if (!isSuperAdmin && userEmployeeId != null) ...[
                      FilterChip(
                        selected: _filterOnlyMyLeads,
                        label: const Text('My Assigned Leads Only'),
                        onSelected: (sel) => setState(() => _filterOnlyMyLeads = sel),
                        selectedColor: primaryColor.withValues(alpha: 0.2),
                        checkmarkColor: primaryColor,
                      ),
                      const SizedBox(width: 10),
                    ],
                    // Dropdown for Sales Managers (Admin or Team view)
                    if (isSuperAdmin || !_filterOnlyMyLeads) ...[
                      Text('Assigned To: ', style: TextStyle(fontSize: 12, color: textMuted)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: salesUsers.any((u) => u.employeeId == _selectedSalesManagerId)
                                ? _selectedSalesManagerId
                                : null,
                            isDense: true,
                            hint: const Text('All Sales Managers'),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All Sales Managers')),
                              ...salesUsers.map((u) => DropdownMenuItem(
                                    value: u.employeeId,
                                    child: Text(u.fullName.isNotEmpty ? u.fullName : 'Sales User #${u.employeeId}'),
                                  )),
                            ],
                            onChanged: (id) => setState(() => _selectedSalesManagerId = id),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Customer Cards List
          if (leads.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.person_search_rounded, size: 54, color: textMuted),
                    const SizedBox(height: 12),
                    Text(
                      'No Assigned Leads Found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Leads assigned to this sales person will appear here.',
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: leads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, idx) {
                final lead = leads[idx];
                return _buildCustomerCard(
                  context,
                  lead,
                  salesUsers,
                  isDark,
                  cardBg,
                  borderColor,
                  textMuted,
                  primaryColor,
                  userEmployeeId,
                );
              },
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Customer Card Component
  // ---------------------------------------------------------------------------
  Widget _buildCustomerCard(
    BuildContext context,
    CrmLead lead,
    List<CrmSalesUser> salesUsers,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
    Color primaryColor,
    int? userEmployeeId,
  ) {
    final unitShown = lead.unitShown;
    final proposals = lead.proposals;
    final appointedMgr = lead.assignedToName ?? 'Unassigned';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Bar: Name, Phone, Status badge, Quick status toggle
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: primaryColor.withValues(alpha: 0.12),
                  child: Text(
                    lead.name.isNotEmpty ? lead.name[0].toUpperCase() : 'C',
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              lead.name.isNotEmpty
                                  ? lead.name
                                  : 'Client #${lead.id.length >= 6 ? lead.id.substring(0, 6) : lead.id}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusDropdown(context, lead, isDark),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 14,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone_rounded, size: 14, color: textMuted),
                              const SizedBox(width: 4),
                              Text(lead.phone, style: TextStyle(fontSize: 13, color: textMuted)),
                            ],
                          ),
                          if (lead.email != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.email_outlined, size: 14, color: textMuted),
                                const SizedBox(width: 4),
                                Text(lead.email!, style: TextStyle(fontSize: 13, color: textMuted)),
                              ],
                            ),
                          if (lead.address != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on_outlined, size: 14, color: textMuted),
                                const SizedBox(width: 4),
                                Text(lead.address!, style: TextStyle(fontSize: 13, color: textMuted)),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Assigned Sales Manager Chip
                      Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 14, color: Colors.blue.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Sales Manager: $appointedMgr',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                            ),
                          ),
                          if (lead.campaignName != null) ...[
                            const SizedBox(width: 10),
                            Text('•  Campaign: ${lead.campaignName}', style: TextStyle(fontSize: 11, color: textMuted)),
                          ],
                        ],
                      ),
                      Builder(
                        builder: (context) {
                          final isVisitCompleted = lead.status == CrmStatus.siteVisitDone ||
                              lead.status == CrmStatus.proposalSent ||
                              lead.status == CrmStatus.bookingConfirmed ||
                              lead.visitedAt != null;
                          final isObsoleteVisitFollowUp = isVisitCompleted &&
                              (lead.latestFollowUp?.remarks?.toLowerCase().contains('visit') ?? false);
                          final hasActiveFollowUp = lead.latestFollowUp != null &&
                              lead.latestFollowUp!.status.toUpperCase() == 'PENDING' &&
                              !isObsoleteVisitFollowUp;

                          if (!hasActiveFollowUp && lead.status != CrmStatus.followUp) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.alarm_on_rounded, size: 15, color: Color(0xFFEA580C)),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      lead.latestFollowUp != null
                                          ? 'Follow-up: ${DateFormat("dd MMM yyyy").format(lead.latestFollowUp!.scheduledDate.toLocal())} at ${lead.latestFollowUp!.scheduledTime}${lead.latestFollowUp!.remarks?.isNotEmpty == true ? ' • "${lead.latestFollowUp!.remarks}"' : ""}'
                                          : 'Follow-up: Date & time not scheduled yet',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFEA580C),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => _showFollowUpSchedulingModal(context, lead),
                                    child: const Text(
                                      'Change',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFEA580C),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Quick Status Menu
                PopupMenuButton<String>(
                  tooltip: 'Update Status',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (newStatus) {
                    _handleQuickStatusChange(context, lead, newStatus);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'CNR', child: Text('CNR (Auto +24h Reschedule)')),
                    const PopupMenuItem(value: 'FOLLOW_UP', child: Text('Follow up')),
                    const PopupMenuItem(value: 'SCHEDULED_VISIT', child: Text('Visit Scheduled')),
                    const PopupMenuItem(value: 'SITE_VISIT_DONE', child: Text('Visit Done (Auto System Time)')),
                    const PopupMenuItem(value: 'NOT_INTERESTED', child: Text('Not Interested')),
                    const PopupMenuItem(value: 'INTERESTED', child: Text('Interested')),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scope-Aware Details Section: Loan Requirement (Finserve) vs Unit Shown (Real Estate)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: isDark ? Colors.black.withValues(alpha: 0.15) : const Color(0xFFF1F5F9).withValues(alpha: 0.6),
            child: (lead.scope == 'NB_FINSERVE' || context.read<CrmRepository>().scope == 'NB_FINSERVE')
                ? () {
                    final portalLink = _getPortalLink(lead);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF2563EB), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Loan Requirement: ${lead.customFields['Loan_Type'] ?? lead.customFields['Type_Of_Loan'] ?? lead.customFields['loan_type'] ?? 'Finance / Loan Inquiry'}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Desired Amount: ₹ ${lead.customFields['Amount'] ?? lead.customFields['amount'] ?? lead.customFields['Budget'] ?? '--'} • Location: ${lead.customFields['Location'] ?? lead.customFields['location'] ?? lead.address ?? '--'}',
                                    style: TextStyle(fontSize: 12, color: textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (portalLink != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.link_rounded, size: 16, color: Color(0xFF2563EB)),
                                const SizedBox(width: 6),
                                const Text(
                                  'Portal Link: ',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                ),
                                Expanded(
                                  child: SelectableText(
                                    portalLink,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: isDark ? Colors.blue.shade200 : const Color(0xFF1D4ED8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _copyPortalLinkDirect(portalLink),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.copy_rounded, size: 12, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text('Copy', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => _shareLeadPortalViaWhatsApp(lead, portalLink),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF25D366),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.chat_bubble_outline_rounded, size: 12, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text('WhatsApp', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  }()
                : (unitShown != null
                    ? Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.apartment_rounded, color: Color(0xFF10B981), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Unit Shown: ${unitShown['unitNo'] ?? "Unit"} (${unitShown['projectName'] ?? "Project"} - ${unitShown['towerName'] ?? "Tower"})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${unitShown['unitType'] ?? "Flat"} • ${unitShown['carpetArea'] ?? "--"} sq.ft • Floor ${unitShown['floorNo'] ?? "--"} • Value: ₹ ${NumberFormat("#,##,###").format(num.tryParse(unitShown['totalValue']?.toString() ?? '0') ?? 0)}',
                                  style: TextStyle(fontSize: 12, color: textMuted),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.edit_outlined, size: 15),
                            label: const Text('Change Unit', style: TextStyle(fontSize: 12)),
                            onPressed: () => _showSelectUnitModal(context, lead),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: textMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No unit recorded as shown to customer yet.',
                              style: TextStyle(fontSize: 12, color: textMuted, fontStyle: FontStyle.italic),
                            ),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.add_home_work_rounded, size: 15),
                            label: const Text('Select Unit Shown', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _showSelectUnitModal(context, lead),
                          ),
                        ],
                      )),
          ),

          const Divider(height: 1),

          // Bottom Action Bar: Proposals summary & CTA buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Proposals badge
                if (proposals.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFFD97706)),
                        const SizedBox(width: 4),
                        Text(
                          '${proposals.length} ${proposals.length == 1 ? "Proposal" : "Proposals"}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                        ),
                      ],
                    ),
                  ),
                ],

                const Spacer(),

                // "View Details & Logs"
                OutlinedButton.icon(
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: const Text('Details & Logs'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => _showCustomerDetailsAndLogsModal(context, lead),
                ),
                const SizedBox(width: 8),

                // Primary Action: Finserve -> "Application & Docs"; Real Estate -> "Generate Quotation"
                if (lead.scope == 'NB_FINSERVE' || context.read<CrmRepository>().scope == 'NB_FINSERVE') ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.assignment_turned_in_rounded, size: 17),
                    label: const Text('Application & Docs'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      elevation: 0,
                    ),
                    onPressed: () => _showFinserveApplicationModal(context, lead),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.request_quote_rounded, size: 17),
                    label: const Text('Generate Quotation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC5A059),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      elevation: 0,
                    ),
                    onPressed: () => _showGenerateQuotationModal(context, lead),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: Quotations Module (Grouped by Client with Dropdown)
  // ===========================================================================
  Widget _buildQuotationsTab(
    BuildContext context,
    List<CrmLead> leadsWithProposals,
    List<CrmLead> allLeads,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
    Color primaryColor,
    Color goldColor,
    int? userEmployeeId,
    String? currentUserName,
  ) {
    if (leadsWithProposals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.request_quote_outlined, size: 60, color: textMuted),
              const SizedBox(height: 16),
              Text(
                'No Quotations Generated Yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Generate a quotation from the Assigned Customers tab to see it here.',
                style: TextStyle(fontSize: 13, color: textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.people_alt_rounded, size: 18),
                label: const Text('Go to Assigned Customers'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: goldColor,
                  foregroundColor: Colors.black87,
                ),
                onPressed: () {
                  _tabController.animateTo(0);
                },
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Proposals & Estimates',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Select a client to view and manage all revisions, reject, or confirm booking.',
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ],
                ),
              ),
              // Search input
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _quotationSearchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search client or unit...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Client Proposals Accordion / Dropdown Cards
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadsWithProposals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (ctx, idx) {
              final lead = leadsWithProposals[idx];
              return _ClientProposalsGroupCard(
                key: ValueKey('client_proposals_${lead.id}'),
                lead: lead,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textMuted: textMuted,
                primaryColor: primaryColor,
                goldColor: goldColor,
                onProposalUpdated: () {
                  context.read<CrmLeadsBloc>().add(const CrmLeadsRefreshRequested());
                },
                onGenerateNewProposal: () {
                  _showGenerateQuotationModal(context, lead, isRevision: true);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MODAL 1: Select Unit Shown (Project, Tower, Unit fetched from ERP Projects)
  // ===========================================================================
  void _showSelectUnitModal(BuildContext context, CrmLead lead) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _ErpSelectUnitDialog(
        lead: lead,
        onSave: (unitData) {
          final authState = context.read<AuthBloc>().state;
          final currentUserName = authState.user?.name ?? 'Sales Manager';
          final currentUserId = authState.user?.employeeId;

          final newLog = CrmCustomerLog(
            id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
            title: 'Unit Shown: Unit ${unitData['unitNo']}',
            description:
                'Unit ${unitData['unitNo']} in ${unitData['towerName']}, ${unitData['projectName']} shown to customer by $currentUserName. Remarks: ${unitData['remarks'] ?? ""}',
            type: 'UNIT_SHOWN',
            timestamp: DateTime.now(),
            performedByName: currentUserName,
            performedById: currentUserId,
          );

          final updatedLogs = [
            newLog.toJson(),
            ...lead.activityLogs.map((l) => l.toJson()),
          ];

          final updatedCustomFields = {
            ...lead.customFields,
            'unitShown': {
              ...unitData,
              'shownByName': currentUserName,
              'shownById': currentUserId,
            },
            'activityLogs': updatedLogs,
            'salesManagerName': currentUserName,
          };

          context.read<CrmLeadsBloc>().add(
                CrmLeadsLeadUpdated(lead.id, {
                  'customFields': updatedCustomFields,
                }),
              );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unit ${unitData['unitNo']} (${unitData['projectName']}) recorded as shown.'),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // MODAL: Follow-up Scheduling with Date and Time
  // ===========================================================================
  void _showFollowUpSchedulingModal(BuildContext context, CrmLead lead) {
    DateTime selectedDate = lead.latestFollowUp?.scheduledDate != null
        ? lead.latestFollowUp!.scheduledDate.toLocal()
        : DateTime.now().add(const Duration(days: 1));

    TimeOfDay selectedTime = const TimeOfDay(hour: 11, minute: 0);
    if (lead.latestFollowUp?.scheduledTime != null) {
      final parts = lead.latestFollowUp!.scheduledTime.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 11;
        final m = int.tryParse(parts[1].split(' ').first) ?? 0;
        selectedTime = TimeOfDay(hour: h, minute: m);
      }
    }

    final remarksCtrl = TextEditingController(text: lead.latestFollowUp?.remarks ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.schedule_rounded, color: Color(0xFFEA580C)),
              const SizedBox(width: 10),
              Expanded(child: Text('Schedule Follow-up: ${lead.name}')),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(dialogCtx),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (lead.latestFollowUp != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.history_rounded, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Current Follow-up: ${DateFormat("dd MMM yyyy").format(lead.latestFollowUp!.scheduledDate.toLocal())} at ${lead.latestFollowUp!.scheduledTime}. Updating will reschedule it.',
                              style: const TextStyle(fontSize: 12, color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  Text('Customer Phone: ${lead.phone}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),

                  // Scheduled Date Picker
                  const Text('Follow-up Date *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 14)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd MMM yyyy').format(selectedDate),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFFEA580C)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Scheduled Time Picker
                  const Text('Follow-up Time *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setModalState(() => selectedTime = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedTime.format(context),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFFEA580C)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Follow-up Summary Pill
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available_rounded, size: 18, color: Color(0xFFEA580C)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Follow-up set for: ${DateFormat("dd MMM yyyy").format(selectedDate)} at ${selectedTime.format(context)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Remarks
                  const Text('Follow-up Agenda / Discussion Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: remarksCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Enter agenda, questions discussed, client interest level...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
              label: const Text('Save & Schedule'),
              onPressed: () {
                Navigator.pop(dialogCtx);
                final dateIso = selectedDate.toIso8601String().split('T').first;
                final timeFormatted = selectedTime.format(context);
                final remarks = remarksCtrl.text.trim();

                final authState = context.read<AuthBloc>().state;
                final currentUserName = authState.user?.name ?? 'Sales Manager';
                final currentUserId = authState.user?.employeeId;

                final newLog = CrmCustomerLog(
                  id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
                  title: 'Follow-up Scheduled',
                  description:
                      'Follow-up scheduled for ${DateFormat("dd MMM yyyy").format(selectedDate)} at $timeFormatted. Remarks: ${remarks.isNotEmpty ? remarks : "None"}',
                  type: 'FOLLOW_UP',
                  timestamp: DateTime.now(),
                  performedByName: currentUserName,
                  performedById: currentUserId,
                );

                final updatedLogs = [
                  newLog.toJson(),
                  ...lead.activityLogs.map((l) => l.toJson()),
                ];

                final updatedCustomFields = {
                  ...lead.customFields,
                  'activityLogs': updatedLogs,
                };

                // Dispatch status update event with date & time
                context.read<CrmLeadsBloc>().add(
                      CrmLeadsLeadStatusUpdated(
                        lead.id,
                        status: 'FOLLOW_UP',
                        scheduledDate: dateIso,
                        scheduledTime: timeFormatted,
                        remarks: remarks,
                      ),
                    );

                // Also update customFields activity logs
                context.read<CrmLeadsBloc>().add(
                      CrmLeadsLeadUpdated(lead.id, {
                        'customFields': updatedCustomFields,
                      }),
                    );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Follow-up scheduled for ${DateFormat("dd MMM yyyy").format(selectedDate)} at $timeFormatted'),
                    backgroundColor: const Color(0xFFEA580C),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // MODAL 2: Generate Quotation & Proposal
  // ===========================================================================
  void _showGenerateQuotationModal(BuildContext context, CrmLead lead, {bool isRevision = false}) async {
    final authState = context.read<AuthBloc>().state;
    final currentUserName = authState.user?.name ?? 'Sales Executive';
    final currentUserId = authState.user?.employeeId;

    // Prefill unit info from unitShown if available
    final unitShown = lead.unitShown;
    String projectName = unitShown?['projectName']?.toString() ?? 'NB Heights';
    String towerName = unitShown?['towerName']?.toString() ?? 'Tower A';
    String unitNo = unitShown?['unitNo']?.toString() ?? '101';
    String unitType = unitShown?['unitType']?.toString() ?? '3 BHK Luxury';
    double carpetAreaVal = double.tryParse(unitShown?['carpetArea']?.toString() ?? '') ?? 0.0;
    double superBuiltUpVal = double.tryParse(unitShown?['superBuiltUp']?.toString() ?? '') ?? carpetAreaVal;
    double baseRateVal = double.tryParse(unitShown?['baseRate']?.toString() ?? '') ?? 0.0;
    double plcVal = double.tryParse(unitShown?['plc']?.toString() ?? '') ?? 0.0;
    double frcVal = double.tryParse(unitShown?['frc']?.toString() ?? '') ?? 0.0;
    double devChargesVal = double.tryParse(unitShown?['developmentCharge']?.toString() ?? '') ?? 0.0;
    String unitRemarks = unitShown?['remarks']?.toString() ?? '';

    // Unit taxes, maintenance, other charges
    double gstPercent = 0.0;
    double gstAmountVal = 0.0;
    double stampDutyPercent = 0.0;
    double stampDutyAmountVal = 0.0;
    double regChargesVal = 0.0;
    double maintenanceVal = 0.0;
    double otherChargesVal = 0.0;

    // Attempt to fetch exact ERP unit configuration amounts from repository
    try {
      final repo = ref.read(projectRepositoryProvider);
      final uId = unitShown?['unitId']?.toString();
      final uNo = unitNo.trim();
      final pId = unitShown?['projectId']?.toString();
      final pName = projectName.trim();
      final tId = unitShown?['towerId']?.toString();
      final tName = towerName.trim();

      final projects = await repo.list();
      ErpProject? matchedProj;
      if (pId != null && pId.isNotEmpty) {
        matchedProj = projects.where((p) => p.id == pId).firstOrNull;
      }
      if (matchedProj == null && pName.isNotEmpty) {
        matchedProj = projects.where((p) => p.name.toLowerCase() == pName.toLowerCase()).firstOrNull;
      }
      matchedProj ??= projects.firstOrNull;

      if (matchedProj != null) {
        projectName = matchedProj.name;
        final towers = await repo.listTowers(matchedProj.id);
        ErpProjectTower? matchedTower;
        if (tId != null && tId.isNotEmpty) {
          matchedTower = towers.where((t) => t.id == tId).firstOrNull;
        }
        if (matchedTower == null && tName.isNotEmpty) {
          matchedTower = towers.where((t) => t.name.toLowerCase() == tName.toLowerCase()).firstOrNull;
        }
        matchedTower ??= towers.firstOrNull;

        if (matchedTower != null) {
          towerName = matchedTower.name;
          final fullTower = await repo.getTower(matchedProj.id, matchedTower.id);
          ErpProjectUnit? matchedUnit;
          if (uId != null && uId.isNotEmpty) {
            matchedUnit = fullTower.units.where((u) => u.id == uId).firstOrNull;
          }
          if (matchedUnit == null && uNo.isNotEmpty) {
            matchedUnit = fullTower.units.where((u) => u.unitNo.toLowerCase() == uNo.toLowerCase()).firstOrNull;
          }

          if (matchedUnit != null) {
            unitNo = matchedUnit.unitNo;
            unitType = matchedUnit.unitTypeCode ?? (matchedUnit.isDuplex ? 'Duplex' : 'Apartment');
            if (matchedUnit.carpetArea != null && matchedUnit.carpetArea! > 0) {
              carpetAreaVal = matchedUnit.carpetArea!;
            }
            if (matchedUnit.superBuiltUp != null && matchedUnit.superBuiltUp! > 0) {
              superBuiltUpVal = matchedUnit.superBuiltUp!;
            }
            if (matchedUnit.baseRate != null && matchedUnit.baseRate! > 0) {
              baseRateVal = matchedUnit.baseRate!;
            }
            plcVal = matchedUnit.plc ?? 0.0;
            frcVal = matchedUnit.frc ?? 0.0;

            final area = superBuiltUpVal > 0 ? superBuiltUpVal : carpetAreaVal;
            final bsv = area * baseRateVal;

            if (matchedUnit.totalUnitValue != null && matchedUnit.totalUnitValue! > 0) {
              final diff = matchedUnit.totalUnitValue! - bsv - plcVal - frcVal;
              devChargesVal = diff > 0 ? diff : 0.0;
            } else if (matchedUnit.developmentCharge != null && matchedUnit.developmentCharge! > 0) {
              devChargesVal = matchedUnit.developmentCharge! > 1000
                  ? matchedUnit.developmentCharge!
                  : (area * matchedUnit.developmentCharge!);
            }

            for (final t in matchedUnit.taxes) {
              final upper = t.name.toUpperCase();
              if (upper.contains('GST')) {
                gstPercent = t.ratePercent;
                gstAmountVal = t.amount;
              } else if (upper.contains('STAMP')) {
                stampDutyPercent = t.ratePercent;
                stampDutyAmountVal = t.amount;
              } else if (upper.contains('REG')) {
                regChargesVal += t.amount;
              } else {
                otherChargesVal += t.amount;
              }
            }

            for (final m in matchedUnit.maintenance) {
              maintenanceVal += m.amount;
            }

            for (final o in matchedUnit.otherCharges) {
              otherChargesVal += o.amount;
            }

            if (matchedUnit.remarks != null && matchedUnit.remarks!.isNotEmpty) {
              unitRemarks = matchedUnit.remarks!;
            }
          }
        }
      }
    } catch (_) {}

    if (!context.mounted) return;

    // Fallback from unitShown JSON if not resolved via repository
    if (gstAmountVal == 0 && unitShown?['taxes'] is List) {
      for (final t in (unitShown!['taxes'] as List)) {
        final m = Map<String, dynamic>.from(t as Map);
        final name = (m['name'] ?? '').toString().toUpperCase();
        final amt = (m['amount'] as num?)?.toDouble() ?? 0.0;
        final pct = (m['ratePercent'] as num?)?.toDouble() ?? 0.0;
        if (name.contains('GST')) {
          gstPercent = pct;
          gstAmountVal = amt;
        } else if (name.contains('STAMP')) {
          stampDutyPercent = pct;
          stampDutyAmountVal = amt;
        } else if (name.contains('REG')) {
          regChargesVal += amt;
        } else {
          otherChargesVal += amt;
        }
      }
    }
    if (maintenanceVal == 0 && unitShown?['maintenance'] is List) {
      for (final m in (unitShown!['maintenance'] as List)) {
        final amt = (m['amount'] as num?)?.toDouble() ?? 0.0;
        maintenanceVal += amt;
      }
    }
    if (otherChargesVal == 0 && unitShown?['otherCharges'] is List) {
      for (final o in (unitShown!['otherCharges'] as List)) {
        final amt = (o['amount'] as num?)?.toDouble() ?? 0.0;
        otherChargesVal += amt;
      }
    }

    final area = superBuiltUpVal > 0 ? superBuiltUpVal : carpetAreaVal;
    final basePriceVal = area * baseRateVal;

    // Controllers initialized directly from unit config amounts - nothing hardcoded!
    final nameCtrl = TextEditingController(text: lead.name);
    final phoneCtrl = TextEditingController(text: lead.phone);
    final emailCtrl = TextEditingController(text: lead.email ?? '');
    final addressCtrl = TextEditingController(text: lead.address ?? '');

    final unitNoCtrl = TextEditingController(text: unitNo);
    final projectCtrl = TextEditingController(text: projectName);
    final towerCtrl = TextEditingController(text: towerName);
    final unitTypeCtrl = TextEditingController(text: unitType);
    final carpetAreaCtrl = TextEditingController(text: carpetAreaVal > 0 ? carpetAreaVal.toStringAsFixed(0) : '');
    final superBuiltUpCtrl = TextEditingController(text: superBuiltUpVal > 0 ? superBuiltUpVal.toStringAsFixed(0) : '');

    final baseRateCtrl = TextEditingController(text: baseRateVal > 0 ? baseRateVal.toStringAsFixed(0) : '');
    final basePriceCtrl = TextEditingController(text: basePriceVal > 0 ? basePriceVal.toStringAsFixed(0) : '');
    final plcCtrl = TextEditingController(text: plcVal > 0 ? plcVal.toStringAsFixed(0) : '0');
    final frcCtrl = TextEditingController(text: frcVal > 0 ? frcVal.toStringAsFixed(0) : '0');
    final devChargesCtrl = TextEditingController(text: devChargesVal > 0 ? devChargesVal.toStringAsFixed(0) : '0');
    final maintenanceCtrl = TextEditingController(text: maintenanceVal > 0 ? maintenanceVal.toStringAsFixed(0) : '0');
    final otherChargesCtrl = TextEditingController(text: otherChargesVal > 0 ? otherChargesVal.toStringAsFixed(0) : '0');

    final gstCtrl = TextEditingController(text: gstAmountVal > 0 ? gstAmountVal.toStringAsFixed(0) : '0');
    final stampDutyCtrl = TextEditingController(text: stampDutyAmountVal > 0 ? stampDutyAmountVal.toStringAsFixed(0) : '0');
    final regChargesCtrl = TextEditingController(text: regChargesVal > 0 ? regChargesVal.toStringAsFixed(0) : '0');

    final descriptionCtrl = TextEditingController(text: unitRemarks);
    final disclaimerCtrl = TextEditingController(
      text:
          '1. Prices and availability are subject to change without prior notice.\n2. Applicable Government GST and Stamp Duty charges are subject to statutory revisions.\n3. Booking is subject to clearance of booking token and standard terms of agreement.',
    );

    // Proposal Expiry Date: defaults to 7 days from now
    DateTime expiryDate = DateTime.now().add(const Duration(days: 7));

    double grandTotal = 0.0;

    void recalculate(void Function(void Function()) setModalState) {
      setModalState(() {
        final sbArea = double.tryParse(superBuiltUpCtrl.text) ?? 0.0;
        final bRate = double.tryParse(baseRateCtrl.text) ?? 0.0;
        final bPrice = double.tryParse(basePriceCtrl.text) ?? (sbArea * bRate);
        if (basePriceCtrl.text.isEmpty || basePriceCtrl.text == '0') {
          basePriceCtrl.text = bPrice.toStringAsFixed(0);
        }

        final plc = double.tryParse(plcCtrl.text) ?? 0.0;
        final frc = double.tryParse(frcCtrl.text) ?? 0.0;
        final dev = double.tryParse(devChargesCtrl.text) ?? 0.0;
        final gst = double.tryParse(gstCtrl.text) ?? 0.0;
        final stampDuty = double.tryParse(stampDutyCtrl.text) ?? 0.0;
        final reg = double.tryParse(regChargesCtrl.text) ?? 0.0;
        final maint = double.tryParse(maintenanceCtrl.text) ?? 0.0;
        final other = double.tryParse(otherChargesCtrl.text) ?? 0.0;

        grandTotal = bPrice + plc + frc + dev + gst + stampDuty + reg + maint + other;
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // Initial calculation
          if (grandTotal == 0.0) {
            recalculate(setModalState);
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Bar
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC5A059).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.request_quote_rounded, color: Color(0xFFC5A059), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isRevision ? 'Generate Revised Proposal' : 'Generate Customer Quotation',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Sales Executive can customize any values, set expiry date, and finalize the proposal.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Scrollable Body
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // SECTION 1: Client Details
                          _buildSectionHeader('1. Client Details (Editable)'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: nameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Client Full Name *',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: phoneCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Mobile Number *',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: emailCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Email Address',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: addressCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Address / City',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // SECTION 2: Unit Details
                          _buildSectionHeader('2. Unit & Property Details (Editable)'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: projectCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Project Name',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: towerCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Tower / Wing',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: unitNoCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Unit Number *',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: unitTypeCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Unit Type (e.g. 3 BHK)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: carpetAreaCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Carpet Area (sq.ft)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => recalculate(setModalState),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: superBuiltUpCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Super Built-Up Area (sq.ft)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => recalculate(setModalState),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // SECTION 3: Financials & Taxes
                          _buildSectionHeader('3. Financial Breakdown & Taxes (Editable)'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: baseRateCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Base Rate (₹ / sq.ft)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => recalculate(setModalState),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: basePriceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Base Price (₹)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => recalculate(setModalState),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: plcCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'PLC (₹)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => recalculate(setModalState),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: frcCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Floor Rise Charge (FRC) (₹)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => recalculate(setModalState),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: devChargesCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Dev. & Club Charges (₹)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => recalculate(setModalState),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: gstCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: gstPercent > 0
                                        ? 'GST (${gstPercent.toStringAsFixed(0)}%) (₹)'
                                        : 'GST (₹)',
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => recalculate(setModalState),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: stampDutyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: stampDutyPercent > 0
                                        ? 'Stamp Duty (${stampDutyPercent.toStringAsFixed(1)}%) (₹)'
                                        : 'Stamp Duty (₹)',
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => recalculate(setModalState),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: regChargesCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Registration Fees (₹)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => recalculate(setModalState),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: maintenanceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Adv. Maintenance (₹)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => recalculate(setModalState),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: otherChargesCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Legal & Doc Charges (₹)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => recalculate(setModalState),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Net Grand Total Display
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Net Grand Total / Payable:',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '₹ ${NumberFormat("#,##,###").format(grandTotal)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // SECTION 4: Description & Disclaimer
                          _buildSectionHeader('4. Property Description & Disclaimers'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: descriptionCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Property / Unit Description',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: disclaimerCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Disclaimer & Terms',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // SECTION 5: Proposal Expiry Date
                          _buildSectionHeader('5. Proposal Validity & Expiry Date *'),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: expiryDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setModalState(() => expiryDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.event_available_rounded, color: Color(0xFFC5A059)),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Valid Until: ${DateFormat("dd MMMM yyyy").format(expiryDate)}',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const Icon(Icons.calendar_month_rounded, size: 20),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Validity Line Highlight Box
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC5A059).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFC5A059).withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_outlined, color: Color(0xFFB45309)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'This proposal is valid till ${DateFormat("dd MMMM yyyy").format(expiryDate)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Divider(height: 24),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Generate & Send Proposal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC5A059),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: () {
                          final proposalId = 'PROP-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
                          final rev = isRevision ? lead.proposals.length + 1 : 1;

                          final proposal = CrmProposal(
                            id: proposalId,
                            leadId: lead.id,
                            revision: rev,
                            status: 'ACTIVE',
                            createdAt: DateTime.now(),
                            expiryDate: expiryDate,
                            clientName: nameCtrl.text.trim(),
                            clientPhone: phoneCtrl.text.trim(),
                            clientEmail: emailCtrl.text.trim(),
                            clientAddress: addressCtrl.text.trim(),
                            projectId: projectCtrl.text.trim(),
                            projectName: projectCtrl.text.trim(),
                            towerId: towerCtrl.text.trim(),
                            towerName: towerCtrl.text.trim(),
                            unitId: unitNoCtrl.text.trim(),
                            unitNo: unitNoCtrl.text.trim(),
                            unitType: unitTypeCtrl.text.trim(),
                            floorNo: int.tryParse(unitNoCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '')) ?? 1,
                            carpetArea: double.tryParse(carpetAreaCtrl.text) ?? carpetAreaVal,
                            superBuiltUp: double.tryParse(superBuiltUpCtrl.text) ?? superBuiltUpVal,
                            baseRate: double.tryParse(baseRateCtrl.text) ?? baseRateVal,
                            basePrice: double.tryParse(basePriceCtrl.text) ?? 0.0,
                            plc: double.tryParse(plcCtrl.text) ?? 0.0,
                            frc: double.tryParse(frcCtrl.text) ?? 0.0,
                            developmentCharges: double.tryParse(devChargesCtrl.text) ?? 0.0,
                            parkingCharges: 0.0,
                            maintenanceCharges: double.tryParse(maintenanceCtrl.text) ?? 0.0,
                            gstPercentage: gstPercent,
                            gstAmount: double.tryParse(gstCtrl.text) ?? 0.0,
                            stampDutyPercentage: stampDutyPercent,
                            stampDutyAmount: double.tryParse(stampDutyCtrl.text) ?? 0.0,
                            registrationCharges: double.tryParse(regChargesCtrl.text) ?? 0.0,
                            otherChargesAmount: double.tryParse(otherChargesCtrl.text) ?? 0.0,
                            discountAmount: 0.0,
                            grandTotal: grandTotal,
                            description: descriptionCtrl.text.trim(),
                            disclaimer: disclaimerCtrl.text.trim(),
                            createdById: currentUserId,
                            createdByName: currentUserName,
                          );

                          // Activity log
                          final newLog = CrmCustomerLog(
                            id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
                            title: 'Proposal Generated: $proposalId (Rev $rev)',
                            description:
                                'Proposal for Unit ${proposal.unitNo} generated by $currentUserName. Total: ₹ ${NumberFormat("#,##,###").format(grandTotal)}. Valid till ${DateFormat("dd MMM yyyy").format(expiryDate)}.',
                            type: 'PROPOSAL_GENERATED',
                            timestamp: DateTime.now(),
                            performedByName: currentUserName,
                            performedById: currentUserId,
                          );

                          final existingProposals = lead.proposals.map((p) => p.toJson()).toList();
                          final updatedProposals = [proposal.toJson(), ...existingProposals];

                          final updatedLogs = [
                            newLog.toJson(),
                            ...lead.activityLogs.map((l) => l.toJson()),
                          ];

                          final updatedCustomFields = {
                            ...lead.customFields,
                            'proposals': updatedProposals,
                            'activityLogs': updatedLogs,
                            'Email': emailCtrl.text.trim(),
                            'Address': addressCtrl.text.trim(),
                            'unitShown': {
                              'projectName': projectCtrl.text.trim(),
                              'towerName': towerCtrl.text.trim(),
                              'unitNo': unitNoCtrl.text.trim(),
                              'unitType': unitTypeCtrl.text.trim(),
                              'carpetArea': carpetAreaCtrl.text.trim(),
                              'superBuiltUp': superBuiltUpCtrl.text.trim(),
                              'baseRate': baseRateCtrl.text.trim(),
                              'plc': double.tryParse(plcCtrl.text) ?? 0.0,
                              'frc': double.tryParse(frcCtrl.text) ?? 0.0,
                              'developmentCharge': double.tryParse(devChargesCtrl.text) ?? 0.0,
                              'totalValue': grandTotal.toString(),
                              'remarks': descriptionCtrl.text.trim(),
                            },
                          };

                          Navigator.pop(dialogCtx);

                          // Save lead with PROPOSAL_SENT status
                          context.read<CrmLeadsBloc>().add(
                                CrmLeadsLeadUpdated(lead.id, {
                                  'name': nameCtrl.text.trim(),
                                  'phone': phoneCtrl.text.trim(),
                                  'status': 'PROPOSAL_SENT',
                                  'customFields': updatedCustomFields,
                                }),
                              );

                          // Switch to Quotations Tab
                          _tabController.animateTo(1);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // MODAL 3: Customer Details & Full Activity Logs (Audit Timeline)
  // ===========================================================================
  void _showCustomerDetailsAndLogsModal(BuildContext context, CrmLead lead) {
    final noteCtrl = TextEditingController();
    String newLogType = 'FOLLOW_UP';
    DateTime selectedFollowUpDate = lead.latestFollowUp?.scheduledDate != null
        ? lead.latestFollowUp!.scheduledDate.toLocal()
        : DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedFollowUpTime = const TimeOfDay(hour: 11, minute: 0);
    if (lead.latestFollowUp?.scheduledTime != null) {
      final parts = lead.latestFollowUp!.scheduledTime.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 11;
        final m = int.tryParse(parts[1].split(' ').first) ?? 0;
        selectedFollowUpTime = TimeOfDay(hour: h, minute: m);
      }
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final allLogs = <CrmCustomerLog>[...lead.activityLogs];

          // Also merge any call logs & follow-ups into view
          if (lead.latestFollowUp != null &&
              !allLogs.any((l) => l.description.contains(lead.latestFollowUp!.remarks ?? 'Follow-up'))) {
            allLogs.add(CrmCustomerLog(
              id: lead.latestFollowUp!.id,
              title: 'Scheduled Follow-up',
              description:
                  'Follow-up scheduled for ${DateFormat("dd MMM yyyy").format(lead.latestFollowUp!.scheduledDate.toLocal())} at ${lead.latestFollowUp!.scheduledTime}. Remarks: ${lead.latestFollowUp!.remarks ?? "None"}',
              type: 'FOLLOW_UP',
              timestamp: lead.latestFollowUp!.createdAt,
              performedByName: lead.latestFollowUp!.assignedToName,
            ));
          }

          if (lead.scheduledVisitAt != null && !allLogs.any((l) => l.type == 'VISIT_SCHEDULED')) {
            allLogs.add(CrmCustomerLog(
              id: 'visit_${lead.id}',
              title: 'Site Visit Scheduled',
              description:
                  'Site visit scheduled for ${DateFormat("dd MMM yyyy hh:mm a").format(lead.scheduledVisitAt!)} by telecaller ${lead.telecallerName ?? "Staff"}',
              type: 'VISIT_SCHEDULED',
              timestamp: lead.scheduledVisitAt!,
              performedByName: lead.telecallerName,
            ));
          }

          if (lead.visitedAt != null && !allLogs.any((l) => l.type == 'VISIT_DONE')) {
            allLogs.add(CrmCustomerLog(
              id: 'visited_${lead.id}',
              title: 'Site Visit Done & Manager Appointed',
              description:
                  'Site visit successfully completed. ${lead.assignedToName ?? "Sales Executive"} appointed as Sales Manager.',
              type: 'VISIT_DONE',
              timestamp: lead.visitedAt!,
              performedByName: lead.assignedToName,
            ));
          }

          allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_edu_rounded, color: Color(0xFF2563EB), size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Customer Logs & History: ${lead.name}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Phone: ${lead.phone} • Status: ${lead.status.displayName}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Customer Overview
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        Text('👤 Manager: ${lead.assignedToName ?? "Unassigned"}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('📞 Telecaller: ${lead.telecallerName ?? "Direct / Reception"}',
                            style: const TextStyle(fontSize: 13)),
                        if (lead.unitShown != null)
                          Text('🏢 Unit Shown: ${lead.unitShown!['unitNo']}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.green)),
                        Text('🏷️ Source: ${lead.leadSource ?? "Website"}', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Add New Interaction Form
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Add Interaction Log / Follow-up',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        if (newLogType == 'FOLLOW_UP') ...[
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: selectedFollowUpDate,
                                      firstDate: DateTime.now().subtract(const Duration(days: 14)),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setModalState(() => selectedFollowUpDate = picked);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Date: ${DateFormat("dd MMM yyyy").format(selectedFollowUpDate)}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                        const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFFEA580C)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: selectedFollowUpTime,
                                    );
                                    if (picked != null) {
                                      setModalState(() => selectedFollowUpTime = picked);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Time: ${selectedFollowUpTime.format(context)}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                        const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFFEA580C)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            DropdownButton<String>(
                              value: newLogType,
                              isDense: true,
                              items: const [
                                DropdownMenuItem(value: 'FOLLOW_UP', child: Text('Follow-up Call')),
                                DropdownMenuItem(value: 'VISIT_DONE', child: Text('Site Visit Done')),
                                DropdownMenuItem(value: 'NOTE', child: Text('General Note')),
                              ],
                              onChanged: (v) {
                                if (v != null) setModalState(() => newLogType = v);
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: noteCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Enter notes, client feedback, or outcome...',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                if (noteCtrl.text.trim().isEmpty) return;
                                final authState = context.read<AuthBloc>().state;
                                final currentUserName = authState.user?.name ?? 'Sales Manager';
                                final currentUserId = authState.user?.employeeId;

                                final isFollowUp = newLogType == 'FOLLOW_UP';
                                final dateIso = selectedFollowUpDate.toIso8601String().split('T').first;
                                final timeFormatted = selectedFollowUpTime.format(context);

                                final log = CrmCustomerLog(
                                  id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
                                  title: newLogType == 'VISIT_DONE'
                                      ? 'Site Visit Completed'
                                      : isFollowUp
                                          ? 'Follow-up Scheduled'
                                          : 'Interaction Note',
                                  description: isFollowUp
                                      ? 'Follow-up scheduled for ${DateFormat("dd MMM yyyy").format(selectedFollowUpDate)} at $timeFormatted. Remarks: ${noteCtrl.text.trim()}'
                                      : noteCtrl.text.trim(),
                                  type: newLogType,
                                  timestamp: DateTime.now(),
                                  performedByName: currentUserName,
                                  performedById: currentUserId,
                                );

                                final updatedLogs = [
                                  log.toJson(),
                                  ...lead.activityLogs.map((l) => l.toJson()),
                                ];

                                final updatedCustomFields = {
                                  ...lead.customFields,
                                  'activityLogs': updatedLogs,
                                };

                                if (isFollowUp) {
                                  context.read<CrmLeadsBloc>().add(
                                        CrmLeadsLeadStatusUpdated(
                                          lead.id,
                                          status: 'FOLLOW_UP',
                                          scheduledDate: dateIso,
                                          scheduledTime: timeFormatted,
                                          remarks: noteCtrl.text.trim(),
                                        ),
                                      );
                                }

                                context.read<CrmLeadsBloc>().add(
                                      CrmLeadsLeadUpdated(lead.id, {
                                        'customFields': updatedCustomFields,
                                        if (newLogType == 'VISIT_DONE') 'status': 'SITE_VISIT_DONE',
                                      }),
                                    );

                                noteCtrl.clear();
                                setModalState(() {});
                              },
                              child: const Text('Add Log'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Activity Timeline & Audit Trail',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),

                  // Timeline List
                  Expanded(
                    child: allLogs.isEmpty
                        ? const Center(child: Text('No interaction history logged yet.'))
                        : ListView.separated(
                            itemCount: allLogs.length,
                            separatorBuilder: (_, __) => const Divider(height: 16),
                            itemBuilder: (ctx, i) {
                              final log = allLogs[i];
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLogIcon(log.type),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              log.title,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            Text(
                                              DateFormat('dd MMM yyyy, hh:mm a').format(log.timestamp),
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(log.description, style: const TextStyle(fontSize: 12)),
                                        if (log.performedByName != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'By: ${log.performedByName}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status Change Helper & Status-Specific Modals
  // ---------------------------------------------------------------------------
  void _handleQuickStatusChange(BuildContext context, CrmLead lead, String newStatus) {
    if (newStatus == 'CNR') {
      _showCnrModal(context, lead);
      return;
    }
    if (newStatus == 'FOLLOW_UP') {
      _showFollowUpSchedulingModal(context, lead);
      return;
    }
    if (newStatus == 'SCHEDULED_VISIT') {
      _showScheduleVisitModal(context, lead);
      return;
    }
    if (newStatus == 'SITE_VISIT_DONE') {
      _showVisitDoneModal(context, lead);
      return;
    }
    if (newStatus == 'NOT_INTERESTED') {
      _showNotInterestedModal(context, lead);
      return;
    }
    if (newStatus == 'INTERESTED') {
      _showInterestedModal(context, lead);
      return;
    }

    final authState = context.read<AuthBloc>().state;
    final currentUserName = authState.user?.name ?? 'Sales Manager';
    final currentUserId = authState.user?.employeeId;

    final log = CrmCustomerLog(
      id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Status Updated to $newStatus',
      description: 'Status changed to $newStatus by $currentUserName',
      type: 'STATUS_CHANGE',
      timestamp: DateTime.now(),
      performedByName: currentUserName,
      performedById: currentUserId,
    );

    final updatedLogs = [
      log.toJson(),
      ...lead.activityLogs.map((l) => l.toJson()),
    ];

    final updatedCustomFields = {
      ...lead.customFields,
      'activityLogs': updatedLogs,
    };

    final Map<String, dynamic> updatePayload = {
      'status': newStatus,
      'customFields': updatedCustomFields,
    };

    context.read<CrmLeadsBloc>().add(
          CrmLeadsLeadUpdated(lead.id, updatePayload),
        );
  }

  void _showCnrModal(BuildContext context, CrmLead lead) {
    final tomorrow = DateTime.now().add(const Duration(hours: 24));
    DateTime selectedDate = tomorrow;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(tomorrow);
    final remarkController = TextEditingController(text: 'CNR - Call Not Received. Auto rescheduled after 24 hours.');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
            final timeStr = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_missed_rounded, color: Color(0xFFF59E0B), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'CNR — Auto Reschedule',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Call Not Received: Auto-rescheduled for +24 hours.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.amber.shade200 : const Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Client: ${lead.name.isNotEmpty ? lead.name : "Unnamed"} • ${lead.phone}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Rescheduled Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setModalState(() => selectedDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(10),
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.04),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 10),
                              Text(
                                DateFormat('dd MMM yyyy (EEE)').format(selectedDate),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              const Text('Change', style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Rescheduled Time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setModalState(() => selectedTime = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(10),
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.04),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 10),
                              Text(
                                selectedTime.format(ctx),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              const Text('Change', style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Remarks (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: remarkController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Add remark for this reschedule...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final remarks = remarkController.text.trim().isNotEmpty
                        ? remarkController.text.trim()
                        : 'CNR - Call Not Received. Auto rescheduled after 24 hours.';
                    Navigator.pop(dialogCtx);
                    context.read<CrmLeadsBloc>().add(
                          CrmLeadsLeadStatusUpdated(
                            lead.id,
                            status: 'CNR',
                            scheduledDate: dateStr,
                            scheduledTime: timeStr,
                            remarks: remarks,
                          ),
                        );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('CNR: Rescheduled to $dateStr at $timeStr'),
                        backgroundColor: const Color(0xFFF59E0B),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Confirm Reschedule'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showScheduleVisitModal(BuildContext context, CrmLead lead) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    DateTime selectedDate = tomorrow;
    TimeOfDay selectedTime = const TimeOfDay(hour: 11, minute: 0);
    final remarkController = TextEditingController(text: 'Visit scheduled.');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
            final timeStr = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
            final visitDateTime = DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
              selectedTime.hour,
              selectedTime.minute,
            );

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Schedule Visit',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Client: ${lead.name.isNotEmpty ? lead.name : "Unnamed"} • ${lead.phone}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select the appointment date & time for the visit.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.blue.shade200 : const Color(0xFF1D4ED8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Visit Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setModalState(() => selectedDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(10),
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.04),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF2563EB)),
                              const SizedBox(width: 10),
                              Text(
                                DateFormat('dd MMM yyyy (EEE)').format(selectedDate),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              const Text('Change', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Visit Time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setModalState(() => selectedTime = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(10),
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.04),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF2563EB)),
                              const SizedBox(width: 10),
                              Text(
                                selectedTime.format(ctx),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              const Text('Change', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Remarks (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: remarkController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'e.g. Branch visit / Site meeting...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final remarks = remarkController.text.trim().isNotEmpty
                        ? remarkController.text.trim()
                        : 'Visit scheduled.';
                    Navigator.pop(dialogCtx);
                    context.read<CrmLeadsBloc>().add(
                          CrmLeadsLeadStatusUpdated(
                            lead.id,
                            status: 'SCHEDULED_VISIT',
                            scheduledDate: dateStr,
                            scheduledTime: timeStr,
                            scheduledVisitAt: visitDateTime.toIso8601String(),
                            remarks: remarks,
                          ),
                        );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Visit Scheduled for $dateStr at $timeStr'),
                        backgroundColor: const Color(0xFF2563EB),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Schedule Visit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showVisitDoneModal(BuildContext context, CrmLead lead) {
    final now = DateTime.now();
    final formattedTime = DateFormat('dd MMM yyyy, hh:mm a').format(now);
    final remarkController = TextEditingController(text: 'Visit completed at $formattedTime');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Mark Visit Done',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF047857)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Auto-fetched System Date & Time',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.green.shade200 : const Color(0xFF047857),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formattedTime,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Client: ${lead.name.isNotEmpty ? lead.name : "Unnamed"} • ${lead.phone}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Remarks (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: remarkController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Add remarks about the completed visit...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                final remarks = remarkController.text.trim().isNotEmpty
                    ? remarkController.text.trim()
                    : 'Visit completed at $formattedTime';

                context.read<CrmLeadsBloc>().add(
                      CrmLeadsLeadStatusUpdated(
                        lead.id,
                        status: 'SITE_VISIT_DONE',
                        remarks: remarks,
                      ),
                    );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Visit Done recorded at $formattedTime'),
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Confirm Visit Done'),
            ),
          ],
        );
      },
    );
  }

  void _showNotInterestedModal(BuildContext context, CrmLead lead) {
    final settings = context.read<CrmLeadsBloc>().state.settings;
    final configuredReasons = settings?.notInterestedReasons ?? [];
    final reasons = configuredReasons.isNotEmpty
        ? configuredReasons
        : [
            'Budget mismatch',
            'Found somewhere else',
            'Locality mismatch',
            'Rate of Interest high',
            'Loan eligibility low',
            'Others',
          ];

    String selectedReason = reasons.contains('Budget mismatch') ? 'Budget mismatch' : reasons.first;
    final remarkController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isOthers = selectedReason.trim().toLowerCase() == 'others';
            final isDark = Theme.of(ctx).brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.thumb_down_alt_rounded, color: Color(0xFFEF4444), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Mark as Not Interested',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Client: ${lead.name.isNotEmpty ? lead.name : "Unnamed"} • ${lead.phone}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Select Reason *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedReason,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: reasons.map((r) {
                          return DropdownMenuItem<String>(
                            value: r,
                            child: Text(r, style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedReason = val);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        isOthers ? 'Remarks (Required for "Others") *' : 'Remarks (Optional)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: remarkController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: isOthers ? 'Specify specific reason...' : 'Add remarks...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final remark = remarkController.text.trim();
                    if (isOthers && remark.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter remarks for "Others"')),
                      );
                      return;
                    }
                    Navigator.pop(dialogCtx);
                    context.read<CrmLeadsBloc>().add(
                          CrmLeadsLeadStatusUpdated(
                            lead.id,
                            status: 'NOT_INTERESTED',
                            notInterestedReason: selectedReason,
                            notInterestedRemark: remark.isNotEmpty ? remark : null,
                          ),
                        );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Lead marked as Not Interested'),
                        backgroundColor: Color(0xFFEF4444),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Confirm Not Interested'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showInterestedModal(BuildContext context, CrmLead lead) {
    final remarkCtrl = TextEditingController(text: 'Client expressed high interest.');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded, color: Color(0xFF10B981), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Mark as Interested',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Client: ${lead.name.isNotEmpty ? lead.name : "Unnamed"} • ${lead.phone}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lead status will be updated to Interested. Full customer intake details will be configured.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.green.shade200 : const Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Notes / Remarks (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: remarkCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. Interested in loan closure...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                final remarks = remarkCtrl.text.trim();
                context.read<CrmLeadsBloc>().add(
                      CrmLeadsLeadStatusUpdated(
                        lead.id,
                        status: 'INTERESTED',
                        remarks: remarks.isNotEmpty ? remarks : null,
                      ),
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lead marked as Interested'),
                    backgroundColor: Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                final crmRepo = context.read<CrmRepository>();
                if (lead.scope == 'NB_FINSERVE' || crmRepo.scope == 'NB_FINSERVE') {
                  Future.delayed(const Duration(milliseconds: 250), () {
                    if (context.mounted) {
                      _showFinserveApplicationModal(context, lead);
                    }
                  });
                }
              },
              child: const Text('Confirm Interested'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // UI Helper Badges & Metrics
  // ---------------------------------------------------------------------------
  Widget _buildStatusDropdown(BuildContext context, CrmLead lead, bool isDark) {
    Color badgeBg;
    Color badgeFg;
    Color badgeBorder;

    switch (lead.status) {
      case CrmStatus.notStarted:
        badgeBg = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9);
        badgeFg = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569);
        badgeBorder = isDark ? Colors.white.withValues(alpha: 0.20) : const Color(0xFFCBD5E1);
        break;
      case CrmStatus.assigned:
        badgeBg = const Color(0xFF6366F1).withValues(alpha: isDark ? 0.22 : 0.12);
        badgeFg = isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
        badgeBorder = const Color(0xFF6366F1).withValues(alpha: isDark ? 0.45 : 0.35);
        break;
      case CrmStatus.cnr:
        badgeBg = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.22 : 0.12);
        badgeFg = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
        badgeBorder = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.45 : 0.35);
        break;
      case CrmStatus.followUp:
        badgeBg = const Color(0xFFEA580C).withValues(alpha: isDark ? 0.22 : 0.12);
        badgeFg = isDark ? const Color(0xFFFB923C) : const Color(0xFFC2410C);
        badgeBorder = const Color(0xFFEA580C).withValues(alpha: isDark ? 0.45 : 0.35);
        break;
      case CrmStatus.scheduledVisit:
        badgeBg = const Color(0xFF2563EB).withValues(alpha: isDark ? 0.22 : 0.12);
        badgeFg = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);
        badgeBorder = const Color(0xFF2563EB).withValues(alpha: isDark ? 0.45 : 0.35);
        break;
      case CrmStatus.siteVisitDone:
        badgeBg = const Color(0xFF10B981).withValues(alpha: isDark ? 0.22 : 0.12);
        badgeFg = isDark ? const Color(0xFF34D399) : const Color(0xFF047857);
        badgeBorder = const Color(0xFF10B981).withValues(alpha: isDark ? 0.45 : 0.35);
        break;
      case CrmStatus.notInterested:
      case CrmStatus.rejected:
        badgeBg = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.22 : 0.12);
        badgeFg = isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
        badgeBorder = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.45 : 0.35);
        break;
      case CrmStatus.interested:
      case CrmStatus.bookingConfirmed:
        badgeBg = const Color(0xFF16A34A).withValues(alpha: isDark ? 0.22 : 0.12);
        badgeFg = isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
        badgeBorder = const Color(0xFF16A34A).withValues(alpha: isDark ? 0.45 : 0.35);
        break;
      case CrmStatus.proposalSent:
        badgeBg = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.22 : 0.12);
        badgeFg = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
        badgeBorder = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.45 : 0.35);
        break;
    }

    final dropdownItems = <CrmStatus>[
      CrmStatus.cnr,
      CrmStatus.followUp,
      CrmStatus.scheduledVisit,
      CrmStatus.siteVisitDone,
      CrmStatus.notInterested,
      CrmStatus.interested,
    ];
    if (!dropdownItems.contains(lead.status)) {
      dropdownItems.insert(0, lead.status);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeBorder, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CrmStatus>(
          value: lead.status,
          isDense: true,
          dropdownColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          icon: Icon(Icons.arrow_drop_down_rounded, size: 18, color: badgeFg),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: badgeFg),
          selectedItemBuilder: (BuildContext ctx) {
            return dropdownItems.map((s) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  s.displayName,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: badgeFg),
                ),
              );
            }).toList();
          },
          items: dropdownItems.map((s) {
            Color dotColor;
            switch (s) {
              case CrmStatus.notStarted:
                dotColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
                break;
              case CrmStatus.assigned:
                dotColor = const Color(0xFF6366F1);
                break;
              case CrmStatus.cnr:
                dotColor = const Color(0xFFF59E0B);
                break;
              case CrmStatus.followUp:
                dotColor = isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C);
                break;
              case CrmStatus.scheduledVisit:
                dotColor = const Color(0xFF2563EB);
                break;
              case CrmStatus.siteVisitDone:
                dotColor = const Color(0xFF10B981);
                break;
              case CrmStatus.notInterested:
              case CrmStatus.rejected:
                dotColor = const Color(0xFFEF4444);
                break;
              case CrmStatus.interested:
              case CrmStatus.bookingConfirmed:
                dotColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
                break;
              case CrmStatus.proposalSent:
                dotColor = const Color(0xFFF59E0B);
                break;
            }
            return DropdownMenuItem<CrmStatus>(
              value: s,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    s.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (newStatus) {
            if (newStatus == null || newStatus == lead.status) return;
            _handleQuickStatusChange(context, lead, newStatus.backendValue);
          },
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
  }) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildLogIcon(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'CALL':
        icon = Icons.call_rounded;
        color = Colors.blue;
        break;
      case 'VISIT_SCHEDULED':
        icon = Icons.calendar_today_rounded;
        color = Colors.indigo;
        break;
      case 'VISIT_DONE':
        icon = Icons.verified_rounded;
        color = Colors.green;
        break;
      case 'SALES_MANAGER_APPOINTED':
        icon = Icons.badge_rounded;
        color = Colors.purple;
        break;
      case 'UNIT_SHOWN':
        icon = Icons.apartment_rounded;
        color = Colors.teal;
        break;
      case 'PROPOSAL_GENERATED':
        icon = Icons.request_quote_rounded;
        color = const Color(0xFFC5A059);
        break;
      case 'STATUS_CHANGE':
        icon = Icons.sync_alt_rounded;
        color = Colors.orange;
        break;
      case 'FOLLOW_UP':
        icon = Icons.schedule_rounded;
        color = const Color(0xFFEA580C);
        break;
      default:
        icon = Icons.note_rounded;
        color = Colors.blueGrey;
    }

    return CircleAvatar(
      radius: 16,
      backgroundColor: color.withValues(alpha: 0.12),
      child: Icon(icon, color: color, size: 16),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB)),
    );
  }

  Widget _buildFinserveApplicationsTab(
    BuildContext context,
    List<CrmLead> allLeads,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
    Color primaryColor,
    Color goldColor,
  ) {
    final appLeads = allLeads.where((l) {
      final isInterested = l.status == CrmStatus.interested || l.status.backendValue == 'INTERESTED';
      final hasAppDetails = l.customFields['applicationDetails'] != null;
      final hasPortalToken = l.customFields['portalToken'] != null;
      return isInterested || hasAppDetails || hasPortalToken;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.assignment_turned_in_rounded, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Finserve Loan Applications & Client Intake',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Review collected personal/company/reference details, track required documents, and dispatch Client Portal links.',
                    style: TextStyle(fontSize: 13, color: textMuted),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${appLeads.length} Applications Active',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: appLeads.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.assignment_outlined, size: 56, color: textMuted.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'No active loan applications yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textMuted),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Mark an assigned lead as "Interested" to start the loan intake & document process.',
                          style: TextStyle(fontSize: 13, color: textMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: appLeads.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final lead = appLeads[index];
                      final loanType = lead.customFields['Loan_Type'] ?? lead.customFields['loan_type'] ?? 'Home Loan';
                      final docs = List<dynamic>.from(lead.customFields['documents'] ?? []);
                      final portalLink = _getPortalLink(lead);
                      final requiredDocs = CrmSettings.defaultLoanTypeDocsMap[loanType] ?? CrmSettings.defaultLoanTypeDocsMap['Home Loan'] ?? [];

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: primaryColor.withValues(alpha: 0.15),
                              child: Text(
                                lead.name.isNotEmpty ? lead.name[0].toUpperCase() : 'C',
                                style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        lead.name.isNotEmpty ? lead.name : 'Unnamed Client',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          lead.status.displayName,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                        ),
                                      ),
                                      if (portalLink != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.link_rounded, size: 12, color: Color(0xFF2563EB)),
                                              SizedBox(width: 4),
                                              Text(
                                                'Portal Link Active',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () => _copyPortalLinkDirect(portalLink),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.copy_rounded, size: 11, color: Color(0xFF2563EB)),
                                                SizedBox(width: 3),
                                                Text('Copy', style: TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: () => _shareLeadPortalViaWhatsApp(lead, portalLink),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF25D366).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.4)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.chat_bubble_outline_rounded, size: 11, color: Color(0xFF16A34A)),
                                                SizedBox(width: 3),
                                                Text('WhatsApp', style: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '📞 ${lead.phone} • ✉️ ${lead.email ?? "No Email"} • Product: $loanType',
                                    style: TextStyle(fontSize: 13, color: textMuted),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        'Documents: ${docs.length} of ${requiredDocs.length} Uploaded',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: docs.length >= requiredDocs.length && requiredDocs.isNotEmpty
                                              ? const Color(0xFF10B981)
                                              : (docs.isEmpty ? Colors.amber.shade800 : primaryColor),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        width: 100,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: requiredDocs.isEmpty ? 0 : (docs.length / requiredDocs.length).clamp(0.0, 1.0),
                                            backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                            valueColor: AlwaysStoppedAnimation(
                                              docs.length >= requiredDocs.length && requiredDocs.isNotEmpty
                                                  ? const Color(0xFF10B981)
                                                  : primaryColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
                              label: const Text('Open Application & Docs'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _showFinserveApplicationModal(context, lead),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showFinserveApplicationModal(BuildContext context, CrmLead lead) {
    final leadsBloc = context.read<CrmLeadsBloc>();
    final crmRepo = context.read<CrmRepository>();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => BlocProvider<CrmLeadsBloc>.value(
        value: leadsBloc,
        child: _FinserveApplicationDialog(
          lead: lead,
          crmRepository: crmRepo,
          leadsBloc: leadsBloc,
        ),
      ),
    );
  }

  String? _getPortalLink(CrmLead lead) {
    String? link = lead.customFields['portalLink']?.toString();
    final token = lead.customFields['portalToken']?.toString();
    final origin = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api/?$'), '');
    if (link != null && link.isNotEmpty) {
      if (link.contains('localhost:5000')) {
        return link.replaceAll('localhost:5000', 'localhost:4000');
      }
      return link;
    }
    if (token != null && token.isNotEmpty) {
      return '$origin/client-portal?token=$token';
    }
    return null;
  }

  void _copyPortalLinkDirect(String link) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Client Portal link copied to clipboard!'),
        backgroundColor: Color(0xFF2563EB),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareLeadPortalViaWhatsApp(CrmLead lead, String link) async {
    final cleanPhone = lead.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final pPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
    final clientName = lead.name.isNotEmpty ? lead.name : 'Customer';
    final loanType = lead.customFields['Loan_Type']?.toString() ??
        lead.customFields['loan_type']?.toString() ??
        'Loan';
    final message = 'Hello $clientName,\n\n'
        'Greetings from NB Finserve!\n\n'
        'Please verify and submit your documents for your $loanType application using our secure Client Portal link:\n'
        '$link\n\n'
        '🔐 To access, enter your registered mobile number (${lead.phone}) and verify with the 6-digit OTP sent to your email.\n\n'
        'Thank you,\nNB Finserve Team';

    final uri = Uri.parse('https://wa.me/$pPhone?text=${Uri.encodeComponent(message)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open WhatsApp: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// =============================================================================
// Client Proposals Group Card with Dropdown (Tab 2 Component)
// =============================================================================
class _ClientProposalsGroupCard extends StatefulWidget {
  final CrmLead lead;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Color textMuted;
  final Color primaryColor;
  final Color goldColor;
  final VoidCallback onProposalUpdated;
  final VoidCallback onGenerateNewProposal;

  const _ClientProposalsGroupCard({
    super.key,
    required this.lead,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.textMuted,
    required this.primaryColor,
    required this.goldColor,
    required this.onProposalUpdated,
    required this.onGenerateNewProposal,
  });

  @override
  State<_ClientProposalsGroupCard> createState() => _ClientProposalsGroupCardState();
}

class _ClientProposalsGroupCardState extends State<_ClientProposalsGroupCard> {
  late String _selectedProposalId;

  @override
  void initState() {
    super.initState();
    _selectedProposalId = widget.lead.proposals.isNotEmpty ? widget.lead.proposals.first.id : '';
  }

  @override
  void didUpdateWidget(covariant _ClientProposalsGroupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.lead.proposals.any((p) => p.id == _selectedProposalId)) {
      if (widget.lead.proposals.isNotEmpty) {
        _selectedProposalId = widget.lead.proposals.first.id;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final proposals = widget.lead.proposals;
    if (proposals.isEmpty) return const SizedBox.shrink();

    final selectedProposal = proposals.firstWhere(
      (p) => p.id == _selectedProposalId,
      orElse: () => proposals.first,
    );

    final isExpired = selectedProposal.isExpired;
    final isRejected = selectedProposal.isRejected;
    final isBooked = selectedProposal.isBooked;

    return Container(
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Client Name, Contact, and Proposals Dropdown Selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: widget.goldColor.withValues(alpha: 0.15),
                  child: Text(
                    widget.lead.name.isNotEmpty ? widget.lead.name[0].toUpperCase() : 'C',
                    style: TextStyle(fontWeight: FontWeight.bold, color: widget.goldColor, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.lead.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.lead.phone} • ${widget.lead.email ?? "No Email"}',
                        style: TextStyle(fontSize: 12, color: widget.textMuted),
                      ),
                    ],
                  ),
                ),
                // DROPDOWN for all proposals of this client
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: widget.borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedProposalId,
                      isDense: true,
                      items: proposals.map((p) {
                        return DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(
                            'Proposal #${p.id} (Rev ${p.revision}) — Unit ${p.unitNo} [${p.displayStatus}]',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (newId) {
                        if (newId != null) {
                          setState(() => _selectedProposalId = newId);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Button to Generate New Proposal for this same client
                IconButton(
                  tooltip: 'Generate Another Proposal for this Client',
                  icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFC5A059)),
                  onPressed: widget.onGenerateNewProposal,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Selected Proposal Details Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Proposal Status Banner
                Row(
                  children: [
                    _buildProposalStatusBadge(selectedProposal),
                    const SizedBox(width: 12),
                    Text(
                      'Generated: ${DateFormat("dd MMM yyyy, hh:mm a").format(selectedProposal.createdAt)}',
                      style: TextStyle(fontSize: 12, color: widget.textMuted),
                    ),
                    const Spacer(),
                    Text(
                      'By: ${selectedProposal.createdByName ?? "Sales Exec"}',
                      style: TextStyle(fontSize: 12, color: widget.textMuted, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Unit & Price Grid
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: widget.borderColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Unit #${selectedProposal.unitNo} (${selectedProposal.projectName} - ${selectedProposal.towerName})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${selectedProposal.unitType} • Floor ${selectedProposal.floorNo} • Carpet: ${selectedProposal.carpetArea} sq.ft (Super Built-Up: ${selectedProposal.superBuiltUp} sq.ft)',
                                style: TextStyle(fontSize: 12, color: widget.textMuted),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Total Value', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                '₹ ${NumberFormat("#,##,###").format(selectedProposal.grandTotal)}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      // Breakdown chips - only unit config amounts
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          _statItem('Base Rate', '₹ ${selectedProposal.baseRate.toStringAsFixed(0)}/sq.ft'),
                          _statItem('Base Price', '₹ ${NumberFormat("#,##,###").format(selectedProposal.basePrice)}'),
                          if (selectedProposal.plc > 0)
                            _statItem('PLC', '₹ ${NumberFormat("#,##,###").format(selectedProposal.plc)}'),
                          if (selectedProposal.frc > 0)
                            _statItem('FRC', '₹ ${NumberFormat("#,##,###").format(selectedProposal.frc)}'),
                          if (selectedProposal.developmentCharges > 0)
                            _statItem('Dev Charges', '₹ ${NumberFormat("#,##,###").format(selectedProposal.developmentCharges)}'),
                          if (selectedProposal.gstAmount > 0)
                            _statItem('GST (${selectedProposal.gstPercentage.toStringAsFixed(0)}%)', '₹ ${NumberFormat("#,##,###").format(selectedProposal.gstAmount)}'),
                          if (selectedProposal.stampDutyAmount > 0)
                            _statItem('Stamp Duty (${selectedProposal.stampDutyPercentage.toStringAsFixed(1)}%)', '₹ ${NumberFormat("#,##,###").format(selectedProposal.stampDutyAmount)}'),
                          if (selectedProposal.registrationCharges > 0)
                            _statItem('Registration', '₹ ${NumberFormat("#,##,###").format(selectedProposal.registrationCharges)}'),
                          if (selectedProposal.maintenanceCharges > 0)
                            _statItem('Maintenance', '₹ ${NumberFormat("#,##,###").format(selectedProposal.maintenanceCharges)}'),
                          if (selectedProposal.otherChargesAmount > 0)
                            _statItem('Other Charges', '₹ ${NumberFormat("#,##,###").format(selectedProposal.otherChargesAmount)}'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Description & Disclaimer
                if (selectedProposal.description.isNotEmpty) ...[
                  Text('Description:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.textMuted)),
                  const SizedBox(height: 2),
                  Text(selectedProposal.description, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                if (selectedProposal.disclaimer.isNotEmpty) ...[
                  Text('Disclaimer & Terms:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.textMuted)),
                  const SizedBox(height: 2),
                  Text(selectedProposal.disclaimer, style: TextStyle(fontSize: 11, color: widget.textMuted)),
                  const SizedBox(height: 12),
                ],

                // Proposal Validity Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isExpired
                        ? Colors.red.withValues(alpha: 0.1)
                        : const Color(0xFFC5A059).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isExpired
                          ? Colors.red.withValues(alpha: 0.3)
                          : const Color(0xFFC5A059).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isExpired ? Icons.alarm_off_rounded : Icons.alarm_on_rounded,
                        color: isExpired ? Colors.red : const Color(0xFFB45309),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isExpired
                              ? 'This proposal has EXPIRED on ${DateFormat("dd MMMM yyyy").format(selectedProposal.expiryDate)}'
                              : 'This proposal is valid till ${DateFormat("dd MMMM yyyy").format(selectedProposal.expiryDate)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isExpired ? Colors.red.shade700 : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Actions: Reject, Confirm Booking, Generate New, Print
                Row(
                  children: [
                    // Direct Print to Paper / PDF
                    ElevatedButton.icon(
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('Print on Paper'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC5A059),
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        elevation: 0,
                      ),
                      onPressed: () {
                        printProposalQuotation(
                          proposal: selectedProposal,
                          onMessage: (msg) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 8),

                    // Preview Modal
                    OutlinedButton.icon(
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('Preview'),
                      onPressed: () => _showQuotationPrintModal(context, selectedProposal),
                    ),
                    const SizedBox(width: 8),

                    // Generate Revised
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                      label: const Text('New Revision'),
                      onPressed: widget.onGenerateNewProposal,
                    ),

                    const Spacer(),

                    // If rejected -> show lifecycle closed note
                    if (isRejected) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Rejected — Lifecycle Done',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ] else if (isBooked) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Booking Confirmed!',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isExpired) ...[
                      // If expired, show status as expired
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Proposal Expired',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ] else ...[
                      // ACTIVE PROPOSAL: Show Reject & Confirm Booking Options
                      TextButton.icon(
                        icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 16),
                        label: const Text('Reject Proposal', style: TextStyle(color: Colors.red)),
                        onPressed: () => _handleRejectProposal(context, selectedProposal),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: const Text('Confirm Booking'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: () => _handleConfirmBooking(context, selectedProposal),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildProposalStatusBadge(CrmProposal proposal) {
    if (proposal.isBooked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('BOOKING CONFIRMED', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
      );
    }
    if (proposal.isRejected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('REJECTED', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
      );
    }
    if (proposal.isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('EXPIRED', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text('PROPOSAL SENT / ACTIVE', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  // Reject Action
  void _handleRejectProposal(BuildContext context, CrmProposal proposal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Reject Proposal'),
          ],
        ),
        content: Text(
          'Are you sure you want to mark Proposal #${proposal.id} as rejected? This will close the lifecycle for this proposal.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);

              final authState = context.read<AuthBloc>().state;
              final currentUserName = authState.user?.name ?? 'Sales Manager';
              final currentUserId = authState.user?.employeeId;

              final updatedProposals = widget.lead.proposals.map((p) {
                if (p.id == proposal.id) {
                  return CrmProposal(
                    id: p.id,
                    leadId: p.leadId,
                    revision: p.revision,
                    status: 'REJECTED',
                    createdAt: p.createdAt,
                    expiryDate: p.expiryDate,
                    clientName: p.clientName,
                    clientPhone: p.clientPhone,
                    clientEmail: p.clientEmail,
                    clientAddress: p.clientAddress,
                    projectId: p.projectId,
                    projectName: p.projectName,
                    towerId: p.towerId,
                    towerName: p.towerName,
                    unitId: p.unitId,
                    unitNo: p.unitNo,
                    unitType: p.unitType,
                    floorNo: p.floorNo,
                    carpetArea: p.carpetArea,
                    superBuiltUp: p.superBuiltUp,
                    baseRate: p.baseRate,
                    basePrice: p.basePrice,
                    plc: p.plc,
                    frc: p.frc,
                    developmentCharges: p.developmentCharges,
                    parkingCharges: 0.0,
                    maintenanceCharges: p.maintenanceCharges,
                    gstPercentage: p.gstPercentage,
                    gstAmount: p.gstAmount,
                    stampDutyPercentage: p.stampDutyPercentage,
                    stampDutyAmount: p.stampDutyAmount,
                    registrationCharges: p.registrationCharges,
                    otherChargesAmount: p.otherChargesAmount,
                    discountAmount: 0.0,
                    grandTotal: p.grandTotal,
                    description: p.description,
                    disclaimer: p.disclaimer,
                    createdById: p.createdById,
                    createdByName: p.createdByName,
                  ).toJson();
                }
                return p.toJson();
              }).toList();

              final log = CrmCustomerLog(
                id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
                title: 'Proposal Rejected: ${proposal.id}',
                description: 'Proposal #${proposal.id} was rejected by customer. Lifecycle closed.',
                type: 'STATUS_CHANGE',
                timestamp: DateTime.now(),
                performedByName: currentUserName,
                performedById: currentUserId,
              );

              final updatedLogs = [
                log.toJson(),
                ...widget.lead.activityLogs.map((l) => l.toJson()),
              ];

              context.read<CrmLeadsBloc>().add(
                    CrmLeadsLeadUpdated(widget.lead.id, {
                      'status': 'REJECTED',
                      'customFields': {
                        ...widget.lead.customFields,
                        'proposals': updatedProposals,
                        'activityLogs': updatedLogs,
                      },
                    }),
                  );

              widget.onProposalUpdated();
            },
            child: const Text('Yes, Reject'),
          ),
        ],
      ),
    );
  }

  // Confirm Booking Action
  void _handleConfirmBooking(BuildContext context, CrmProposal proposal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Text('Confirm Unit Booking'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Confirm booking for Unit #${proposal.unitNo} in ${proposal.projectName}?'),
            const SizedBox(height: 10),
            Text(
              'Customer: ${proposal.clientName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Agreed Value: ₹ ${NumberFormat("#,##,###").format(proposal.grandTotal)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Booking status will be confirmed. You can proceed with the post-booking payment and documentation steps.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);

              final authState = context.read<AuthBloc>().state;
              final currentUserName = authState.user?.name ?? 'Sales Manager';
              final currentUserId = authState.user?.employeeId;

              final updatedProposals = widget.lead.proposals.map((p) {
                if (p.id == proposal.id) {
                  return CrmProposal(
                    id: p.id,
                    leadId: p.leadId,
                    revision: p.revision,
                    status: 'BOOKING_CONFIRMED',
                    createdAt: p.createdAt,
                    expiryDate: p.expiryDate,
                    clientName: p.clientName,
                    clientPhone: p.clientPhone,
                    clientEmail: p.clientEmail,
                    clientAddress: p.clientAddress,
                    projectId: p.projectId,
                    projectName: p.projectName,
                    towerId: p.towerId,
                    towerName: p.towerName,
                    unitId: p.unitId,
                    unitNo: p.unitNo,
                    unitType: p.unitType,
                    floorNo: p.floorNo,
                    carpetArea: p.carpetArea,
                    superBuiltUp: p.superBuiltUp,
                    baseRate: p.baseRate,
                    basePrice: p.basePrice,
                    plc: p.plc,
                    frc: p.frc,
                    developmentCharges: p.developmentCharges,
                    parkingCharges: 0.0,
                    maintenanceCharges: p.maintenanceCharges,
                    gstPercentage: p.gstPercentage,
                    gstAmount: p.gstAmount,
                    stampDutyPercentage: p.stampDutyPercentage,
                    stampDutyAmount: p.stampDutyAmount,
                    registrationCharges: p.registrationCharges,
                    otherChargesAmount: p.otherChargesAmount,
                    discountAmount: 0.0,
                    grandTotal: p.grandTotal,
                    description: p.description,
                    disclaimer: p.disclaimer,
                    createdById: p.createdById,
                    createdByName: p.createdByName,
                  ).toJson();
                }
                return p.toJson();
              }).toList();

              final log = CrmCustomerLog(
                id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
                title: 'Booking Confirmed: Unit ${proposal.unitNo}',
                description:
                    'Booking confirmed for Unit #${proposal.unitNo} (${proposal.projectName}) at ₹ ${NumberFormat("#,##,###").format(proposal.grandTotal)} by $currentUserName.',
                type: 'STATUS_CHANGE',
                timestamp: DateTime.now(),
                performedByName: currentUserName,
                performedById: currentUserId,
              );

              final updatedLogs = [
                log.toJson(),
                ...widget.lead.activityLogs.map((l) => l.toJson()),
              ];

              context.read<CrmLeadsBloc>().add(
                    CrmLeadsLeadUpdated(widget.lead.id, {
                      'status': 'BOOKING_CONFIRMED',
                      'customFields': {
                        ...widget.lead.customFields,
                        'proposals': updatedProposals,
                        'activityLogs': updatedLogs,
                      },
                    }),
                  );

              widget.onProposalUpdated();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Booking Confirmed for Unit #${proposal.unitNo}!'),
                  backgroundColor: const Color(0xFF16A34A),
                ),
              );
            },
            child: const Text('Confirm Booking'),
          ),
        ],
      ),
    );
  }

  // Print / Preview Quotation Modal
  void _showQuotationPrintModal(BuildContext context, CrmProposal proposal) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('NB DEVELOPERS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFC5A059))),
                      Text('Official Property Price Quotation', style: TextStyle(fontSize: 12, color: widget.textMuted)),
                    ],
                  ),
                  Text('Ref: #${proposal.id} (Rev ${proposal.revision})', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Client: ${proposal.clientName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Contact: ${proposal.clientPhone} • ${proposal.clientEmail}'),
                      Text('Address: ${proposal.clientAddress}'),
                      const SizedBox(height: 14),
                      Text('Property: Unit ${proposal.unitNo}, ${proposal.towerName}, ${proposal.projectName}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Type: ${proposal.unitType} • Super Built-Up: ${proposal.superBuiltUp} sq.ft'),
                      const Divider(height: 20),
                      _printRow('Base Rate', '₹ ${proposal.baseRate.toStringAsFixed(0)} / sq.ft'),
                      _printRow('Base Price', '₹ ${NumberFormat("#,##,###").format(proposal.basePrice)}'),
                      if (proposal.plc > 0)
                        _printRow('PLC Charges', '₹ ${NumberFormat("#,##,###").format(proposal.plc)}'),
                      if (proposal.frc > 0)
                        _printRow('Floor Rise (FRC)', '₹ ${NumberFormat("#,##,###").format(proposal.frc)}'),
                      if (proposal.developmentCharges > 0)
                        _printRow('Development Charges', '₹ ${NumberFormat("#,##,###").format(proposal.developmentCharges)}'),
                      if (proposal.gstAmount > 0)
                        _printRow('GST (${proposal.gstPercentage.toStringAsFixed(0)}%)', '₹ ${NumberFormat("#,##,###").format(proposal.gstAmount)}'),
                      if (proposal.stampDutyAmount > 0)
                        _printRow('Stamp Duty (${proposal.stampDutyPercentage.toStringAsFixed(1)}%)', '₹ ${NumberFormat("#,##,###").format(proposal.stampDutyAmount)}'),
                      if (proposal.registrationCharges > 0)
                        _printRow('Registration Charges', '₹ ${NumberFormat("#,##,###").format(proposal.registrationCharges)}'),
                      if (proposal.maintenanceCharges > 0)
                        _printRow('Maintenance Charges', '₹ ${NumberFormat("#,##,###").format(proposal.maintenanceCharges)}'),
                      if (proposal.otherChargesAmount > 0)
                        _printRow('Legal / Other Charges', '₹ ${NumberFormat("#,##,###").format(proposal.otherChargesAmount)}'),
                      const Divider(height: 20),
                      _printRow('Grand Total', '₹ ${NumberFormat("#,##,###").format(proposal.grandTotal)}', isBold: true, isHighlight: true),
                      const SizedBox(height: 16),
                      Text('Description:\n${proposal.description}', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 10),
                      Text('Terms & Conditions:\n${proposal.disclaimer}', style: TextStyle(fontSize: 11, color: widget.textMuted)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC5A059).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            'This proposal is valid till ${DateFormat("dd MMMM yyyy").format(proposal.expiryDate)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFB45309)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Print to Paper / PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC5A059),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    onPressed: () {
                      printProposalQuotation(
                        proposal: proposal,
                        onMessage: (msg) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _printRow(String label, String value, {bool isBold = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isHighlight ? 16 : 13,
              color: isHighlight ? const Color(0xFF16A34A) : null,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MODAL: ERP Projects -> Tower -> Unit Dynamic Selector Dialog
// =============================================================================
class _ErpSelectUnitDialog extends ConsumerStatefulWidget {
  const _ErpSelectUnitDialog({
    required this.lead,
    required this.onSave,
  });

  final CrmLead lead;
  final void Function(Map<String, dynamic> unitData) onSave;

  @override
  ConsumerState<_ErpSelectUnitDialog> createState() => _ErpSelectUnitDialogState();
}

class _ErpSelectUnitDialogState extends ConsumerState<_ErpSelectUnitDialog> {
  bool _isLoadingProjects = true;
  bool _isLoadingTowers = false;
  bool _isLoadingUnits = false;
  String? _loadError;

  List<ErpProject> _projects = [];
  ErpProject? _selectedProject;

  List<ErpProjectTower> _towers = [];
  ErpProjectTower? _selectedTower;

  List<ErpProjectUnit> _units = [];
  ErpProjectUnit? _selectedUnit;

  late final TextEditingController _customUnitCtrl;
  late final TextEditingController _unitTypeCtrl;
  late final TextEditingController _carpetAreaCtrl;
  late final TextEditingController _superBuiltUpCtrl;
  late final TextEditingController _floorNoCtrl;
  late final TextEditingController _baseRateCtrl;
  late final TextEditingController _totalValueCtrl;
  late final TextEditingController _notesCtrl;

  late final TextEditingController _manualProjectCtrl;
  late final TextEditingController _manualTowerCtrl;

  @override
  void initState() {
    super.initState();
    final unitShown = widget.lead.unitShown;
    _manualProjectCtrl = TextEditingController(text: unitShown?['projectName']?.toString() ?? 'NB Heights');
    _manualTowerCtrl = TextEditingController(text: unitShown?['towerName']?.toString() ?? 'Tower A');
    _customUnitCtrl = TextEditingController(text: unitShown?['unitNo']?.toString() ?? '');
    _unitTypeCtrl = TextEditingController(text: unitShown?['unitType']?.toString() ?? '3 BHK Luxury');
    _carpetAreaCtrl = TextEditingController(text: unitShown?['carpetArea']?.toString() ?? '1450');
    _superBuiltUpCtrl = TextEditingController(text: unitShown?['superBuiltUp']?.toString() ?? '1950');
    _floorNoCtrl = TextEditingController(text: unitShown?['floorNo']?.toString() ?? '1');
    _baseRateCtrl = TextEditingController(text: unitShown?['baseRate']?.toString() ?? '6500');
    _totalValueCtrl = TextEditingController(text: unitShown?['totalValue']?.toString() ?? '9500000');
    _notesCtrl = TextEditingController(text: unitShown?['remarks']?.toString() ?? 'Customer physically visited and viewed the unit.');

    _fetchProjects();
  }

  @override
  void dispose() {
    _manualProjectCtrl.dispose();
    _manualTowerCtrl.dispose();
    _customUnitCtrl.dispose();
    _unitTypeCtrl.dispose();
    _carpetAreaCtrl.dispose();
    _superBuiltUpCtrl.dispose();
    _floorNoCtrl.dispose();
    _baseRateCtrl.dispose();
    _totalValueCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchProjects() async {
    setState(() {
      _isLoadingProjects = true;
      _loadError = null;
    });

    try {
      final repo = ref.read(projectRepositoryProvider);
      final list = await repo.list();
      if (!mounted) return;

      setState(() {
        _projects = list;
        _isLoadingProjects = false;
      });

      if (list.isNotEmpty) {
        final prevProjectId = widget.lead.unitShown?['projectId']?.toString();
        final prevProjectName = widget.lead.unitShown?['projectName']?.toString();
        final matchedProj = list.firstWhere(
          (p) => (prevProjectId != null && p.id == prevProjectId) ||
                 (prevProjectName != null && p.name.toLowerCase() == prevProjectName.toLowerCase()),
          orElse: () => list.first,
        );
        _selectProject(matchedProj);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProjects = false;
        _loadError = 'Failed to load ERP projects: $e';
      });
    }
  }

  Future<void> _selectProject(ErpProject proj) async {
    setState(() {
      _selectedProject = proj;
      _isLoadingTowers = true;
      _towers = [];
      _selectedTower = null;
      _units = [];
      _selectedUnit = null;
    });

    try {
      final repo = ref.read(projectRepositoryProvider);
      final twrs = await repo.listTowers(proj.id);
      if (!mounted) return;

      setState(() {
        _towers = twrs;
        _isLoadingTowers = false;
      });

      if (twrs.isNotEmpty) {
        final prevTowerId = widget.lead.unitShown?['towerId']?.toString();
        final prevTowerName = widget.lead.unitShown?['towerName']?.toString();
        final matchedTower = twrs.firstWhere(
          (t) => (prevTowerId != null && t.id == prevTowerId) ||
                 (prevTowerName != null && t.name.toLowerCase() == prevTowerName.toLowerCase()),
          orElse: () => twrs.first,
        );
        _selectTower(matchedTower);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingTowers = false;
      });
    }
  }

  Future<void> _selectTower(ErpProjectTower tower) async {
    setState(() {
      _selectedTower = tower;
      _isLoadingUnits = true;
      _units = [];
      _selectedUnit = null;
    });

    try {
      List<ErpProjectUnit> uList = tower.units;
      if (uList.isEmpty && _selectedProject != null) {
        final fullTower = await ref.read(projectRepositoryProvider).getTower(_selectedProject!.id, tower.id);
        uList = fullTower.units;
      }
      if (!mounted) return;

      setState(() {
        _units = uList;
        _isLoadingUnits = false;
      });

      if (uList.isNotEmpty) {
        final prevUnitNo = widget.lead.unitShown?['unitNo']?.toString();
        final prevUnitId = widget.lead.unitShown?['unitId']?.toString();
        final matchedUnit = uList.firstWhere(
          (u) => (prevUnitId != null && u.id == prevUnitId) ||
                 (prevUnitNo != null && u.unitNo.toLowerCase() == prevUnitNo.toLowerCase()),
          orElse: () => uList.first,
        );
        _selectUnit(matchedUnit);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingUnits = false;
      });
    }
  }

  void _selectUnit(ErpProjectUnit unit) {
    setState(() {
      _selectedUnit = unit;
      _customUnitCtrl.text = unit.unitNo;
      _unitTypeCtrl.text = unit.unitTypeCode ?? (unit.isDuplex ? 'Duplex' : 'Apartment');
      _carpetAreaCtrl.text = (unit.carpetArea ?? 0) > 0 ? unit.carpetArea!.toStringAsFixed(0) : '';
      _superBuiltUpCtrl.text = (unit.superBuiltUp ?? 0) > 0 ? unit.superBuiltUp!.toStringAsFixed(0) : '';
      _floorNoCtrl.text = unit.floorNo.toString();
      _baseRateCtrl.text = (unit.baseRate ?? 0) > 0 ? unit.baseRate!.toStringAsFixed(0) : '';

      final val = unit.effectiveGrandTotal > 0 ? unit.effectiveGrandTotal : (unit.totalValue ?? 0);
      _totalValueCtrl.text = val > 0 ? val.toStringAsFixed(0) : '';

      if (unit.remarks != null && unit.remarks!.isNotEmpty) {
        _notesCtrl.text = unit.remarks!;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasProjects = _projects.isNotEmpty;
    final projectName = _selectedProject?.name ?? (_manualProjectCtrl.text.isNotEmpty ? _manualProjectCtrl.text : 'NB Heights');
    final towerName = _selectedTower?.name ?? (_manualTowerCtrl.text.isNotEmpty ? _manualTowerCtrl.text : 'Tower A');
    final chosenUnitNo = _customUnitCtrl.text.trim().isNotEmpty
        ? _customUnitCtrl.text.trim()
        : (_selectedUnit?.unitNo ?? '');

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.home_work_rounded, color: Color(0xFF2563EB)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Record Unit Shown: ${widget.lead.name}'),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer Phone: ${widget.lead.phone}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),

              if (_loadError != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_loadError!, style: const TextStyle(fontSize: 12, color: Colors.red)),
                      ),
                      TextButton(
                        onPressed: _fetchProjects,
                        child: const Text('Retry', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ],

              // Project Selector (Fetched dynamically from ERP)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Project * (ERP Projects)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  if (_isLoadingProjects)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (_isLoadingProjects)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade50,
                  ),
                  child: const Row(
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Fetching active ERP projects...', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                )
              else if (hasProjects)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ErpProject>(
                      value: _projects.contains(_selectedProject) ? _selectedProject : _projects.first,
                      isExpanded: true,
                      items: _projects
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text('${p.name} (Project #${p.projectNo})'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) _selectProject(val);
                      },
                    ),
                  ),
                )
              else ...[
                // Manual fallback if ERP has no projects
                TextField(
                  controller: _manualProjectCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Project Name (Manual entry)',
                    hintText: 'e.g. NB Heights',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Tower Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Tower *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  if (_isLoadingTowers)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (_isLoadingTowers)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade50,
                  ),
                  child: const Row(
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Loading towers from ERP...', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                )
              else if (_towers.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ErpProjectTower>(
                      value: _towers.contains(_selectedTower) ? _selectedTower : _towers.first,
                      isExpanded: true,
                      items: _towers
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text('${t.name} (${t.units.length} units configured)'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) _selectTower(val);
                      },
                    ),
                  ),
                )
              else ...[
                TextField(
                  controller: _manualTowerCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tower / Wing (Manual entry)',
                    hintText: 'e.g. Tower A',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Unit Number Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Unit Number *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  if (_isLoadingUnits)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _isLoadingUnits
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 8),
                                Text('Loading units...', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          )
                        : _units.isNotEmpty
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<ErpProjectUnit>(
                                    value: _units.contains(_selectedUnit) ? _selectedUnit : _units.first,
                                    isExpanded: true,
                                    items: _units
                                        .map((u) => DropdownMenuItem(
                                              value: u,
                                              child: Text('Unit ${u.unitNo} • Floor ${u.floorNo} (${u.unitTypeCode ?? "Flat"})'),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) _selectUnit(val);
                                    },
                                  ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('No ERP units found for this tower', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _customUnitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Or Custom #',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Specs Grid
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _unitTypeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Unit Type / BHK',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _floorNoCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Floor No',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _carpetAreaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Carpet Area (sq.ft)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _superBuiltUpCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Super Built-Up (sq.ft)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _baseRateCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Base Rate (₹/sq.ft)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _totalValueCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total Value / Price (₹)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Site Visit Remarks / Customer Response',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (chosenUnitNo.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select or specify a unit number.')),
              );
              return;
            }

            final unitData = {
              'projectId': _selectedProject?.id,
              'projectName': projectName,
              'towerId': _selectedTower?.id,
              'towerName': towerName,
              'unitId': _selectedUnit?.id ?? chosenUnitNo,
              'unitNo': chosenUnitNo,
              'unitType': _unitTypeCtrl.text.trim(),
              'carpetArea': _carpetAreaCtrl.text.trim(),
              'superBuiltUp': _superBuiltUpCtrl.text.trim(),
              'floorNo': _floorNoCtrl.text.trim(),
              'baseRate': _baseRateCtrl.text.trim(),
              'plc': _selectedUnit?.plc ?? 0.0,
              'frc': _selectedUnit?.frc ?? 0.0,
              'developmentCharge': _selectedUnit?.developmentCharge ?? 0.0,
              'totalUnitValue': _selectedUnit?.totalUnitValue ?? 0.0,
              'taxes': _selectedUnit?.taxes.map((t) => {
                    'name': t.name,
                    'ratePercent': t.ratePercent,
                    'amount': t.amount,
                  }).toList() ?? [],
              'maintenance': _selectedUnit?.maintenance.map((m) => {
                    'name': m.name,
                    'ratePerSqft': m.ratePerSqft,
                    'amount': m.amount,
                    'calculationType': m.calculationType,
                  }).toList() ?? [],
              'otherCharges': _selectedUnit?.otherCharges.map((o) => {
                    'name': o.name,
                    'docCount': o.docCount,
                    'feePerDoc': o.feePerDoc,
                    'amount': o.amount,
                  }).toList() ?? [],
              'totalValue': _totalValueCtrl.text.trim(),
              'shownAt': DateTime.now().toIso8601String(),
              'remarks': _notesCtrl.text.trim(),
            };

            widget.onSave(unitData);
            Navigator.pop(context);
          },
          child: const Text('Save Unit Shown'),
        ),
      ],
    );
  }
}

// =============================================================================
// Finserve Loan Application & Documents Modal Dialog
// =============================================================================
class _FinserveApplicationDialog extends StatefulWidget {
  final CrmLead lead;
  final CrmRepository? crmRepository;
  final CrmLeadsBloc? leadsBloc;

  const _FinserveApplicationDialog({
    required this.lead,
    this.crmRepository,
    this.leadsBloc,
  });

  @override
  State<_FinserveApplicationDialog> createState() => _FinserveApplicationDialogState();
}

class _FinserveApplicationDialogState extends State<_FinserveApplicationDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CrmLead _currentLead;

  CrmRepository get _repo => widget.crmRepository ?? context.read<CrmRepository>();

  void _refreshLeads() {
    if (widget.leadsBloc != null) {
      widget.leadsBloc!.add(const CrmLeadsRefreshRequested());
      return;
    }
    try {
      context.read<CrmLeadsBloc>().add(const CrmLeadsRefreshRequested());
    } catch (_) {}
  }

  // Personal Controllers
  late TextEditingController _mobileCtrl;
  late TextEditingController _alternateNoCtrl;
  late TextEditingController _personalEmailCtrl;
  String _maritalStatus = 'Married';
  late TextEditingController _motherNameCtrl;
  late TextEditingController _spouseNameCtrl;
  String _education = 'Graduate';
  late TextEditingController _currentAddressCtrl;
  String _currentAddressType = 'Owned';
  late TextEditingController _permanentAddressCtrl;
  String _permanentAddressType = 'Owned';
  late TextEditingController _requiredLoanAmountCtrl;
  late TextEditingController _loanPurposeCtrl;

  // Company Controllers
  late TextEditingController _companyNameCtrl;
  late TextEditingController _companyAddressCtrl;
  late TextEditingController _currentWorkExpCtrl;
  late TextEditingController _totalWorkExpCtrl;
  late TextEditingController _officialEmailCtrl;
  late TextEditingController _officeLandlineNoCtrl;

  // Reference Controllers
  late TextEditingController _ref1NameCtrl;
  late TextEditingController _ref1MobileCtrl;
  late TextEditingController _ref1RelationCtrl;
  late TextEditingController _ref1AddressCtrl;

  late TextEditingController _ref2NameCtrl;
  late TextEditingController _ref2MobileCtrl;
  late TextEditingController _ref2RelationCtrl;
  late TextEditingController _ref2AddressCtrl;

  String _selectedLoanType = 'Home Loan';
  String? _portalLink;
  bool _isGeneratingLink = false;
  bool _isSavingDetails = false;
  String? _uploadingDocId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentLead = widget.lead;

    final appDetails = Map<String, dynamic>.from(_currentLead.customFields['applicationDetails'] ?? {});

    _mobileCtrl = TextEditingController(text: appDetails['mobileNo']?.toString() ?? _currentLead.phone);
    _alternateNoCtrl = TextEditingController(text: appDetails['alternateNo']?.toString() ?? '');
    _personalEmailCtrl = TextEditingController(text: appDetails['personalEmail']?.toString() ?? _currentLead.email ?? '');
    _maritalStatus = appDetails['maritalStatus']?.toString() ?? 'Married';
    _motherNameCtrl = TextEditingController(text: appDetails['motherName']?.toString() ?? '');
    _spouseNameCtrl = TextEditingController(text: appDetails['spouseName']?.toString() ?? '');
    _education = appDetails['education']?.toString() ?? 'Graduate';
    _currentAddressCtrl = TextEditingController(text: appDetails['currentAddress']?.toString() ?? _currentLead.address ?? '');
    _currentAddressType = appDetails['currentAddressType']?.toString() ?? 'Owned';
    _permanentAddressCtrl = TextEditingController(text: appDetails['permanentAddress']?.toString() ?? _currentLead.address ?? '');
    _permanentAddressType = appDetails['permanentAddressType']?.toString() ?? 'Owned';
    _requiredLoanAmountCtrl = TextEditingController(
      text: appDetails['requiredLoanAmount']?.toString() ?? _currentLead.customFields['Amount']?.toString() ?? _currentLead.customFields['amount']?.toString() ?? _currentLead.customFields['Budget']?.toString() ?? '',
    );
    _loanPurposeCtrl = TextEditingController(
      text: appDetails['loanPurpose']?.toString() ?? _currentLead.customFields['Loan_Type']?.toString() ?? _currentLead.customFields['loan_type']?.toString() ?? 'Home Loan',
    );

    // Company
    _companyNameCtrl = TextEditingController(text: appDetails['companyName']?.toString() ?? _currentLead.customFields['Company']?.toString() ?? '');
    _companyAddressCtrl = TextEditingController(text: appDetails['companyAddress']?.toString() ?? '');
    _currentWorkExpCtrl = TextEditingController(text: appDetails['currentWorkExp']?.toString() ?? '');
    _totalWorkExpCtrl = TextEditingController(text: appDetails['totalWorkExp']?.toString() ?? '');
    _officialEmailCtrl = TextEditingController(text: appDetails['officialEmail']?.toString() ?? '');
    _officeLandlineNoCtrl = TextEditingController(text: appDetails['officeLandlineNo']?.toString() ?? '');

    // Reference
    _ref1NameCtrl = TextEditingController(text: appDetails['ref1Name']?.toString() ?? '');
    _ref1MobileCtrl = TextEditingController(text: appDetails['ref1Mobile']?.toString() ?? '');
    _ref1RelationCtrl = TextEditingController(text: appDetails['ref1Relation']?.toString() ?? '');
    _ref1AddressCtrl = TextEditingController(text: appDetails['ref1Address']?.toString() ?? '');

    _ref2NameCtrl = TextEditingController(text: appDetails['ref2Name']?.toString() ?? '');
    _ref2MobileCtrl = TextEditingController(text: appDetails['ref2Mobile']?.toString() ?? '');
    _ref2RelationCtrl = TextEditingController(text: appDetails['ref2Relation']?.toString() ?? '');
    _ref2AddressCtrl = TextEditingController(text: appDetails['ref2Address']?.toString() ?? '');

    final leadLoanType = _currentLead.customFields['Loan_Type']?.toString() ?? _currentLead.customFields['loan_type']?.toString() ?? 'Home Loan';
    if (CrmSettings.defaultLoanTypeDocsMap.containsKey(leadLoanType)) {
      _selectedLoanType = leadLoanType;
    }

    _portalLink = _currentLead.customFields['portalLink']?.toString();
    final origin = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api/?$'), '');
    if (_portalLink != null && _portalLink!.isNotEmpty) {
      if (_portalLink!.contains('localhost:5000')) {
        _portalLink = _portalLink!.replaceAll('localhost:5000', 'localhost:4000');
      }
    } else {
      final token = _currentLead.customFields['portalToken']?.toString();
      if (token != null && token.isNotEmpty) {
        _portalLink = '$origin/client-portal?token=$token';
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mobileCtrl.dispose();
    _alternateNoCtrl.dispose();
    _personalEmailCtrl.dispose();
    _motherNameCtrl.dispose();
    _spouseNameCtrl.dispose();
    _currentAddressCtrl.dispose();
    _permanentAddressCtrl.dispose();
    _requiredLoanAmountCtrl.dispose();
    _loanPurposeCtrl.dispose();
    _companyNameCtrl.dispose();
    _companyAddressCtrl.dispose();
    _currentWorkExpCtrl.dispose();
    _totalWorkExpCtrl.dispose();
    _officialEmailCtrl.dispose();
    _officeLandlineNoCtrl.dispose();
    _ref1NameCtrl.dispose();
    _ref1MobileCtrl.dispose();
    _ref1RelationCtrl.dispose();
    _ref1AddressCtrl.dispose();
    _ref2NameCtrl.dispose();
    _ref2MobileCtrl.dispose();
    _ref2RelationCtrl.dispose();
    _ref2AddressCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _collectFormData() {
    return {
      'mobileNo': _mobileCtrl.text.trim(),
      'alternateNo': _alternateNoCtrl.text.trim(),
      'personalEmail': _personalEmailCtrl.text.trim(),
      'maritalStatus': _maritalStatus,
      'motherName': _motherNameCtrl.text.trim(),
      'spouseName': _spouseNameCtrl.text.trim(),
      'education': _education,
      'currentAddress': _currentAddressCtrl.text.trim(),
      'currentAddressType': _currentAddressType,
      'permanentAddress': _permanentAddressCtrl.text.trim(),
      'permanentAddressType': _permanentAddressType,
      'requiredLoanAmount': _requiredLoanAmountCtrl.text.trim(),
      'loanPurpose': _loanPurposeCtrl.text.trim(),
      'companyName': _companyNameCtrl.text.trim(),
      'companyAddress': _companyAddressCtrl.text.trim(),
      'currentWorkExp': _currentWorkExpCtrl.text.trim(),
      'totalWorkExp': _totalWorkExpCtrl.text.trim(),
      'officialEmail': _officialEmailCtrl.text.trim(),
      'officeLandlineNo': _officeLandlineNoCtrl.text.trim(),
      'ref1Name': _ref1NameCtrl.text.trim(),
      'ref1Mobile': _ref1MobileCtrl.text.trim(),
      'ref1Relation': _ref1RelationCtrl.text.trim(),
      'ref1Address': _ref1AddressCtrl.text.trim(),
      'ref2Name': _ref2NameCtrl.text.trim(),
      'ref2Mobile': _ref2MobileCtrl.text.trim(),
      'ref2Relation': _ref2RelationCtrl.text.trim(),
      'ref2Address': _ref2AddressCtrl.text.trim(),
    };
  }

  Future<void> _saveApplicationDetails() async {
    setState(() => _isSavingDetails = true);
    try {
      final data = _collectFormData();
      final res = await _repo.updateLeadApplicationDetails(
        _currentLead.id,
        {
          'applicationDetails': data,
          'loanType': _selectedLoanType,
        },
      );
      if (!mounted) return;
      setState(() {
        _isSavingDetails = false;
        if (res['lead'] != null) {
          _currentLead = CrmLead.fromJson(Map<String, dynamic>.from(res['lead']));
        }
      });
      _refreshLeads();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application details saved successfully!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingDetails = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save details: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _generatePortalLink() async {
    setState(() => _isGeneratingLink = true);
    try {
      final res = await _repo.generateClientPortalLink(_currentLead.id);
      if (!mounted) return;
      final portalUrl = res['portalUrl']?.toString() ?? res['link']?.toString();
      setState(() {
        _isGeneratingLink = false;
        _portalLink = portalUrl;
        if (res['lead'] != null) {
          _currentLead = CrmLead.fromJson(Map<String, dynamic>.from(res['lead']));
        }
      });
      _refreshLeads();
      if (portalUrl != null && portalUrl.isNotEmpty) {
        _showGeneratedLinkDialog(portalUrl);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGeneratingLink = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate portal link: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showGeneratedLinkDialog(String url) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.link_rounded, color: Color(0xFF10B981), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Client Portal Link Ready!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share this unique, secure upload link with ${_currentLead.name.isNotEmpty ? _currentLead.name : "the client"}. They can upload their documents directly after entering their registered phone number and OTP.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unique Client Portal URL:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      url,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Link'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Portal link copied to clipboard!'),
                            backgroundColor: Color(0xFF2563EB),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: const Text('Send WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.pop(dlgCtx);
                        _shareViaWhatsApp();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Color(0xFFB45309)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This link is permanently saved for this client. You can also copy or reshare it directly from the Customer Card or the Applications tab at any time.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _copyPortalLink() {
    if (_portalLink == null) return;
    Clipboard.setData(ClipboardData(text: _portalLink!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Client Portal link copied to clipboard!'),
        backgroundColor: Color(0xFF2563EB),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareViaWhatsApp() async {
    if (_portalLink == null) return;
    final cleanPhone = _currentLead.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final pPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
    final clientName = _currentLead.name.isNotEmpty ? _currentLead.name : 'Customer';
    final message = 'Hello $clientName,\n\n'
        'Greetings from NB Finserve!\n\n'
        'Please verify and submit your documents for your $_selectedLoanType application using our secure Client Portal link:\n'
        '$_portalLink\n\n'
        '🔐 To access, enter your registered mobile number (${_currentLead.phone}) and verify with the 6-digit OTP sent to your email.\n\n'
        'Thank you,\nNB Finserve Team';

    final uri = Uri.parse('https://wa.me/$pPhone?text=${Uri.encodeComponent(message)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open WhatsApp: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickAndUploadDoc(String docTypeId, String docName) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      final bytes = pickedFile.bytes;
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file data. Please try another file.')),
          );
        }
        return;
      }

      setState(() => _uploadingDocId = docTypeId);

      if (!mounted) return;
      final res = await _repo.uploadLeadDoc(
        _currentLead.id,
        docTypeId: docTypeId,
        docName: docName,
        bytes: bytes,
        filename: pickedFile.name,
      );

      if (!mounted) return;
      setState(() {
        _uploadingDocId = null;
        if (res['lead'] != null) {
          _currentLead = CrmLead.fromJson(Map<String, dynamic>.from(res['lead']));
        }
      });
      _refreshLeads();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$docName uploaded successfully!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingDocId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload document: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1916) : Colors.white;
    final borderColor = isDark ? const Color(0xFFC5A059).withValues(alpha: 0.22) : const Color(0xFFE2E8F0);
    final textMuted = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF64748B);
    const primaryColor = Color(0xFF2563EB);
    const goldColor = Color(0xFFC5A059);

    final size = MediaQuery.of(context).size;
    final dialogWidth = (size.width * 0.88).clamp(600.0, 940.0);
    final dialogHeight = (size.height * 0.88).clamp(500.0, 780.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: cardBg,
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // Header Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF24201D) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.assignment_turned_in_rounded, color: primaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Loan Application & Document Intake',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'INTERESTED',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Client: ${_currentLead.name.isNotEmpty ? _currentLead.name : "Unnamed"} • 📞 ${_currentLead.phone} • ✉️ ${_currentLead.email ?? "No Email"}',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Client Portal Link Action Banner
            _buildPortalLinkBanner(isDark, borderColor, textMuted, goldColor),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF221F1B) : const Color(0xFFF1F5F9),
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: primaryColor,
                labelColor: primaryColor,
                unselectedLabelColor: textMuted,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.description_outlined, size: 18),
                    text: '📝 Application Details (24 Fields)',
                  ),
                  Tab(
                    icon: Icon(Icons.folder_shared_outlined, size: 18),
                    text: '📁 Document Checklist & Portal',
                  ),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildApplicationDetailsTab(isDark, borderColor, textMuted, primaryColor),
                  _buildDocumentChecklistTab(isDark, borderColor, textMuted, primaryColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortalLinkBanner(bool isDark, Color borderColor, Color textMuted, Color goldColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF29241F) : const Color(0xFFFEF9C3).withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: _portalLink != null
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.link_rounded, color: Color(0xFFD97706), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Secure Client Document Portal Link',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        _portalLink!,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: const Text('Copy Link', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _copyPortalLink,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                  label: const Text('Send WhatsApp', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _shareViaWhatsApp,
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Regenerate link',
                  icon: _isGeneratingLink
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded, size: 18),
                  onPressed: _isGeneratingLink ? null : _generatePortalLink,
                ),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Color(0xFFB45309)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Generate a secure, single-use client portal link to let the client upload documents directly with email OTP verification.',
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: _isGeneratingLink
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.share_rounded, size: 16),
                  label: Text(_isGeneratingLink ? 'Generating...' : 'Generate Client Portal Link'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: _isGeneratingLink ? null : _generatePortalLink,
                ),
              ],
            ),
    );
  }

  Widget _buildApplicationDetailsTab(bool isDark, Color borderColor, Color textMuted, Color primaryColor) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 1: Personal Details
                _buildSectionCard(
                  title: '🎗️ PERSONAL DETAILS 🎗️',
                  isDark: isDark,
                  borderColor: borderColor,
                  children: [
                    _buildFieldRow([
                      _buildTextField('MOBILE NO *', _mobileCtrl, hint: 'e.g. 9876543210'),
                      _buildTextField('ALTERNATE NO', _alternateNoCtrl, hint: 'e.g. 9123456789'),
                      _buildTextField('PERSONAL MAIL ID *', _personalEmailCtrl, hint: 'e.g. client@gmail.com'),
                    ]),
                    const SizedBox(height: 12),
                    _buildFieldRow([
                      _buildDropdownField('MARITAL STATUS *', _maritalStatus, ['Single', 'Married', 'Divorced', 'Widowed'], (val) {
                        if (val != null) setState(() => _maritalStatus = val);
                      }),
                      _buildTextField('MOTHER NAME *', _motherNameCtrl, hint: "Mother's Full Name"),
                      _buildTextField('SPOUSE NAME', _spouseNameCtrl, hint: "Spouse's Full Name (if married)"),
                    ]),
                    const SizedBox(height: 12),
                    _buildFieldRow([
                      _buildDropdownField('EDUCATION *', _education, ['High School', 'Graduate', 'Post Graduate', 'Doctorate', 'Professional', 'Other'], (val) {
                        if (val != null) setState(() => _education = val);
                      }),
                      _buildDropdownField('CURRENT RESIDENCE (RENT/OWNED) *', _currentAddressType, ['Owned', 'Rented', 'Parental', 'Company Provided'], (val) {
                        if (val != null) setState(() => _currentAddressType = val);
                      }),
                      _buildDropdownField('PERMANENT RESIDENCE (RENT/OWNED) *', _permanentAddressType, ['Owned', 'Rented', 'Parental'], (val) {
                        if (val != null) setState(() => _permanentAddressType = val);
                      }),
                    ]),
                    const SizedBox(height: 12),
                    _buildFieldRow([
                      _buildTextField('CURRENT ADDRESS *', _currentAddressCtrl, maxLines: 2, hint: 'Flat / Street / City / Pincode'),
                      _buildTextField('PERMANENT ADDRESS *', _permanentAddressCtrl, maxLines: 2, hint: 'Permanent Native Address'),
                    ]),
                    const SizedBox(height: 12),
                    _buildFieldRow([
                      _buildTextField('REQUIRE LOAN AMOUNT *', _requiredLoanAmountCtrl, hint: 'e.g. 4500000'),
                      _buildTextField('LOAN PURPOSE *', _loanPurposeCtrl, hint: 'e.g. Home Purchase, Business Expansion'),
                    ]),
                  ],
                ),
                const SizedBox(height: 16),

                // Section 2: Company Details
                _buildSectionCard(
                  title: '🎗️ COMPANY DETAILS 🎗️',
                  isDark: isDark,
                  borderColor: borderColor,
                  children: [
                    _buildFieldRow([
                      _buildTextField('COMPANY NAME *', _companyNameCtrl, hint: 'e.g. TCS, Infosys, Self Employed'),
                      _buildTextField('CURRENT WORK EXP *', _currentWorkExpCtrl, hint: 'e.g. 3 Years'),
                      _buildTextField('TOTAL WORK EXP *', _totalWorkExpCtrl, hint: 'e.g. 7 Years'),
                    ]),
                    const SizedBox(height: 12),
                    _buildFieldRow([
                      _buildTextField('COMPANY ADDRESS *', _companyAddressCtrl, maxLines: 2, hint: 'Office Address & City'),
                      _buildTextField('OFFICIAL MAIL ID', _officialEmailCtrl, hint: 'e.g. emp@company.com'),
                      _buildTextField('OFFICE LANDLINE NO', _officeLandlineNoCtrl, hint: 'e.g. 022-28492040'),
                    ]),
                  ],
                ),
                const SizedBox(height: 16),

                // Section 3: Reference Details
                _buildSectionCard(
                  title: '🎗️ REFERENCE DETAILS 🎗️',
                  isDark: isDark,
                  borderColor: borderColor,
                  children: [
                    const Text('Reference 1 (Personal / Professional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB))),
                    const SizedBox(height: 8),
                    _buildFieldRow([
                      _buildTextField('1. NAME *', _ref1NameCtrl, hint: 'Full Name'),
                      _buildTextField('1. MOBILE NO *', _ref1MobileCtrl, hint: '10-digit Mobile'),
                      _buildTextField('1. RELATION *', _ref1RelationCtrl, hint: 'e.g. Colleague, Brother, Friend'),
                      _buildTextField('1. ADDRESS *', _ref1AddressCtrl, hint: 'Address'),
                    ]),
                    const SizedBox(height: 14),
                    const Text('Reference 2 (Personal / Professional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB))),
                    const SizedBox(height: 8),
                    _buildFieldRow([
                      _buildTextField('2. NAME *', _ref2NameCtrl, hint: 'Full Name'),
                      _buildTextField('2. MOBILE NO *', _ref2MobileCtrl, hint: '10-digit Mobile'),
                      _buildTextField('2. RELATION *', _ref2RelationCtrl, hint: 'e.g. Uncle, Manager, Neighbor'),
                      _buildTextField('2. ADDRESS *', _ref2AddressCtrl, hint: 'Address'),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Action Bar Bottom
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF24201D) : const Color(0xFFF8FAFC),
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Text(
                'All 24 fields are synced directly with the Client Portal in READ-ONLY mode.',
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: _isSavingDetails
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_isSavingDetails ? 'Saving Details...' : 'Save Application Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSavingDetails ? null : _saveApplicationDetails,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentChecklistTab(bool isDark, Color borderColor, Color textMuted, Color primaryColor) {
    final clientSubmitted = _currentLead.customFields['clientPortalSubmitted'] == true;
    final allDocs = List<dynamic>.from(_currentLead.customFields['documents'] ?? []);
    // Before save / submit by client, admin cannot view client-uploaded documents
    final docsList = allDocs.where((d) => clientSubmitted || d['uploadedBy'] != 'CLIENT').toList();
    final requiredDocIds = CrmSettings.defaultLoanTypeDocsMap[_selectedLoanType] ?? CrmSettings.defaultLoanTypeDocsMap['Home Loan'] ?? [];
    const availableDocTypes = CrmSettings.defaultLoanDocTypes;

    final uploadedDocTypeIds = docsList.map((d) => d['docTypeId']?.toString()).toSet();
    final completedCount = requiredDocIds.where((id) => uploadedDocTypeIds.contains(id)).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Loan Type Selector & Progress
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF24201D) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Loan Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 4),
                      DropdownButton<String>(
                        value: CrmSettings.defaultLoanTypeDocsMap.containsKey(_selectedLoanType) ? _selectedLoanType : 'Home Loan',
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        items: CrmSettings.defaultLoanTypeDocsMap.keys.map((k) {
                          return DropdownMenuItem(value: k, child: Text(k));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedLoanType = val);
                        },
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$completedCount of ${requiredDocIds.length} Required Docs Received',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: completedCount >= requiredDocIds.length && requiredDocIds.isNotEmpty
                            ? const Color(0xFF10B981)
                            : const Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: requiredDocIds.isEmpty ? 0 : (completedCount / requiredDocIds.length).clamp(0.0, 1.0),
                          backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation(
                            completedCount >= requiredDocIds.length && requiredDocIds.isNotEmpty
                                ? const Color(0xFF10B981)
                                : primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Client Submission Status Banner
          if (!clientSubmitted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_clock_rounded, size: 18, color: Colors.amber),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Client has not finalized their portal yet. Client-uploaded documents will appear here once the client confirms and submits their portal.',
                      style: TextStyle(fontSize: 12.5, color: Colors.amber, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_rounded, size: 18, color: Color(0xFF10B981)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Client confirmed and submitted application. Documents are locked for client; administrator can review and manage.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          Text(
            'REQUIRED DOCUMENTS FOR $_selectedLoanType',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),

          // Document List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: requiredDocIds.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final docTypeId = requiredDocIds[index];
              CrmLoanDocType? docType;
              for (final d in availableDocTypes) {
                if (d.id == docTypeId) {
                  docType = d;
                  break;
                }
              }
              final docName = docType?.name ?? docTypeId.replaceAll('_', ' ').toUpperCase();
              final isUploading = _uploadingDocId == docTypeId;

              dynamic uploadedDoc;
              for (final d in docsList) {
                if (d['docTypeId'] == docTypeId) {
                  uploadedDoc = d;
                  break;
                }
              }
              final isUploaded = uploadedDoc != null;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF24201D) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isUploaded
                        ? const Color(0xFF10B981).withValues(alpha: 0.4)
                        : borderColor,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isUploaded
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : Colors.amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isUploaded ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                        color: isUploaded ? const Color(0xFF10B981) : const Color(0xFFD97706),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(docName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Max ${docType?.maxFileSizeMb ?? 5}MB',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textMuted),
                                ),
                              ),
                            ],
                          ),
                          if (isUploaded) ...[
                            const SizedBox(height: 4),
                            Text(
                              'File: ${uploadedDoc['originalName'] ?? uploadedDoc['filename'] ?? "Document"} • ${uploadedDoc['uploadedAt'] != null ? DateFormat("dd MMM yyyy, hh:mm a").format(DateTime.parse(uploadedDoc['uploadedAt']).toLocal()) : ""}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF10B981)),
                            ),
                          ] else ...[
                            const SizedBox(height: 4),
                            Text('Awaiting client submission via portal or internal upload', style: TextStyle(fontSize: 12, color: textMuted)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (isUploaded && uploadedDoc['fileUrl'] != null) ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.open_in_new_rounded, size: 14),
                        label: const Text('View', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          final url = uploadedDoc['fileUrl']?.toString();
                          if (url != null) {
                            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    OutlinedButton.icon(
                      icon: isUploading
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload_file_rounded, size: 14),
                      label: Text(
                        isUploading ? 'Uploading...' : (isUploaded ? 'Replace' : 'Upload'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: isUploading ? null : () => _pickAndUploadDoc(docTypeId, docName),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required bool isDark,
    required Color borderColor,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24201D) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFieldRow(List<Widget> children) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? hint, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: options.contains(value) ? value : options.first,
          isDense: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

