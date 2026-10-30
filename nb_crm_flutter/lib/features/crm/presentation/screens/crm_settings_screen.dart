import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/load_status.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../../core/tour/models/tour_models.dart';
import '../../../../core/tour/widgets/tour_target.dart';
import '../../data/crm_repository.dart';
import '../../domain/crm_models.dart';
import '../bloc/crm_settings_bloc.dart';
import '../widgets/crm_whatsapp_settings_widget.dart';
import '../widgets/crm_nineance_telephony_tab.dart';
import '../widgets/crm_scope_selector.dart';

class CrmSettingsScreen extends StatelessWidget {
  const CrmSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CrmSettingsBloc>(
      create: (ctx) => CrmSettingsBloc(
        crmRepository: ctx.read<CrmRepository>(),
      )..add(const CrmSettingsLoadRequested()),
      child: const _CrmSettingsView(),
    );
  }
}

class _PresalesCategoryMeta {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> badges;
  final List<String> previews;

  const _PresalesCategoryMeta({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.badges,
    required this.previews,
  });
}

class _CrmSettingsView extends StatefulWidget {
  const _CrmSettingsView();

  @override
  State<_CrmSettingsView> createState() => _CrmSettingsViewState();
}

class _CrmSettingsViewState extends State<_CrmSettingsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Controllers for Retention Settings
  final _notInterestedDaysController = TextEditingController(text: '30');
  final _binDaysController = TextEditingController(text: '30');
  final _quotationGeneralRemarksController = TextEditingController(text: CrmSettings.defaultQuotationGeneralRemarks);
  bool _quotationRemarksLoaded = false;

  // KPI Management Toggles
  bool _kpiShowActiveLeads = true;
  bool _kpiShowTodayFollowups = true;
  bool _kpiShowInterestedDeals = true;
  bool _kpiShowBinCount = true;
  bool _kpiShowTotalCalls = true;
  bool _kpiShowAnsweredCalls = true;
  bool _kpiShowMissedCalls = true;
  bool _kpiShowTalkTime = true;
  bool _kpiShowFreshLeads = true;
  bool _kpiShowConversionRate = true;
  bool _kpiLoaded = false;

  // Pre-Sales & Front Desk Configuration
  bool _presalesConfigLoaded = false;
  String? _activePresalesSection; // null = Hub Overview; or 'loans_docs', 'application_fields', 'lead_routing', 'workload_queue', 'site_visit', 'lead_sources', 'reference_types', 'not_interested'
  int _bankSubTab = 0; // 0 = Loan Products & Document Checklists, 1 = Master Document Pool
  List<String> _notInterestedReasons = [
    'Budget mismatch',
    'Found somewhere else',
    'Locality mismatch',
    'Others',
  ];
  List<String> _leadSources = [
    'Walk IN',
    'Channel Partner',
    'Reference',
  ];
  List<String> _referenceTypes = [
    'B2B',
    'Employee',
    'Other Client',
  ];
  int? _siteVisitDeskEmployeeId;
  List<int> _excelAssignedTelecallerIds = [];
  List<int> _webhookAssignedTelecallerIds = [];
  List<String> _loanTypes = [
    'Home Loan',
    'Personal Loan',
    'Business Loan',
    'Mortgage / LAP',
    'Auto Loan',
    'Education Loan',
  ];
  List<CrmLoanDocType> _loanDocTypes = List<CrmLoanDocType>.from(CrmSettings.defaultLoanDocTypes);
  Map<String, List<String>> _loanTypeDocsMap = Map<String, List<String>>.from(
    CrmSettings.defaultLoanTypeDocsMap.map((k, v) => MapEntry(k, List<String>.from(v))),
  );
  List<FinserveApplicationField> _finserveApplicationFields = List<FinserveApplicationField>.from(
    CrmSettings.defaultFinserveApplicationFields,
  );
  final _newLoanTypeController = TextEditingController();
  final _newDocNameController = TextEditingController();
  final _newDocMaxMbController = TextEditingController(text: '5');
  final _newReasonController = TextEditingController();
  final _newSourceController = TextEditingController();
  final _newRefTypeController = TextEditingController();

  int _maxTelecallerActiveWorkload = 20;
  Map<String, int> _telecallerMaxWorkloadMap = {};
  int _untouchedLeadTimeoutMinutes = 30;
  int _idleTimeoutMinutes = 5;
  WaitingQueueStatus? _waitingQueueStatus;
  bool _waitingQueueLoading = false;
  final _maxWorkloadController = TextEditingController(text: '20');
  final _untouchedTimeoutController = TextEditingController(text: '30');
  final _idleTimeoutController = TextEditingController(text: '5');

  bool _settingsHydrated = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    CrmRepository.crmScopeNotifier.addListener(_onScopeUpdated);
  }

  void _onScopeUpdated() {
    if (mounted) {
      _presalesConfigLoaded = false;
      _settingsHydrated = false;
      _kpiLoaded = false;
      _quotationRemarksLoaded = false;
      _activePresalesSection = null;
      _bankSubTab = 0;
      context.read<CrmSettingsBloc>().add(const CrmSettingsLoadRequested());
      setState(() {});
    }
  }

  @override
  void dispose() {
    CrmRepository.crmScopeNotifier.removeListener(_onScopeUpdated);
    _tabController.dispose();
    _notInterestedDaysController.dispose();
    _binDaysController.dispose();
    _newLoanTypeController.dispose();
    _newDocNameController.dispose();
    _newDocMaxMbController.dispose();
    _newReasonController.dispose();
    _newSourceController.dispose();
    _newRefTypeController.dispose();
    _maxWorkloadController.dispose();
    _untouchedTimeoutController.dispose();
    _idleTimeoutController.dispose();
    _quotationGeneralRemarksController.dispose();
    super.dispose();
  }

  void _syncSettings(CrmSettings settings) {
    if (!_settingsHydrated) {
      _notInterestedDaysController.text = settings.notInterestedRetentionDays.toString();
      _binDaysController.text = settings.binRetentionDays.toString();
      _settingsHydrated = true;
    }
    if (!_kpiLoaded) {
      _kpiShowActiveLeads = settings.kpiShowActiveLeads;
      _kpiShowTodayFollowups = settings.kpiShowTodayFollowups;
      _kpiShowInterestedDeals = settings.kpiShowInterestedDeals;
      _kpiShowBinCount = settings.kpiShowBinCount;
      _kpiShowTotalCalls = settings.kpiShowTotalCalls;
      _kpiShowAnsweredCalls = settings.kpiShowAnsweredCalls;
      _kpiShowMissedCalls = settings.kpiShowMissedCalls;
      _kpiShowTalkTime = settings.kpiShowTalkTime;
      _kpiShowFreshLeads = settings.kpiShowFreshLeads;
      _kpiShowConversionRate = settings.kpiShowConversionRate;
      _kpiLoaded = true;
    }
    if (!_quotationRemarksLoaded) {
      if (settings.quotationGeneralRemarks.isNotEmpty) {
        _quotationGeneralRemarksController.text = settings.quotationGeneralRemarks;
      }
      _quotationRemarksLoaded = true;
    }
    if (!_presalesConfigLoaded) {
      _notInterestedReasons = List<String>.from(settings.notInterestedReasons);
      _leadSources = List<String>.from(settings.leadSources);
      _referenceTypes = List<String>.from(settings.referenceTypes);
      _siteVisitDeskEmployeeId = settings.siteVisitDeskEmployeeId;
      _excelAssignedTelecallerIds = List<int>.from(settings.excelAssignedTelecallerIds);
      _webhookAssignedTelecallerIds = List<int>.from(settings.webhookAssignedTelecallerIds);
      _loanTypes = List<String>.from(settings.loanTypes);
      _loanDocTypes = List<CrmLoanDocType>.from(settings.loanDocTypes);
      _loanTypeDocsMap = Map<String, List<String>>.from(
        settings.loanTypeDocsMap.map((k, v) => MapEntry(k, List<String>.from(v))),
      );
      _finserveApplicationFields = List<FinserveApplicationField>.from(settings.finserveApplicationFields);
      _maxTelecallerActiveWorkload = settings.maxTelecallerActiveWorkload;
      _maxWorkloadController.text = _maxTelecallerActiveWorkload.toString();
      _telecallerMaxWorkloadMap = Map<String, int>.from(settings.telecallerMaxWorkloadMap);
      _untouchedLeadTimeoutMinutes = settings.untouchedLeadTimeoutMinutes;
      _untouchedTimeoutController.text = _untouchedLeadTimeoutMinutes.toString();
      _idleTimeoutMinutes = settings.idleTimeoutMinutes;
      _idleTimeoutController.text = _idleTimeoutMinutes.toString();
      _presalesConfigLoaded = true;
      _loadWaitingQueueStatus();
    }
  }

  Future<void> _loadWaitingQueueStatus() async {
    if (_waitingQueueLoading) return;
    setState(() => _waitingQueueLoading = true);
    try {
      final status = await context.read<CrmRepository>().getWaitingQueueStatus();
      if (mounted) {
        setState(() {
          _waitingQueueStatus = status;
          _waitingQueueLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _waitingQueueLoading = false);
    }
  }

  Future<void> _triggerQueueDispatch() async {
    try {
      final res = await context.read<CrmRepository>().dispatchWaitingQueue();
      if (mounted) {
        final dispatched = res['dispatchedCount'] ?? 0;
        final remaining = res['remainingQueuedCount'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dispatched $dispatched leads to active telecallers. $remaining waiting in queue.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadWaitingQueueStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to dispatch queue: $e'), backgroundColor: Colors.red),
        );
      }
    }
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

    final repo = context.read<CrmRepository>();
    final isFinserve = repo.scope == 'NB_FINSERVE';

    return BlocConsumer<CrmSettingsBloc, CrmSettingsState>(
      listener: (context, state) {
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
          );
        } else if (state.successMessage != null && state.successMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.successMessage!), backgroundColor: Colors.green),
          );
        }
        if (state.settings != null) {
          _syncSettings(state.settings!);
        }
      },
      builder: (context, state) {
        if (state.settings != null) {
          _syncSettings(state.settings!);
        }

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF141210) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Text(isFinserve ? 'Finserve CRM Settings' : 'CRM Settings & Configuration'),
            leading: const AppBackButton(fallbackLocation: '/crm/dashboard'),
            backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: TourTarget(
              id: TourIds.step('crm.settings', 2),
              child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: [
                Tab(text: isFinserve ? 'Pre-Sales Settings' : 'Pre-Sales & Front Desk'),
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF25D366)),
                      SizedBox(width: 6),
                      Text('WhatsApp Automation'),
                    ],
                  ),
                ),
                const Tab(text: '9ance Cloud Telephony'),
                const Tab(text: 'Dashboard KPI Management'),
                const Tab(text: 'Bin & Retention Policy'),
                const Tab(text: 'General Preferences'),
              ],
            ),
              ),
            ),
            actions: [
              CrmScopeSelectorWidget(
                onScopeChanged: () {
                  _settingsHydrated = false;
                  _kpiLoaded = false;
                  _presalesConfigLoaded = false;
                  _activePresalesSection = null;
                  _bankSubTab = 0;
                  context.read<CrmSettingsBloc>().add(const CrmSettingsLoadRequested());
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Refresh Settings',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  _settingsHydrated = false;
                  _kpiLoaded = false;
                  _presalesConfigLoaded = false;
                  _activePresalesSection = null;
                  _bankSubTab = 0;
                  context.read<CrmSettingsBloc>().add(const CrmSettingsLoadRequested());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('CRM configuration refreshed'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildPresalesFrontDeskTab(state, isDark, cardBg, borderColor, textMuted, primaryGold, isFinserve),
              CrmWhatsappSettingsWidget(
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textMuted: textMuted,
                primaryColor: primaryGold,
              ),
              state.settings == null
                  ? const Center(child: CircularProgressIndicator())
                  : CrmNineanceTelephonyTab(
                      settings: state.settings!,
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textMuted: textMuted,
                      onSettingsChanged: () {
                        context.read<CrmSettingsBloc>().add(const CrmSettingsLoadRequested());
                      },
                    ),
              _buildKpiManagementTab(state, isDark, cardBg, borderColor, textMuted, primaryGold),
              _buildRetentionPolicyTab(isDark, cardBg, borderColor, textMuted, primaryGold),
              _buildGeneralTab(isDark, cardBg, borderColor, textMuted),
            ],
          ),
        );
      },
    );
  }


  // ---------------------------------------------------------------------------
  // Tab 3: Dashboard KPI Management (Admin Control & Metrics Toggle)
  // ---------------------------------------------------------------------------
  Widget _buildKpiManagementTab(
    CrmSettingsState state,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
    Color primaryColor,
  ) {
    final kpi = state.kpiMetrics;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF6366F1), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dashboard KPI Management',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Admin Control: Toggle and customize which metrics, lead analytics, and 9ance telephony statistics appear on your CRM Dashboard.',
                          style: TextStyle(fontSize: 13, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Quick Actions Toolbar
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _kpiShowActiveLeads = true;
                        _kpiShowTodayFollowups = true;
                        _kpiShowInterestedDeals = true;
                        _kpiShowBinCount = true;
                        _kpiShowTotalCalls = true;
                        _kpiShowAnsweredCalls = true;
                        _kpiShowMissedCalls = true;
                        _kpiShowTalkTime = true;
                        _kpiShowFreshLeads = true;
                        _kpiShowConversionRate = true;
                      });
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: const Text('Enable All'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _kpiShowActiveLeads = true;
                        _kpiShowTodayFollowups = true;
                        _kpiShowInterestedDeals = true;
                        _kpiShowBinCount = true;
                        _kpiShowTotalCalls = false;
                        _kpiShowAnsweredCalls = false;
                        _kpiShowMissedCalls = false;
                        _kpiShowTalkTime = false;
                        _kpiShowFreshLeads = false;
                        _kpiShowConversionRate = false;
                      });
                    },
                    icon: const Icon(Icons.restart_alt_rounded, size: 16),
                    label: const Text('Default 4 KPIs'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Section 1: Lead Pipeline & Conversion Metrics
              Row(
                children: [
                  const Icon(Icons.insights_rounded, size: 20, color: Color(0xFF0284C7)),
                  const SizedBox(width: 8),
                  Text(
                    'Lead Pipeline & Conversion KPIs',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (kpi == null)
                state.status == LoadStatus.loading
                    ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                    : state.errorMessage != null
                        ? Text('Error loading stats: ${state.errorMessage}', style: const TextStyle(color: Colors.red))
                        : const SizedBox.shrink()
              else
                Column(
                  children: [
                    _buildKpiToggleCard(
                      title: 'Active Leads Pipeline',
                      subtitle: 'Total ongoing un-archived pre-sales leads across all campaigns.',
                      liveValue: '${kpi.totalActiveLeads}',
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF0284C7),
                      value: _kpiShowActiveLeads,
                      onChanged: (val) => setState(() => _kpiShowActiveLeads = val),
                      isDark: isDark,
                      borderColor: borderColor,
                    ),
                    const SizedBox(height: 10),
                    _buildKpiToggleCard(
                      title: 'Fresh / Not Started Leads',
                      subtitle: 'New leads ready to be contacted by telecallers.',
                      liveValue: '${kpi.freshLeads}',
                      icon: Icons.fiber_new_rounded,
                      color: const Color(0xFF3B82F6),
                      value: _kpiShowFreshLeads,
                      onChanged: (val) => setState(() => _kpiShowFreshLeads = val),
                      isDark: isDark,
                      borderColor: borderColor,
                    ),
                    const SizedBox(height: 10),
                    _buildKpiToggleCard(
                      title: 'Interested Deals',
                      subtitle: 'Qualified hot leads handed over to Sales Representatives.',
                      liveValue: '${kpi.interestedDeals}',
                      icon: Icons.thumb_up_rounded,
                      color: const Color(0xFF16A34A),
                      value: _kpiShowInterestedDeals,
                      onChanged: (val) => setState(() => _kpiShowInterestedDeals = val),
                      isDark: isDark,
                      borderColor: borderColor,
                    ),
                    const SizedBox(height: 10),
                    _buildKpiToggleCard(
                      title: 'Sales Conversion Rate (%)',
                      subtitle: 'Percentage of total active pipeline converted to Interested.',
                      liveValue: '${kpi.conversionRate}%',
                      icon: Icons.trending_up_rounded,
                      color: const Color(0xFFEC4899),
                      value: _kpiShowConversionRate,
                      onChanged: (val) => setState(() => _kpiShowConversionRate = val),
                      isDark: isDark,
                      borderColor: borderColor,
                    ),
                    const SizedBox(height: 10),
                    _buildKpiToggleCard(
                      title: 'In Bin / Archive',
                      subtitle: 'Restorable discarded leads safely quarantined in the Bin.',
                      liveValue: '${kpi.binCount}',
                      icon: Icons.delete_outline_rounded,
                      color: const Color(0xFFEF4444),
                      value: _kpiShowBinCount,
                      onChanged: (val) => setState(() => _kpiShowBinCount = val),
                      isDark: isDark,
                      borderColor: borderColor,
                    ),
                  ],
                ),
              const SizedBox(height: 28),

              // Section 2: Elision / Greeter Telephony Metrics
              Row(
                children: [
                  const Icon(Icons.phone_in_talk_rounded, size: 20, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Text(
                    '9ance Telephony & Dialing KPIs',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (kpi != null)
                Column(
                  children: [
                    _buildKpiToggleCard(
                      title: "Today's Scheduled Follow-up Calls",
                      subtitle: 'Pending follow-up calls requiring action today.',
                      liveValue: '${kpi.todayFollowUps}',
                      icon: Icons.schedule_rounded,
                      color: const Color(0xFFEA580C),
                      value: _kpiShowTodayFollowups,
                      onChanged: (val) => setState(() => _kpiShowTodayFollowups = val),
                      isDark: isDark,
                      borderColor: borderColor,
                    ),
                    const SizedBox(height: 10),
                    _buildKpiToggleCard(
                      title: 'Total Calls Logged',
                      subtitle: 'All inbound and outbound calls tracked via 9ance.',
                      liveValue: '${kpi.totalCalls}',
                      icon: Icons.phone_in_talk_rounded,
                      color: const Color(0xFF8B5CF6),
                      value: _kpiShowTotalCalls,
                      onChanged: (val) => setState(() => _kpiShowTotalCalls = val),
                      isDark: isDark,
                      borderColor: borderColor,
                    ),
                    const SizedBox(height: 10),
                    _buildKpiToggleCard(
                      title: 'Answered Calls',
                      subtitle: 'Successfully connected discussions with customers.',
                      liveValue: '${kpi.answeredCalls}',
                      icon: Icons.phone_callback_rounded,
                      color: const Color(0xFF10B981),
                      value: _kpiShowAnsweredCalls,
                      onChanged: (val) => setState(() => _kpiShowAnsweredCalls = val),
                      isDark: isDark,
                      borderColor: borderColor,
                    ),
                    const SizedBox(height: 10),
                    _buildKpiToggleCard(
                      title: 'Missed / Busy Calls',
                      subtitle: 'Unsuccessful dialing attempts requiring follow-up retry.',
                      liveValue: '${kpi.missedCalls}',
                      icon: Icons.phone_missed_rounded,
                      color: const Color(0xFFF59E0B),
                      value: _kpiShowMissedCalls,
                      onChanged: (val) => setState(() => _kpiShowMissedCalls = val),
                      isDark: isDark,
                      borderColor: borderColor,
                    ),
                    const SizedBox(height: 10),
                    _buildKpiToggleCard(
                      title: 'Total Talk Time',
                      subtitle: 'Cumulative conversation duration in minutes across all calls.',
                      liveValue: '${kpi.totalTalkTimeMinutes}m',
                      icon: Icons.timer_rounded,
                      color: const Color(0xFF06B6D4),
                      value: _kpiShowTalkTime,
                      onChanged: (val) => setState(() => _kpiShowTalkTime = val),
                      isDark: isDark,
                      borderColor: borderColor,
                    ),
                  ],
                ),
              const SizedBox(height: 28),

              // Save Button (Responsive)
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _saveKpiSettings,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save Dashboard KPI Preferences'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiToggleCard({
    required String title,
    required String subtitle,
    required String liveValue,
    required IconData icon,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? (value ? const Color(0xFF24201D) : const Color(0xFF191715)) : (value ? Colors.white : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? color.withValues(alpha: 0.4) : borderColor,
          width: value ? 1.5 : 1.0,
        ),
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Live: $liveValue',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(
            value: value,
            activeThumbColor: color,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 4: Bin & Retention Policy
  // ---------------------------------------------------------------------------
  Widget _buildRetentionPolicyTab(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
    Color primaryColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_delete_outlined, color: Color(0xFFEF4444), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lead Retention & Bin Policy',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configure days before inactive "Not interested" leads move to Bin, and Bin retention duration.',
                          style: TextStyle(fontSize: 13, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 20),

              // Not Interested Retention
              Text('Not Interested Lead Active Window (Days)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
              const SizedBox(height: 4),
              Text(
                'When telecaller marks a lead as "Not interested", it remains in Pre-sales for this duration before moving to Bin.',
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notInterestedDaysController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  suffixText: 'Days',
                  prefixIcon: const Icon(Icons.timer_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),

              // Bin Retention
              Text('Bin Retention Period (Days)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
              const SizedBox(height: 4),
              Text(
                'Leads in the Bin can be restored back to Pre-sales with "Not started" status at any point during this period.',
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _binDaysController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  suffixText: 'Days',
                  prefixIcon: const Icon(Icons.delete_sweep_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: _saveRetentionSettings,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Save Retention Rules'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 4: General Preferences
  // ---------------------------------------------------------------------------
  Widget _buildGeneralTab(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Material(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'General Preferences',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.currency_rupee_rounded, size: 22),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Default Currency',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        'INR (₹)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 22),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Telecaller Calling Window',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '09:30 AM – 07:00 PM',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.security_rounded, size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sales Rep Assignment Access Control',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Telecallers have view-only access once assigned to sales user.',
                              style: TextStyle(fontSize: 12, color: textMuted),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                    ],
                  ),
                ),
                const Divider(height: 32),

                // Quotation General Remarks Template
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC5A059).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.request_quote_rounded, color: Color(0xFFC5A059), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quotation General Remarks & Standard Terms',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Company-wide template that pre-fills standard terms on all customer quotations. Sales representatives can append deal-specific additional remarks.',
                            style: TextStyle(fontSize: 12, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _quotationGeneralRemarksController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'General Remarks / Terms & Conditions Template',
                    hintText: 'Enter numbered terms or notes that appear on customer quotations...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_rounded, size: 16),
                    label: const Text('Save Quotation Terms'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC5A059),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: _saveQuotationRemarks,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _saveKpiSettings() {
    context.read<CrmSettingsBloc>().add(CrmSettingsSaved({
      'kpi_show_active_leads': _kpiShowActiveLeads.toString(),
      'kpi_show_today_followups': _kpiShowTodayFollowups.toString(),
      'kpi_show_interested_deals': _kpiShowInterestedDeals.toString(),
      'kpi_show_bin_count': _kpiShowBinCount.toString(),
      'kpi_show_total_calls': _kpiShowTotalCalls.toString(),
      'kpi_show_answered_calls': _kpiShowAnsweredCalls.toString(),
      'kpi_show_missed_calls': _kpiShowMissedCalls.toString(),
      'kpi_show_talk_time': _kpiShowTalkTime.toString(),
      'kpi_show_fresh_leads': _kpiShowFreshLeads.toString(),
      'kpi_show_conversion_rate': _kpiShowConversionRate.toString(),
    }));
  }

  void _saveRetentionSettings() {
    context.read<CrmSettingsBloc>().add(CrmSettingsSaved({
      'not_interested_retention_days': _notInterestedDaysController.text.trim(),
      'bin_retention_days': _binDaysController.text.trim(),
    }));
  }

  void _saveQuotationRemarks() {
    context.read<CrmSettingsBloc>().add(CrmSettingsSaved({
      'quotation_general_remarks': _quotationGeneralRemarksController.text.trim(),
    }));
  }

  // ---------------------------------------------------------------------------
  // Tab 0: Pre-Sales & Front Desk Configuration (Modular Hub Architecture)
  // ---------------------------------------------------------------------------
  Widget _buildPresalesFrontDeskTab(
    CrmSettingsState state,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
    Color primaryColor,
    bool isFinserve,
  ) {
    final employees = state.employees;

    if (_activePresalesSection != null) {
      return _buildPresalesDetailView(
        sectionId: _activePresalesSection!,
        state: state,
        employees: employees,
        isDark: isDark,
        cardBg: cardBg,
        borderColor: borderColor,
        textMuted: textMuted,
        primaryColor: primaryColor,
        isFinserve: isFinserve,
      );
    }

    return _buildPresalesHubView(
      state: state,
      employees: employees,
      isDark: isDark,
      cardBg: cardBg,
      borderColor: borderColor,
      textMuted: textMuted,
      primaryColor: primaryColor,
      isFinserve: isFinserve,
    );
  }

  // ---------------------------------------------------------------------------
  // Pre-Sales Hub View (Clean Modular Tiles / Clickables)
  // ---------------------------------------------------------------------------
  Widget _buildPresalesHubView({
    required CrmSettingsState state,
    required List<CrmSalesUser> employees,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textMuted,
    required Color primaryColor,
    required bool isFinserve,
  }) {
    final categories = _getPresalesCategories(isFinserve, employees);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hub Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF26221E), const Color(0xFF1A1816)]
                    : [const Color(0xFFF1F5F9), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isFinserve ? Icons.account_balance_rounded : Icons.tune_rounded,
                    color: primaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              isFinserve
                                  ? 'Finserve Pre-Sales & Loan Setup Hub'
                                  : 'Pre-Sales & Front Desk Configuration Hub',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isFinserve ? 'FINSERVE SCOPE' : 'REAL ESTATE SCOPE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isFinserve
                            ? 'Select any module below to configure loan products, bank verification checklists, application forms, queue limits, and desk assignments.'
                            : 'Select any module below to configure front desk reception, marketing sources, telecaller assignment pools, and queue timeouts.',
                        style: TextStyle(fontSize: 13, color: textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: state.isSaving ? null : _savePresalesSettings,
                  icon: state.isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(state.isSaving ? 'Saving...' : 'Save All Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Overview KPI Chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (isFinserve) ...[
                _buildMetricChip(
                  icon: Icons.account_balance_rounded,
                  label: 'Loan Products',
                  value: '${_loanTypes.length}',
                  color: const Color(0xFF2563EB),
                ),
                _buildMetricChip(
                  icon: Icons.folder_special_rounded,
                  label: 'Doc Master',
                  value: '${_loanDocTypes.length} Docs',
                  color: const Color(0xFF10B981),
                ),
                _buildMetricChip(
                  icon: Icons.dynamic_form_rounded,
                  label: 'Form Fields',
                  value: '${_finserveApplicationFields.length}',
                  color: const Color(0xFF7C3AED),
                ),
              ] else ...[
                _buildMetricChip(
                  icon: Icons.folder_special_rounded,
                  label: 'Doc Master',
                  value: '${_loanDocTypes.length} Docs',
                  color: const Color(0xFF10B981),
                ),
                _buildMetricChip(
                  icon: Icons.how_to_reg_rounded,
                  label: 'Site Reception',
                  value: _siteVisitDeskEmployeeId != null ? 'Assigned' : 'Admin Only',
                  color: const Color(0xFF4F46E5),
                ),
                _buildMetricChip(
                  icon: Icons.source_rounded,
                  label: 'Lead Sources',
                  value: '${_leadSources.length}',
                  color: const Color(0xFF0284C7),
                ),
                _buildMetricChip(
                  icon: Icons.people_outline_rounded,
                  label: 'Referral Types',
                  value: '${_referenceTypes.length}',
                  color: const Color(0xFF9333EA),
                ),
              ],
              _buildMetricChip(
                icon: Icons.alt_route_rounded,
                label: 'Excel Desk',
                value: '${_excelAssignedTelecallerIds.length} Reps',
                color: const Color(0xFF16A34A),
              ),
              _buildMetricChip(
                icon: Icons.campaign_rounded,
                label: 'Meta Desk',
                value: '${_webhookAssignedTelecallerIds.length} Reps',
                color: const Color(0xFF3B82F6),
              ),
              _buildMetricChip(
                icon: Icons.speed_rounded,
                label: 'Workload Cap',
                value: 'Max ${_maxWorkloadController.text}/rep',
                color: const Color(0xFFF59E0B),
              ),
              _buildMetricChip(
                icon: Icons.hourglass_top_rounded,
                label: 'Waiting List',
                value: '${_waitingQueueStatus?.queuedLeadsCount ?? 0}',
                color: const Color(0xFFEF4444),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section Title
          Row(
            children: [
              Text(
                'CONFIGURATION MODULES (CLICK TO OPEN)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Divider(color: borderColor)),
            ],
          ),
          const SizedBox(height: 16),

          // Clickable Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isTwoCol = constraints.maxWidth >= 720;
              final cardWidth = isTwoCol
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: categories.map((cat) {
                  return SizedBox(
                    width: cardWidth,
                    child: _buildCategoryCard(
                      cat: cat,
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textMuted: textMuted,
                      primaryColor: primaryColor,
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Category Card Widget (Clickable Hub Tile)
  // ---------------------------------------------------------------------------
  Widget _buildCategoryCard({
    required _PresalesCategoryMeta cat,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textMuted,
    required Color primaryColor,
  }) {
    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: () {
          setState(() {
            _activePresalesSection = cat.id;
          });
        },
        borderRadius: BorderRadius.circular(16),
        hoverColor: cat.color.withValues(alpha: 0.05),
        splashColor: cat.color.withValues(alpha: 0.12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          cat.color.withValues(alpha: 0.22),
                          cat.color.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cat.color.withValues(alpha: 0.35)),
                    ),
                    child: Icon(cat.icon, color: cat.color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cat.subtitle,
                          style: TextStyle(fontSize: 12.5, color: textMuted, height: 1.35),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: cat.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Badges
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: cat.badges.map((b) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: cat.color.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      b,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: cat.color,
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (cat.previews.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: cat.previews.map((p) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF24201D) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        p,
                        style: TextStyle(
                          fontSize: 11,
                          color: textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Open & Configure',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: cat.color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 18, color: cat.color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pre-Sales Detail View (Dedicated Screen for Clicked Section)
  // ---------------------------------------------------------------------------
  Widget _buildPresalesDetailView({
    required String sectionId,
    required CrmSettingsState state,
    required List<CrmSalesUser> employees,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textMuted,
    required Color primaryColor,
    required bool isFinserve,
  }) {
    final categories = _getPresalesCategories(isFinserve, employees);
    _PresalesCategoryMeta? activeCat;
    for (final c in categories) {
      if (c.id == sectionId) {
        activeCat = c;
        break;
      }
    }
    // Fallback if not found
    if (activeCat == null) {
      activeCat = categories.first;
      sectionId = activeCat.id;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Navigation & Action Header
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _activePresalesSection = null),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('All Modules'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: activeCat.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(activeCat.icon, color: activeCat.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeCat.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeCat.subtitle,
                      style: TextStyle(fontSize: 12.5, color: textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              ElevatedButton.icon(
                onPressed: state.isSaving ? null : _savePresalesSettings,
                icon: state.isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(state.isSaving ? 'Saving...' : 'Save Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Horizontal Quick Switcher Bar (1-Tap Switch between categories)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  InkWell(
                    onTap: () => setState(() => _activePresalesSection = null),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.grid_view_rounded, size: 14),
                          SizedBox(width: 6),
                          Text('Overview Hub', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('•', style: TextStyle(color: Colors.grey)),
                  const SizedBox(width: 8),
                  ...categories.map((c) {
                    final isSelected = c.id == sectionId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        showCheckmark: false,
                        avatar: Icon(
                          c.icon,
                          size: 14,
                          color: isSelected ? Colors.white : c.color,
                        ),
                        label: Text(c.title),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                        ),
                        selectedColor: c.color,
                        backgroundColor: isDark ? const Color(0xFF24201D) : const Color(0xFFF8FAFC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isSelected ? c.color : borderColor,
                          ),
                        ),
                        onSelected: (_) {
                          setState(() {
                            _activePresalesSection = c.id;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Render Selected Category View Cleanly
          if (sectionId == 'loans_docs')
            _buildBankAndLoanDocumentsSection(
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              textMuted: textMuted,
              primaryColor: primaryColor,
            )
          else if (sectionId == 'doc_master')
            _buildMasterDocumentTypesCard(
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              textMuted: textMuted,
              primaryColor: primaryColor,
            )
          else if (sectionId == 'application_fields')
            _buildFinserveApplicationFieldsCard(
              context: context,
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              textMuted: textMuted,
              primaryColor: primaryColor,
            )
          else if (sectionId == 'lead_routing')
            _buildLeadRoutingSection(
              employees: employees,
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              textMuted: textMuted,
              primaryColor: primaryColor,
            )
          else if (sectionId == 'workload_queue')
            _buildWaitingQueueAndWorkloadCard(
              context: context,
              employees: employees,
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              textMuted: textMuted,
              primaryColor: primaryColor,
            )
          else if (sectionId == 'site_visit')
            _buildSiteVisitDeskSection(
              employees: employees,
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              textMuted: textMuted,
              primaryColor: primaryColor,
            )
          else if (sectionId == 'lead_sources')
            _buildLeadSourcesSection(
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              textMuted: textMuted,
              primaryColor: primaryColor,
            )
          else if (sectionId == 'reference_types')
            _buildReferenceTypesSection(
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              textMuted: textMuted,
              primaryColor: primaryColor,
            )
          else if (sectionId == 'not_interested')
            _buildNotInterestedReasonsSection(
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              textMuted: textMuted,
              primaryColor: primaryColor,
            ),

          const SizedBox(height: 28),

          // Bottom Navigation Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _activePresalesSection = null),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Back to Modules Hub'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: state.isSaving ? null : _savePresalesSettings,
                icon: state.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 20),
                label: Text(state.isSaving ? 'Saving...' : (isFinserve ? 'Save Pre-Sales Settings' : 'Save Pre-Sales Configurations')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Category Definitions Helper
  // ---------------------------------------------------------------------------
  List<_PresalesCategoryMeta> _getPresalesCategories(bool isFinserve, List<CrmSalesUser> employees) {
    if (isFinserve) {
      return [
        _PresalesCategoryMeta(
          id: 'loans_docs',
          title: 'Bank & Loan Products',
          subtitle: 'Configure loan products (Home Loan, Business Loan, LAP) and required bank verification checklists',
          icon: Icons.account_balance_rounded,
          color: const Color(0xFF2563EB),
          badges: [
            '${_loanTypes.length} Loan Products',
            'Checklist Mapping',
          ],
          previews: _loanTypes.take(4).toList(),
        ),
        _PresalesCategoryMeta(
          id: 'doc_master',
          title: 'Doc Master (Document Types)',
          subtitle: 'Add, edit, or remove master documents (PAN, Aadhaar, Bank Statement, etc.) and file size limits',
          icon: Icons.folder_special_rounded,
          color: const Color(0xFF10B981),
          badges: [
            '${_loanDocTypes.length} Master Document Types',
            'Max File Sizes & Formats',
          ],
          previews: _loanDocTypes.take(4).map((d) => d.name).toList(),
        ),
        _PresalesCategoryMeta(
          id: 'application_fields',
          title: 'Application Form Fields',
          subtitle: 'Personal, company, reference, and custom loan inquiry form fields schema',
          icon: Icons.dynamic_form_rounded,
          color: const Color(0xFF7C3AED),
          badges: [
            '${_finserveApplicationFields.length} Form Fields',
            '${_finserveApplicationFields.where((f) => f.enabled).length} Active',
          ],
          previews: const ['Personal Info', 'Company Details', 'References', 'Custom Fields'],
        ),
        _PresalesCategoryMeta(
          id: 'lead_routing',
          title: 'Lead Flow & Desk Routing',
          subtitle: 'Round-robin assignment pools for Excel uploads and Meta/Webhook campaigns',
          icon: Icons.alt_route_rounded,
          color: const Color(0xFF059669),
          badges: [
            '${_excelAssignedTelecallerIds.length} Excel Reps',
            '${_webhookAssignedTelecallerIds.length} Meta Reps',
          ],
          previews: const ['Excel Desk Round-Robin', 'Meta / Campaign Desk Round-Robin'],
        ),
        _PresalesCategoryMeta(
          id: 'workload_queue',
          title: 'Workload & Waiting Queue',
          subtitle: 'Max capacity limits, untouched timeouts, idle limits, and auto-dispatch',
          icon: Icons.speed_rounded,
          color: const Color(0xFFD97706),
          badges: [
            'Max ${_maxWorkloadController.text} Leads/Rep',
            '${_untouchedTimeoutController.text}m Untouched Limit',
            '${_waitingQueueStatus?.queuedLeadsCount ?? 0} In Queue',
          ],
          previews: const ['Live Agent Presence', 'Workload Thresholds', 'Waiting List Auto-Dispatch'],
        ),
        _PresalesCategoryMeta(
          id: 'not_interested',
          title: 'Not Interested Reasons',
          subtitle: 'Dropdown options displayed to telecallers when marking a lead as cold or dropped',
          icon: Icons.thumb_down_alt_outlined,
          color: const Color(0xFFDC2626),
          badges: [
            '${_notInterestedReasons.length} Reasons Defined',
          ],
          previews: _notInterestedReasons.take(3).toList(),
        ),
      ];
    }

    // Real Estate (NB Developer)
    String siteVisitRep = 'Admin Only';
    if (_siteVisitDeskEmployeeId != null) {
      for (final e in employees) {
        if (e.employeeId == _siteVisitDeskEmployeeId) {
          siteVisitRep = e.fullName;
          break;
        }
      }
    }

    return [
      _PresalesCategoryMeta(
        id: 'doc_master',
        title: 'Doc Master (Document Types)',
        subtitle: 'Manage master document types, verification checklists, and file size limits',
        icon: Icons.folder_special_rounded,
        color: const Color(0xFF10B981),
        badges: [
          '${_loanDocTypes.length} Master Document Types',
          'Max File Sizes & Formats',
        ],
        previews: _loanDocTypes.take(4).map((d) => d.name).toList(),
      ),
      _PresalesCategoryMeta(
        id: 'lead_routing',
        title: 'Lead Flow & Desk Routing',
        subtitle: 'Round-robin assignment pools for Excel uploads and Meta/Webhook campaigns',
        icon: Icons.alt_route_rounded,
        color: const Color(0xFF059669),
        badges: [
          '${_excelAssignedTelecallerIds.length} Excel Reps',
          '${_webhookAssignedTelecallerIds.length} Meta Reps',
        ],
        previews: const ['Excel Desk Round-Robin', 'Meta / Campaign Desk Round-Robin'],
      ),
      _PresalesCategoryMeta(
        id: 'workload_queue',
        title: 'Workload & Waiting Queue',
        subtitle: 'Max capacity limits, untouched timeouts, idle limits, and auto-dispatch',
        icon: Icons.speed_rounded,
        color: const Color(0xFFD97706),
        badges: [
          'Max ${_maxWorkloadController.text} Leads/Rep',
          '${_untouchedTimeoutController.text}m Untouched Limit',
          '${_waitingQueueStatus?.queuedLeadsCount ?? 0} In Queue',
        ],
        previews: const ['Live Agent Presence', 'Workload Thresholds', 'Waiting List Auto-Dispatch'],
      ),
      _PresalesCategoryMeta(
        id: 'site_visit',
        title: 'Site Visit & Reception Desk',
        subtitle: 'Designated front-desk employee in charge of visitor check-in at site',
        icon: Icons.how_to_reg_rounded,
        color: const Color(0xFF4F46E5),
        badges: [
          _siteVisitDeskEmployeeId != null ? 'In-Charge Assigned' : 'Admin Only',
        ],
        previews: [siteVisitRep],
      ),
      _PresalesCategoryMeta(
        id: 'lead_sources',
        title: 'Front Desk Lead Sources',
        subtitle: 'Channel options during visitor check-in (Walk IN, CP, Reference, etc.)',
        icon: Icons.source_rounded,
        color: const Color(0xFF0284C7),
        badges: [
          '${_leadSources.length} Active Sources',
        ],
        previews: _leadSources.take(3).toList(),
      ),
      _PresalesCategoryMeta(
        id: 'reference_types',
        title: 'Reference Sub-Categories',
        subtitle: 'Sub-types when a prospect indicates they were referred',
        icon: Icons.people_outline_rounded,
        color: const Color(0xFF9333EA),
        badges: [
          '${_referenceTypes.length} Referral Types',
        ],
        previews: _referenceTypes.take(3).toList(),
      ),
      _PresalesCategoryMeta(
        id: 'not_interested',
        title: 'Not Interested Reasons',
        subtitle: 'Dropdown options displayed to telecallers when marking a lead as cold or dropped',
        icon: Icons.thumb_down_alt_outlined,
        color: const Color(0xFFDC2626),
        badges: [
          '${_notInterestedReasons.length} Reasons Defined',
        ],
        previews: _notInterestedReasons.take(3).toList(),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Finserve Bank & Loan Documents Matrix Section
  // ---------------------------------------------------------------------------
  Widget _buildBankAndLoanDocumentsSection({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textMuted,
    required Color primaryColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-segmented toggle for Bank Section
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF24201D) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildSubTabButton(
                index: 0,
                icon: Icons.payments_rounded,
                label: 'Loan Products & Document Checklists (${_loanTypes.length})',
                isSelected: _bankSubTab == 0,
                primaryColor: primaryColor,
                isDark: isDark,
              ),
              _buildSubTabButton(
                index: 1,
                icon: Icons.file_copy_rounded,
                label: 'Master Bank Document Pool & File Limits (${_loanDocTypes.length})',
                isSelected: _bankSubTab == 1,
                primaryColor: primaryColor,
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        if (_bankSubTab == 0)
          _buildLoanProductsChecklistCard(
            isDark: isDark,
            cardBg: cardBg,
            borderColor: borderColor,
            textMuted: textMuted,
            primaryColor: primaryColor,
          )
        else
          _buildMasterDocumentTypesCard(
            isDark: isDark,
            cardBg: cardBg,
            borderColor: borderColor,
            textMuted: textMuted,
            primaryColor: primaryColor,
          ),
      ],
    );
  }

  Widget _buildSubTabButton({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color primaryColor,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () => setState(() => _bankSubTab = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2B2621) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? primaryColor
                  : (isDark ? Colors.white60 : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF1E293B))
                    : (isDark ? Colors.white60 : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Sub-card 1: Types of Loans & Document Selection Checklists
  Widget _buildLoanProductsChecklistCard({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textMuted,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_rounded, color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finserve: Types of Loan & Required Document Checklists',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure loan products and check which documents are required for each loan type. These documents will auto-list for customer loans.',
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: () => setState(() => _activePresalesSection = 'doc_master'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.folder_special_rounded, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Need to add new document types or change file size limits? Manage them in Doc Master',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                    ),
                  ),
                  Text(
                    'Open Doc Master →',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Add New Loan Type
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newLoanTypeController,
                  decoration: InputDecoration(
                    hintText: 'Add new loan product (e.g. LAP, Gold Loan, MSME Loan)...',
                    isDense: true,
                    prefixIcon: const Icon(Icons.add_business_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onSubmitted: (_) => _addLoanType(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _addLoanType,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Loan Product'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Loan Products Cards with Document Checklists
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _loanTypes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final loanType = _loanTypes[index];
              final requiredDocIds = _loanTypeDocsMap[loanType] ?? [];

              return Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF24201D) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Strip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2B2621) : const Color(0xFFF1F5F9),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.payments_outlined, color: Color(0xFF2563EB), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  loanType,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: requiredDocIds.isEmpty
                                        ? Colors.amber.withValues(alpha: 0.15)
                                        : const Color(0xFF10B981).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${requiredDocIds.length} of ${_loanDocTypes.length} Docs Required',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: requiredDocIds.isEmpty ? Colors.amber.shade800 : const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _toggleAllDocsForLoanType(loanType, true),
                            child: const Text('Select All', style: TextStyle(fontSize: 12)),
                          ),
                          TextButton(
                            onPressed: () => _toggleAllDocsForLoanType(loanType, false),
                            child: const Text('Clear All', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ),
                          if (_loanTypes.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                              tooltip: 'Delete $loanType',
                              onPressed: () => _removeLoanType(loanType),
                            ),
                        ],
                      ),
                    ),

                    // Document Checkboxes
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _loanDocTypes.isEmpty
                          ? const Text(
                              'No document types available. Please add document types in the master pool above.',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            )
                          : Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              children: _loanDocTypes.map((doc) {
                                final isChecked = requiredDocIds.contains(doc.id);

                                return InkWell(
                                  onTap: () => _toggleDocForLoanType(loanType, doc.id, !isChecked),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isChecked
                                          ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFFEFF6FF))
                                          : (isDark ? const Color(0xFF1F1C19) : Colors.white),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isChecked
                                            ? const Color(0xFF3B82F6)
                                            : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                                        width: isChecked ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: isChecked,
                                          activeColor: const Color(0xFF2563EB),
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                          onChanged: (val) => _toggleDocForLoanType(loanType, doc.id, val ?? false),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          doc.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${doc.maxFileSizeMb}MB',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textMuted),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
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
  // Doc Master: Master Document Types & Max File Size Configurations
  // ---------------------------------------------------------------------------
  Widget _buildMasterDocumentTypesCard({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textMuted,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.folder_special_rounded, color: Color(0xFF10B981), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Doc Master: Master Document Pool & Verification Checklist',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage all master document types (PAN, Aadhaar, Bank Statement, Salary Slips, etc.), set allowed file size limits (MB), and add or remove documents. These documents auto-populate in verification checklists and client upload portals.',
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Add New Document Type Form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF24201D) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, size: 18, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Text(
                      'Add New Master Document Type',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
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
                        controller: _newDocNameController,
                        decoration: InputDecoration(
                          hintText: 'Document Name (e.g. PAN Card, Bank Statement, GST Certificate)...',
                          isDense: true,
                          prefixIcon: const Icon(Icons.description_outlined, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onSubmitted: (_) => _addLoanDocType(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 130,
                      child: TextField(
                        controller: _newDocMaxMbController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Max Size',
                          suffixText: 'MB',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onSubmitted: (_) => _addLoanDocType(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _addLoanDocType,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Document'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Display List of Added Master Document Types
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Configured Document Pool (${_loanDocTypes.length} Available in Master)',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_loanDocTypes.length} Active Types',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_loanDocTypes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF24201D) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Icon(Icons.folder_open_rounded, size: 44, color: textMuted),
                  const SizedBox(height: 10),
                  Text(
                    'No document types in Doc Master yet',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Use the form above to add document types (e.g. PAN Card, Bank Statement, Aadhaar, ITR, Salary Slips).',
                    style: TextStyle(fontSize: 12.5, color: textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isTwoCol = constraints.maxWidth >= 600;
                final itemWidth = isTwoCol ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _loanDocTypes.map((doc) {
                    return SizedBox(
                      width: itemWidth,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF26221E) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.description_rounded, size: 20, color: Color(0xFF10B981)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc.name,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Max ${doc.maxFileSizeMb} MB',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        doc.allowedFormats.join(', ').toUpperCase(),
                                        style: TextStyle(fontSize: 10.5, color: textMuted),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                              tooltip: 'Delete ${doc.name}',
                              onPressed: () => _removeLoanDocType(doc.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Lead Flow Routing & Telecaller Assignment Section
  // ---------------------------------------------------------------------------
  Widget _buildLeadRoutingSection({
    required List<CrmSalesUser> employees,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textMuted,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.alt_route_rounded, color: Color(0xFF6366F1), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lead Flow Routing & Telecaller Assignment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure separate telecaller teams for Excel uploads and Meta/Webhook campaigns. Leads will automatically be round-robin distributed among selected members, and team members will only see their respective modules.',
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildMultiSelectTelecallerCard(
            context: context,
            title: 'Assign Excel leads to',
            description: 'Select team members/telecallers who will handle leads uploaded via Excel or created manually under Excel flow.',
            icon: Icons.table_chart_rounded,
            iconColor: const Color(0xFF16A34A),
            selectedIds: _excelAssignedTelecallerIds,
            employees: employees,
            onChanged: (updated) => setState(() => _excelAssignedTelecallerIds = updated),
            isDark: isDark,
            cardBg: cardBg,
            borderColor: borderColor,
            textMuted: textMuted,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 16),
          _buildMultiSelectTelecallerCard(
            context: context,
            title: 'Assign Meta / Campaign leads to',
            description: 'Select team members/telecallers who will handle online webhook leads arriving from Meta Graph API or Ads campaigns.',
            icon: Icons.campaign_rounded,
            iconColor: const Color(0xFF2563EB),
            selectedIds: _webhookAssignedTelecallerIds,
            employees: employees,
            onChanged: (updated) => setState(() => _webhookAssignedTelecallerIds = updated),
            isDark: isDark,
            cardBg: cardBg,
            borderColor: borderColor,
            textMuted: textMuted,
            primaryColor: primaryColor,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Site Visit Desk In-Charge Section (Real Estate)
  // ---------------------------------------------------------------------------
  Widget _buildSiteVisitDeskSection({
    required List<CrmSalesUser> employees,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textMuted,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.how_to_reg_rounded, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Designated Site Visit Desk In-Charge',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select the employee authorized to check in visitors at the site reception, verify scheduled visits, and assign Sales Representatives.',
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<int?>(
            value: _siteVisitDeskEmployeeId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Front Desk Employee',
              prefixIcon: const Icon(Icons.badge_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('None (Only System Admins can perform Check-in)'),
              ),
              ...employees.map((e) => DropdownMenuItem<int?>(
                    value: e.employeeId,
                    child: Text(
                      '${e.fullName} (${e.designation ?? "Employee"}${e.department != null ? " • ${e.department}" : ""}) - Emp #${e.employeeId}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
            ],
            onChanged: (val) {
              setState(() {
                _siteVisitDeskEmployeeId = val;
              });
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Lead Sources Section (Real Estate)
  // ---------------------------------------------------------------------------
  Widget _buildLeadSourcesSection({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textMuted,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.source_rounded, color: Colors.blue, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Front Desk: Lead Sources',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sources available during new visitor check-in (e.g. Walk IN, Channel Partner, Reference).',
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _leadSources.map((source) {
              return Chip(
                label: Text(source),
                deleteIcon: _leadSources.length <= 1 ? null : const Icon(Icons.close_rounded, size: 16),
                onDeleted: _leadSources.length <= 1
                    ? null
                    : () {
                        setState(() {
                          _leadSources.remove(source);
                        });
                      },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newSourceController,
                  decoration: InputDecoration(
                    hintText: 'Add new lead source...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onSubmitted: (_) => _addSource(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _addSource,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Reference Sub-Categories Section (Real Estate)
  // ---------------------------------------------------------------------------
  Widget _buildReferenceTypesSection({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textMuted,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.people_outline_rounded, color: Colors.purple, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reference Sub-Categories',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sub-types displayed when a visitor indicates they were referred (e.g. B2B, Employee, Other Client).',
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _referenceTypes.map((type) {
              return Chip(
                label: Text(type),
                deleteIcon: _referenceTypes.length <= 1 ? null : const Icon(Icons.close_rounded, size: 16),
                onDeleted: _referenceTypes.length <= 1
                    ? null
                    : () {
                        setState(() {
                          _referenceTypes.remove(type);
                        });
                      },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newRefTypeController,
                  decoration: InputDecoration(
                    hintText: 'Add new reference category...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onSubmitted: (_) => _addRefType(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _addRefType,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Not Interested Reasons Section (Both CRMs)
  // ---------------------------------------------------------------------------
  Widget _buildNotInterestedReasonsSection({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textMuted,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.thumb_down_alt_outlined, color: Colors.redAccent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pre-Sales: "Not Interested" Reasons',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dropdown options displayed to telecallers when marking a lead as Not Interested. (Selecting "Others" prompts for a manual remark).',
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _notInterestedReasons.map((reason) {
              final isOthers = reason.toLowerCase() == 'others';
              return Chip(
                label: Text(reason),
                deleteIcon: isOthers ? null : const Icon(Icons.close_rounded, size: 16),
                onDeleted: isOthers
                    ? null
                    : () {
                        setState(() {
                          _notInterestedReasons.remove(reason);
                        });
                      },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newReasonController,
                  decoration: InputDecoration(
                    hintText: 'Add new reason (e.g. Price too high, Location far)...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onSubmitted: (_) => _addReason(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _addReason,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addLoanType() {
    final text = _newLoanTypeController.text.trim();
    if (text.isEmpty) return;
    if (!_loanTypes.contains(text)) {
      setState(() {
        _loanTypes.add(text);
        _loanTypeDocsMap[text] = _loanDocTypes.take(2).map((d) => d.id).toList();
        _newLoanTypeController.clear();
      });
    }
  }

  void _removeLoanType(String type) {
    if (_loanTypes.length <= 1) return;
    setState(() {
      _loanTypes.remove(type);
      _loanTypeDocsMap.remove(type);
    });
  }

  void _addLoanDocType() {
    final name = _newDocNameController.text.trim();
    if (name.isEmpty) return;
    final mb = int.tryParse(_newDocMaxMbController.text.trim()) ?? 5;
    final id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'_+'), '_');

    if (_loanDocTypes.any((d) => d.id == id || d.name.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document type with this name already exists')),
      );
      return;
    }

    setState(() {
      final newDoc = CrmLoanDocType(
        id: id,
        name: name,
        maxFileSizeMb: mb > 0 ? mb : 5,
        allowedFormats: const ['pdf', 'jpg', 'jpeg', 'png'],
      );
      _loanDocTypes.add(newDoc);
      _newDocNameController.clear();
      _newDocMaxMbController.text = '5';
    });
  }

  void _removeLoanDocType(String docId) {
    setState(() {
      _loanDocTypes.removeWhere((d) => d.id == docId);
      for (final list in _loanTypeDocsMap.values) {
        list.remove(docId);
      }
    });
  }

  void _toggleDocForLoanType(String loanType, String docId, bool isSelected) {
    setState(() {
      final list = List<String>.from(_loanTypeDocsMap[loanType] ?? []);
      if (isSelected) {
        if (!list.contains(docId)) list.add(docId);
      } else {
        list.remove(docId);
      }
      _loanTypeDocsMap[loanType] = list;
    });
  }

  void _toggleAllDocsForLoanType(String loanType, bool selectAll) {
    setState(() {
      if (selectAll) {
        _loanTypeDocsMap[loanType] = _loanDocTypes.map((d) => d.id).toList();
      } else {
        _loanTypeDocsMap[loanType] = [];
      }
    });
  }

  void _addReason() {
    final text = _newReasonController.text.trim();
    if (text.isEmpty) return;
    if (!_notInterestedReasons.contains(text)) {
      setState(() {
        _notInterestedReasons.add(text);
        _newReasonController.clear();
      });
    }
  }

  void _addSource() {
    final text = _newSourceController.text.trim();
    if (text.isEmpty) return;
    if (!_leadSources.contains(text)) {
      setState(() {
        _leadSources.add(text);
        _newSourceController.clear();
      });
    }
  }

  void _addRefType() {
    final text = _newRefTypeController.text.trim();
    if (text.isEmpty) return;
    if (!_referenceTypes.contains(text)) {
      setState(() {
        _referenceTypes.add(text);
        _newRefTypeController.clear();
      });
    }
  }

  Widget _buildFinserveApplicationFieldsCard({
    required BuildContext context,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textMuted,
    required Color primaryColor,
  }) {
    final personalFields = _finserveApplicationFields.where((f) => f.section.toUpperCase() == 'PERSONAL').toList();
    final companyFields = _finserveApplicationFields.where((f) => f.section.toUpperCase() == 'COMPANY').toList();
    final referenceFields = _finserveApplicationFields.where((f) => f.section.toUpperCase() == 'REFERENCE').toList();
    final customFields = _finserveApplicationFields.where((f) {
      final s = f.section.toUpperCase();
      return s != 'PERSONAL' && s != 'COMPANY' && s != 'REFERENCE';
    }).toList();

    final totalActive = _finserveApplicationFields.where((f) => f.enabled).length;
    final totalRequired = _finserveApplicationFields.where((f) => f.required && f.enabled).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFC5A059).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFFC5A059), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loan Application Form Schema & Required Fields',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure intake fields taken when a client is marked Interested. Toggle "Mandatory" to enforce required fields in client submission, and "Active" to show/hide.',
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.restore_rounded, size: 16),
                    label: const Text('Reset Defaults', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onPressed: _resetApplicationFieldsToDefault,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Field', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: _showAddCustomFieldDialog,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_finserveApplicationFields.length} Total Fields',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$totalActive Active',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$totalRequired Mandatory',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Group 1: Personal Details
          _buildAppFieldSection(
            title: '🎗️ PERSONAL DETAILS',
            subtitle: 'Personal contacts, family relations, residence, and loan purpose',
            fields: personalFields,
            isDark: isDark,
            borderColor: borderColor,
            textMuted: textMuted,
          ),
          const SizedBox(height: 16),

          // Group 2: Company Details
          _buildAppFieldSection(
            title: '🎗️ COMPANY DETAILS',
            subtitle: 'Employment records, work experience, official email & landline',
            fields: companyFields,
            isDark: isDark,
            borderColor: borderColor,
            textMuted: textMuted,
          ),
          const SizedBox(height: 16),

          // Group 3: Reference Details
          _buildAppFieldSection(
            title: '🎗️ REFERENCE DETAILS',
            subtitle: 'Two mandatory reference contacts with relation and addresses',
            fields: referenceFields,
            isDark: isDark,
            borderColor: borderColor,
            textMuted: textMuted,
          ),

          if (customFields.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildAppFieldSection(
              title: '🎗️ CUSTOM / ADDITIONAL FIELDS',
              subtitle: 'Additional fields configured specifically for this scope',
              fields: customFields,
              isDark: isDark,
              borderColor: borderColor,
              textMuted: textMuted,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppFieldSection({
    required String title,
    required String subtitle,
    required List<FinserveApplicationField> fields,
    required bool isDark,
    required Color borderColor,
    required Color textMuted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24201D) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2B2621) : const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(width: 8),
                Text(
                  '• $subtitle',
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
                const Spacer(),
                Text(
                  '${fields.where((f) => f.enabled).length}/${fields.length} Active',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMuted),
                ),
              ],
            ),
          ),
          if (fields.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No fields configured in this section', style: TextStyle(color: textMuted, fontSize: 13)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: fields.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: borderColor.withValues(alpha: 0.5)),
              itemBuilder: (context, index) {
                final field = fields[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // Field Label and Key
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              field.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: field.enabled ? (isDark ? Colors.white : const Color(0xFF1E293B)) : textMuted,
                                decoration: field.enabled ? null : TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Key: ${field.key}',
                              style: TextStyle(fontSize: 11, color: textMuted, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      // Type Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          field.type.toUpperCase(),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted),
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Required Toggle
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Required',
                            style: TextStyle(
                              fontSize: 12,
                              color: field.required ? const Color(0xFFD97706) : textMuted,
                              fontWeight: field.required ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Switch(
                            value: field.required,
                            activeColor: const Color(0xFFD97706),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: field.enabled ? (val) => _toggleFieldRequired(field.key, val) : null,
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Enabled Toggle
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 12,
                              color: field.enabled ? const Color(0xFF16A34A) : textMuted,
                              fontWeight: field.enabled ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Switch(
                            value: field.enabled,
                            activeColor: const Color(0xFF16A34A),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: (val) => _toggleFieldEnabled(field.key, val),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      // Delete custom field button
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                        tooltip: 'Remove field',
                        onPressed: () => _removeApplicationField(field.key),
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

  void _toggleFieldRequired(String key, bool val) {
    setState(() {
      final index = _finserveApplicationFields.indexWhere((f) => f.key == key);
      if (index != -1) {
        final current = _finserveApplicationFields[index];
        _finserveApplicationFields[index] = current.copyWith(required: val);
      }
    });
  }

  void _toggleFieldEnabled(String key, bool val) {
    setState(() {
      final index = _finserveApplicationFields.indexWhere((f) => f.key == key);
      if (index != -1) {
        final current = _finserveApplicationFields[index];
        _finserveApplicationFields[index] = current.copyWith(enabled: val);
      }
    });
  }

  void _removeApplicationField(String key) {
    setState(() {
      _finserveApplicationFields.removeWhere((f) => f.key == key);
    });
  }

  void _resetApplicationFieldsToDefault() {
    setState(() {
      _finserveApplicationFields = List<FinserveApplicationField>.from(
        CrmSettings.defaultFinserveApplicationFields,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Application form fields reset to standard default schema')),
    );
  }

  void _showAddCustomFieldDialog() {
    final labelCtrl = TextEditingController();
    final keyCtrl = TextEditingController();
    String section = 'PERSONAL';
    String type = 'text';
    bool isRequired = true;
    bool isEnabled = true;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Application Field', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: labelCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Field Label *',
                        hintText: 'e.g. Pan Card Number, Mother Tongue...',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        if (keyCtrl.text.isEmpty || keyCtrl.text == val.toLowerCase().replaceAll(' ', '_')) {
                          keyCtrl.text = val.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
                          setDialogState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: keyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Field Key / ID *',
                        hintText: 'e.g. panCardNumber',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: section,
                      decoration: const InputDecoration(
                        labelText: 'Form Section',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'PERSONAL', child: Text('🎗️ Personal Details')),
                        DropdownMenuItem(value: 'COMPANY', child: Text('🎗️ Company Details')),
                        DropdownMenuItem(value: 'REFERENCE', child: Text('🎗️ Reference Details')),
                        DropdownMenuItem(value: 'CUSTOM', child: Text('🎗️ Custom / Other Section')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => section = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: const InputDecoration(
                        labelText: 'Input Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'text', child: Text('Text Line')),
                        DropdownMenuItem(value: 'number', child: Text('Number / Amount')),
                        DropdownMenuItem(value: 'phone', child: Text('Phone / Mobile')),
                        DropdownMenuItem(value: 'email', child: Text('Email Address')),
                        DropdownMenuItem(value: 'textarea', child: Text('Multi-line Text / Address')),
                        DropdownMenuItem(value: 'select', child: Text('Dropdown Selection')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => type = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: isRequired,
                          onChanged: (val) => setDialogState(() => isRequired = val ?? true),
                        ),
                        const Text('Mandatory (Required Field)'),
                        const Spacer(),
                        Checkbox(
                          value: isEnabled,
                          onChanged: (val) => setDialogState(() => isEnabled = val ?? true),
                        ),
                        const Text('Enabled'),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final label = labelCtrl.text.trim();
                    final key = keyCtrl.text.trim();
                    if (label.isEmpty || key.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter field label and key')),
                      );
                      return;
                    }
                    Navigator.pop(dialogCtx);
                    setState(() {
                      _finserveApplicationFields.add(FinserveApplicationField(
                        key: key,
                        label: label,
                        section: section,
                        type: type,
                        required: isRequired,
                        enabled: isEnabled,
                      ));
                    });
                  },
                  child: const Text('Add Field'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _savePresalesSettings() {
    final repo = context.read<CrmRepository>();
    final isFinserve = repo.scope == 'NB_FINSERVE';
    if (isFinserve) {
      context.read<CrmSettingsBloc>().add(CrmSettingsSaved({
        'loan_types': jsonEncode(_loanTypes),
        'loan_doc_types': jsonEncode(_loanDocTypes.map((d) => d.toJson()).toList()),
        'loan_type_docs_map': jsonEncode(_loanTypeDocsMap),
        'finserve_application_fields': jsonEncode(_finserveApplicationFields.map((f) => f.toJson()).toList()),
        'not_interested_reasons': jsonEncode(_notInterestedReasons),
        'excel_assigned_telecaller_ids': jsonEncode(_excelAssignedTelecallerIds),
        'webhook_assigned_telecaller_ids': jsonEncode(_webhookAssignedTelecallerIds),
        'max_telecaller_active_workload': _maxWorkloadController.text.trim(),
        'telecaller_max_workload_map': jsonEncode(_telecallerMaxWorkloadMap),
        'untouched_lead_timeout_minutes': _untouchedTimeoutController.text.trim(),
        'idle_timeout_minutes': _idleTimeoutController.text.trim(),
      }));
    } else {
      context.read<CrmSettingsBloc>().add(CrmSettingsSaved({
        'loan_doc_types': jsonEncode(_loanDocTypes.map((d) => d.toJson()).toList()),
        'not_interested_reasons': jsonEncode(_notInterestedReasons),
        'lead_sources': jsonEncode(_leadSources),
        'reference_types': jsonEncode(_referenceTypes),
        'site_visit_desk_employee_id': _siteVisitDeskEmployeeId?.toString() ?? '',
        'excel_assigned_telecaller_ids': jsonEncode(_excelAssignedTelecallerIds),
        'webhook_assigned_telecaller_ids': jsonEncode(_webhookAssignedTelecallerIds),
        'max_telecaller_active_workload': _maxWorkloadController.text.trim(),
        'telecaller_max_workload_map': jsonEncode(_telecallerMaxWorkloadMap),
        'untouched_lead_timeout_minutes': _untouchedTimeoutController.text.trim(),
        'idle_timeout_minutes': _idleTimeoutController.text.trim(),
      }));
    }
  }

  Widget _buildMultiSelectTelecallerCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required List<int> selectedIds,
    required List<CrmSalesUser> employees,
    required void Function(List<int> updated) onChanged,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textMuted,
    required Color primaryColor,
  }) {
    final selectedEmployees = employees.where((e) => selectedIds.contains(e.employeeId)).toList();

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => _showTelecallerMultiSelectDialog(
              context: context,
              title: title,
              initialSelectedIds: selectedIds,
              employees: employees,
              onConfirmed: onChanged,
              isDark: isDark,
              primaryColor: primaryColor,
            ),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.checklist_rounded, size: 18, color: iconColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedIds.isEmpty
                          ? 'Select telecaller(s) from dropdown with checkboxes...'
                          : '${selectedIds.length} person(s) assigned (Click to modify)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selectedIds.isEmpty ? textMuted : (isDark ? Colors.white : const Color(0xFF1E293B)),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${selectedIds.length} selected',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: iconColor),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down_rounded, size: 18, color: iconColor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (selectedEmployees.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedEmployees.map((emp) {
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: iconColor.withValues(alpha: 0.2),
                    child: Text(
                      emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: iconColor),
                    ),
                  ),
                  label: Text(
                    '${emp.fullName}${emp.designation != null ? " • ${emp.designation}" : ""} (#${emp.employeeId})',
                    style: const TextStyle(fontSize: 12),
                  ),
                  deleteIcon: const Icon(Icons.close_rounded, size: 15),
                  onDeleted: () {
                    final updated = List<int>.from(selectedIds)..remove(emp.employeeId);
                    onChanged(updated);
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _showTelecallerMultiSelectDialog({
    required BuildContext context,
    required String title,
    required List<int> initialSelectedIds,
    required List<CrmSalesUser> employees,
    required void Function(List<int> updated) onConfirmed,
    required bool isDark,
    required Color primaryColor,
  }) {
    List<int> tempSelected = List<int>.from(initialSelectedIds);
    String searchQuery = '';
    String selectedOrg = 'ALL';
    String selectedSubOrg = 'ALL';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final telecallerCandidates = employees.where((e) => e.isTelecaller).toList();
            final candidatePool = telecallerCandidates.isNotEmpty ? telecallerCandidates : employees;

            // Extract dynamic unique organizations
            final uniqueOrgs = candidatePool
                .map((e) => e.organization)
                .where((o) => o != null && o.trim().isNotEmpty)
                .cast<String>()
                .toSet()
                .toList()
              ..sort();

            // Extract dynamic unique sub-organizations (optionally filtered by selectedOrg)
            final subOrgPool = selectedOrg == 'ALL'
                ? candidatePool
                : candidatePool.where((e) => e.organization == selectedOrg);
            final uniqueSubOrgs = subOrgPool
                .map((e) => e.subOrganization)
                .where((s) => s != null && s.trim().isNotEmpty)
                .cast<String>()
                .toSet()
                .toList()
              ..sort();

            final filtered = candidatePool.where((e) {
              if (selectedOrg != 'ALL' && e.organization != selectedOrg) return false;
              if (selectedSubOrg != 'ALL' && e.subOrganization != selectedSubOrg) return false;
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              return e.fullName.toLowerCase().contains(q) ||
                  (e.designation ?? '').toLowerCase().contains(q) ||
                  (e.department ?? '').toLowerCase().contains(q) ||
                  (e.role ?? '').toLowerCase().contains(q) ||
                  (e.organization ?? '').toLowerCase().contains(q) ||
                  (e.subOrganization ?? '').toLowerCase().contains(q) ||
                  e.employeeId.toString().contains(q);
            }).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.checklist_rtl_rounded, color: primaryColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 540,
                height: 560,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dynamic Org & Sub-Org Bifurcation Dropdowns
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF262320) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.business_rounded, size: 16, color: Color(0xFF6366F1)),
                              SizedBox(width: 6),
                              Text(
                                'Filter by Organization & Sub-Organization',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Organization dropdown
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedOrg,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Organization',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  items: [
                                    const DropdownMenuItem(value: 'ALL', child: Text('All Organizations', style: TextStyle(fontSize: 12))),
                                    ...uniqueOrgs.map((org) => DropdownMenuItem(
                                          value: org,
                                          child: Text(org, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                        )),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setDialogState(() {
                                        selectedOrg = v;
                                        selectedSubOrg = 'ALL';
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Sub-Organization dropdown
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedSubOrg,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Sub Organization',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  items: [
                                    const DropdownMenuItem(value: 'ALL', child: Text('All Sub-Orgs', style: TextStyle(fontSize: 12))),
                                    ...uniqueSubOrgs.map((subOrg) => DropdownMenuItem(
                                          value: subOrg,
                                          child: Text(subOrg, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                        )),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setDialogState(() => selectedSubOrg = v);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search telecaller by name, role, sub-org...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (val) {
                        setDialogState(() => searchQuery = val.trim());
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${tempSelected.length} selected (${filtered.length} visible in filter)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setDialogState(() {
                                  for (final e in filtered) {
                                    if (!tempSelected.contains(e.employeeId)) {
                                      tempSelected.add(e.employeeId);
                                    }
                                  }
                                });
                              },
                              child: const Text('Select Filtered', style: TextStyle(fontSize: 12)),
                            ),
                            TextButton(
                              onPressed: () {
                                setDialogState(() {
                                  for (final e in filtered) {
                                    tempSelected.remove(e.employeeId);
                                  }
                                });
                              },
                              child: const Text('Clear Filtered', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                selectedSubOrg != 'ALL'
                                    ? 'No telecallers found in Sub-Org "$selectedSubOrg".'
                                    : (selectedOrg != 'ALL'
                                        ? 'No telecallers found in Organization "$selectedOrg".'
                                        : 'No employees found matching filter.'),
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final emp = filtered[i];
                                final isChecked = tempSelected.contains(emp.employeeId);
                                final subOrgLabel = emp.subOrganization != null && emp.subOrganization!.isNotEmpty
                                    ? emp.subOrganization!
                                    : (emp.organization ?? '');
                                return CheckboxListTile(
                                  dense: true,
                                  value: isChecked,
                                  title: Row(
                                    children: [
                                      Text(
                                        emp.fullName,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      if (subOrgLabel.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            subOrgLabel,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF6366F1),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${emp.designation ?? "Telecaller"}${emp.department != null ? " • ${emp.department}" : ""} (Emp #${emp.employeeId})',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  activeColor: primaryColor,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        if (!tempSelected.contains(emp.employeeId)) {
                                          tempSelected.add(emp.employeeId);
                                        }
                                      } else {
                                        tempSelected.remove(emp.employeeId);
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
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    onConfirmed(tempSelected);
                  },
                  child: const Text('Apply Selection'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildWaitingQueueAndWorkloadCard({
    required BuildContext context,
    required List<CrmSalesUser> employees,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textMuted,
    required Color primaryColor,
  }) {
    final status = _waitingQueueStatus;
    final presenceMap = <int, TelecallerPresenceInfo>{};
    if (status != null) {
      for (final p in status.telecallers) {
        presenceMap[p.employeeId] = p;
      }
    }

    // Build authoritative list containing ONLY telecallers
    final Map<int, ({int employeeId, String fullName, bool isPunchedIn, bool isActiveOnScreen, int currentWorkload})> telecallerRows = {};

    if (status != null) {
      for (final p in status.telecallers) {
        telecallerRows[p.employeeId] = (
          employeeId: p.employeeId,
          fullName: p.fullName,
          isPunchedIn: p.isPunchedIn,
          isActiveOnScreen: p.isActiveOnScreen,
          currentWorkload: p.currentWorkload,
        );
      }
    }

    for (final emp in employees.where((e) => e.isTelecaller)) {
      final presence = presenceMap[emp.employeeId];
      telecallerRows.putIfAbsent(
        emp.employeeId,
        () => (
          employeeId: emp.employeeId,
          fullName: emp.fullName,
          isPunchedIn: presence?.isPunchedIn ?? false,
          isActiveOnScreen: presence?.isActiveOnScreen ?? false,
          currentWorkload: presence?.currentWorkload ?? 0,
        ),
      );
    }

    final telecallerList = telecallerRows.values.toList()
      ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFF59E0B), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Telecaller Workload & Waiting Queue Automation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Leads enter a waiting queue and are dispatched to telecallers who have punched in today and are active on screen. Leads untouched for 30 minutes return to the queue.',
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: _waitingQueueLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh Queue Status',
                onPressed: _loadWaitingQueueStatus,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Live Metrics & Dispatch Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF24201D) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMetricChip(
                      icon: Icons.list_alt_rounded,
                      label: 'In Queue',
                      value: '${status?.queuedLeadsCount ?? 0}',
                      color: const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 12),
                    _buildMetricChip(
                      icon: Icons.person_pin_rounded,
                      label: 'Active Telecallers',
                      value: '${status?.activeTelecallersCount ?? 0}',
                      color: const Color(0xFF059669),
                    ),
                    const SizedBox(width: 12),
                    _buildMetricChip(
                      icon: Icons.space_dashboard_rounded,
                      label: 'Available Slots',
                      value: '${status?.totalAvailableCapacity ?? 0}',
                      color: const Color(0xFF2563EB),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _triggerQueueDispatch,
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: const Text('Dispatch Queue Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Configuration Fields (Workload limits & timeouts)
          Text(
            'Queue & Automation Rules',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _maxWorkloadController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Global Max Active Workload (CNR + Not Started)',
                    hintText: 'e.g. 20',
                    helperText: 'Max active leads assigned before pausing',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _untouchedTimeoutController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Untouched Lead Timeout (Minutes)',
                    hintText: 'e.g. 30',
                    helperText: 'Returns lead to queue if untouched',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _idleTimeoutController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Screen Inactivity Idle Timeout (Minutes)',
                    hintText: 'e.g. 5',
                    helperText: 'Sets status to "On Break" if no screen activity',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Per-Telecaller Capacity Table
          Text(
            'Individual Telecaller Capacity Overrides',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Specify individual lead capacities (CNR + Not Started) for specific team members. Leave blank to use the global limit.',
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 14),

          if (telecallerList.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 20, color: textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No team members with role "Telecaller" or "Telecalling" found. Only telecallers are managed under workload overrides.',
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: telecallerList.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                itemBuilder: (ctx, i) {
                  final emp = telecallerList[i];
                  final isPunchedIn = emp.isPunchedIn;
                  final isActiveOnScreen = emp.isActiveOnScreen;
                  final currentWorkload = emp.currentWorkload;
                  final customLimit = _telecallerMaxWorkloadMap[emp.employeeId.toString()];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: primaryColor.withValues(alpha: 0.15),
                          child: Text(
                            emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'T',
                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                emp.fullName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // Attendance Chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isPunchedIn
                                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                          : Colors.grey.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isPunchedIn ? 'Punched In' : 'Not Punched In',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isPunchedIn ? const Color(0xFF059669) : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  // Screen Presence Chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isActiveOnScreen
                                          ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                                          : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isActiveOnScreen ? 'Active on Screen' : 'On Break / Idle',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isActiveOnScreen ? const Color(0xFF2563EB) : const Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Active Workload (CNR + Not Started): $currentWorkload',
                                    style: TextStyle(fontSize: 11, color: textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 140,
                          child: TextFormField(
                            initialValue: customLimit?.toString() ?? '',
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Max Capacity',
                              hintText: 'Default',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val.trim());
                              setState(() {
                                if (parsed != null && parsed > 0) {
                                  _telecallerMaxWorkloadMap[emp.employeeId.toString()] = parsed;
                                } else {
                                  _telecallerMaxWorkloadMap.remove(emp.employeeId.toString());
                                }
                              });
                            },
                          ),
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

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

