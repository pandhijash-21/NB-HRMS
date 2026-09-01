import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;

import '../../../../core/router/app_back_button.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/crm_models.dart';
import '../crm_providers.dart';

class CrmPreSalesScreen extends ConsumerStatefulWidget {
  const CrmPreSalesScreen({super.key});

  @override
  ConsumerState<CrmPreSalesScreen> createState() => _CrmPreSalesScreenState();
}

class _CrmPreSalesScreenState extends ConsumerState<CrmPreSalesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  String _selectedStatusFilter = 'ALL';
  String _followUpFilter = 'today';

  // Call Recording Filters
  String _recordingDateFilter = 'all';
  String _recordingStatusFilter = 'ALL';
  final TextEditingController _recordingSearchController = TextEditingController();
  bool _recordingsOnlyWithAudio = false;

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
        ? const Color(0xFFC5A059).withOpacity(0.18)
        : const Color(0xFFE2E8F0);
    final textMuted = isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF64748B);
    final primaryGold = isDark ? const Color(0xFFC5A059) : const Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141210) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Pre-Sales Management'),
        leading: const AppBackButton(fallbackLocation: '/crm/dashboard'),
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: TabBar(
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
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(crmLeadsProvider.notifier).refresh();
              ref.invalidate(crmFollowUpsProvider);
              ref.invalidate(crmColumnsProvider);
              ref.invalidate(crmSalesUsersProvider);
              ref.invalidate(crmCallLogsProvider);
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // Disables swipe gesture conflicts / carousel effect
        children: [
          _buildLeadsTableTab(isDark, cardBg, borderColor, textMuted, primaryGold),
          _buildFollowUpsTab(isDark, cardBg, borderColor, textMuted, primaryGold),
          _buildCallRecordingsTab(isDark, cardBg, borderColor, textMuted, primaryGold),
          _buildPipelineTab(isDark, cardBg, borderColor, textMuted),
          _buildQuotationsTab(isDark, cardBg, borderColor, textMuted),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: Leads & Inquiries with Dynamic Columns & Telecaller Lock Rules
  // ---------------------------------------------------------------------------
  Widget _buildLeadsTableTab(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
    Color primaryColor,
  ) {
    final projectsAsync = ref.watch(crmProjectsProvider);
    final selectedProjectId = ref.watch(selectedProjectIdProvider);
    final campaignsAsync = ref.watch(crmCampaignsProvider);
    final selectedCampaignId = ref.watch(selectedCampaignIdProvider);
    final columnsAsync = ref.watch(crmColumnsProvider);
    final leadsAsync = ref.watch(crmLeadsProvider);
    final salesUsersAsync = ref.watch(crmSalesUsersProvider);
    final authState = ref.watch(authNotifierProvider);

    final currentUser = authState.user;
    final userRole = currentUser?.role.toUpperCase() ?? '';
    final userEmployeeId = currentUser?.employeeId;
    final isAdmin = ['ADMIN', 'SUPER_ADMIN', 'SYSTEM_ADMIN'].contains(userRole);

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
                  return projectsAsync.when(
                    data: (projects) {
                      final effectiveSelectedId = (selectedProjectId != null && projects.any((p) => p.id == selectedProjectId))
                          ? selectedProjectId
                          : 'ALL';

                      return DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: effectiveSelectedId,
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
                            ref.read(selectedProjectIdProvider.notifier).setProjectId(newProjId);
                            ref.read(selectedCampaignIdProvider.notifier).setCampaignId(null);
                            ref.read(crmLeadsFilterProvider.notifier).setCampaignId(null);
                            ref.invalidate(crmCampaignsProvider);
                            ref.invalidate(crmColumnsProvider);
                            ref.invalidate(crmLeadsProvider);
                            ref.invalidate(crmKpiProvider);
                          }
                        },
                      );
                    },
                    loading: () => const SizedBox(height: 40, child: Center(child: LinearProgressIndicator())),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                }

                Widget buildCampaignSelector() {
                  return campaignsAsync.when(
                    data: (campaigns) {
                      const allValue = 'ALL';
                      final hasValidSelection = selectedCampaignId != null &&
                          campaigns.any((c) => c.id == selectedCampaignId);
                      final effectiveSelectedId =
                          hasValidSelection ? selectedCampaignId! : allValue;

                      return DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: effectiveSelectedId,
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
                          ref.read(selectedCampaignIdProvider.notifier).setCampaignId(newCampId);
                          ref.read(crmLeadsFilterProvider.notifier).setCampaignId(newCampId);
                          ref.invalidate(crmColumnsProvider);
                          ref.invalidate(crmLeadsProvider);
                          ref.invalidate(crmKpiProvider);
                        },
                      );
                    },
                    loading: () => const SizedBox(height: 40, child: Center(child: LinearProgressIndicator())),
                    error: (_, __) => const SizedBox.shrink(),
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
                      ref.read(crmLeadsFilterProvider.notifier).setSearch(val.trim());
                    },
                  );
                }

                Widget buildStatusFilter() {
                  return DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedStatusFilter,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Statuses', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'NOT_STARTED', child: Text('Not started', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'FOLLOW_UP', child: Text('Follow up', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'INTERESTED', child: Text('Interested', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'NOT_INTERESTED', child: Text('Not interested', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedStatusFilter = val);
                        ref.read(crmLeadsFilterProvider.notifier).setStatus(val);
                      }
                    },
                  );
                }

                Widget buildActionButtons({bool expand = false}) {
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
                        columnsAsync.when(
                          data: (columns) => Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showAddLeadDialog(context, columns),
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
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
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
                      columnsAsync.when(
                        data: (columns) => ElevatedButton.icon(
                          onPressed: () => _showAddLeadDialog(context, columns),
                          icon: const Icon(Icons.person_add_rounded, size: 18),
                          label: const Text('Add Lead'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
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
                      const SizedBox(height: 12),
                      buildActionButtons(expand: true),
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
                    buildActionButtons(expand: false),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Dynamic Data Table with Custom Scrollbar
          columnsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
            error: (err, _) => Center(child: Text('Error loading columns: $err', style: const TextStyle(color: Colors.red))),
            data: (rawColumns) {
              final columns = rawColumns.where((c) => c.isVisibleInTable && c.isActive).toList();
              return leadsAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
                error: (err, _) => Center(child: Text('Error loading leads: $err', style: const TextStyle(color: Colors.red))),
                data: (leads) {
                  if (leads.isEmpty) {
                    return Container(
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
                    );
                  }

                  final salesUsers = salesUsersAsync.value ?? [];

                  return Container(
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
                            isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
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
                            const DataColumn(label: Text('Assigned Sales Rep', style: TextStyle(fontWeight: FontWeight.bold))),
                            ...columns.map((c) => DataColumn(label: Text(c.label, style: const TextStyle(fontWeight: FontWeight.bold)))),
                            const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: List.generate(leads.length, (index) {
                            final lead = leads[index];

                            // Telecaller Edit Lock Rule:
                            // If lead is assigned, ONLY Admin or the Assigned Sales Rep can alter it.
                            final isAssigned = lead.assignedToId != null;
                            final isAssignedSalesRep = userEmployeeId != null && userEmployeeId == lead.assignedToId;
                            final canAlterLead = !isAssigned || isAdmin || isAssignedSalesRep;

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
                                        color: const Color(0xFF16A34A).withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF16A34A), size: 18),
                                    ),
                                    onPressed: () => _handleElisionCallAndFollowUp(context, lead),
                                  ),
                                ),

                                // Status Column (Editable if permitted, locked badge if telecaller on assigned lead)
                                DataCell(
                                  _buildStatusDropdown(context, lead, canAlterLead),
                                ),

                                // Assigned Sales User Column (Interactive if permitted, locked badge if telecaller)
                                DataCell(
                                  _buildAssignedUserDropdown(
                                    context,
                                    lead,
                                    salesUsers,
                                    isDark,
                                    primaryColor,
                                    textMuted,
                                    canAlterLead,
                                  ),
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
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Interactive Assigned Sales User Dropdown in Table Cell (With Telecaller Lock)
  // ---------------------------------------------------------------------------
  Widget _buildAssignedUserDropdown(
    BuildContext context,
    CrmLead lead,
    List<CrmSalesUser> salesUsers,
    bool isDark,
    Color primaryColor,
    Color textMuted,
    bool canAlter,
  ) {
    // 1. Build a map of unique users by employeeId
    final uniqueUsers = <int, CrmSalesUser>{};
    for (final u in salesUsers) {
      uniqueUsers[u.employeeId] = u;
    }

    // 2. If the lead has an assignedToId that isn't in uniqueUsers yet, add it
    if (lead.assignedToId != null && !uniqueUsers.containsKey(lead.assignedToId)) {
      uniqueUsers[lead.assignedToId!] = CrmSalesUser(
        employeeId: lead.assignedToId!,
        fullName: lead.assignedToName ?? 'Employee #${lead.assignedToId}',
        designation: 'Sales',
      );
    }

    // 3. Dropdown value must either be null or one of the unique keys
    final selectedValue = (lead.assignedToId != null && uniqueUsers.containsKey(lead.assignedToId))
        ? lead.assignedToId
        : null;

    final isAssigned = selectedValue != null;
    final assignedName = isAssigned ? uniqueUsers[selectedValue]!.fullName : 'Unassigned';

    // If telecaller is locked out of altering this assigned lead:
    if (!canAlter && isAssigned) {
      return Tooltip(
        message: 'Assigned to $assignedName — Only Admins and assigned rep can alter.',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, size: 14, color: Colors.amber),
              const SizedBox(width: 6),
              Text(
                assignedName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isAssigned
            ? primaryColor.withOpacity(0.08)
            : (isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAssigned ? primaryColor.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: selectedValue,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down_rounded, size: 18, color: isAssigned ? primaryColor : textMuted),
          hint: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_outline_rounded, size: 14, color: textMuted),
              const SizedBox(width: 4),
              Text('Unassigned', style: TextStyle(fontSize: 12, color: textMuted)),
            ],
          ),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text('Unassigned', style: TextStyle(fontSize: 12, color: textMuted)),
            ),
            ...uniqueUsers.values.map((u) {
              return DropdownMenuItem<int?>(
                value: u.employeeId,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.badge_outlined, size: 14, color: primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      u.fullName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    if (u.designation != null && u.designation!.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text('(${u.designation})', style: TextStyle(fontSize: 11, color: textMuted)),
                    ],
                  ],
                ),
              );
            }),
          ],
          onChanged: (newEmpId) async {
            if (newEmpId == selectedValue) return;

            try {
              await ref.read(crmLeadsProvider.notifier).updateLead(lead.id, {
                'assignedToId': newEmpId,
              });

              final name = newEmpId != null && uniqueUsers.containsKey(newEmpId)
                  ? uniqueUsers[newEmpId]!.fullName
                  : 'Unassigned';

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(newEmpId != null ? 'Assigned to $name' : 'Lead unassigned'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update assignment: $e'), backgroundColor: Colors.red),
                );
              }
            }
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status Dropdown with Modal Triggers (With Telecaller Lock)
  // ---------------------------------------------------------------------------
  Widget _buildStatusDropdown(BuildContext context, CrmLead lead, bool canAlter) {
    Color badgeBg;
    Color badgeFg;

    switch (lead.status) {
      case CrmStatus.notStarted:
        badgeBg = Colors.grey.withOpacity(0.15);
        badgeFg = Colors.grey.shade700;
        break;
      case CrmStatus.followUp:
        badgeBg = const Color(0xFFEA580C).withOpacity(0.15);
        badgeFg = const Color(0xFFEA580C);
        break;
      case CrmStatus.interested:
        badgeBg = const Color(0xFF16A34A).withOpacity(0.15);
        badgeFg = const Color(0xFF16A34A);
        break;
      case CrmStatus.notInterested:
        badgeBg = const Color(0xFFEF4444).withOpacity(0.15);
        badgeFg = const Color(0xFFEF4444);
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CrmStatus>(
          value: lead.status,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down_rounded, size: 18, color: badgeFg),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: badgeFg),
          items: const [
            DropdownMenuItem(value: CrmStatus.notStarted, child: Text('Not started')),
            DropdownMenuItem(value: CrmStatus.followUp, child: Text('Follow up')),
            DropdownMenuItem(value: CrmStatus.interested, child: Text('Interested')),
            DropdownMenuItem(value: CrmStatus.notInterested, child: Text('Not interested')),
          ],
          onChanged: (newStatus) {
            if (newStatus == null || newStatus == lead.status) return;

            if (newStatus == CrmStatus.followUp) {
              _showFollowUpSchedulingModal(context, lead);
            } else if (newStatus == CrmStatus.interested) {
              _showInterestedSalesAssignmentModal(context, lead);
            } else if (newStatus == CrmStatus.notInterested) {
              _updateLeadStatus(lead.id, 'NOT_INTERESTED');
            } else {
              _updateLeadStatus(lead.id, 'NOT_STARTED');
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
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
    Color primaryColor,
  ) {
    final followUpsAsync = ref.watch(crmFollowUpsProvider(_followUpFilter));

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
                    selected: _followUpFilter == 'today',
                    onSelected: (val) => setState(() => _followUpFilter = 'today'),
                  ),
                  ChoiceChip(
                    label: const Text('Upcoming', style: TextStyle(fontSize: 12)),
                    selected: _followUpFilter == 'upcoming',
                    onSelected: (val) => setState(() => _followUpFilter = 'upcoming'),
                  ),
                  ChoiceChip(
                    label: const Text('All', style: TextStyle(fontSize: 12)),
                    selected: _followUpFilter == 'all',
                    onSelected: (val) => setState(() => _followUpFilter = 'all'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          followUpsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
            error: (err, _) => Center(child: Text('Error loading follow-ups: $err', style: const TextStyle(color: Colors.red))),
            data: (followUps) {
              if (followUps.isEmpty) {
                return Container(
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
                );
              }

              return ListView.separated(
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
                            color: const Color(0xFFEA580C).withOpacity(0.12),
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
                                      color: Colors.blue.withOpacity(0.12),
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
                            ref.read(crmRepositoryProvider).clickToCall(f.leadId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Dialing ${f.leadPhone ?? "lead"}...')),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
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
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
    Color primaryColor,
  ) {
    final filter = CrmCallLogsFilter(
      dateFilter: _recordingDateFilter,
      callStatus: _recordingStatusFilter,
      search: _recordingSearchController.text.trim(),
      hasRecording: _recordingsOnlyWithAudio,
    );

    final logsAsync = ref.watch(crmCallLogsProvider(filter));

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
                onPressed: () => ref.invalidate(crmCallLogsProvider),
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
                    _buildRecordingFilterChip('All Calls', 'all', isDark),
                    _buildRecordingFilterChip("Today's Calls", 'today', isDark),
                    _buildRecordingFilterChip('Yesterday', 'yesterday', isDark),
                    _buildRecordingFilterChip('This Week', 'this_week', isDark),
                    _buildRecordingFilterChip('This Month', 'this_month', isDark),
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
                          value: _recordingStatusFilter,
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
                            if (val != null) setState(() => _recordingStatusFilter = val);
                          },
                        ),
                      ),
                    ),

                    // Audio Only Filter Pill
                    FilterChip(
                      selected: _recordingsOnlyWithAudio,
                      label: const Text('🎙️ Audio Recordings Only'),
                      onSelected: (val) => setState(() => _recordingsOnlyWithAudio = val),
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
                                    setState(() {});
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Logs Content
          logsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Text('Error loading call logs: $err', style: const TextStyle(color: Colors.red)),
              ),
            ),
            data: (logs) {
              if (logs.isEmpty) {
                return Center(
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
                );
              }

              // Summary Stats
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
                        Text('Total Talk Time: ${totalMinutes} mins', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0284C7))),
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : Colors.black12,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('No Audio', style: TextStyle(fontSize: 11, color: textMuted)),
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
      ),
    );
  }

  Widget _buildRecordingFilterChip(String label, String value, bool isDark) {
    final isSelected = _recordingDateFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _recordingDateFilter = value);
      },
    );
  }

  void _showRecordingPlayerModal(BuildContext context, CrmCallLog log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.mic_rounded, color: Color(0xFF16A34A)),
            const SizedBox(width: 10),
            Expanded(child: Text('Call Audio: ${log.customerNumber ?? 'Customer'}')),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Call Date: ${_formatDateTime(log.callTime)}'),
              const SizedBox(height: 4),
              Text('Duration: ${_formatDuration(log.duration)} | Status: ${log.callStatus}'),
              const SizedBox(height: 16),
              const Text('Recording URL:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        log.recordingUrl ?? '',
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: 'Copy Audio URL',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: log.recordingUrl ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Audio URL copied to clipboard!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          if (log.recordingUrl != null && log.recordingUrl!.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                try {
                  web.window.open(log.recordingUrl!, '_blank');
                } catch (_) {}
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open / Listen Recording'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
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
      final callRes = await ref.read(crmRepositoryProvider).clickToCall(lead.id);
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
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
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

                await _updateLeadStatus(
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
    final cols = ref.read(crmColumnsProvider).value ?? [];
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
                      color: primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primaryColor.withOpacity(0.2)),
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
                    value: sourceKey,
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
                    value: targetKey,
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
                try {
                  final res = await ref.read(crmColumnsProvider.notifier).mergeColumns(
                    sourceKey: sourceKey,
                    targetKey: targetKey,
                    targetLabel: labelCtrl.text.trim(),
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res['message']?.toString() ?? 'Columns merged successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to merge columns: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
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

    final salesUsers = ref.read(crmSalesUsersProvider).value ?? [];
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
                      color: Colors.blue.withOpacity(0.08),
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
                      value: selectedEmployeeId,
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

                await _updateLeadStatus(
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

      final activeCampaignId = ref.read(selectedCampaignIdProvider);
      final importRes = await ref.read(crmLeadsProvider.notifier).importExcel(
            file.bytes!,
            file.name,
            campaignId: activeCampaignId,
          );

      ref.invalidate(crmLeadsProvider);
      ref.invalidate(crmColumnsProvider);
      ref.invalidate(crmCampaignsProvider);
      ref.invalidate(crmProjectsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(importRes['message']?.toString() ?? 'Excel imported successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
                      else
                        TextField(
                          controller: controllers[col.columnKey],
                          keyboardType: col.dataType == 'NUMBER' || col.dataType == 'PHONE'
                              ? TextInputType.phone
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

              if (phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Phone number is required.')),
                );
                return;
              }

              final activeCampaignId = ref.read(selectedCampaignIdProvider);
              final campaigns = ref.read(crmCampaignsProvider).value ?? [];
              final effectiveCampaignId = (activeCampaignId != null && activeCampaignId.isNotEmpty)
                  ? activeCampaignId
                  : (campaigns.isNotEmpty ? campaigns.first.id : null);

              Navigator.pop(dialogCtx);

              try {
                await ref.read(crmLeadsProvider.notifier).createLead({
                  'name': name.isEmpty ? 'Unnamed Lead' : name,
                  'phone': phone,
                  'status': 'NOT_STARTED',
                  'campaignId': effectiveCampaignId,
                  'customFields': customFields,
                });

                ref.invalidate(crmLeadsProvider);
                ref.invalidate(crmColumnsProvider);
                ref.invalidate(crmCampaignsProvider);
                ref.invalidate(crmProjectsProvider);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lead added successfully!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add lead: $e'), backgroundColor: Colors.red),
                  );
                }
              }
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
              ? lead.phone
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
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withOpacity(0.35)),
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
                        color: Colors.grey.withOpacity(0.08),
                      ),
                      child: Text(
                        lead.assignedToName ?? 'Unassigned',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    DropdownButtonFormField<int?>(
                      isExpanded: true,
                      value: selectedAssignee,
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
                          TextField(
                            controller: controllers[col.columnKey],
                            readOnly: isReadOnly,
                            decoration: InputDecoration(
                              hintText: 'Enter ${col.label.toLowerCase()}',
                              border: const OutlineInputBorder(),
                              filled: isReadOnly,
                              fillColor: isReadOnly ? Colors.grey.withOpacity(0.08) : null,
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

                  Navigator.pop(dialogCtx);

                  try {
                    await ref.read(crmLeadsProvider.notifier).updateLead(lead.id, {
                      'name': name,
                      'phone': phone,
                      'customFields': customFields,
                      'assignedToId': selectedAssignee,
                    });

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lead updated successfully!')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
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
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(crmLeadsProvider.notifier).moveToBin(lead.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lead "${lead.name}" moved to Bin')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Move to Bin'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateLeadStatus(
    String leadId,
    String status, {
    String? scheduledDate,
    String? scheduledTime,
    String? remarks,
    int? assignedToId,
  }) async {
    try {
      await ref.read(crmLeadsProvider.notifier).updateLeadStatus(
            leadId,
            status: status,
            scheduledDate: scheduledDate,
            scheduledTime: scheduledTime,
            remarks: remarks,
            assignedToId: assignedToId,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lead status updated to "$status"'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
