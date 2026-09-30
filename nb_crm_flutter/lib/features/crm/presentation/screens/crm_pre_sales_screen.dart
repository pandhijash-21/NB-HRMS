import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/tour/models/tour_models.dart';
import '../../../../core/tour/widgets/tour_target.dart';
import '../../../../core/widgets/mobile_input_formatter.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/domain/permissions.dart';
import '../../data/crm_repository.dart';
import '../../domain/crm_models.dart';
import '../bloc/crm_leads_bloc.dart';
import '../widgets/crm_audio_player_dialog.dart';

class CrmPreSalesScreen extends StatelessWidget {
  const CrmPreSalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CrmLeadsBloc>(
      create: (ctx) => CrmLeadsBloc(
        crmRepository: ctx.read<CrmRepository>(),
      )..add(const CrmLeadsLoadRequested()),
      child: const _CrmPreSalesView(),
    );
  }
}

class _CrmPreSalesView extends StatefulWidget {
  const _CrmPreSalesView();

  @override
  State<_CrmPreSalesView> createState() => _CrmPreSalesViewState();
}

class _CrmPreSalesViewState extends State<_CrmPreSalesView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();

  // Call Recording Filters
  final TextEditingController _recordingSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _horizontalScrollController.dispose();
    _recordingSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFFC5A059).withValues(alpha: 0.18)
        : const Color(0xFFE2E8F0);
    final textMuted = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF64748B);
    final primaryGold = isDark ? const Color(0xFFC5A059) : const Color(0xFF2563EB);

    final authState = context.watch<AuthBloc>().state;

    return BlocConsumer<CrmLeadsBloc, CrmLeadsState>(
      listener: (context, state) {
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        } else if (state.actionSuccessMessage != null &&
            state.actionSuccessMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.actionSuccessMessage!),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF141210) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('Pre-Sales Management'),
            leading: const AppBackButton(fallbackLocation: '/crm/dashboard'),
            backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: TourTarget(
                id: TourIds.step('crm.pre_sales', 2),
                child: TourTarget(
                  id: TourIds.step('crm.pre_sales', 3),
                  child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Leads & Inquiries'),
                Tab(text: 'Follow-ups & Scheduled Calls'),
                Tab(text: 'Call Recordings'),
                Tab(text: 'Pipeline & Deals'),
                Tab(text: 'Quotations'),
              ],
            ),
                ),
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  context.read<CrmLeadsBloc>().add(const CrmLeadsRefreshRequested());
                },
              ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(), // Disables swipe gesture conflicts / carousel effect
            children: [
              _buildLeadsTableTab(context, state, authState, isDark, cardBg, borderColor, textMuted, primaryGold),
              _buildFollowUpsTab(context, state, isDark, cardBg, borderColor, textMuted, primaryGold),
              _buildCallRecordingsTab(context, state, isDark, cardBg, borderColor, textMuted, primaryGold),
              _buildPipelineTab(isDark, cardBg, borderColor, textMuted),
              _buildQuotationsTab(isDark, cardBg, borderColor, textMuted),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: Leads & Inquiries with Dynamic Columns & Telecaller Lock Rules
  // ---------------------------------------------------------------------------
  Widget _buildLeadsTableTab(
    BuildContext context,
    CrmLeadsState state,
    AuthState authState,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
    Color primaryColor,
  ) {
    final projects = state.projects;
    final selectedProjectId = state.selectedProjectId;
    final campaigns = state.campaigns;
    final selectedCampaignId = state.selectedCampaignId;
    final columns = state.columns.where((c) => c.isVisibleInTable && c.isActive).toList();
    final leads = state.leads;
    final salesUsers = state.salesUsers;

    final currentUser = authState.user;
    final userRole = currentUser?.role.toUpperCase() ?? '';
    final userEmployeeId = currentUser?.employeeId;
    final isAdmin = ['ADMIN', 'SUPER_ADMIN', 'SYSTEM_ADMIN'].contains(userRole);
    final canWrite = Permissions.canWriteCrmPreSales(authState.permissions, authState.user?.role);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar: Progressive Project & Campaign Selection, Search, Status, Import, Add Lead
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 950;

                Widget buildProjectSelector() {
                  final effectiveSelectedId = (selectedProjectId != null && projects.any((p) => p.id == selectedProjectId))
                      ? selectedProjectId
                      : 'ALL';

                  return DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: effectiveSelectedId,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.apartment_rounded, size: 18, color: primaryColor),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'ALL',
                        child: Text('All Projects', overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      ...projects.map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          )),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        final newProjId = val == 'ALL' ? null : val;
                        context.read<CrmLeadsBloc>().add(CrmLeadsProjectSelected(newProjId));
                      }
                    },
                  );
                }

                Widget buildCampaignSelector() {
                  const allValue = 'ALL';
                  final hasValidSelection = selectedCampaignId != null &&
                      campaigns.any((c) => c.id == selectedCampaignId);
                  final effectiveSelectedId =
                      hasValidSelection ? selectedCampaignId : allValue;

                  return DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: effectiveSelectedId,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.campaign_rounded, size: 18, color: primaryColor),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: allValue,
                        child: Text(
                          campaigns.isEmpty ? '0 Campaigns for Project' : 'All Campaigns',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      ...campaigns.map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              '${c.name} (${c.leadsCount})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          )),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      final newCampId = val == allValue ? null : val;
                      context.read<CrmLeadsBloc>().add(CrmLeadsCampaignSelected(newCampId));
                    },
                  );
                }

                Widget buildSearchField() {
                  return TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search name or phone...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) {
                      context.read<CrmLeadsBloc>().add(CrmLeadsSearchChanged(val.trim()));
                    },
                  );
                }

                Widget buildStatusFilter() {
                  return DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: state.statusFilter,
                    dropdownColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'ALL',
                        child: Text('All Statuses', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                      ),
                      DropdownMenuItem(
                        value: 'NOT_STARTED',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text('Not started', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'CNR',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text('CNR', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'SCHEDULED_VISIT',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text('Scheduled Visit', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'SITE_VISIT_DONE',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text('Site Done', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'NOT_INTERESTED',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text('Not interested', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'FOLLOW_UP',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text('Follow up', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'INTERESTED',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text('Interested', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        context.read<CrmLeadsBloc>().add(CrmLeadsStatusFilterChanged(val));
                      }
                    },
                  );
                }

                Widget buildActionButtons({bool expand = false}) {
                  if (!canWrite) return const SizedBox.shrink();
                  if (expand) {
                    return Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _handleExcelImport(context),
                            icon: const Icon(Icons.upload_file_rounded, size: 18),
                            label: const Text('Import Excel'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showAddLeadDialog(context, state.columns),
                            icon: const Icon(Icons.person_add_rounded, size: 18),
                            label: const Text('Add Lead'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showMergeColumnsDialog(context, primaryColor),
                        icon: const Icon(Icons.call_merge_rounded, size: 16),
                        label: const Text('Merge Columns'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _handleExcelImport(context),
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: const Text('Import Excel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showAddLeadDialog(context, state.columns),
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: const Text('Add Lead'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  );
                }

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: constraints.maxWidth < 500 ? double.infinity : (constraints.maxWidth - 10) / 2,
                            child: buildProjectSelector(),
                          ),
                          SizedBox(
                            width: constraints.maxWidth < 500 ? double.infinity : (constraints.maxWidth - 10) / 2,
                            child: buildCampaignSelector(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: constraints.maxWidth < 500 ? double.infinity : (constraints.maxWidth - 10) / 2,
                            child: buildSearchField(),
                          ),
                          SizedBox(
                            width: constraints.maxWidth < 500 ? double.infinity : (constraints.maxWidth - 10) / 2,
                            child: buildStatusFilter(),
                          ),
                        ],
                      ),
                      if (canWrite) ...[
                        const SizedBox(height: 12),
                        buildActionButtons(expand: true),
                      ],
                    ],
                  );
                }

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    SizedBox(width: 170, child: buildProjectSelector()),
                    SizedBox(width: 170, child: buildCampaignSelector()),
                    SizedBox(width: 190, child: buildSearchField()),
                    SizedBox(width: 150, child: buildStatusFilter()),
                    if (canWrite) buildActionButtons(expand: false),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Dynamic Data Table with Custom Scrollbar
          if (state.status.isLoading && leads.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (state.status.isFailure && leads.isEmpty)
            Center(child: Text('Error loading leads: ${state.errorMessage}', style: const TextStyle(color: Colors.red)))
          else if (leads.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.assignment_late_outlined, size: 48, color: textMuted),
                    const SizedBox(height: 12),
                    Text('No Pre-Sales Leads Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                    const SizedBox(height: 6),
                    Text('Click "Import Excel" to upload leads or "Add Lead" to enter manually.', style: TextStyle(fontSize: 13, color: textMuted)),
                  ],
                ),
              ),
            )
          else
            RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Scrollbar(
                  controller: _horizontalScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
                      ),
                      horizontalMargin: 16,
                      columnSpacing: 20,
                      columns: [
                        const DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(
                          label: Row(
                            children: [
                              Icon(Icons.phone_in_talk_rounded, size: 16, color: Color(0xFF16A34A)),
                              SizedBox(width: 6),
                              Text('Elision', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                            ],
                          ),
                        ),
                        const DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        ...columns.map((c) => DataColumn(label: Text(c.label, style: const TextStyle(fontWeight: FontWeight.bold)))),
                        const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: List.generate(leads.length, (index) {
                        final lead = leads[index];

                        // Telecaller Limitation:
                        // Telecallers only alter status, schedule calls/visits, or mark not interested.
                        final isAssigned = lead.assignedToId != null;
                        final isAssignedSalesRep = userEmployeeId != null && userEmployeeId == lead.assignedToId;
                        final canAlterLead = canWrite && (!isAssigned || isAdmin || isAssignedSalesRep);

                        return DataRow(
                          cells: [
                            DataCell(Text('${index + 1}')),

                            // Elision Phone Icon Column
                            DataCell(
                              IconButton(
                                tooltip: 'Click-to-Call via Elision',
                                icon: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF16A34A), size: 18),
                                ),
                                onPressed: () => _handleElisionCallAndFollowUp(context, lead),
                              ),
                            ),

                            // Status Column (4 telecaller statuses)
                            DataCell(
                              _buildStatusDropdown(context, lead, canAlterLead, salesUsers),
                            ),

                            // Dynamic Columns (Honoring column visibility)
                            ...columns.map((c) {
                              String cellValue = '';
                              final keyLower = c.columnKey.toLowerCase().replaceAll(' ', '_');
                              if (keyLower == 'client_name' || keyLower == 'name' || keyLower == 'customer_name') {
                                cellValue = lead.name.isNotEmpty ? lead.name : (lead.customFields[c.columnKey]?.toString() ?? '');
                              } else if (keyLower == 'phone' || keyLower == 'mobile' || keyLower == 'contact' || keyLower == 'phone_number') {
                                cellValue = lead.phone.isNotEmpty ? lead.phone : (lead.customFields[c.columnKey]?.toString() ?? '');
                              } else {
                                cellValue = lead.customFields[c.columnKey]?.toString() ??
                                    lead.customFields[c.columnKey.toLowerCase()]?.toString() ??
                                    '-';
                              }

                              return DataCell(
                                Text(
                                  cellValue.isEmpty ? '-' : cellValue,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: (keyLower == 'client_name' || keyLower == 'name') ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              );
                            }),

                            // Actions (Edit / Delete to Bin)
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      canAlterLead ? Icons.edit_outlined : Icons.lock_outline_rounded,
                                      size: 18,
                                      color: canAlterLead ? null : Colors.amber.shade700,
                                    ),
                                    tooltip: canAlterLead
                                        ? 'Edit Lead Details'
                                        : 'Assigned to ${lead.assignedToName ?? "Sales Rep"} (View-only for telecaller)',
                                    onPressed: () => _showEditLeadDialog(
                                      context,
                                      lead,
                                      columns,
                                      salesUsers,
                                      isReadOnly: !canAlterLead,
                                    ),
                                  ),
                                  if (canAlterLead)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                      tooltip: 'Move to Bin',
                                      onPressed: () => _confirmMoveToBin(context, lead),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }



  // ---------------------------------------------------------------------------
  // Status Dropdown with Modal Triggers (With Telecaller Lock)
  // ---------------------------------------------------------------------------
  Widget _buildStatusDropdown(
    BuildContext context,
    CrmLead lead,
    bool canAlter,
    List<CrmSalesUser> salesUsers,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color badgeBg;
    Color badgeFg;
    Color badgeBorder;

    switch (lead.status) {
      case CrmStatus.notStarted:
        badgeBg = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9);
        badgeFg = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569);
        badgeBorder = isDark ? Colors.white.withValues(alpha: 0.20) : const Color(0xFFCBD5E1);
        break;
      case CrmStatus.cnr:
        badgeBg = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.22 : 0.12);
        badgeFg = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
        badgeBorder = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.45 : 0.35);
        break;
      case CrmStatus.scheduledVisit:
        badgeBg = const Color(0xFF2563EB).withValues(alpha: isDark ? 0.22 : 0.12);
        badgeFg = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);
        badgeBorder = const Color(0xFF2563EB).withValues(alpha: isDark ? 0.45 : 0.35);
        break;
      case CrmStatus.notInterested:
        badgeBg = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.22 : 0.12);
        badgeFg = isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
        badgeBorder = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.45 : 0.35);
        break;
      case CrmStatus.siteVisitDone:
        badgeBg = const Color(0xFF10B981).withValues(alpha: isDark ? 0.22 : 0.12);
        badgeFg = isDark ? const Color(0xFF34D399) : const Color(0xFF047857);
        badgeBorder = const Color(0xFF10B981).withValues(alpha: isDark ? 0.45 : 0.35);
        break;
      case CrmStatus.followUp:
        badgeBg = const Color(0xFFEA580C).withValues(alpha: isDark ? 0.22 : 0.12);
        badgeFg = isDark ? const Color(0xFFFB923C) : const Color(0xFFC2410C);
        badgeBorder = const Color(0xFFEA580C).withValues(alpha: isDark ? 0.45 : 0.35);
        break;
      case CrmStatus.interested:
        badgeBg = const Color(0xFF16A34A).withValues(alpha: isDark ? 0.22 : 0.12);
        badgeFg = isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
        badgeBorder = const Color(0xFF16A34A).withValues(alpha: isDark ? 0.45 : 0.35);
        break;
    }

    // If telecaller cannot alter this assigned lead, render locked badge
    if (!canAlter) {
      return Tooltip(
        message: 'Lead is assigned to ${lead.assignedToName ?? "Sales Rep"} — Telecallers have view-only access.',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: badgeBorder, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 13, color: badgeFg),
              const SizedBox(width: 5),
              Text(
                lead.status.displayName,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: badgeFg),
              ),
            ],
          ),
        ),
      );
    }

    // Telecaller 4 primary statuses: Not started, CNR, Schedule A Visit, Not Interested
    final dropdownItems = <CrmStatus>[
      CrmStatus.notStarted,
      CrmStatus.cnr,
      CrmStatus.scheduledVisit,
      CrmStatus.notInterested,
    ];
    if (!dropdownItems.contains(lead.status)) {
      dropdownItems.add(lead.status);
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
              case CrmStatus.cnr:
                dotColor = const Color(0xFFF59E0B);
                break;
              case CrmStatus.scheduledVisit:
                dotColor = const Color(0xFF2563EB);
                break;
              case CrmStatus.notInterested:
                dotColor = const Color(0xFFEF4444);
                break;
              case CrmStatus.siteVisitDone:
                dotColor = const Color(0xFF10B981);
                break;
              case CrmStatus.followUp:
                dotColor = isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C);
                break;
              case CrmStatus.interested:
                dotColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
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
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
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

            if (newStatus == CrmStatus.cnr) {
              _showCnrModal(context, lead);
            } else if (newStatus == CrmStatus.scheduledVisit) {
              _showScheduleVisitModal(context, lead);
            } else if (newStatus == CrmStatus.notInterested) {
              _showNotInterestedModal(context, lead, context.read<CrmLeadsBloc>().state.settings);
            } else if (newStatus == CrmStatus.notStarted) {
              _updateLeadStatus(lead.id, 'NOT_STARTED');
            } else if (newStatus == CrmStatus.followUp) {
              _showFollowUpSchedulingModal(context, lead);
            } else if (newStatus == CrmStatus.interested) {
              _showInterestedSalesAssignmentModal(context, lead);
            }
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: Follow-ups & Scheduled Calls
  // ---------------------------------------------------------------------------

  Widget _buildFollowUpsTab(
    BuildContext context,
    CrmLeadsState state,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
    Color primaryColor,
  ) {
    final followUps = state.followUps;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                'Scheduled Follow-ups & Calls',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('Today', style: TextStyle(fontSize: 12)),
                    selected: state.followUpFilter == 'today',
                    onSelected: (val) => context.read<CrmLeadsBloc>().add(const CrmLeadsFollowUpFilterChanged('today')),
                  ),
                  ChoiceChip(
                    label: const Text('Upcoming', style: TextStyle(fontSize: 12)),
                    selected: state.followUpFilter == 'upcoming',
                    onSelected: (val) => context.read<CrmLeadsBloc>().add(const CrmLeadsFollowUpFilterChanged('upcoming')),
                  ),
                  ChoiceChip(
                    label: const Text('All', style: TextStyle(fontSize: 12)),
                    selected: state.followUpFilter == 'all',
                    onSelected: (val) => context.read<CrmLeadsBloc>().add(const CrmLeadsFollowUpFilterChanged('all')),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (followUps.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.event_available_rounded, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text('No follow-ups scheduled for this period.', style: TextStyle(color: textMuted)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: followUps.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final f = followUps[index];
                final dateStr = '${f.scheduledDate.day}/${f.scheduledDate.month}/${f.scheduledDate.year}';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.schedule_rounded, color: Color(0xFFEA580C), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  f.leadName ?? 'Lead Follow-up',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$dateStr at ${f.scheduledTime}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (f.leadPhone != null) ...[
                              Text('Phone: ${f.leadPhone}', style: TextStyle(fontSize: 13, color: textMuted)),
                              const SizedBox(height: 2),
                            ],
                            if (f.remarks != null && f.remarks!.isNotEmpty)
                              Text('Notes: ${f.remarks}', style: TextStyle(fontSize: 13, color: textMuted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: 'Click-to-Call',
                        icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF16A34A)),
                        onPressed: () {
                          context.read<CrmLeadsBloc>().add(CrmLeadsClickToCallRequested(f.leadId));
                        },
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

  // ---------------------------------------------------------------------------
  // TAB 3: Call Recordings & Telephony Logs (Elision / Greeter CTI)
  // ---------------------------------------------------------------------------
  Widget _buildCallRecordingsTab(
    BuildContext context,
    CrmLeadsState state,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
    Color primaryColor,
  ) {
    final logs = state.callLogs;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header & Refresh
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.graphic_eq_rounded, size: 20, color: Color(0xFF16A34A)),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Call Recordings & Telephony Logs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track all incoming and outgoing Greeter CTI calls, talk durations, and listen to audio recordings.',
                    style: TextStyle(fontSize: 13, color: textMuted),
                  ),
                ],
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                tooltip: 'Reload Call Logs',
                onPressed: () => context.read<CrmLeadsBloc>().add(const CrmLeadsCallLogsFilterChanged()),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filters Toolbar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Filter Pills
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Date Filter:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted)),
                    _buildRecordingFilterChip(context, state, 'All Calls', 'all', isDark),
                    _buildRecordingFilterChip(context, state, "Today's Calls", 'today', isDark),
                    _buildRecordingFilterChip(context, state, 'Yesterday', 'yesterday', isDark),
                    _buildRecordingFilterChip(context, state, 'This Week', 'this_week', isDark),
                    _buildRecordingFilterChip(context, state, 'This Month', 'this_month', isDark),
                  ],
                ),
                const SizedBox(height: 14),

                // Secondary Filters (Status, Audio-Only, Search)
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Status Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: state.callRecordingFilterStatus,
                          dropdownColor: cardBg,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('All Dispositions')),
                            DropdownMenuItem(value: 'ANSWERED', child: Text('Answered / Completed')),
                            DropdownMenuItem(value: 'MISSED', child: Text('Missed Calls')),
                            DropdownMenuItem(value: 'BUSY', child: Text('Busy Calls')),
                            DropdownMenuItem(value: 'FAILED', child: Text('Failed / Error')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              context.read<CrmLeadsBloc>().add(CrmLeadsCallLogsFilterChanged(callStatus: val));
                            }
                          },
                        ),
                      ),
                    ),

                    // Audio Only Filter Pill
                    FilterChip(
                      selected: state.callRecordingsOnlyWithAudio,
                      label: const Text('🎙️ Audio Recordings Only'),
                      onSelected: (val) => context.read<CrmLeadsBloc>().add(CrmLeadsCallLogsFilterChanged(hasRecording: val)),
                    ),

                    // Search Field
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _recordingSearchController,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search number or lead...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          suffixIcon: _recordingSearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  onPressed: () {
                                    _recordingSearchController.clear();
                                    context.read<CrmLeadsBloc>().add(const CrmLeadsCallLogsFilterChanged(search: ''));
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        onChanged: (val) => context.read<CrmLeadsBloc>().add(CrmLeadsCallLogsFilterChanged(search: val.trim())),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Logs Content
          if (logs.isEmpty)
            Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone_missed_rounded, size: 48, color: textMuted),
                    const SizedBox(height: 12),
                    Text(
                      'No Call Recordings or Logs Found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try adjusting the date filter or placing a call from Pre-Sales.',
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Summary Stats
            Builder(
              builder: (context) {
                final answeredCount = logs.where((l) => ['ANSWERED', 'ANSWER', 'COMPLETED', 'SUCCESS'].contains(l.callStatus.toUpperCase())).length;
                final totalSeconds = logs.fold<int>(0, (sum, l) => sum + l.duration);
                final totalMinutes = (totalSeconds / 60).toStringAsFixed(1);

                return Column(
                children: [
                  // Analytics Strip
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF24201D) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 6,
                      children: [
                        Text('Total Calls: ${logs.length}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                        Text('Answered: $answeredCount', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                        Text('Total Talk Time: $totalMinutes mins', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0284C7))),
                      ],
                    ),
                  ),

                  // Call Logs List
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final isAnswered = ['ANSWERED', 'ANSWER', 'COMPLETED', 'SUCCESS'].contains(log.callStatus.toUpperCase());
                      final isInitiated = log.callStatus.toUpperCase() == 'INITIATED';
                      final isMissed = log.callStatus.contains('MISSED') || log.callStatus.contains('NOANSWER');
                      final isBusy = log.callStatus.contains('BUSY');
                      final hasAudio = log.recordingUrl != null && log.recordingUrl!.isNotEmpty;

                      final Color statusColor;
                      final IconData statusIcon;
                      final String statusLabel;

                      if (isAnswered) {
                        statusColor = const Color(0xFF16A34A);
                        statusIcon = Icons.phone_in_talk_rounded;
                        statusLabel = 'ANSWERED';
                      } else if (isInitiated) {
                        statusColor = const Color(0xFF0284C7);
                        statusIcon = Icons.ring_volume_rounded;
                        statusLabel = 'INITIATED (DIALING)';
                      } else if (isMissed) {
                        statusColor = const Color(0xFFF59E0B);
                        statusIcon = Icons.phone_missed_rounded;
                        statusLabel = 'MISSED';
                      } else if (isBusy) {
                        statusColor = const Color(0xFFEA580C);
                        statusIcon = Icons.phone_disabled_rounded;
                        statusLabel = 'BUSY';
                      } else {
                        statusColor = const Color(0xFFDC2626);
                        statusIcon = Icons.error_outline_rounded;
                        statusLabel = log.callStatus;
                      }

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            // Status Icon
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                statusIcon,
                                color: statusColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Main Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      SelectableText(
                                        log.customerNumber ?? 'Unknown Customer',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'monospace',
                                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                                        ),
                                      ),
                                      if (log.leadName != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            log.leadName!,
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                                          ),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        'Agent: ${log.agentNumber ?? 'N/A'}',
                                        style: TextStyle(fontSize: 12, color: textMuted),
                                      ),
                                      Text(
                                        'DID: ${log.did ?? 'General'}',
                                        style: TextStyle(fontSize: 12, color: textMuted),
                                      ),
                                      Text(
                                        isInitiated && log.duration == 0
                                            ? 'Status: Dialing...'
                                            : 'Duration: ${_formatDuration(log.duration)}',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                                      ),
                                      Text(
                                        _formatDateTime(log.callTime),
                                        style: TextStyle(fontSize: 12, color: textMuted),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Action Buttons
                            if (hasAudio)
                              ElevatedButton.icon(
                                onPressed: () => _showRecordingPlayerModal(context, log),
                                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                label: const Text('Play Audio'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              )
                            else
                              InkWell(
                                onTap: () => _showRecordingPlayerModal(context, log),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.black12,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_link_rounded, size: 14, color: textMuted),
                                      const SizedBox(width: 4),
                                      Text('Attach Audio', style: TextStyle(fontSize: 11, color: textMuted)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ],
    ),
  );
}

  Widget _buildRecordingFilterChip(
    BuildContext context,
    CrmLeadsState state,
    String label,
    String value,
    bool isDark,
  ) {
    final isSelected = state.callRecordingFilterDate == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          context.read<CrmLeadsBloc>().add(CrmLeadsCallLogsFilterChanged(dateFilter: value));
        }
      },
    );
  }

  void _showRecordingPlayerModal(BuildContext context, CrmCallLog log) {
    CrmAudioPlayerDialog.show(context, log);
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0s';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins == 0) return '${secs}s';
    return '${mins}m ${secs.toString().padLeft(2, '0')}s';
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    final year = local.year;
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute $ampm';
  }

  // ---------------------------------------------------------------------------
  // TAB 4: Pipeline & Deals
  // ---------------------------------------------------------------------------
  Widget _buildPipelineTab(bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.view_kanban_outlined, size: 54, color: textMuted),
          const SizedBox(height: 12),
          Text('Pipeline Kanban Board', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          const SizedBox(height: 4),
          Text('Deals categorized by stages (Discovery, Site Visit, Negotiation, Won).', style: TextStyle(fontSize: 13, color: textMuted)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 4: Quotations
  // ---------------------------------------------------------------------------
  Widget _buildQuotationsTab(bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.request_quote_outlined, size: 54, color: textMuted),
          const SizedBox(height: 12),
          Text('Quotations & Estimates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          const SizedBox(height: 4),
          Text('Generate, share, and track property price quotes.', style: TextStyle(fontSize: 13, color: textMuted)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Elision Call & Automatic Follow-Up Trigger
  // ---------------------------------------------------------------------------
  Future<void> _handleElisionCallAndFollowUp(BuildContext context, CrmLead lead) async {
    try {
      final callRes = await context.read<CrmRepository>().clickToCall(lead.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(callRes['message']?.toString() ?? 'Initiated call to ${lead.phone}'),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}

    if (mounted) {
      _showFollowUpSchedulingModal(context, lead);
    }
  }

  // ---------------------------------------------------------------------------
  // Modal: Follow-up Scheduling (Date, Time, Remarks)
  // ---------------------------------------------------------------------------
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
            ],
          ),
          content: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
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
                              'Current Follow-up: ${DateFormat("dd MMM yyyy").format(lead.latestFollowUp!.scheduledDate.toLocal())} at ${lead.latestFollowUp!.scheduledTime}. Updating here will change the single active follow-up.',
                              style: const TextStyle(fontSize: 12, color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Text('Client Phone: ${lead.phone}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),

                  // Date Picker
                  const Text('Follow-up Date *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
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
                          Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                          const Icon(Icons.calendar_today_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Time Picker
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
                          Text(selectedTime.format(context)),
                          const Icon(Icons.access_time_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Remarks
                  const Text('Call Notes / Remarks', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: remarksCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Enter discussion notes, client feedback, or visit requirements...',
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
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final dateIso = selectedDate.toIso8601String().split('T').first;
                final timeFormatted = selectedTime.format(context);

                _updateLeadStatus(
                  lead.id,
                  'FOLLOW_UP',
                  scheduledDate: dateIso,
                  scheduledTime: timeFormatted,
                  remarks: remarksCtrl.text.trim(),
                );
              },
              child: const Text('Save & Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Modal: Merge Columns
  // ---------------------------------------------------------------------------
  void _showMergeColumnsDialog(BuildContext context, Color primaryColor) {
    final cols = context.read<CrmLeadsBloc>().state.columns;
    if (cols.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 columns are required to perform a merge.')),
      );
      return;
    }

    String sourceKey = cols[0].columnKey;
    String targetKey = cols[1].columnKey;
    String retainedLabel = cols[1].label;
    final labelCtrl = TextEditingController(text: retainedLabel);

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Merge Columns'),
          content: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      'Merge two columns that have the same meaning (e.g. "client_name" into "Name"). All existing lead data from Source will be transferred to Target, and Source column will be removed.',
                      style: TextStyle(fontSize: 12, color: primaryColor),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Source Column (To be merged & removed) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: sourceKey,
                    items: cols
                        .map((c) => DropdownMenuItem(
                              value: c.columnKey,
                              child: Text('${c.label} (${c.columnKey})', overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => sourceKey = val);
                      }
                    },
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),

                  const Text('Target Column (To keep & store data) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: targetKey,
                    items: cols
                        .map((c) => DropdownMenuItem(
                              value: c.columnKey,
                              child: Text('${c.label} (${c.columnKey})', overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          targetKey = val;
                          final match = cols.firstWhere((c) => c.columnKey == val);
                          retainedLabel = match.label;
                          labelCtrl.text = match.label;
                        });
                      }
                    },
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),

                  const Text('Final Retained Header Label *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Client Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
              onPressed: () async {
                if (sourceKey == targetKey) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Source and Target columns cannot be the same')),
                  );
                  return;
                }

                Navigator.pop(dialogCtx);
                context.read<CrmLeadsBloc>().add(
                      CrmLeadsColumnsMerged(
                        sourceKey: sourceKey,
                        targetKey: targetKey,
                        targetLabel: labelCtrl.text.trim(),
                      ),
                    );
              },
              child: const Text('Confirm & Merge'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Modal: Interested Status with HRMS Sales User Assignment
  // ---------------------------------------------------------------------------
  void _showInterestedSalesAssignmentModal(BuildContext context, CrmLead lead) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 14, minute: 0);
    final remarksCtrl = TextEditingController();

    final salesUsers = context.read<CrmLeadsBloc>().state.salesUsers;
    final uniqueUsers = <int, CrmSalesUser>{};
    for (final u in salesUsers) {
      uniqueUsers[u.employeeId] = u;
    }
    if (lead.assignedToId != null && !uniqueUsers.containsKey(lead.assignedToId)) {
      uniqueUsers[lead.assignedToId!] = CrmSalesUser(
        employeeId: lead.assignedToId!,
        fullName: lead.assignedToName ?? 'Employee #${lead.assignedToId}',
        designation: 'Sales',
      );
    }

    int? selectedEmployeeId = (lead.assignedToId != null && uniqueUsers.containsKey(lead.assignedToId))
        ? lead.assignedToId
        : (uniqueUsers.isNotEmpty ? uniqueUsers.keys.first : null);

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.thumb_up_rounded, color: Color(0xFF16A34A)),
              const SizedBox(width: 10),
              Expanded(child: Text('Interested Client: ${lead.name}')),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Assigning to a Sales Representative will hand over the deal. Telecallers will have view-only access thereafter.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sales User Dropdown from HRMS
                  const Text('Assign Sales Representative (HRMS) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (uniqueUsers.isEmpty)
                    const Text('Loading sales representatives...', style: TextStyle(fontSize: 12, color: Colors.grey))
                  else
                    DropdownButtonFormField<int?>(
                      isExpanded: true,
                      initialValue: selectedEmployeeId,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.badge_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      items: uniqueUsers.values.map((u) {
                        final label = u.designation != null && u.designation!.isNotEmpty
                            ? '${u.fullName} (${u.designation})'
                            : u.fullName;
                        return DropdownMenuItem<int?>(
                          value: u.employeeId,
                          child: Text(label, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setModalState(() => selectedEmployeeId = val),
                    ),
                  const SizedBox(height: 14),

                  // Meeting / Call Date
                  const Text('Sales Call / Meeting Date *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
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
                          Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                          const Icon(Icons.calendar_today_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Meeting / Call Time
                  const Text('Meeting / Call Time *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                          Text(selectedTime.format(context)),
                          const Icon(Icons.access_time_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Handover Notes
                  const Text('Handover Remarks / Client Preferences', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: remarksCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Budget, preferred unit size, location preferences, visit schedule...',
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
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final dateIso = selectedDate.toIso8601String().split('T').first;
                final timeFormatted = selectedTime.format(context);

                _updateLeadStatus(
                  lead.id,
                  'INTERESTED',
                  scheduledDate: dateIso,
                  scheduledTime: timeFormatted,
                  remarks: remarksCtrl.text.trim(),
                  assignedToId: selectedEmployeeId,
                );
              },
              child: const Text('Assign & Schedule Meeting'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Excel File Picker & Import Handler
  // ---------------------------------------------------------------------------
  Future<void> _handleExcelImport(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file data. Please try another file.')),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Importing "${file.name}"...')),
        );
      }

      context.read<CrmLeadsBloc>().add(
            CrmLeadsExcelImported(
              file.bytes!,
              file.name,
            ),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import Excel: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Dialog: Add Lead Dynamically
  // ---------------------------------------------------------------------------
  void _showAddLeadDialog(BuildContext context, List<CrmColumnConfig> columns) {
    final controllers = <String, TextEditingController>{};
    for (final col in columns) {
      controllers[col.columnKey] = TextEditingController();
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add New Pre-Sales Lead'),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: columns.map((col) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${col.label}${col.isRequired ? " *" : ""}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      if (col.dataType == 'SELECT' && col.options.isNotEmpty)
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          items: col.options
                              .map((opt) => DropdownMenuItem(value: opt, child: Text(opt, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) controllers[col.columnKey]?.text = val;
                          },
                        )
                      else if (col.dataType == 'PHONE' || col.columnKey == 'phone' || col.label.toLowerCase().contains('phone') || col.label.toLowerCase().contains('mobile'))
                        TextField(
                          controller: controllers[col.columnKey],
                          keyboardType: TextInputType.phone,
                          inputFormatters: mobileInputFormatters,
                          decoration: InputDecoration(
                            hintText: '10-digit number',
                            prefixIcon: buildMobilePrefix(isDark: Theme.of(context).brightness == Brightness.dark),
                            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                            border: const OutlineInputBorder(),
                          ),
                        )
                      else
                        TextField(
                          controller: controllers[col.columnKey],
                          keyboardType: col.dataType == 'NUMBER'
                              ? TextInputType.number
                              : TextInputType.text,
                          decoration: InputDecoration(
                            hintText: 'Enter ${col.label.toLowerCase()}',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final customFields = <String, dynamic>{};
              String phone = '';
              String name = '';

              for (final col in columns) {
                final val = controllers[col.columnKey]?.text.trim() ?? '';
                final lowerKey = col.columnKey.toLowerCase();
                if (lowerKey == 'phone' || lowerKey.contains('phone') || col.dataType == 'PHONE') {
                  if (phone.isEmpty && val.isNotEmpty) phone = val;
                } else if (lowerKey == 'name' || lowerKey.contains('name') || lowerKey.contains('client')) {
                  if (name.isEmpty && val.isNotEmpty) name = val;
                }
                customFields[col.columnKey] = val;
              }

              if (phone.isEmpty) {
                phone = customFields['phone']?.toString() ??
                    customFields['Phone']?.toString() ??
                    customFields['Phone_Number']?.toString() ??
                    '';
              }
              if (name.isEmpty) {
                name = customFields['name']?.toString() ??
                    customFields['client_name']?.toString() ??
                    customFields['Client_Name']?.toString() ??
                    customFields['Full_Name']?.toString() ??
                    '';
              }

              if (phone.isEmpty || phone.length != 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Phone number must be exactly 10 digits.')),
                );
                return;
              }

              final leadsState = context.read<CrmLeadsBloc>().state;
              final activeCampaignId = leadsState.selectedCampaignId;
              final campaigns = leadsState.campaigns;
              final effectiveCampaignId = (activeCampaignId != null && activeCampaignId.isNotEmpty)
                  ? activeCampaignId
                  : (campaigns.isNotEmpty ? campaigns.first.id : null);

              Navigator.pop(dialogCtx);

              context.read<CrmLeadsBloc>().add(
                    CrmLeadsLeadCreated({
                      'name': name.isEmpty ? 'Unnamed Lead' : name,
                      'phone': phone,
                      'status': 'NOT_STARTED',
                      'campaignId': effectiveCampaignId,
                      'customFields': customFields,
                    }),
                  );
            },
            child: const Text('Create Lead'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog: Edit Lead with Read-Only View for Telecallers on Assigned Leads
  // ---------------------------------------------------------------------------
  void _showEditLeadDialog(
    BuildContext context,
    CrmLead lead,
    List<CrmColumnConfig> columns,
    List<CrmSalesUser> salesUsers, {
    bool isReadOnly = false,
  }) {
    final controllers = <String, TextEditingController>{};
    for (final col in columns) {
      final initialVal = col.columnKey == 'client_name' || col.columnKey == 'name'
          ? lead.name
          : (col.columnKey == 'phone'
              ? cleanMobile10(lead.phone)
              : (lead.customFields[col.columnKey]?.toString() ?? ''));
      controllers[col.columnKey] = TextEditingController(text: initialVal);
    }

    final uniqueUsers = <int, CrmSalesUser>{};
    for (final u in salesUsers) {
      uniqueUsers[u.employeeId] = u;
    }
    if (lead.assignedToId != null && !uniqueUsers.containsKey(lead.assignedToId)) {
      uniqueUsers[lead.assignedToId!] = CrmSalesUser(
        employeeId: lead.assignedToId!,
        fullName: lead.assignedToName ?? 'Employee #${lead.assignedToId}',
        designation: 'Sales',
      );
    }

    int? selectedAssignee = (lead.assignedToId != null && uniqueUsers.containsKey(lead.assignedToId))
        ? lead.assignedToId
        : null;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setEditState) => AlertDialog(
          title: Row(
            children: [
              if (isReadOnly) ...[
                const Icon(Icons.lock_outline_rounded, color: Colors.amber),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  isReadOnly ? 'Lead Details (Read-Only)' : 'Edit Lead: ${lead.name}',
                ),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isReadOnly) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_rounded, color: Colors.amber, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This lead is assigned to ${lead.assignedToName ?? "Sales Rep"}. Telecallers have view-only access.',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Assigned Sales User dropdown
                  const Text('Assigned Sales Representative', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (isReadOnly)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.withValues(alpha: 0.08),
                      ),
                      child: Text(
                        lead.assignedToName ?? 'Unassigned',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    DropdownButtonFormField<int?>(
                      isExpanded: true,
                      initialValue: selectedAssignee,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.badge_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Unassigned')),
                        ...uniqueUsers.values.map((u) {
                          final label = u.designation != null && u.designation!.isNotEmpty
                              ? '${u.fullName} (${u.designation})'
                              : u.fullName;
                          return DropdownMenuItem<int?>(
                            value: u.employeeId,
                            child: Text(label, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (val) => setEditState(() => selectedAssignee = val),
                    ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  ...columns.map((col) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(col.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          if (col.dataType == 'PHONE' || col.columnKey == 'phone' || col.label.toLowerCase().contains('phone') || col.label.toLowerCase().contains('mobile'))
                            TextField(
                              controller: controllers[col.columnKey],
                              readOnly: isReadOnly,
                              keyboardType: TextInputType.phone,
                              inputFormatters: mobileInputFormatters,
                              decoration: InputDecoration(
                                hintText: '10-digit number',
                                prefixIcon: buildMobilePrefix(isDark: Theme.of(context).brightness == Brightness.dark),
                                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                border: const OutlineInputBorder(),
                                filled: isReadOnly,
                                fillColor: isReadOnly ? Colors.grey.withValues(alpha: 0.08) : null,
                              ),
                            )
                          else
                            TextField(
                              controller: controllers[col.columnKey],
                              readOnly: isReadOnly,
                              decoration: InputDecoration(
                                hintText: 'Enter ${col.label.toLowerCase()}',
                                border: const OutlineInputBorder(),
                                filled: isReadOnly,
                                fillColor: isReadOnly ? Colors.grey.withValues(alpha: 0.08) : null,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(isReadOnly ? 'Close' : 'Cancel'),
            ),
            if (!isReadOnly)
              ElevatedButton(
                onPressed: () async {
                  final customFields = <String, dynamic>{};
                  String phone = lead.phone;
                  String name = lead.name;

                  for (final col in columns) {
                    final val = controllers[col.columnKey]?.text.trim() ?? '';
                    if (col.columnKey == 'phone') phone = val;
                    if (col.columnKey == 'client_name') name = val;
                    customFields[col.columnKey] = val;
                  }

                  if (phone.isNotEmpty && phone.length != 10) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Phone number must be exactly 10 digits.')),
                    );
                    return;
                  }

                  Navigator.pop(dialogCtx);

                  context.read<CrmLeadsBloc>().add(
                        CrmLeadsLeadUpdated(lead.id, {
                          'name': name,
                          'phone': phone,
                          'customFields': customFields,
                          'assignedToId': selectedAssignee,
                        }),
                      );
                },
                child: const Text('Save Changes'),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmMoveToBin(BuildContext context, CrmLead lead) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move Lead to Bin?'),
        content: Text('Are you sure you want to move "${lead.name}" to the Bin? You can restore it later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CrmLeadsBloc>().add(CrmLeadsLeadMovedToBin(lead.id));
            },
            child: const Text('Move to Bin'),
          ),
        ],
      ),
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
                                    'Call Not Received: Auto-scheduled for +24 hours.',
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
                            border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('dd MMM yyyy (EEE)').format(selectedDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              const Icon(Icons.calendar_today_rounded, size: 18),
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
                            border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(selectedTime.format(ctx), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              const Icon(Icons.access_time_rounded, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text('Remark', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: remarkController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Enter call remark...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('Confirm Reschedule'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _updateLeadStatus(
                      lead.id,
                      'CNR',
                      scheduledDate: dateStr,
                      scheduledTime: timeStr,
                      remarks: remarkController.text.trim(),
                    );
                  },
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
    final remarkController = TextEditingController(text: 'Site visit scheduled.');

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
                      'Schedule A Site Visit',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Client Details Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CLIENT DETAILS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.person_outline_rounded, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    lead.name.isNotEmpty ? lead.name : 'Client Name Not Set',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.phone_outlined, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  lead.phone.isNotEmpty ? '+91 ${lead.phone}' : 'No phone',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                            if (lead.campaignName != null && lead.campaignName!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.campaign_rounded, size: 16),
                                  const SizedBox(width: 8),
                                  Text('Campaign: ${lead.campaignName}', style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('Site Visit Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                            border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('dd MMMM yyyy (EEEE)').format(selectedDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              const Icon(Icons.calendar_today_rounded, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text('Site Visit Time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                            border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(selectedTime.format(ctx), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              const Icon(Icons.access_time_rounded, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text('Notes / Visit Instructions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: remarkController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'e.g. Client interested in 3BHK tower A...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: const Text('Confirm Site Visit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _updateLeadStatus(
                      lead.id,
                      'SCHEDULED_VISIT',
                      scheduledDate: dateStr,
                      scheduledTime: timeStr,
                      scheduledVisitAt: visitDateTime.toIso8601String(),
                      remarks: remarkController.text.trim(),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNotInterestedModal(BuildContext context, CrmLead lead, CrmSettings? settings) {
    final configuredReasons = settings?.notInterestedReasons ?? [];
    final reasons = configuredReasons.isNotEmpty
        ? configuredReasons
        : [
            'Budget mismatch',
            'Found somewhere else',
            'Locality mismatch',
            'Others',
          ];

    String selectedReason = reasons.contains('Budget mismatch') ? 'Budget mismatch' : reasons.first;
    final remarkController = TextEditingController();
    String? remarkError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isOthers = selectedReason.trim().toLowerCase() == 'others';

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
                        'Select the reason why ${lead.name.isNotEmpty ? lead.name : "the client"} is not interested:',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 14),

                      const Text('Reason', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: reasons.contains(selectedReason) ? selectedReason : reasons.first,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedReason = val;
                              remarkError = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          const Text('Remark', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          if (isOthers) ...[
                            const SizedBox(width: 6),
                            const Text('(Mandatory for "Others")', style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w600)),
                          ] else ...[
                            const SizedBox(width: 6),
                            const Text('(Optional)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: remarkController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: isOthers ? 'Please describe reason in detail...' : 'Additional notes (optional)...',
                          errorText: remarkError,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (_) {
                          if (remarkError != null) {
                            setModalState(() => remarkError = null);
                          }
                        },
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
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Mark Not Interested'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final remark = remarkController.text.trim();
                    if (isOthers && remark.isEmpty) {
                      setModalState(() {
                        remarkError = 'Please enter a remark explaining the reason.';
                      });
                      return;
                    }

                    Navigator.pop(dialogCtx);
                    _updateLeadStatus(
                      lead.id,
                      'NOT_INTERESTED',
                      notInterestedReason: selectedReason,
                      notInterestedRemark: remark,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _updateLeadStatus(
    String leadId,
    String status, {
    String? scheduledDate,
    String? scheduledTime,
    String? scheduledVisitAt,
    String? remarks,
    int? assignedToId,
    String? notInterestedReason,
    String? notInterestedRemark,
  }) {
    context.read<CrmLeadsBloc>().add(
          CrmLeadsLeadStatusUpdated(
            leadId,
            status: status,
            scheduledDate: scheduledDate,
            scheduledTime: scheduledTime,
            scheduledVisitAt: scheduledVisitAt,
            remarks: remarks,
            assignedToId: assignedToId,
            notInterestedReason: notInterestedReason,
            notInterestedRemark: notInterestedRemark,
          ),
        );
  }
}
