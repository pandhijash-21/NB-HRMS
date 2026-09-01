import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_back_button.dart';

class CrmPostSalesScreen extends ConsumerStatefulWidget {
  const CrmPostSalesScreen({super.key});

  @override
  ConsumerState<CrmPostSalesScreen> createState() => _CrmPostSalesScreenState();
}

class _CrmPostSalesScreenState extends ConsumerState<CrmPostSalesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;

    final primaryColor = const Color(0xFF16A34A);
    final cardBg = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFFC5A059).withOpacity(0.18)
        : const Color(0xFFE2E8F0);
    final textMuted = isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141210) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Post-Sales'),
        leading: const AppBackButton(fallbackLocation: '/crm/dashboard'),
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Handovers & Delivery'),
            Tab(text: 'Customer Accounts'),
            Tab(text: 'Service & Support'),
            Tab(text: 'Feedback & Reviews'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New Ticket / Request',
            icon: const Icon(Icons.add_task_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Create Post-Sales Ticket ready for integration'),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Post-sales data refreshed'),
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
          _buildHandoversTab(isDark, cardBg, borderColor, textMuted, wide),
          _buildAccountsTab(isDark, cardBg, borderColor, textMuted),
          _buildServiceTab(isDark, cardBg, borderColor, textMuted),
          _buildFeedbackTab(isDark, cardBg, borderColor, textMuted),
        ],
      ),
    );
  }

  Widget _buildHandoversTab(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
    bool wide,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search & Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search customer accounts, units, or projects...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: cardBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Filters coming soon')),
                  );
                },
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Filter'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Status Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusPill('All Handovers (0)', true, isDark),
                const SizedBox(width: 8),
                _buildStatusPill('Documentation (0)', false, isDark),
                const SizedBox(width: 8),
                _buildStatusPill('Inspection Pending (0)', false, isDark),
                const SizedBox(width: 8),
                _buildStatusPill('Handed Over (0)', false, isDark),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Empty / Placeholder State
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.handshake_rounded,
                      size: 44,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'No Post-Sales Records',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage post-sales handovers, customer onboarding, documentation, and service lifecycle after deal closure.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: textMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('New Handover form ready for integration'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Initiate Handover'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String title, bool active, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? (isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFF16A34A).withOpacity(0.12))
            : (isDark ? const Color(0xFF1E1B18) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? (isDark ? const Color(0xFFC5A059) : const Color(0xFF16A34A))
              : (isDark ? const Color(0xFF393939) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active
              ? (isDark ? const Color(0xFFE2D6BE) : const Color(0xFF16A34A))
              : (isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF64748B)),
        ),
      ),
    );
  }

  Widget _buildAccountsTab(bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_box_rounded, size: 48, color: Color(0xFF0284C7)),
            const SizedBox(height: 16),
            Text(
              'Customer Accounts Directory',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Access centralized client profiles, purchase history, key contacts, and agreement documents.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceTab(bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.support_agent_rounded, size: 48, color: Color(0xFFEA580C)),
            const SizedBox(height: 16),
            Text(
              'Service Requests & Support Tickets',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track customer complaints, service requests, maintenance tickets, and SLA resolutions.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackTab(bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rate_rounded, size: 48, color: Color(0xFFEAB308)),
            const SizedBox(height: 16),
            Text(
              'Customer Feedback & CSAT',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Collect customer satisfaction scores, reviews, and survey responses to improve service quality.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
