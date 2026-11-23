import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/bloc/load_status.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../../core/widgets/click_to_call_dial_dialog.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../core/tour/models/tour_models.dart';
import '../../../../core/tour/widgets/tour_target.dart';
import '../../data/crm_repository.dart';
import '../bloc/crm_dashboard_bloc.dart';
import '../../domain/crm_models.dart';
import '../widgets/crm_scope_selector.dart';

class CrmDashboardScreen extends StatelessWidget {
  const CrmDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CrmDashboardBloc>(
      create: (ctx) => CrmDashboardBloc(
        crmRepository: ctx.read<CrmRepository>(),
      )..add(const CrmDashboardLoadRequested()),
      child: const _CrmDashboardView(),
    );
  }
}

class _CrmDashboardView extends StatelessWidget {
  const _CrmDashboardView();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CrmDashboardBloc>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final isSmall = width < 600;

    final primaryGold = isDark ? const Color(0xFFC5A059) : const Color(0xFF2563EB);
    final cardBg = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFFC5A059).withValues(alpha: 0.18)
        : const Color(0xFFE2E8F0);
    final textMuted = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF64748B);

    final auth = context.watch<AuthBloc>().state;
    final canReadPreSales = Permissions.canReadCrmPreSales(auth.permissions, auth.user?.role);
    final canReadPostSales = Permissions.canReadCrmPostSales(auth.permissions, auth.user?.role);
    final canAccessSettings = Permissions.hasPermission(auth.permissions, 'CRM_SETTINGS', 'WRITE') ||
        Permissions.isAdmin(auth.user?.role);
    final canAccessBin = Permissions.hasPermission(auth.permissions, 'CRM_SETTINGS', 'READ') ||
        Permissions.isAdmin(auth.user?.role);

    return BlocConsumer<CrmDashboardBloc, CrmDashboardState>(
      listener: (context, state) {
        if (state.actionSuccessMessage != null && state.actionSuccessMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.actionSuccessMessage!)),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF141210) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('NB CRM Workspace'),
            leading: const AppBackButton(),
            backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            actions: [
              CrmScopeSelectorWidget(
                onScopeChanged: () {
                  bloc.add(const CrmDashboardRefreshRequested());
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Virtual Building Elevation',
                icon: const Icon(Icons.apartment_rounded),
                onPressed: () => context.go('/crm/virtual-building'),
              ),
              if (canAccessBin)
                IconButton(
                  tooltip: 'Bin / Archive',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => context.go('/crm/bin'),
                ),
              if (canAccessSettings)
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => context.go('/crm/settings'),
                ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  bloc.add(const CrmDashboardRefreshRequested());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('CRM data refreshed'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 24 : 14,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Welcome & Header Banner
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isSmall ? 14 : 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF26211A), const Color(0xFF1B1814)]
                      : [const Color(0xFFEEF2FF), const Color(0xFFF8FAFC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.hub_rounded,
                      color: primaryGold,
                      size: isSmall ? 24 : 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NB CRM Enterprise Hub',
                          style: TextStyle(
                            fontSize: isSmall ? 17 : 20,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Unified Lead Acquisition, Telephony, Follow-ups, and Sales Operations.',
                          style: TextStyle(
                            fontSize: isSmall ? 12 : 13,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // KPI Grid (Fully Responsive on All Screen Sizes, Admin Toggleable)
            if (state.status == LoadStatus.loading && state.kpiMetrics == null)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()))
            else if (state.kpiMetrics != null) ...[
              (() {
                final kpi = state.kpiMetrics!;
                final settings = state.settings;
                final isPersonal = kpi.isPersonal || !Permissions.isAdmin(auth.user?.role);
                final List<Widget> cards = [];

                if (settings?.kpiShowActiveLeads ?? true) {
                  cards.add(_buildKpiCard(
                    context,
                    title: 'Active Leads',
                    value: '${kpi.totalActiveLeads}',
                    subtext: isPersonal ? 'My assigned pipeline' : 'In pipeline (not in bin)',
                    icon: Icons.people_alt_rounded,
                    color: const Color(0xFF0284C7),
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    meaningDefinition: 'Total active customer inquiries currently progressing through your pre-sales telecalling pipeline (excludes soft-deleted and bin leads).',
                    meaningCalculation: 'Count of non-deleted CRM leads across all campaigns where status is active.',
                    meaningAction: 'A high active count indicates a healthy pipeline. Ensure telecallers follow up regularly to keep turnaround times low.',
                    actionLabel: 'View Active Leads',
                    onTap: () => context.go('/crm/pre-sales?tab=0&flow=ALL'),
                  ));
                  cards.add(_buildKpiCard(
                    context,
                    title: 'Total Leads',
                    value: '${kpi.totalLeads}',
                    subtext: 'Active ${kpi.totalActiveLeads} + Bin ${kpi.binCount}',
                    icon: Icons.summarize_rounded,
                    color: const Color(0xFF0F766E),
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    meaningDefinition: 'Total lifetime leads recorded in the CRM across all sources, including active pipeline leads and leads moved to the bin.',
                    meaningCalculation: 'Active Leads (${kpi.totalActiveLeads}) + Bin / Archived Leads (${kpi.binCount}) = ${kpi.totalLeads} Total.',
                    meaningAction: 'Evaluates cumulative top-of-funnel lead acquisition volume across historical campaigns.',
                    actionLabel: 'View All Leads',
                    onTap: () => context.go('/crm/pre-sales?tab=0&flow=ALL'),
                  ));
                }

                if (settings?.kpiShowTodayFollowups ?? true) {
                  cards.add(_buildKpiCard(
                    context,
                    title: "Today's Calls",
                    value: '${kpi.todayFollowUps}',
                    subtext: 'Scheduled calls',
                    icon: Icons.schedule_rounded,
                    color: const Color(0xFFEA580C),
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    meaningDefinition: 'Follow-ups, scheduled callbacks, and site visit appointments due for calling today.',
                    meaningCalculation: 'Scheduled follow-up date and time match today\'s calendar date.',
                    meaningAction: 'Top daily priority. Calling scheduled leads on time prevents deal leakage and boosts client trust.',
                    actionLabel: 'Open Today\'s Follow-ups',
                    onTap: () => context.go('/crm/pre-sales?tab=1'),
                  ));
                }

                if (settings?.kpiShowInterestedDeals ?? true) {
                  cards.add(_buildKpiCard(
                    context,
                    title: 'Interested Deals',
                    value: '${kpi.interestedDeals}',
                    subtext: 'Assigned to sales reps',
                    icon: Icons.thumb_up_rounded,
                    color: const Color(0xFF16A34A),
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    meaningDefinition: 'High-intent prospective buyers marked Interested or Site Visit Done ready for sales closing.',
                    meaningCalculation: 'Leads where status is INTERESTED or SITE_VISIT_DONE handed over to sales reps.',
                    meaningAction: 'Immediate revenue pipeline. Coordinate closely with sales reps to track site visits and token payments.',
                    actionLabel: 'View Deals Pipeline',
                    onTap: () => context.go('/crm/pre-sales?tab=3'),
                  ));
                }

                if (settings?.kpiShowBinCount ?? true) {
                  cards.add(_buildKpiCard(
                    context,
                    title: 'In Bin / Archive',
                    value: '${kpi.binCount}',
                    subtext: 'Diff from total (restorable)',
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFEF4444),
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    meaningDefinition: 'Leads removed from the active pipeline (duplicates, invalid phone numbers, or unresponsive leads).',
                    meaningCalculation: 'Leads marked isDeleted = true in this CRM scope (fully restorable anytime).',
                    meaningAction: 'Regularly audit the bin to restore mistakenly deleted leads or permanently purge expired leads.',
                    actionLabel: 'Open CRM Bin',
                    onTap: () => context.go('/crm/bin'),
                  ));
                }

                if (settings?.kpiShowTotalCalls ?? true) {
                  cards.add(_buildKpiCard(
                    context,
                    title: 'Total Calls Logged',
                    value: '${kpi.totalCalls}',
                    subtext: '9ance call logs',
                    icon: Icons.phone_in_talk_rounded,
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    meaningDefinition: 'Total telephony calls placed by agents through the 9ance Cloud Telephony Gateway.',
                    meaningCalculation: 'Total call records synchronized from 9ance telephony API and incoming webhooks.',
                    meaningAction: 'Reflects telecaller outbound cadence and overall team dialing activity.',
                    actionLabel: 'View Call Logs',
                    onTap: () => context.go('/crm/pre-sales?tab=2'),
                  ));
                }

                if (settings?.kpiShowAnsweredCalls ?? true) {
                  cards.add(_buildKpiCard(
                    context,
                    title: 'Answered Calls',
                    value: '${kpi.answeredCalls}',
                    subtext: 'Connected talks',
                    icon: Icons.phone_callback_rounded,
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    meaningDefinition: 'Successful call connections where the prospect answered the phone and spoke with the telecaller.',
                    meaningCalculation: 'Calls where call disposition is ANSWERED with customer talk duration > 0 seconds.',
                    meaningAction: 'Direct measure of lead contactability and connection rate. Aim to increase connection rates with optimal call timing.',
                    actionLabel: 'View Answered Calls',
                    onTap: () => context.go('/crm/pre-sales?tab=2&callStatus=ANSWERED'),
                  ));
                }

                if (settings?.kpiShowMissedCalls ?? true) {
                  cards.add(_buildKpiCard(
                    context,
                    title: 'Missed / Busy',
                    value: '${kpi.missedCalls}',
                    subtext: 'Pending retry calls',
                    icon: Icons.phone_missed_rounded,
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    meaningDefinition: 'Outbound dialing attempts where the customer line was busy, unanswered, or connection failed.',
                    meaningCalculation: 'Calls where 9ance returned status MISSED, BUSY, NO_ANSWER, or CANCEL.',
                    meaningAction: 'Pending retry queue. Re-schedule outbound attempts at different hours or send automated WhatsApp follow-ups.',
                    actionLabel: 'View Missed Calls',
                    onTap: () => context.go('/crm/pre-sales?tab=2&callStatus=MISSED'),
                  ));
                }

                if (settings?.kpiShowTalkTime ?? true) {
                  cards.add(_buildKpiCard(
                    context,
                    title: 'Total Talk Time',
                    value: '${kpi.totalTalkTimeMinutes}m',
                    subtext: 'Cumulative call time',
                    icon: Icons.timer_rounded,
                    color: const Color(0xFF06B6D4),
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    meaningDefinition: 'Cumulative customer conversation time logged across all telecallers today.',
                    meaningCalculation: 'Sum of all customer talk duration seconds converted into minutes.',
                    meaningAction: 'Quality benchmark. Higher talk time per call correlates strongly with thorough lead qualification and rapport building.',
                    actionLabel: 'View Talk Time Analytics',
                    onTap: () => _showTalkTimeBreakdownDialog(context, kpi, isDark),
                  ));
                }

                if (settings?.kpiShowFreshLeads ?? true) {
                  cards.add(_buildKpiCard(
                    context,
                    title: 'Fresh Leads',
                    value: '${kpi.freshLeads}',
                    subtext: 'Uncontacted leads',
                    icon: Icons.fiber_new_rounded,
                    color: const Color(0xFF3B82F6),
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    meaningDefinition: 'New incoming leads from Excel imports or webhooks that have not yet received their first call.',
                    meaningCalculation: 'Leads where status = NOT_STARTED and total calls logged = 0.',
                    meaningAction: 'Speed-to-lead is critical. Calling new inquiries within 15 minutes yields up to 300% higher connect rates.',
                    actionLabel: 'View Fresh Leads',
                    onTap: () => context.go('/crm/pre-sales?tab=0&status=NOT_STARTED'),
                  ));
                }

                if (settings?.kpiShowConversionRate ?? true) {
                  cards.add(_buildKpiCard(
                    context,
                    title: 'Conversion Rate',
                    value: '${kpi.conversionRate}%',
                    subtext: 'Pre-sales to sales',
                    icon: Icons.trending_up_rounded,
                    color: const Color(0xFFEC4899),
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    meaningDefinition: 'Percentage of active leads that successfully progressed into Interested Deals.',
                    meaningCalculation: 'Interested Deals (${kpi.interestedDeals}) ÷ Active Pipeline Leads (${kpi.totalActiveLeads}) × 100%.',
                    meaningAction: 'Core efficiency KPI. Evaluates lead source quality, telecaller pitch effectiveness, and funnel health.',
                    actionLabel: 'View Conversion Funnel',
                    onTap: () => _showConversionFunnelDialog(context, kpi, isDark),
                  ));
                }

                if (cards.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Center(
                      child: Text(
                        'No KPI metrics enabled. Visit CRM Settings > Dashboard KPI Management to enable cards.',
                        style: TextStyle(fontSize: 13, color: textMuted),
                      ),
                    ),
                  );
                }

                final gridWidget = TourTarget(
                  id: TourIds.step('crm.dashboard', 2),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = constraints.maxWidth;
                      final isLarge = cardWidth >= 900;
                      final isMedium = cardWidth >= 600;

                      final crossAxisCount = isLarge ? 4 : (isMedium ? 3 : 2);
                      final childAspectRatio = isLarge
                          ? 1.8
                          : (isMedium ? 1.5 : (cardWidth < 360 ? 1.08 : (cardWidth < 420 ? 1.18 : 1.35)));

                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: childAspectRatio,
                        children: cards,
                      );
                    },
                  ),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: (isPersonal ? const Color(0xFF0284C7) : const Color(0xFFD97706))
                            .withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (isPersonal ? const Color(0xFF0284C7) : const Color(0xFFD97706))
                              .withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPersonal ? Icons.person_rounded : Icons.admin_panel_settings_rounded,
                            size: 16,
                            color: isPersonal
                                ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                                : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isPersonal
                                  ? 'My Performance KPIs (Personal Metrics)'
                                  : 'Total Organization KPIs (Admin Overview Across All Agents)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isPersonal
                                    ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                                    : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309)),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isPersonal ? const Color(0xFF0284C7) : const Color(0xFFD97706))
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isPersonal ? 'INDIVIDUAL' : 'ADMIN VIEW',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: isPersonal
                                    ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                                    : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    gridWidget,
                  ],
                );
              })(),
            ],
            const SizedBox(height: 20),

            // TODAY'S SCHEDULED FOLLOW-UPS SECTION HEADER
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.alarm_on_rounded, size: 16, color: Color(0xFFEA580C)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Today's Scheduled Follow-ups",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: state.todayFollowUps.isNotEmpty
                        ? const Color(0xFFEA580C).withValues(alpha: 0.12)
                        : (isDark ? Colors.white10 : Colors.black12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${state.todayFollowUps.length} Pending Today',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: state.todayFollowUps.isNotEmpty ? const Color(0xFFEA580C) : textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Today's Follow-up Calls List
            if (state.todayFollowUps.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 40, color: Colors.green.withValues(alpha: 0.7)),
                      const SizedBox(height: 8),
                      Text(
                        'No pending calls scheduled for today!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All follow-ups are up to date.',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.todayFollowUps.length > 5 ? 5 : state.todayFollowUps.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                      itemBuilder: (context, index) {
                        final item = state.todayFollowUps[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFEA580C).withValues(alpha: 0.12),
                            child: const Icon(Icons.phone_in_talk_rounded, size: 18, color: Color(0xFFEA580C)),
                          ),
                          title: Text(
                            item.leadName ?? 'Unnamed Lead',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          subtitle: Text(
                            '${item.leadPhone ?? "No phone"} • Time: ${item.scheduledTime}${item.remarks != null ? " • ${item.remarks}" : ""}',
                            style: TextStyle(fontSize: 12, color: textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF16A34A), size: 18),
                                tooltip: 'Call Lead',
                                onPressed: () async {
                                  final dial = await showClickToCallDialDialog(
                                    context,
                                    phone: item.leadPhone ?? '',
                                    leadName: item.leadName,
                                  );
                                  if (dial == null || !context.mounted) return;
                                  context.read<CrmRepository>().clickToCall(
                                        item.leadId,
                                        customerNumber: dial,
                                      );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Calling ${item.leadName ?? dial}...'),
                                      backgroundColor: const Color(0xFF16A34A),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 4),
                              ElevatedButton(
                                onPressed: () => bloc.add(CrmDashboardFollowUpCompleted(item.id, remarks: 'Completed from Dashboard')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: const Size(60, 32),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Done', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (state.todayFollowUps.length > 5) ...[
                      Divider(height: 1, color: borderColor),
                      InkWell(
                        onTap: () => context.go('/crm/pre-sales'),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View all ${state.todayFollowUps.length} follow-ups in Pre-Sales',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFEA580C)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Quick Navigation Shortcuts
            TourTarget(
              id: TourIds.step('crm.dashboard', 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Text(
              'CRM Modules & Workspaces',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),

            LayoutBuilder(
              builder: (context, constraints) {
                final List<Widget> moduleTiles = [
                  if (canReadPreSales)
                    _buildModuleTile(
                      context,
                      title: 'Pre-sales',
                      description: 'Inquiries, dynamic columns, 9ance dialer, and sales pipeline.',
                      icon: Icons.point_of_sale_rounded,
                      color: const Color(0xFF0284C7),
                      route: '/crm/pre-sales',
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textMuted: textMuted,
                    ),
                  if (canReadPostSales)
                    _buildModuleTile(
                      context,
                      title: 'Post-sales',
                      description: 'Handovers, client accounts, customer service & tickets.',
                      icon: Icons.support_agent_rounded,
                      color: const Color(0xFF16A34A),
                      route: '/crm/post-sales',
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textMuted: textMuted,
                    ),
                  if (canAccessBin)
                    _buildModuleTile(
                      context,
                      title: 'CRM Bin',
                      description: 'Discarded & Not Interested leads with 30-day restore.',
                      icon: Icons.delete_outline_rounded,
                      color: const Color(0xFFEF4444),
                      route: '/crm/bin',
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textMuted: textMuted,
                    ),
                  if (canAccessSettings)
                    _buildModuleTile(
                      context,
                      title: 'CRM Settings',
                      description: 'Dynamic columns, 9ance Cloud Telephony, and retention rules.',
                      icon: Icons.settings_rounded,
                      color: primaryGold,
                      route: '/crm/settings',
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textMuted: textMuted,
                    ),
                ];

                if (moduleTiles.isEmpty) {
                  return const SizedBox.shrink();
                }

                final isStacked = constraints.maxWidth < 650;

                if (isStacked) {
                  return Column(
                    children: [
                      for (int i = 0; i < moduleTiles.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        moduleTiles[i],
                      ],
                    ],
                  );
                }

                final rows = <Widget>[];
                for (int i = 0; i < moduleTiles.length; i += 2) {
                  final first = moduleTiles[i];
                  final second = (i + 1 < moduleTiles.length) ? moduleTiles[i + 1] : null;
                  if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
                  rows.add(
                    Row(
                      children: [
                        Expanded(child: first),
                        const SizedBox(width: 12),
                        Expanded(child: second ?? const SizedBox.shrink()),
                      ],
                    ),
                  );
                }

                return Column(children: rows);
              },
            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  },
);
}

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required String meaningDefinition,
    required String meaningCalculation,
    required String meaningAction,
    String? actionLabel,
    required VoidCallback onTap,
  }) {
    bool isHovered = false;

    return StatefulBuilder(
      builder: (context, setHoverState) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setHoverState(() => isHovered = true),
          onExit: (_) => setHoverState(() => isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: isHovered
                  ? (isDark ? const Color(0xFF262E3D) : Colors.white)
                  : cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isHovered ? color.withValues(alpha: 0.6) : borderColor,
                width: isHovered ? 1.5 : 1,
              ),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message: 'Learn what "$title" means & calculation',
                                child: InkWell(
                                  onTap: () => _showKpiMeaningDialog(
                                    context,
                                    title: title,
                                    value: value,
                                    color: color,
                                    definition: meaningDefinition,
                                    calculation: meaningCalculation,
                                    action: meaningAction,
                                    actionLabel: actionLabel,
                                    onNavigate: onTap,
                                    isDark: isDark,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: Icon(
                                      Icons.info_outline_rounded,
                                      size: 13,
                                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(icon, size: 14, color: color),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    value,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                              ),
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 150),
                                opacity: isHovered ? 1.0 : 0.4,
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 13,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtext,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showKpiMeaningDialog(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
    required String definition,
    required String calculation,
    required String action,
    String? actionLabel,
    required VoidCallback onNavigate,
    required bool isDark,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          actionsPadding: const EdgeInsets.all(16),
          title: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildMeaningSection(
                  label: 'What this means',
                  content: definition,
                  color: color,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildMeaningSection(
                  label: 'How it is calculated',
                  content: calculation,
                  color: const Color(0xFF6366F1),
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildMeaningSection(
                  label: 'Recommended telecaller action',
                  content: action,
                  color: const Color(0xFF059669),
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Close', style: TextStyle(color: textMuted)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                onNavigate();
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 15),
              label: Text(actionLabel ?? 'View Data', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMeaningSection({
    required String label,
    required String content,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  void _showTalkTimeBreakdownDialog(BuildContext context, CrmKpiMetrics kpi, bool isDark) {
    final avgMinutes = kpi.answeredCalls > 0
        ? (kpi.totalTalkTimeMinutes / kpi.answeredCalls).toStringAsFixed(1)
        : '0.0';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: const Text('Total Talk Time Breakdown', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol('Total Talk', '${kpi.totalTalkTimeMinutes}m', const Color(0xFF06B6D4), isDark),
                    _buildStatCol('Connected', '${kpi.answeredCalls}', const Color(0xFF10B981), isDark),
                    _buildStatCol('Avg / Call', '${avgMinutes}m', const Color(0xFF6366F1), isDark),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Longer connected conversations correlate strongly with higher site visits and customer interest. Telecallers spending at least 2.5 minutes per call show 2.4x higher conversion.',
                  style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/crm/pre-sales?tab=2');
              },
              child: const Text('View Call Recordings'),
            ),
          ],
        );
      },
    );
  }

  void _showConversionFunnelDialog(BuildContext context, CrmKpiMetrics kpi, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: const Text('Pre-Sales Conversion Funnel', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFunnelRow('1. Pipeline Leads', '${kpi.totalActiveLeads}', 1.0, const Color(0xFF3B82F6), isDark),
                const SizedBox(height: 8),
                _buildFunnelRow(
                  '2. Connected Calls',
                  '${kpi.answeredCalls}',
                  kpi.totalActiveLeads > 0 ? (kpi.answeredCalls / kpi.totalActiveLeads).clamp(0.05, 1.0) : 0.05,
                  const Color(0xFF10B981),
                  isDark,
                ),
                const SizedBox(height: 8),
                _buildFunnelRow(
                  '3. Interested Deals',
                  '${kpi.interestedDeals}',
                  kpi.totalActiveLeads > 0 ? (kpi.interestedDeals / kpi.totalActiveLeads).clamp(0.05, 1.0) : 0.05,
                  const Color(0xFF16A34A),
                  isDark,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC4899).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Overall Conversion Rate', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${kpi.conversionRate}%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFEC4899))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/crm/pre-sales?tab=3');
              },
              child: const Text('View Deals Pipeline'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCol(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : const Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildFunnelRow(String label, String value, double fraction, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            color: color,
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildModuleTile(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String route,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textMuted,
  }) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
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
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: textMuted,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
