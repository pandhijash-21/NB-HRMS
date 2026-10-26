import 'dart:async';
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
import '../widgets/crm_scope_selector.dart';
import '../widgets/crm_telecaller_status_dialog.dart';
import '../widgets/crm_send_whatsapp_dialog.dart';


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

  Timer? _idleTimer;
  Timer? _heartbeatTimer;
  DateTime _lastInteractionTime = DateTime.now();
  bool _isOnBreak = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    CrmRepository.crmScopeNotifier.addListener(_onScopeChanged);
    _setupInactivityTracker();
  }

  bool _isTelecallerUser() {
    if (!mounted) return false;
    final authState = context.read<AuthBloc>().state;
    final role = authState.user?.role;
    if (Permissions.isAdmin(role)) return false;
    if (authState.user?.employeeId == null) return false;
    final r = (role ?? '').toUpperCase();
    if (r.contains('ACCOUNT') ||
        r.contains('PANTRY') ||
        r.contains('DRIVER') ||
        r.contains('HOUSEKEEPING') ||
        r.contains('STORE') ||
        r.contains('PURCHASE') ||
        r.contains('LEGAL') ||
        r.contains('CEO') ||
        r.contains('DIRECTOR')) {
      return false;
    }
    return true;
  }

  void _setupInactivityTracker() {
    if (!_isTelecallerUser()) {
      _heartbeatTimer?.cancel();
      _idleTimer?.cancel();
      if (_isOnBreak) {
        setState(() => _isOnBreak = false);
      }
      return;
    }
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!_isOnBreak && mounted && _isTelecallerUser()) {
        context.read<CrmRepository>().reportTelecallerActivity('ACTIVE').catchError((_) => <String, dynamic>{});
      }
    });
    _onUserInteraction();
  }

  void _onUserInteraction() {
    if (!_isTelecallerUser()) return;
    final now = DateTime.now();
    _idleTimer?.cancel();

    if (_isOnBreak) {
      if (mounted) {
        setState(() => _isOnBreak = false);
      }
      context.read<CrmRepository>().reportTelecallerActivity('ACTIVE').then((_) {
        if (mounted) {
          context.read<CrmLeadsBloc>().add(const CrmLeadsLoadRequested());
        }
      }).catchError((_) {});
    } else if (now.difference(_lastInteractionTime).inSeconds > 45) {
      context.read<CrmRepository>().reportTelecallerActivity('ACTIVE').catchError((_) => <String, dynamic>{});
    }

    _lastInteractionTime = now;

    // Start 5-minute inactivity timer
    _idleTimer = Timer(const Duration(minutes: 5), () {
      if (mounted && !_isOnBreak && _isTelecallerUser()) {
        setState(() => _isOnBreak = true);
        context.read<CrmRepository>().reportTelecallerActivity('ON_BREAK').catchError((_) => <String, dynamic>{});
      }
    });
  }

  void _onScopeChanged() {
    if (mounted) {
      setState(() {});
      context.read<CrmLeadsBloc>().add(const CrmLeadsLoadRequested());
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _heartbeatTimer?.cancel();
    CrmRepository.crmScopeNotifier.removeListener(_onScopeChanged);
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
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _onUserInteraction(),
          onPointerMove: (_) => _onUserInteraction(),
          child: Focus(
            onKeyEvent: (_, __) {
              _onUserInteraction();
              return KeyEventResult.ignored;
            },
            child: Scaffold(
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
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  if (Permissions.isAdmin(authState.user?.role) ||
                      ['ADMIN', 'SUPER_ADMIN', 'SYSTEM_ADMIN'].contains(authState.user?.role.toUpperCase() ?? ''))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: OutlinedButton.icon(
                        onPressed: () => showTelecallerStatusDialog(
                          context,
                          onDispatched: () {
                            context.read<CrmLeadsBloc>().add(const CrmLeadsRefreshRequested());
                          },
                        ),
                        icon: const Icon(Icons.people_alt_rounded, size: 16),
                        label: const Text('Telecaller Activity'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryGold,
                          side: BorderSide(color: primaryGold.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                    ),
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
              body: Column(
                children: [
                  if (_isOnBreak && _isTelecallerUser())
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: const Color(0xFFD97706),
                      child: Row(
                        children: [
                          const Icon(Icons.coffee_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Status: On Break (Inactive for 5 minutes)',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  'New lead assignment is paused. Move mouse, scroll, or tap anywhere to resume active status.',
                                  style: TextStyle(color: Colors.white, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _onUserInteraction,
                            icon: const Icon(Icons.play_arrow_rounded, size: 16),
                            label: const Text('Resume Active'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFFB45309),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(), // Disables swipe gesture conflicts / carousel effect
                      children: [
                        _buildLeadsTableTab(context, state, authState, isDark, cardBg, borderColor, textMuted, primaryGold),
                        _buildFollowUpsTab(context, state, isDark, cardBg, borderColor, textMuted, primaryGold),
                        _buildCallRecordingsTab(context, state, isDark, cardBg, borderColor, textMuted, primaryGold),
                        _buildPipelineTab(isDark, cardBg, borderColor, textMuted),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
    final userName = (currentUser?.name ?? '').toUpperCase();
    final userUsername = (currentUser?.username ?? '').toUpperCase();
    final isItAdminEmp1 = userEmployeeId == 1 &&
        (userRole.contains('ITADMIN') ||
         userRole.contains('ADMIN') ||
         userName.contains('ITADMIN') ||
         userUsername.contains('ITADMIN') ||
         userUsername == '1');
    final canTransfer = Permissions.canTransferLeads(authState.permissions, authState.user?.role);
    final isAdmin = ['ADMIN', 'SUPER_ADMIN', 'SYSTEM_ADMIN'].contains(userRole);
    final canWrite = Permissions.canWriteCrmPreSales(authState.permissions, authState.user?.role);
    final repo = context.read<CrmRepository>();
    final isFinserve = repo.scope == 'NB_FINSERVE';

    final excelAssignedIds = state.settings?.excelAssignedTelecallerIds ?? [];
    final webhookAssignedIds = state.settings?.webhookAssignedTelecallerIds ?? [];

    final isExcelAssigned = userEmployeeId != null && excelAssignedIds.contains(userEmployeeId);
    final isWebhookAssigned = userEmployeeId != null && webhookAssignedIds.contains(userEmployeeId);

    final isOnlyExcel = !isAdmin && isExcelAssigned && !isWebhookAssigned;
    final isOnlyWebhook = !isAdmin && isWebhookAssigned && !isExcelAssigned;
    final effectiveFlow = isOnlyExcel ? 'EXCEL' : (isOnlyWebhook ? 'WEBHOOK' : state.leadFlowFilter);

    final filteredLeads = leads.where((l) {
      if (l.scope != repo.scope) return false;
      if (state.statusFilter == 'WL') {
        return l.isWaitingList;
      }
      // Leads directly assigned to this employee (as sales rep or telecaller) are always visible to them
      if (!isAdmin && userEmployeeId != null && (l.assignedToId == userEmployeeId || l.telecallerId == userEmployeeId)) {
        return true;
      }
      if (effectiveFlow == 'EXCEL') {
        return (l.leadSource == 'EXCEL' || l.leadSource == null) && !l.isManual;
      } else if (effectiveFlow == 'MANUAL') {
        return l.isManual || l.leadSource == 'MANUAL';
      } else if (effectiveFlow == 'WEBHOOK') {
        return l.leadSource == 'WEBHOOK' || l.leadSource == 'META';
      }
      return true;
    }).toList();

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
                        value: 'WL',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFD97706), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text('⏳ Waiting List (WL)', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309))),
                          ],
                        ),
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
                        value: 'ASSIGNED',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text('Assigned', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B))),
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
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (!isOnlyWebhook) ...[
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
                            ],
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
                        ),
                        if (isItAdminEmp1) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _handleCleanCrmData(context),
                              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                              label: const Text('Clean CRM Data'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
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
                      if (!isOnlyWebhook) ...[
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
                      ],
                      if (isAdmin) ...[
                        ElevatedButton.icon(
                          onPressed: () => _handleDistributeLeads(context),
                          icon: const Icon(Icons.bolt_rounded, size: 18),
                          label: Text('Distribute (${leads.where((l) => l.isWaitingList).length})'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (isItAdminEmp1) ...[
                        ElevatedButton.icon(
                          onPressed: () => _handleCleanCrmData(context),
                          icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                          label: const Text('Clean CRM Data'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
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
          const SizedBox(height: 12),

          // Flow Switcher / Assignment Enforced Banner
          if (isOnlyExcel)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.table_chart_rounded, size: 18, color: Color(0xFF16A34A)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '📊 Excel Leads Desk — You are assigned to handle Excel / Manual leads.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                    ),
                  ),
                ],
              ),
            )
          else if (isOnlyWebhook)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.campaign_rounded, size: 18, color: Color(0xFF2563EB)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '⚡ Meta & Webhook Campaigns Desk — You are assigned to handle online campaign leads.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.alt_route_rounded, size: 16, color: primaryColor),
                      const SizedBox(width: 6),
                      Text('Lead Flow Desk:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                    ],
                  ),
                  ChoiceChip(
                    label: Text('All Flows (${leads.length})'),
                    selected: state.leadFlowFilter == 'ALL',
                    onSelected: (val) {
                      if (val) context.read<CrmLeadsBloc>().add(const CrmLeadsLeadFlowFilterChanged('ALL'));
                    },
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.table_chart_rounded, size: 14, color: Color(0xFF16A34A)),
                    label: Text('Excel Leads (${leads.where((l) => (l.leadSource == 'EXCEL' || l.leadSource == null) && !l.isManual).length})'),
                    selected: state.leadFlowFilter == 'EXCEL',
                    onSelected: (val) {
                      if (val) context.read<CrmLeadsBloc>().add(const CrmLeadsLeadFlowFilterChanged('EXCEL'));
                    },
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.edit_note_rounded, size: 14, color: Color(0xFF8B5CF6)),
                    label: Text('Manual Leads (${leads.where((l) => l.isManual || l.leadSource == 'MANUAL').length})'),
                    selected: state.leadFlowFilter == 'MANUAL',
                    onSelected: (val) {
                      if (val) context.read<CrmLeadsBloc>().add(const CrmLeadsLeadFlowFilterChanged('MANUAL'));
                    },
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.campaign_rounded, size: 14, color: Color(0xFF2563EB)),
                    label: Text('Meta / Webhook Leads (${leads.where((l) => l.leadSource == 'WEBHOOK' || l.leadSource == 'META').length})'),
                    selected: state.leadFlowFilter == 'WEBHOOK',
                    onSelected: (val) {
                      if (val) context.read<CrmLeadsBloc>().add(const CrmLeadsLeadFlowFilterChanged('WEBHOOK'));
                    },
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.hourglass_top_rounded, size: 14, color: Color(0xFFD97706)),
                    label: Text('Waiting List (${leads.where((l) => l.isWaitingList).length})'),
                    selected: state.statusFilter == 'WL',
                    selectedColor: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                    onSelected: (val) {
                      context.read<CrmLeadsBloc>().add(CrmLeadsStatusFilterChanged(val ? 'WL' : 'ALL'));
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),

          // Dynamic Data Table with Custom Scrollbar
          if (state.status.isLoading && filteredLeads.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFC5A059)),
              ),
            )
          else if (state.status.isFailure && filteredLeads.isEmpty)
            Center(child: Text('Error loading leads: ${state.errorMessage}', style: const TextStyle(color: Colors.red)))
          else if (filteredLeads.isEmpty)
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
                    Text('No Pre-Sales Leads Found in this Flow', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                    const SizedBox(height: 6),
                    Text(isOnlyWebhook
                        ? 'New leads from Meta / Webhooks will appear here automatically.'
                        : 'Click "Import Excel" to upload leads or "Add Lead" to enter manually.',
                        style: TextStyle(fontSize: 13, color: textMuted)),
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
                        const DataColumn(label: Text('Flow', style: TextStyle(fontWeight: FontWeight.bold))),
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
                        DataColumn(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Allocated To', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              Tooltip(
                                message: 'Allocated To: Telecaller responsible for calling, qualification, and follow-ups. Click transfer button to re-allocate.',
                                child: Icon(Icons.info_outline_rounded, size: 15, color: textMuted),
                              ),
                            ],
                          ),
                        ),
                        DataColumn(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(isFinserve ? 'Assigned Manager' : 'Assigned To', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              Tooltip(
                                message: isFinserve
                                    ? 'Assigned Manager: Loan Officer / Sales Manager assigned for branch meeting, document processing, and closing.'
                                    : 'Assigned To: Sales Representative assigned by Visitor Desk when visitor visits site.',
                                child: Icon(Icons.info_outline_rounded, size: 15, color: textMuted),
                              ),
                            ],
                          ),
                        ),
                        ...columns.map((c) {
                          String labelText = c.label;
                          if (isFinserve) {
                            final lower = c.label.toLowerCase();
                            final keyLower = c.columnKey.toLowerCase();
                            if (lower.contains('requirement') || lower.contains('project') || keyLower.contains('loan')) {
                              labelText = 'Type of Loan';
                            } else if (lower == 'budget' || keyLower == 'budget') {
                              labelText = 'Amount';
                            }
                          }
                          return DataColumn(label: Text(labelText, style: const TextStyle(fontWeight: FontWeight.bold)));
                        }),
                        const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: List.generate(filteredLeads.length, (index) {
                        final lead = filteredLeads[index];

                        // Telecaller Limitation:
                        // Once a sales representative is assigned (assignedToId != null),
                        // telecallers can SEE the lead in their table, but the lead is strictly BLOCKED for telecallers
                        // (no editing, no status change, no transfer, no telecalling).
                        // Only Admins or the assigned Sales Representative themselves can alter the lead.
                        final isAssignedToSales = lead.assignedToId != null;
                        final isAssignedSalesRep = userEmployeeId != null && userEmployeeId == lead.assignedToId;
                        final isBooked = lead.status == CrmStatus.bookingConfirmed || lead.proposals.any((p) => p.isBooked);
                        final isBlockedForTelecaller = (isAssignedToSales && !isAdmin && !isAssignedSalesRep) || isBooked;
                        final canAlterLead = canWrite && !isBlockedForTelecaller && !isBooked;

                        return DataRow(
                          cells: [
                            DataCell(Text('${index + 1}')),
                            DataCell(
                              lead.leadSource == 'WEBHOOK' || lead.leadSource == 'META'
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('⚡ Meta', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                    )
                                  : (lead.isManual || lead.leadSource == 'MANUAL' || (lead.createdByName != null && lead.createdByName!.isNotEmpty))
                                      ? Tooltip(
                                          message: lead.createdByName != null && lead.createdByName!.isNotEmpty
                                              ? 'Manually added by ${lead.createdByName}'
                                              : 'Manually added lead',
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text('✍️ Manual', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                                                  ],
                                                ),
                                                if (lead.createdByName != null && lead.createdByName!.trim().isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    lead.createdByName!.trim(),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: isDark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text('📊 Excel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                        ),
                            ),

                            // Elision Phone Icon Column
                            DataCell(
                              IconButton(
                                tooltip: isBlockedForTelecaller
                                    ? 'Lead is handed over to Sales (${lead.assignedToName ?? "Sales Rep"}) — Telecalling is blocked.'
                                    : 'Click-to-Call via Elision',
                                icon: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isBlockedForTelecaller
                                        ? Colors.grey.withValues(alpha: 0.15)
                                        : const Color(0xFF16A34A).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isBlockedForTelecaller ? Icons.phone_disabled_rounded : Icons.phone_in_talk_rounded,
                                    color: isBlockedForTelecaller ? Colors.grey : const Color(0xFF16A34A),
                                    size: 18,
                                  ),
                                ),
                                onPressed: isBlockedForTelecaller
                                    ? () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Lead is assigned to Sales (${lead.assignedToName ?? "Sales Rep"}). Telecalling is blocked for telecallers.'),
                                            backgroundColor: Colors.amber.shade900,
                                          ),
                                        );
                                      }
                                    : () => _handleElisionCallAndFollowUp(context, lead),
                              ),
                            ),

                            // Status Column (Default NOT_STARTED, or ASSIGNED when Visitor Desk assigns)
                            DataCell(
                              _buildStatusDropdown(context, lead, canAlterLead, salesUsers),
                            ),

                            // Allocated To Column (Telecaller with Transfer button)
                            DataCell(
                              (lead.telecallerName != null && lead.telecallerName!.isNotEmpty)
                                  ? InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: (canAlterLead && canTransfer) ? () => _showTransferLeadModal(context, lead, salesUsers) : null,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.headset_mic_rounded, size: 12, color: Color(0xFF16A34A)),
                                            const SizedBox(width: 4),
                                            Text(
                                              lead.telecallerName!,
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                            ),
                                            if (canTransfer) ...[
                                              const SizedBox(width: 6),
                                              Tooltip(
                                                message: 'Transfer this lead to another telecaller',
                                                child: Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF16A34A).withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Icon(Icons.swap_horiz_rounded, size: 12, color: Color(0xFF16A34A)),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    )
                                  : InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: canTransfer ? () => _showTransferLeadModal(context, lead, salesUsers) : null,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD97706).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.hourglass_top_rounded, size: 12, color: Color(0xFFD97706)),
                                            const SizedBox(width: 4),
                                            const Text(
                                              'Waiting List (WL)',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                            ),
                                            if (canTransfer) ...[
                                              const SizedBox(width: 4),
                                              const Icon(Icons.swap_horiz_rounded, size: 12, color: Color(0xFFD97706)),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                            ),

                            // Assigned To Column (Sales Representative / Finserve Manager)
                            DataCell(
                              isFinserve
                                  ? InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: canAlterLead ? () => _showAssignSalesManagerModal(context, lead, salesUsers) : null,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: lead.assignedToId != null
                                              ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                                              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.12)),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: lead.assignedToId != null
                                                ? const Color(0xFF2563EB).withValues(alpha: 0.35)
                                                : (isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.25)),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              lead.assignedToId != null ? Icons.person_rounded : Icons.person_add_outlined,
                                              size: 13,
                                              color: lead.assignedToId != null ? const Color(0xFF2563EB) : (isDark ? Colors.white70 : Colors.grey.shade700),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              lead.assignedToName ?? 'Assign Manager',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: lead.assignedToId != null ? const Color(0xFF2563EB) : (isDark ? Colors.white70 : Colors.grey.shade700),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.arrow_drop_down_rounded,
                                              size: 16,
                                              color: lead.assignedToId != null ? const Color(0xFF2563EB) : (isDark ? Colors.white70 : Colors.grey.shade700),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : (lead.assignedToName != null && lead.assignedToName!.isNotEmpty)
                                      ? Tooltip(
                                          message: 'Assigned to Sales Representative by Visitor Desk',
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.35)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.badge_rounded, size: 12, color: Color(0xFF2563EB)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  lead.assignedToName!,
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : Tooltip(
                                          message: 'Awaiting client visit at Visitor Desk',
                                          child: Text('—', style: TextStyle(color: textMuted)),
                                        ),
                            ),

                            // Dynamic Columns (Honoring column visibility)
                            ...columns.map((c) {
                              String cellValue = '';
                              final keyLower = c.columnKey.toLowerCase().replaceAll(' ', '_');
                              final labelLower = c.label.toLowerCase();
                              if (keyLower == 'client_name' || keyLower == 'name' || keyLower == 'customer_name') {
                                cellValue = lead.name.isNotEmpty ? lead.name : (lead.customFields[c.columnKey]?.toString() ?? '');
                              } else if (keyLower == 'phone' || keyLower == 'mobile' || keyLower == 'contact' || keyLower == 'phone_number') {
                                cellValue = lead.phone.isNotEmpty ? lead.phone : (lead.customFields[c.columnKey]?.toString() ?? '');
                              } else if (isFinserve && (keyLower.contains('loan') || keyLower == 'project_type' || labelLower.contains('requirement') || labelLower.contains('project'))) {
                                cellValue = lead.customFields['Loan_Type']?.toString() ??
                                    lead.customFields['loan_type']?.toString() ??
                                    lead.customFields['Project_Type']?.toString() ??
                                    lead.customFields['project_type']?.toString() ??
                                    (lead.customFields[c.columnKey]?.toString() ?? '-');
                              } else if (isFinserve && (keyLower == 'budget' || keyLower == 'amount' || labelLower == 'budget' || labelLower == 'amount')) {
                                cellValue = lead.customFields['Amount']?.toString() ??
                                    lead.customFields['amount']?.toString() ??
                                    lead.customFields['Budget']?.toString() ??
                                    lead.customFields['budget']?.toString() ??
                                    (lead.customFields[c.columnKey]?.toString() ?? '-');
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
                                  if (isFinserve) ...[
                                    IconButton(
                                      icon: const Icon(Icons.assignment_turned_in_outlined, size: 18, color: Color(0xFF10B981)),
                                      tooltip: 'Loan Documents Checklist',
                                      onPressed: () => _showLeadDocsModal(
                                        context,
                                        lead,
                                        context.read<CrmLeadsBloc>().state.settings,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Color(0xFF2563EB)),
                                      tooltip: lead.assignedToName != null ? 'Reassign Sales Manager (${lead.assignedToName})' : 'Assign to Sales Manager',
                                      onPressed: () => _showAssignSalesManagerModal(context, lead, salesUsers),
                                    ),
                                  ],
                                  if ((isAdmin || !isBlockedForTelecaller) && canTransfer)
                                    IconButton(
                                      icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: Color(0xFF6366F1)),
                                      tooltip: 'Transfer Lead to another Telecaller',
                                      onPressed: () => _showTransferLeadModal(context, lead, salesUsers),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.chat_bubble_rounded, size: 18, color: Color(0xFF22C55E)),
                                    tooltip: 'Send WhatsApp Template (BotBiz)',
                                    onPressed: () => showSendWhatsappDialog(context, lead: lead),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      canAlterLead ? Icons.edit_outlined : Icons.lock_outline_rounded,
                                      size: 18,
                                      color: canAlterLead ? null : Colors.amber.shade700,
                                    ),
                                    tooltip: canAlterLead
                                        ? 'Edit Lead Details'
                                        : 'Assigned to Sales: ${lead.assignedToName ?? "Sales Rep"} (Blocked for Telecallers - View Only)',
                                    onPressed: () => _showEditLeadDialog(
                                      context,
                                      lead,
                                      columns,
                                      salesUsers,
                                      isReadOnly: !canAlterLead,
                                    ),
                                  ),
                                  if (canAlterLead && (isAdmin || !isBlockedForTelecaller))
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
      case CrmStatus.proposalSent:
        badgeBg = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.22 : 0.12);
        badgeFg = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
        badgeBorder = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.45 : 0.35);
        break;
      case CrmStatus.bookingConfirmed:
        badgeBg = const Color(0xFF16A34A).withValues(alpha: isDark ? 0.22 : 0.12);
        badgeFg = isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
        badgeBorder = const Color(0xFF16A34A).withValues(alpha: isDark ? 0.45 : 0.35);
        break;
      case CrmStatus.rejected:
        badgeBg = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.22 : 0.12);
        badgeFg = isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
        badgeBorder = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.45 : 0.35);
        break;
    }

    // If lead is booked or telecaller cannot alter this assigned lead, render locked badge
    final isLeadBooked = lead.status == CrmStatus.bookingConfirmed || lead.proposals.any((p) => p.isBooked);
    if (!canAlter || isLeadBooked) {
      final tooltipMsg = isLeadBooked
          ? 'Booking Confirmed — Lead is finalized and locked against all modifications.'
          : 'Lead is assigned to ${lead.assignedToName ?? "Sales Rep"} — Telecallers have view-only access.';
      return Tooltip(
        message: tooltipMsg,
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

    final isFinserve = CrmRepository.crmScopeNotifier.value == 'NB_FINSERVE';

    // Telecaller statuses:
    // In Finserve CRM: Not started, CNR, Follow Up, Not Interested, Assigned
    // In Real Estate CRM: Not started, CNR, Schedule A Visit, Not Interested
    final dropdownItems = isFinserve
        ? <CrmStatus>[
            CrmStatus.notStarted,
            CrmStatus.cnr,
            CrmStatus.followUp,
            CrmStatus.notInterested,
            CrmStatus.assigned,
          ]
        : <CrmStatus>[
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
              case CrmStatus.assigned:
                dotColor = const Color(0xFF6366F1);
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
              case CrmStatus.proposalSent:
                dotColor = const Color(0xFFF59E0B);
                break;
              case CrmStatus.bookingConfirmed:
                dotColor = const Color(0xFF16A34A);
                break;
              case CrmStatus.rejected:
                dotColor = const Color(0xFFEF4444);
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
            } else if (newStatus == CrmStatus.followUp) {
              _showFollowUpSchedulingModal(context, lead);
            } else if (newStatus == CrmStatus.notInterested) {
              _showNotInterestedModal(context, lead, context.read<CrmLeadsBloc>().state.settings);
            } else if (newStatus == CrmStatus.assigned) {
              if (lead.assignedToId != null) {
                _updateLeadStatus(lead.id, 'ASSIGNED');
              } else {
                _showAssignSalesManagerModal(context, lead, salesUsers);
              }
            } else if (newStatus == CrmStatus.scheduledVisit) {
              _showScheduleVisitModal(context, lead);
            } else if (newStatus == CrmStatus.notStarted) {
              _updateLeadStatus(lead.id, 'NOT_STARTED');
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

          if (state.status.isLoading && followUps.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFC5A059)),
              ),
            )
          else if (followUps.isEmpty)
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
          if (state.status.isLoading && logs.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFC5A059)),
              ),
            )
          else if (logs.isEmpty)
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
  // Modal: Assign Sales Manager (Finserve CRM)
  // ---------------------------------------------------------------------------
  void _showAssignSalesManagerModal(
    BuildContext context,
    CrmLead lead,
    List<CrmSalesUser> salesUsers,
  ) {
    final uniqueUsers = <int, CrmSalesUser>{};
    for (final u in salesUsers) {
      uniqueUsers[u.employeeId] = u;
    }
    if (lead.assignedToId != null && !uniqueUsers.containsKey(lead.assignedToId)) {
      uniqueUsers[lead.assignedToId!] = CrmSalesUser(
        employeeId: lead.assignedToId!,
        fullName: lead.assignedToName ?? 'Employee #${lead.assignedToId}',
        designation: 'Sales Manager',
      );
    }

    int? selectedManagerId = lead.assignedToId;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Assign Sales Manager',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
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
                    // Info banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Telecallers can assign or reassign this lead to a Sales Manager for finance advisory & loan closure.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Client details summary
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_outline_rounded, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  lead.name.isNotEmpty ? lead.name : 'Client Name Not Set',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                lead.phone.isNotEmpty ? '+91 ${lead.phone}' : 'No phone',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Select Sales Manager *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    if (uniqueUsers.isEmpty)
                      const Text('Loading sales managers from HRMS...', style: TextStyle(fontSize: 12, color: Colors.grey))
                    else
                      DropdownButtonFormField<int?>(
                        isExpanded: true,
                        initialValue: selectedManagerId,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.badge_outlined, size: 20),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Unassigned (None)', style: TextStyle(color: Colors.grey)),
                          ),
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
                        onChanged: (val) => setModalState(() => selectedManagerId = val),
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
                ),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.read<CrmLeadsBloc>().add(
                        CrmLeadsLeadUpdated(
                          lead.id,
                          {
                            'assignedToId': selectedManagerId,
                            if (selectedManagerId != null) 'status': 'ASSIGNED',
                          },
                        ),
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        selectedManagerId != null
                            ? 'Lead assigned to ${uniqueUsers[selectedManagerId]?.fullName ?? "Sales Manager"}'
                            : 'Lead unassigned',
                      ),
                      backgroundColor: const Color(0xFF16A34A),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text('Confirm Assignment'),
              ),
            ],
          );
        },
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
    final isFinserve = CrmRepository.crmScopeNotifier.value == 'NB_FINSERVE';

    final salesUsers = context.read<CrmLeadsBloc>().state.salesUsers;
    final uniqueUsers = <int, CrmSalesUser>{};
    for (final u in salesUsers) {
      uniqueUsers[u.employeeId] = u;
    }
    if (lead.assignedToId != null && !uniqueUsers.containsKey(lead.assignedToId)) {
      uniqueUsers[lead.assignedToId!] = CrmSalesUser(
        employeeId: lead.assignedToId!,
        fullName: lead.assignedToName ?? 'Employee #${lead.assignedToId}',
        designation: isFinserve ? 'Sales Manager' : 'Sales',
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
                      color: isFinserve ? const Color(0xFF2563EB).withValues(alpha: 0.08) : Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: isFinserve ? const Color(0xFF2563EB) : Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isFinserve
                                ? 'Assigning to a Sales Manager routes the lead for financial consultation. Telecallers retain full ability to manage and reassign.'
                                : 'Assigning to a Sales Representative will hand over the deal. Telecallers will have view-only access thereafter.',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sales User Dropdown from HRMS
                  Text(
                    isFinserve ? 'Assign Sales Manager (HRMS) *' : 'Assign Sales Representative (HRMS) *',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  if (uniqueUsers.isEmpty)
                    Text(
                      isFinserve ? 'Loading sales managers...' : 'Loading sales representatives...',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    )
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
              child: Text(isFinserve ? 'Assign Sales Manager' : 'Assign & Schedule Meeting'),
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

      final leadsState = context.read<CrmLeadsBloc>().state;
      _showExcelImportDialog(
        context: context,
        file: file,
        campaigns: leadsState.campaigns,
        salesUsers: leadsState.salesUsers,
        defaultCampaignId: leadsState.selectedCampaignId,
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
  // Dialog: Interactive Excel Lead Import & Assignment Configuration
  // ---------------------------------------------------------------------------
  void _showExcelImportDialog({
    required BuildContext context,
    required PlatformFile file,
    required List<CrmCampaign> campaigns,
    required List<CrmSalesUser> salesUsers,
    required String? defaultCampaignId,
  }) {
    String? selectedCampaignId = defaultCampaignId ?? (campaigns.isNotEmpty ? campaigns.first.id : null);
    String assignmentMode = 'ROUND_ROBIN';
    int? specificTelecallerId;
    List<int> multiSelectedTelecallerIds = [];

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final selectedEmployees = salesUsers.where((u) => multiSelectedTelecallerIds.contains(u.employeeId)).toList();

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.table_chart_rounded, color: Color(0xFF16A34A), size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import Excel Leads',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Choose campaign and assignment rules',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
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
                    // File tag
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file_rounded, size: 20, color: Color(0xFF16A34A)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              file.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${(file.size / 1024).toStringAsFixed(1)} KB',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Target Campaign
                    const Text('Assign to Campaign *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: selectedCampaignId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.campaign_rounded, size: 20),
                      ),
                      items: campaigns.map((c) {
                        return DropdownMenuItem<String?>(
                          value: c.id,
                          child: Text('${c.name} (${c.code})', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setModalState(() => selectedCampaignId = val),
                    ),
                    const SizedBox(height: 20),

                    // Lead Allocation Mode
                    const Text(
                      'Who should these leads be allocated to? (Telecaller) *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Initial status is set to "Not Started". Status becomes "Assigned" once Visitor Desk assigns a sales representative.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),

                    // Mode 1: Round-Robin
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: 'ROUND_ROBIN',
                      groupValue: assignmentMode,
                      title: const Text('Round-Robin across selected telecallers', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Distribute incoming rows evenly among chosen telecallers', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      onChanged: (val) => setModalState(() => assignmentMode = val ?? 'ROUND_ROBIN'),
                    ),

                    if (assignmentMode == 'ROUND_ROBIN') ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 32, bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => _showTelecallerMultiSelectDialog(
                                context: context,
                                salesUsers: salesUsers,
                                initialSelected: multiSelectedTelecallerIds,
                                onConfirm: (updated) => setModalState(() => multiSelectedTelecallerIds = updated),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.checklist_rounded, size: 18, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        multiSelectedTelecallerIds.isEmpty
                                            ? 'Click to select telecaller(s) with checkboxes...'
                                            : '${multiSelectedTelecallerIds.length} telecaller(s) selected (Click to modify)',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: multiSelectedTelecallerIds.isEmpty ? FontWeight.normal : FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down_rounded),
                                  ],
                                ),
                              ),
                            ),
                            if (selectedEmployees.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: selectedEmployees.map((emp) {
                                  return Chip(
                                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                    avatar: CircleAvatar(
                                      radius: 10,
                                      child: Text(emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 10)),
                                    ),
                                    label: Text(emp.fullName, style: const TextStyle(fontSize: 11)),
                                    deleteIcon: const Icon(Icons.close, size: 14),
                                    onDeleted: () => setModalState(() => multiSelectedTelecallerIds.remove(emp.employeeId)),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    // Mode 2: Specific Telecaller
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: 'SPECIFIC',
                      groupValue: assignmentMode,
                      title: const Text('Allocate all leads to a specific telecaller', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Every lead in this file is allocated to one telecaller', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      onChanged: (val) => setModalState(() => assignmentMode = val ?? 'SPECIFIC'),
                    ),

                    if (assignmentMode == 'SPECIFIC') ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 32, bottom: 8),
                        child: DropdownButtonFormField<int?>(
                          isExpanded: true,
                          initialValue: specificTelecallerId,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                            hintText: 'Choose specific telecaller...',
                          ),
                          items: salesUsers.map((u) {
                            return DropdownMenuItem<int?>(
                              value: u.employeeId,
                              child: Text('${u.fullName} (#${u.employeeId})', overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) => setModalState(() => specificTelecallerId = val),
                        ),
                      ),
                    ],

                    // Mode 3: Unassigned / Waiting list
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: 'UNASSIGNED',
                      groupValue: assignmentMode,
                      title: const Text('Leave unallocated / Waiting list (WL)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Leads will enter the waiting list or auto-dispatch queue', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      onChanged: (val) => setModalState(() => assignmentMode = val ?? 'UNASSIGNED'),
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
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Import Leads'),
                onPressed: () {
                  if (assignmentMode == 'ROUND_ROBIN' && multiSelectedTelecallerIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select at least one telecaller for round-robin assignment or choose another mode')),
                    );
                    return;
                  }
                  if (assignmentMode == 'SPECIFIC' && specificTelecallerId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select the specific telecaller to assign these leads to')),
                    );
                    return;
                  }

                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Importing "${file.name}"...')),
                  );

                  context.read<CrmLeadsBloc>().add(
                    CrmLeadsExcelImported(
                      file.bytes!,
                      file.name,
                      campaignId: selectedCampaignId,
                      assignmentMode: assignmentMode,
                      telecallerId: assignmentMode == 'SPECIFIC' ? specificTelecallerId : null,
                      assignedTelecallerIds: assignmentMode == 'ROUND_ROBIN' ? multiSelectedTelecallerIds : null,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog: Reusable Multi-Select Telecallers with Checkboxes
  // ---------------------------------------------------------------------------
  void _showTelecallerMultiSelectDialog({
    required BuildContext context,
    required List<CrmSalesUser> salesUsers,
    required List<int> initialSelected,
    required void Function(List<int> updated) onConfirm,
  }) {
    List<int> tempSelected = List<int>.from(initialSelected);
    String q = '';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final filtered = salesUsers.where((u) {
            final query = q.toLowerCase().trim();
            if (query.isEmpty) return true;
            return u.fullName.toLowerCase().contains(query) ||
                (u.designation ?? '').toLowerCase().contains(query) ||
                u.employeeId.toString().contains(query);
          }).toList();

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.checklist_rounded, color: Color(0xFF16A34A)),
                SizedBox(width: 8),
                Text('Select Telecallers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (val) => setDlgState(() => q = val),
                    decoration: InputDecoration(
                      hintText: 'Search telecaller...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => setDlgState(() {
                          tempSelected = salesUsers.map((u) => u.employeeId).toList();
                        }),
                        child: const Text('Select All', style: TextStyle(fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () => setDlgState(() {
                          tempSelected.clear();
                        }),
                        child: const Text('Clear All', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  SizedBox(
                    height: 220,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final u = filtered[i];
                        final checked = tempSelected.contains(u.employeeId);
                        return CheckboxListTile(
                          dense: true,
                          value: checked,
                          title: Text(u.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            u.designation?.isNotEmpty == true ? '${u.designation} (#${u.employeeId})' : '#${u.employeeId}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onChanged: (val) {
                            setDlgState(() {
                              if (val == true) {
                                tempSelected.add(u.employeeId);
                              } else {
                                tempSelected.remove(u.employeeId);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  onConfirm(tempSelected);
                },
                child: Text('Done (${tempSelected.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Modal: Transfer Lead to another Telecaller
  // ---------------------------------------------------------------------------
  void _showTransferLeadModal(
    BuildContext context,
    CrmLead lead,
    List<CrmSalesUser> salesUsers,
  ) {
    final authState = context.read<AuthBloc>().state;
    final canTransfer = Permissions.canTransferLeads(authState.permissions, authState.user?.role);
    if (!canTransfer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lead transfer is disabled for your role in RBAC permissions.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    int? selectedTelecallerId;
    final remarksCtrl = TextEditingController();
    String searchQuery = '';

    final currentTelecallerId = lead.telecallerId;
    final currentTelecallerName = (lead.telecallerName != null && lead.telecallerName!.isNotEmpty)
        ? lead.telecallerName!
        : 'Waiting List / Unallocated';

    final candidates = salesUsers.where((u) => u.employeeId != currentTelecallerId).toList();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          final filtered = candidates.where((u) {
            final q = searchQuery.toLowerCase().trim();
            if (q.isEmpty) return true;
            return u.fullName.toLowerCase().contains(q) ||
                (u.designation ?? '').toLowerCase().contains(q) ||
                (u.role ?? '').toLowerCase().contains(q) ||
                u.employeeId.toString().contains(q);
          }).toList();

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF6366F1), size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transfer Allocated Telecaller',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Reassign lead calling & follow-ups to another telecaller',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF24201D) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_rounded, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  lead.name.isNotEmpty ? lead.name : 'Unnamed Lead',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  lead.phone.isNotEmpty ? '+91 ${lead.phone}' : 'No phone',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              const Text('Allocated Telecaller: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                currentTelecallerName,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Select New Telecaller *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      onChanged: (val) => setModalState(() => searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search by telecaller name or designation...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text('No matching telecallers found', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final user = filtered[i];
                                final isSelected = selectedTelecallerId == user.employeeId;
                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  selectedTileColor: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                  leading: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                    child: Text(
                                      user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                                    ),
                                  ),
                                  title: Text(
                                    user.fullName,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  subtitle: Text(
                                    user.designation?.isNotEmpty == true
                                        ? '${user.designation} (#${user.employeeId})'
                                        : 'Employee #${user.employeeId}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF6366F1), size: 20)
                                      : null,
                                  onTap: () => setModalState(() => selectedTelecallerId = user.employeeId),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'Transfer Reason / Note (Optional)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: remarksCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Telecaller on leave, language preference, area re-assignment',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Once transferred, this lead will be immediately removed from your part and assigned to the selected person.',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
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
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('Confirm Transfer'),
                onPressed: () {
                  if (selectedTelecallerId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a telecaller to transfer this lead to')),
                    );
                    return;
                  }
                  Navigator.pop(dialogCtx);
                  context.read<CrmLeadsBloc>().add(
                    CrmLeadTransferRequested(
                      leadId: lead.id,
                      targetTelecallerId: selectedTelecallerId!,
                      remarks: remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Finserve: Loan Documents Auto-Checklist Widget & Inspection Modal
  // ---------------------------------------------------------------------------
  Widget _buildLeadDocChecklistWidget({
    required BuildContext context,
    required String selectedLoanType,
    required CrmSettings? settings,
    required Map<String, Map<String, dynamic>> uploadedDocs,
    required void Function(String docId, Map<String, dynamic> docData) onDocUploaded,
    required void Function(String docId) onDocRemoved,
    bool isReadOnly = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final requiredDocIds = settings?.loanTypeDocsMap[selectedLoanType] ?? [];
    final docTypesPool = settings?.loanDocTypes ?? CrmSettings.defaultLoanDocTypes;

    final attachedCount = requiredDocIds.where((id) => uploadedDocs.containsKey(id)).length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24201D) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2563EB).withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.assignment_turned_in_outlined, size: 18, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Application Documents ($selectedLoanType)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (attachedCount == requiredDocIds.length && requiredDocIds.isNotEmpty)
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$attachedCount of ${requiredDocIds.length} Attached',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: (attachedCount == requiredDocIds.length && requiredDocIds.isNotEmpty)
                        ? const Color(0xFF10B981)
                        : const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (requiredDocIds.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No documents configured for "$selectedLoanType" in Settings.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            )
          else
            ...requiredDocIds.map((docId) {
              final doc = docTypesPool.firstWhere(
                (d) => d.id == docId,
                orElse: () => CrmLoanDocType(
                  id: docId,
                  name: docId.replaceAll('_', ' ').toUpperCase(),
                  maxFileSizeMb: 5,
                ),
              );
              final isUploaded = uploadedDocs.containsKey(docId);
              final uploadedInfo = uploadedDocs[docId];

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isUploaded
                        ? const Color(0xFF10B981).withValues(alpha: 0.6)
                        : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                    width: isUploaded ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isUploaded ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: isUploaded ? const Color(0xFF10B981) : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  doc.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isUploaded ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Max ${doc.maxFileSizeMb} MB',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                ),
                              ),
                            ],
                          ),
                          if (isUploaded && uploadedInfo != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              '${uploadedInfo['fileName']} • ${uploadedInfo['fileSizeFormatted'] ?? ""}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isUploaded) ...[
                      if (!isReadOnly)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                          tooltip: 'Remove document',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          onPressed: () => onDocRemoved(docId),
                        ),
                    ] else if (!isReadOnly) ...[
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final res = await FilePicker.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
                              withData: true,
                            );
                            if (res != null && res.files.isNotEmpty) {
                              final file = res.files.first;
                              final maxBytes = doc.maxFileSizeMb * 1024 * 1024;
                              if (file.size > maxBytes) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'File size (${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB) exceeds maximum allowed limit of ${doc.maxFileSizeMb} MB.',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                                return;
                              }
                              final sizeFormatted = file.size > 1024 * 1024
                                  ? '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB'
                                  : '${(file.size / 1024).toStringAsFixed(0)} KB';
                              onDocUploaded(docId, {
                                'docId': docId,
                                'docName': doc.name,
                                'fileName': file.name,
                                'fileSize': file.size,
                                'fileSizeFormatted': sizeFormatted,
                                'uploadedAt': DateTime.now().toIso8601String(),
                              });
                            }
                          } catch (err) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('File selection failed: $err'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.upload_file_rounded, size: 14),
                        label: const Text('Attach', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showLeadDocsModal(BuildContext context, CrmLead lead, CrmSettings? settings) {
    String currentLoanType = lead.customFields['Loan_Type']?.toString() ??
        lead.customFields['loan_type']?.toString() ??
        lead.customFields['Project_Type']?.toString() ??
        (settings?.loanTypes.isNotEmpty == true ? settings!.loanTypes.first : 'Home Loan');

    final uploadedDocs = <String, Map<String, dynamic>>{};
    try {
      final rawDocs = lead.customFields['loan_documents'];
      if (rawDocs is List) {
        for (final item in rawDocs) {
          if (item is Map) {
            final docId = item['docId']?.toString() ?? item['id']?.toString() ?? '';
            if (docId.isNotEmpty) {
              uploadedDocs[docId] = Map<String, dynamic>.from(item);
            }
          }
        }
      }
    } catch (_) {}

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.folder_shared_rounded, color: Color(0xFF10B981)),
                const SizedBox(width: 10),
                Expanded(child: Text('Loan Documents: ${lead.name}')),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Loan Type Selector
                    Row(
                      children: [
                        const Text('Type of Loan:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: settings?.loanTypes.contains(currentLoanType) == true
                                ? currentLoanType
                                : (settings?.loanTypes.firstOrNull ?? currentLoanType),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: (settings?.loanTypes ?? [currentLoanType])
                                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => currentLoanType = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildLeadDocChecklistWidget(
                      context: modalCtx,
                      selectedLoanType: currentLoanType,
                      settings: settings,
                      uploadedDocs: uploadedDocs,
                      onDocUploaded: (docId, data) {
                        setModalState(() => uploadedDocs[docId] = data);
                      },
                      onDocRemoved: (docId) {
                        setModalState(() => uploadedDocs.remove(docId));
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(modalCtx), child: const Text('Close')),
              ElevatedButton.icon(
                onPressed: () {
                  final updatedCustomFields = Map<String, dynamic>.from(lead.customFields);
                  updatedCustomFields['Loan_Type'] = currentLoanType;
                  updatedCustomFields['loan_documents'] = uploadedDocs.values.toList();
                  context.read<CrmLeadsBloc>().add(
                        CrmLeadsLeadUpdated(lead.id, {
                          'customFields': updatedCustomFields,
                        }),
                      );
                  Navigator.pop(modalCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Loan documents updated successfully'), backgroundColor: Colors.green),
                  );
                },
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save Documents'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog: Add Lead Dynamically
  // ---------------------------------------------------------------------------
  void _showAddLeadDialog(BuildContext context, List<CrmColumnConfig> columns) {
    final controllers = <String, TextEditingController>{};
    for (final col in columns) {
      controllers[col.columnKey] = TextEditingController();
    }
    String selectedFlow = (context.read<CrmLeadsBloc>().state.leadFlowFilter == 'WEBHOOK')
        ? 'WEBHOOK'
        : (context.read<CrmLeadsBloc>().state.leadFlowFilter == 'EXCEL' ? 'EXCEL' : 'MANUAL');
    final settings = context.read<CrmLeadsBloc>().state.settings;
    String? selectedLoanType;
    final uploadedDocs = <String, Map<String, dynamic>>{};

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add New Pre-Sales Lead'),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lead Flow Selection
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Lead Flow / Acquisition Channel *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: selectedFlow,
                          isExpanded: true,
                          decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.alt_route_rounded)),
                          items: const [
                            DropdownMenuItem(value: 'MANUAL', child: Text('✍️ Manual Addition (Added by Admin / Telecaller)', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'EXCEL', child: Text('📊 Excel Flow (Auto-assign to Excel telecallers)', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'WEBHOOK', child: Text('⚡ Meta / Webhook Flow (Auto-assign to Meta telecallers)', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedFlow = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  ...columns.map((col) {
                    final isFinserve = CrmRepository.crmScopeNotifier.value == 'NB_FINSERVE';
                    final labelLower = col.label.toLowerCase();
                    final keyLower = col.columnKey.toLowerCase();
                    final isLoanTypeCol = isFinserve && (labelLower.contains('requirement') ||
                        labelLower.contains('project') ||
                        keyLower.contains('loan') ||
                        keyLower.contains('project'));
                    final isBudgetCol = isFinserve && (labelLower == 'budget' || keyLower == 'budget' || labelLower == 'amount' || keyLower == 'amount');

                    final displayLabel = isLoanTypeCol ? 'Type of Loan' : (isBudgetCol ? 'Amount' : col.label);

                    final settingsLoanTypes = settings?.loanTypes ?? const [
                      'Home Loan', 'Personal Loan', 'Business Loan', 'Mortgage / LAP', 'Auto Loan', 'Education Loan'
                    ];
                    final loanOptions = col.options.isNotEmpty ? col.options : settingsLoanTypes;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$displayLabel${col.isRequired ? " *" : ""}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      if (isLoanTypeCol)
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(
                            hintText: 'Select type of loan',
                            prefixIcon: Icon(Icons.account_balance_rounded, size: 20),
                            border: OutlineInputBorder(),
                          ),
                          items: loanOptions
                              .map((opt) => DropdownMenuItem(value: opt, child: Text(opt, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              controllers[col.columnKey]?.text = val;
                              controllers['Loan_Type']?.text = val;
                              setDialogState(() {
                                selectedLoanType = val;
                              });
                            }
                          },
                        )
                      else if (isBudgetCol)
                        TextField(
                          controller: controllers[col.columnKey],
                          keyboardType: TextInputType.text,
                          decoration: const InputDecoration(
                            hintText: 'Enter amount',
                            prefixIcon: Icon(Icons.currency_rupee_rounded, size: 20),
                            border: OutlineInputBorder(),
                          ),
                        )
                      else if (col.dataType == 'SELECT' && col.options.isNotEmpty)
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

              // Auto-Listed Documents Checklist for Selected Loan
              if (CrmRepository.crmScopeNotifier.value == 'NB_FINSERVE' &&
                  selectedLoanType != null &&
                  selectedLoanType!.isNotEmpty)
                _buildLeadDocChecklistWidget(
                  context: ctx,
                  selectedLoanType: selectedLoanType!,
                  settings: settings,
                  uploadedDocs: uploadedDocs,
                  onDocUploaded: (docId, data) {
                    setDialogState(() => uploadedDocs[docId] = data);
                  },
                  onDocRemoved: (docId) {
                    setDialogState(() => uploadedDocs.remove(docId));
                  },
                ),
            ],
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
            final isFinserve = CrmRepository.crmScopeNotifier.value == 'NB_FINSERVE';

            for (final col in columns) {
              final val = controllers[col.columnKey]?.text.trim() ?? '';
              final lowerKey = col.columnKey.toLowerCase();
              if (lowerKey == 'phone' || lowerKey.contains('phone') || col.dataType == 'PHONE') {
                if (phone.isEmpty && val.isNotEmpty) phone = val;
              } else if (lowerKey == 'name' || lowerKey.contains('name') || lowerKey.contains('client')) {
                if (name.isEmpty && val.isNotEmpty) name = val;
              }
              customFields[col.columnKey] = val;
              if (isFinserve) {
                if (lowerKey.contains('loan') || lowerKey.contains('project')) {
                  customFields['Loan_Type'] = val;
                }
                if (lowerKey == 'budget' || lowerKey == 'amount') {
                  customFields['Amount'] = val;
                }
              }
            }

            if (isFinserve) {
              if (selectedLoanType != null && selectedLoanType!.isNotEmpty) {
                customFields['Loan_Type'] = selectedLoanType;
              }
              customFields['loan_documents'] = uploadedDocs.values.toList();
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
                    'leadSource': selectedFlow,
                    'campaignId': effectiveCampaignId,
                    'customFields': customFields,
                  }),
                );
          },
          child: const Text('Create Lead'),
        ),
      ],
    ),
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
    final isFinserve = CrmRepository.crmScopeNotifier.value == 'NB_FINSERVE';
    final isLeadBooked = lead.status == CrmStatus.bookingConfirmed || lead.proposals.any((p) => p.isBooked);
    final effectiveReadOnly = isReadOnly || isLeadBooked;

    final controllers = <String, TextEditingController>{};
    for (final col in columns) {
      String initialVal = '';
      final keyLower = col.columnKey.toLowerCase().replaceAll(' ', '_');
      final labelLower = col.label.toLowerCase();
      final isNameCol = keyLower == 'client_name' ||
          keyLower == 'name' ||
          keyLower == 'customer_name' ||
          labelLower.contains('name') ||
          labelLower.contains('client');
      final isPhoneCol = keyLower == 'phone' ||
          keyLower == 'phone_number' ||
          keyLower == 'mobile' ||
          keyLower == 'contact' ||
          labelLower.contains('phone') ||
          labelLower.contains('mobile') ||
          col.dataType == 'PHONE';

      if (isNameCol) {
        initialVal = lead.name.isNotEmpty
            ? lead.name
            : (lead.customFields[col.columnKey]?.toString() ??
                lead.customFields['Client_Name']?.toString() ??
                lead.customFields['client_name']?.toString() ??
                '');
      } else if (isPhoneCol) {
        initialVal = cleanMobile10(lead.phone.isNotEmpty
            ? lead.phone
            : (lead.customFields[col.columnKey]?.toString() ??
                lead.customFields['Phone']?.toString() ??
                lead.customFields['phone']?.toString() ??
                ''));
      } else if (isFinserve &&
          (keyLower.contains('loan') ||
              keyLower.contains('project') ||
              labelLower.contains('project') ||
              labelLower.contains('requirement'))) {
        initialVal = lead.customFields['Loan_Type']?.toString() ??
            lead.customFields['loan_type']?.toString() ??
            lead.customFields['Project_Type']?.toString() ??
            lead.customFields['project_type']?.toString() ??
            (lead.customFields[col.columnKey]?.toString() ?? '');
      } else if (isFinserve &&
          (keyLower == 'budget' ||
              keyLower == 'amount' ||
              labelLower == 'budget' ||
              labelLower == 'amount')) {
        initialVal = lead.customFields['Amount']?.toString() ??
            lead.customFields['amount']?.toString() ??
            lead.customFields['Budget']?.toString() ??
            lead.customFields['budget']?.toString() ??
            (lead.customFields[col.columnKey]?.toString() ?? '');
      } else {
        initialVal = lead.customFields[col.columnKey]?.toString() ??
            lead.customFields[col.columnKey.toLowerCase()]?.toString() ??
            '';
      }
      controllers[col.columnKey] = TextEditingController(text: initialVal);
    }

    final settings = context.read<CrmLeadsBloc>().state.settings;
    String selectedLoanType = '';
    if (isFinserve) {
      selectedLoanType = lead.customFields['Loan_Type']?.toString() ??
          lead.customFields['loan_type']?.toString() ??
          lead.customFields['Project_Type']?.toString() ??
          lead.customFields['project_type']?.toString() ??
          (settings?.loanTypes.isNotEmpty == true ? settings!.loanTypes.first : 'Home Loan');
    }
    final uploadedDocs = <String, Map<String, dynamic>>{};
    try {
      final rawDocs = lead.customFields['loan_documents'];
      if (rawDocs is List) {
        for (final item in rawDocs) {
          if (item is Map) {
            final docId = item['docId']?.toString() ?? item['id']?.toString() ?? '';
            if (docId.isNotEmpty) {
              uploadedDocs[docId] = Map<String, dynamic>.from(item);
            }
          }
        }
      }
    } catch (_) {}

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setEditState) => AlertDialog(
            title: Row(
              children: [
                if (effectiveReadOnly) ...[
                  const Icon(Icons.lock_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    effectiveReadOnly
                        ? (isLeadBooked
                            ? 'Lead Details (Booking Confirmed - Locked)'
                            : 'Lead Details (Locked - In Sales)')
                        : 'Edit Lead: ${lead.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(dialogCtx),
                ),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (effectiveReadOnly) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isLeadBooked
                              ? Colors.green.withValues(alpha: isDark ? 0.2 : 0.12)
                              : Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isLeadBooked
                                ? Colors.green.withValues(alpha: isDark ? 0.45 : 0.35)
                                : Colors.amber.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isLeadBooked ? Icons.verified_rounded : Icons.lock_rounded,
                              color: isLeadBooked ? Colors.green : Colors.amber,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isLeadBooked
                                    ? '🎉 Booking Confirmed! This lead is finalized and completely locked. No further modifications can be made.'
                                    : 'This lead is assigned to Sales (${lead.assignedToName ?? "Sales Rep"}). Telecallers have view-only access. Edits and status changes are blocked.',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (lead.assignedToName != null || lead.telecallerName != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: isDark ? 0.12 : 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withValues(alpha: isDark ? 0.25 : 0.18)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.badge_outlined, size: 15, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Telecaller: ${lead.telecallerName ?? "Unallocated"}   •   Sales Rep: ${lead.assignedToName ?? "Unassigned"}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                  ...columns.map((col) {
                    final labelLower = col.label.toLowerCase();
                    final keyLower = col.columnKey.toLowerCase();
                    final isLoanTypeCol = isFinserve && (labelLower.contains('requirement') ||
                        labelLower.contains('project') ||
                        keyLower.contains('loan') ||
                        keyLower.contains('project'));
                    final isBudgetCol = isFinserve && (labelLower == 'budget' || keyLower == 'budget' || labelLower == 'amount' || keyLower == 'amount');

                    final displayLabel = isLoanTypeCol ? 'Type of Loan' : (isBudgetCol ? 'Amount' : col.label);

                    final settingsLoanTypes = context.read<CrmLeadsBloc>().state.settings?.loanTypes ?? const [
                      'Home Loan', 'Personal Loan', 'Business Loan', 'Mortgage / LAP', 'Auto Loan', 'Education Loan'
                    ];
                    final loanOptions = col.options.isNotEmpty ? col.options : settingsLoanTypes;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          if (isLoanTypeCol)
                            if (effectiveReadOnly)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey.withValues(alpha: 0.08),
                                ),
                                child: Text(controllers[col.columnKey]?.text ?? 'Not specified'),
                              )
                            else
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: loanOptions.contains(controllers[col.columnKey]?.text)
                                    ? controllers[col.columnKey]?.text
                                    : null,
                                decoration: const InputDecoration(
                                  hintText: 'Select type of loan',
                                  prefixIcon: Icon(Icons.account_balance_rounded, size: 20),
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  if (controllers[col.columnKey]?.text.isNotEmpty == true &&
                                      !loanOptions.contains(controllers[col.columnKey]?.text))
                                    DropdownMenuItem(
                                      value: controllers[col.columnKey]?.text,
                                      child: Text(controllers[col.columnKey]!.text, overflow: TextOverflow.ellipsis),
                                    ),
                                  ...loanOptions.map(
                                    (opt) => DropdownMenuItem(value: opt, child: Text(opt, overflow: TextOverflow.ellipsis)),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    controllers[col.columnKey]?.text = val;
                                    setEditState(() => selectedLoanType = val);
                                  }
                                },
                              )
                          else if (isBudgetCol)
                            TextField(
                              controller: controllers[col.columnKey],
                              readOnly: effectiveReadOnly,
                              decoration: InputDecoration(
                                hintText: 'Enter amount',
                                prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 20),
                                border: const OutlineInputBorder(),
                                filled: effectiveReadOnly,
                                fillColor: effectiveReadOnly ? Colors.grey.withValues(alpha: 0.08) : null,
                              ),
                            )
                          else if (col.dataType == 'PHONE' ||
                              col.columnKey.toLowerCase().contains('phone') ||
                              col.columnKey.toLowerCase().contains('mobile') ||
                              col.label.toLowerCase().contains('phone') ||
                              col.label.toLowerCase().contains('mobile'))
                            TextField(
                              controller: controllers[col.columnKey],
                              readOnly: effectiveReadOnly,
                              keyboardType: TextInputType.phone,
                              inputFormatters: mobileInputFormatters,
                              decoration: InputDecoration(
                                hintText: '10-digit number',
                                prefixIcon: buildMobilePrefix(isDark: Theme.of(context).brightness == Brightness.dark),
                                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                border: const OutlineInputBorder(),
                                filled: effectiveReadOnly,
                                fillColor: effectiveReadOnly ? Colors.grey.withValues(alpha: 0.08) : null,
                              ),
                            )
                          else
                            TextField(
                              controller: controllers[col.columnKey],
                              readOnly: effectiveReadOnly,
                              decoration: InputDecoration(
                                hintText: 'Enter ${col.label.toLowerCase()}',
                                border: const OutlineInputBorder(),
                                filled: effectiveReadOnly,
                                fillColor: effectiveReadOnly ? Colors.grey.withValues(alpha: 0.08) : null,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),

                  // Auto-Listed Documents Checklist for Selected Loan
                  if (isFinserve && selectedLoanType.isNotEmpty)
                    _buildLeadDocChecklistWidget(
                      context: ctx,
                      selectedLoanType: selectedLoanType,
                      settings: settings,
                      uploadedDocs: uploadedDocs,
                      isReadOnly: effectiveReadOnly,
                      onDocUploaded: (docId, data) {
                        setEditState(() => uploadedDocs[docId] = data);
                      },
                      onDocRemoved: (docId) {
                        setEditState(() => uploadedDocs.remove(docId));
                      },
                    ),
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
                  final customFields = Map<String, dynamic>.from(lead.customFields);
                  String phone = lead.phone;
                  String name = lead.name;

                  for (final col in columns) {
                    final val = controllers[col.columnKey]?.text.trim() ?? '';
                    final keyLower = col.columnKey.toLowerCase().replaceAll(' ', '_');
                    final labelLower = col.label.toLowerCase();
                    final isNameCol = keyLower == 'client_name' ||
                        keyLower == 'name' ||
                        keyLower == 'customer_name' ||
                        labelLower.contains('name') ||
                        labelLower.contains('client');
                    final isPhoneCol = keyLower == 'phone' ||
                        keyLower == 'phone_number' ||
                        keyLower == 'mobile' ||
                        keyLower == 'contact' ||
                        labelLower.contains('phone') ||
                        labelLower.contains('mobile') ||
                        col.dataType == 'PHONE';

                    if (isPhoneCol) {
                      final cleaned = cleanMobile10(val);
                      if (cleaned.isNotEmpty) phone = cleaned;
                      customFields[col.columnKey] = cleaned;
                      customFields['Phone'] = cleaned;
                      customFields['phone'] = cleaned;
                    } else if (isNameCol) {
                      if (val.isNotEmpty) name = val;
                      customFields[col.columnKey] = val;
                      customFields['Client_Name'] = val;
                      customFields['client_name'] = val;
                    } else {
                      customFields[col.columnKey] = val;
                    }

                    if (isFinserve) {
                      if (keyLower.contains('loan') || keyLower.contains('project')) {
                        customFields['Loan_Type'] = val;
                      }
                      if (keyLower == 'budget' || keyLower == 'amount') {
                        customFields['Amount'] = val;
                      }
                    }
                  }

                  if (isFinserve) {
                    if (selectedLoanType.isNotEmpty) {
                      customFields['Loan_Type'] = selectedLoanType;
                    }
                    customFields['loan_documents'] = uploadedDocs.values.toList();
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
                        }),
                      );
                },
                child: const Text('Save Changes'),
              ),
          ],
        ),
      );
    },
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

  Future<void> _handleDistributeLeads(BuildContext context) async {
    try {
      final repo = context.read<CrmRepository>();
      final res = await repo.dispatchWaitingQueue();
      final dispatched = res['dispatchedCount'] ?? 0;
      final remaining = res['remainingQueuedCount'] ?? 0;
      final active = res['activeTelecallersCount'] ?? 0;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '⚡ Auto-distributed $dispatched leads across $active active telecallers! ($remaining in Waiting List)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
        context.read<CrmLeadsBloc>().add(const CrmLeadsRefreshRequested());
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Failed to distribute leads: $e'),
          ),
        );
      }
    }
  }

  Future<void> _handleCleanCrmData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 26),
            SizedBox(width: 10),
            Text('Clean Real Estate CRM Data?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action is exclusively for ITADMIN (emp code 1).\n\nIt will wipe all Real Estate CRM pre-sales leads, follow-ups, and unbind call logs from the database without wiping the entire HRMS database.\n\nNB Finserve leads will NOT be affected.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              'Are you sure you want to proceed?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFDC2626)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, Clean CRM Data'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cleaning CRM pre-sales data...'), duration: Duration(seconds: 2)),
      );
      final repo = context.read<CrmRepository>();
      final res = await repo.wipeRealEstatePreSalesData();
      if (!context.mounted) return;
      final msg = res['message']?.toString() ?? 'Real Estate pre-sales data cleaned successfully!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF16A34A),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      );
      context.read<CrmLeadsBloc>().add(const CrmLeadsRefreshRequested());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Failed to clean CRM data: $e'),
          ),
        );
      }
    }
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
