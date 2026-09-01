import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_back_button.dart';
import '../../domain/crm_models.dart';
import '../crm_providers.dart';

class CrmSettingsScreen extends ConsumerStatefulWidget {
  const CrmSettingsScreen({super.key});

  @override
  ConsumerState<CrmSettingsScreen> createState() => _CrmSettingsScreenState();
}

class _CrmSettingsScreenState extends ConsumerState<CrmSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Controllers for Telephony Settings (Elision / Greeter Click2Call)
  final _apiUrlController = TextEditingController(text: 'https://greeter.co.in/api/click2call');
  final _userIdController = TextEditingController(text: '634550');
  final _didController = TextEditingController(text: '9484700070');
  final _routeNumberController = TextEditingController(text: '98');
  final _defaultAgentController = TextEditingController(text: '8511139384');

  // Controllers for Retention Settings
  final _notInterestedDaysController = TextEditingController(text: '30');
  final _binDaysController = TextEditingController(text: '30');

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

  bool _telephonyLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _apiUrlController.dispose();
    _userIdController.dispose();
    _didController.dispose();
    _routeNumberController.dispose();
    _defaultAgentController.dispose();
    _notInterestedDaysController.dispose();
    _binDaysController.dispose();
    super.dispose();
  }

  void _syncSettings(CrmSettings settings) {
    if (!_telephonyLoaded) {
      _apiUrlController.text = settings.elisionApiUrl.isNotEmpty ? settings.elisionApiUrl : 'https://greeter.co.in/api/click2call';
      _userIdController.text = settings.elisionUserId.isNotEmpty ? settings.elisionUserId : '634550';
      _didController.text = settings.elisionDid.isNotEmpty ? settings.elisionDid : '9484700070';
      _routeNumberController.text = settings.elisionRouteNumber.isNotEmpty ? settings.elisionRouteNumber : '98';
      _defaultAgentController.text = settings.elisionDefaultAgentNumber.isNotEmpty ? settings.elisionDefaultAgentNumber : '8511139384';
      _notInterestedDaysController.text = settings.notInterestedRetentionDays.toString();
      _binDaysController.text = settings.binRetentionDays.toString();
      _telephonyLoaded = true;
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

    final settingsAsync = ref.watch(crmSettingsProvider);
    settingsAsync.whenData((settings) => _syncSettings(settings));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141210) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('CRM Settings & Configuration'),
        leading: const AppBackButton(fallbackLocation: '/crm/dashboard'),
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Elision Telephony API'),
            Tab(text: 'Dashboard KPI Management'),
            Tab(text: 'Bin & Retention Policy'),
            Tab(text: 'General Preferences'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Settings',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(crmSettingsProvider);
              ref.invalidate(crmKpiProvider);
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
          _buildElisionTelephonyTab(isDark, cardBg, borderColor, textMuted, primaryGold),
          _buildKpiManagementTab(isDark, cardBg, borderColor, textMuted, primaryGold),
          _buildRetentionPolicyTab(isDark, cardBg, borderColor, textMuted, primaryGold),
          _buildGeneralTab(isDark, cardBg, borderColor, textMuted),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Elision Telephony Configuration
  // ---------------------------------------------------------------------------
  Widget _buildElisionTelephonyTab(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
    Color primaryColor,
  ) {
    const webhookUrl = 'https://crm.nbdeveloper.co.in/api/crm/telephony/webhook';

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
                      color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF16A34A), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Elision / Greeter Telephony Integration',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Connect your Greeter Click2Call dialer and configure the Call Log Webhook URL.',
                          style: TextStyle(fontSize: 13, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // CALL LOG POST WEBHOOK URL CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF24201D) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.webhook_rounded, size: 18, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 8),
                        Text(
                          'Call Log Webhook URL (For Greeter Settings)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Paste this URL into your Greeter Portal under SETTING > API Setting > CALL LOG POST API SETTING:',
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: SelectableText(
                              webhookUrl,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            tooltip: 'Copy Webhook URL',
                            onPressed: () {
                              Clipboard.setData(const ClipboardData(text: webhookUrl));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Webhook URL copied to clipboard!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // API Endpoint URL
              Text(
                'API Endpoint URL (API URL)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _apiUrlController,
                decoration: InputDecoration(
                  hintText: 'https://greeter.co.in/api/click2call',
                  prefixIcon: const Icon(Icons.link_rounded, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),

              // 2-Column Responsive Form Fields
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 500;

                  final userField = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User ID (user_id)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _userIdController,
                        decoration: InputDecoration(
                          hintText: 'e.g. 634550',
                          prefixIcon: const Icon(Icons.account_circle_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  );

                  final didField = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Virtual DID Number (did)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _didController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'e.g. 9484700070',
                          prefixIcon: const Icon(Icons.call_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  );

                  if (isCompact) {
                    return Column(
                      children: [
                        userField,
                        const SizedBox(height: 14),
                        didField,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: userField),
                      const SizedBox(width: 16),
                      Expanded(child: didField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 500;

                  final routeField = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Route / Campaign Code (number)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _routeNumberController,
                        decoration: InputDecoration(
                          hintText: 'e.g. 98',
                          prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  );

                  final defaultAgentField = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Default Agent Mobile (agen_number)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _defaultAgentController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'e.g. 9327056272',
                          prefixIcon: const Icon(Icons.headset_mic_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  );

                  if (isCompact) {
                    return Column(
                      children: [
                        routeField,
                        const SizedBox(height: 14),
                        defaultAgentField,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: routeField),
                      const SizedBox(width: 16),
                      Expanded(child: defaultAgentField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),

              // Save Button (Responsive)
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _saveTelephonySettings,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save Telephony Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
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

  // ---------------------------------------------------------------------------
  // Tab 3: Dashboard KPI Management (Admin Control & Metrics Toggle)
  // ---------------------------------------------------------------------------
  Widget _buildKpiManagementTab(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
    Color primaryColor,
  ) {
    final kpiAsync = ref.watch(crmKpiProvider);

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
                          'Admin Control: Toggle and customize which metrics, lead analytics, and Elision telephony statistics appear on your CRM Dashboard.',
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

              kpiAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
                error: (err, _) => Text('Error loading stats: $err', style: const TextStyle(color: Colors.red)),
                data: (kpi) => Column(
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
              ),
              const SizedBox(height: 28),

              // Section 2: Elision / Greeter Telephony Metrics
              Row(
                children: [
                  const Icon(Icons.phone_in_talk_rounded, size: 20, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Text(
                    'Elision Telephony & Dialing KPIs',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              kpiAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (kpi) => Column(
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
                      subtitle: 'All inbound and outbound calls tracked via Greeter CTI.',
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
                      color: const Color(0xFFEF4444).withOpacity(0.12),
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
              Text('General Preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B))),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.currency_rupee_rounded),
                title: const Text('Default Currency'),
                trailing: const Text('INR (₹)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time_rounded),
                title: const Text('Telecaller Calling Window'),
                trailing: const Text('09:30 AM – 07:00 PM', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.security_rounded),
                title: const Text('Sales Rep Assignment Access Control'),
                subtitle: const Text('Telecallers have view-only access once assigned to sales user.'),
                trailing: const Icon(Icons.check_circle_rounded, color: Colors.green),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveTelephonySettings() async {
    try {
      await ref.read(crmSettingsProvider.notifier).saveSettings({
        'elision_api_url': _apiUrlController.text.trim(),
        'elision_user_id': _userIdController.text.trim(),
        'elision_did': _didController.text.trim(),
        'elision_route_number': _routeNumberController.text.trim(),
        'elision_default_agent_number': _defaultAgentController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Elision Telephony settings saved successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveKpiSettings() async {
    try {
      await ref.read(crmSettingsProvider.notifier).saveSettings({
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
      });
      ref.invalidate(crmKpiProvider);
      ref.invalidate(crmSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dashboard KPI preferences saved successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save KPI preferences: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveRetentionSettings() async {
    try {
      await ref.read(crmSettingsProvider.notifier).saveSettings({
        'not_interested_retention_days': _notInterestedDaysController.text.trim(),
        'bin_retention_days': _binDaysController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Retention & Bin rules saved successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
