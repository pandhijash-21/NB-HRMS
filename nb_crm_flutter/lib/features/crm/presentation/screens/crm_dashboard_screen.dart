import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../crm_providers.dart';
import '../../domain/crm_models.dart';

class CrmDashboardScreen extends ConsumerWidget {
  const CrmDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final isSmall = width < 600;

    final primaryGold = isDark ? const Color(0xFFC5A059) : const Color(0xFF2563EB);
    final cardBg = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFFC5A059).withOpacity(0.18)
        : const Color(0xFFE2E8F0);
    final textMuted = isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF64748B);

    final kpiAsync = ref.watch(crmKpiProvider);
    final todayFollowUpsAsync = ref.watch(crmFollowUpsProvider('today'));
    final settingsAsync = ref.watch(crmSettingsProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141210) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('NB CRM Workspace'),
        leading: const AppBackButton(),
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'Bin / Archive',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => context.go('/crm/bin'),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/crm/settings'),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(crmKpiProvider);
              ref.invalidate(crmFollowUpsProvider);
              ref.invalidate(crmSettingsProvider);
              ref.read(crmLeadsProvider.notifier).refresh();
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
                      color: primaryGold.withOpacity(0.12),
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
            kpiAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator())),
              error: (_, __) => const SizedBox.shrink(),
              data: (kpi) {
                final settings = settingsAsync.value;
                final List<Widget> cards = [];

                if (settings?.kpiShowActiveLeads ?? true) {
                  cards.add(_buildKpiCard(
                    context,
                    title: 'Active Leads',
                    value: '${kpi.totalActiveLeads}',
                    subtext: 'Pre-sales pipeline',
                    icon: Icons.people_alt_rounded,
                    color: const Color(0xFF0284C7),
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
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
                  ));
                }

                if (settings?.kpiShowBinCount ?? true) {
                  cards.add(_buildKpiCard(
                    context,
                    title: 'In Bin / Archive',
                    value: '${kpi.binCount}',
                    subtext: 'Restorable leads',
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFEF4444),
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                  ));
                }

                if (settings?.kpiShowTotalCalls ?? true) {
                  cards.add(_buildKpiCard(
                    context,
                    title: 'Total Calls Logged',
                    value: '${kpi.totalCalls}',
                    subtext: 'Greeter / Elision logged',
                    icon: Icons.phone_in_talk_rounded,
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
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

                return LayoutBuilder(
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
                );
              },
            ),
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
                        color: const Color(0xFFEA580C).withOpacity(0.12),
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
                todayFollowUpsAsync.when(
                  data: (items) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: items.isNotEmpty
                          ? const Color(0xFFEA580C).withOpacity(0.12)
                          : (isDark ? Colors.white10 : Colors.black12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${items.length} Pending Today',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: items.isNotEmpty ? const Color(0xFFEA580C) : textMuted,
                      ),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Today's Follow-up Calls List
            todayFollowUpsAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (err, _) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Text('Error loading follow-ups: $err', style: const TextStyle(color: Colors.red)),
              ),
              data: (followUps) {
                if (followUps.isEmpty) {
                  return Container(
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
                          Icon(Icons.check_circle_outline_rounded, size: 40, color: Colors.green.withOpacity(0.7)),
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
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: followUps.length > 5 ? 5 : followUps.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                    itemBuilder: (context, index) {
                      final item = followUps[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFEA580C).withOpacity(0.12),
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
                        trailing: ElevatedButton(
                          onPressed: () async {
                            await ref.read(crmRepositoryProvider).completeFollowUp(
                                  item.id,
                                  remarks: 'Completed from Dashboard',
                                );
                            ref.invalidate(crmFollowUpsProvider);
                            ref.invalidate(crmKpiProvider);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: const Size(60, 32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Done', style: TextStyle(fontSize: 12)),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Quick Navigation Shortcuts
            Text(
              'CRM Modules & Workspaces',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),

            // Adaptive Workspace Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isStacked = constraints.maxWidth < 650;

                if (isStacked) {
                  return Column(
                    children: [
                      _buildModuleTile(
                        context,
                        title: 'Pre-sales',
                        description: 'Inquiries, dynamic columns, Elision dialer, and sales pipeline.',
                        icon: Icons.point_of_sale_rounded,
                        color: const Color(0xFF0284C7),
                        route: '/crm/pre-sales',
                        isDark: isDark,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        textMuted: textMuted,
                      ),
                      const SizedBox(height: 10),
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
                      const SizedBox(height: 10),
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
                      const SizedBox(height: 10),
                      _buildModuleTile(
                        context,
                        title: 'CRM Settings',
                        description: 'Dynamic columns, Elision telephony API, and retention rules.',
                        icon: Icons.settings_rounded,
                        color: primaryGold,
                        route: '/crm/settings',
                        isDark: isDark,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        textMuted: textMuted,
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildModuleTile(
                            context,
                            title: 'Pre-sales',
                            description: 'Inquiries, dynamic columns, Elision dialer, and sales pipeline.',
                            icon: Icons.point_of_sale_rounded,
                            color: const Color(0xFF0284C7),
                            route: '/crm/pre-sales',
                            isDark: isDark,
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textMuted: textMuted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModuleTile(
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModuleTile(
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
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModuleTile(
                            context,
                            title: 'CRM Settings',
                            description: 'Dynamic columns, Elision telephony API, and retention rules.',
                            icon: Icons.settings_rounded,
                            color: primaryGold,
                            route: '/crm/settings',
                            isDark: isDark,
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textMuted: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
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
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(height: 1),
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
                color: color.withOpacity(0.12),
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
