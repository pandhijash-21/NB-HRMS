import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/router/app_back_button.dart';
import '../../data/crm_repository.dart';
import '../../domain/crm_models.dart';
import '../widgets/crm_scope_selector.dart';
import '../widgets/crm_send_whatsapp_dialog.dart';

class _ChartData {
  final String x;
  final num y;
  _ChartData(this.x, this.y);
}

Color _getStatusColor(CrmStatus status) {
  switch (status) {
    case CrmStatus.notStarted:
      return const Color(0xFF64748B);
    case CrmStatus.assigned:
      return const Color(0xFF6366F1);
    case CrmStatus.cnr:
      return const Color(0xFFF59E0B);
    case CrmStatus.scheduledVisit:
      return const Color(0xFF2563EB);
    case CrmStatus.notInterested:
      return const Color(0xFFEF4444);
    case CrmStatus.siteVisitDone:
      return const Color(0xFF10B981);
    case CrmStatus.followUp:
      return const Color(0xFFD97706);
    case CrmStatus.interested:
      return const Color(0xFF8B5CF6);
    case CrmStatus.proposalSent:
      return const Color(0xFF06B6D4);
    case CrmStatus.bookingConfirmed:
      return const Color(0xFF16A34A);
    case CrmStatus.rejected:
      return const Color(0xFFDC2626);
  }
}

IconData _getStatusIcon(CrmStatus status) {
  switch (status) {
    case CrmStatus.notStarted:
      return Icons.radio_button_unchecked_rounded;
    case CrmStatus.assigned:
      return Icons.assignment_ind_rounded;
    case CrmStatus.cnr:
      return Icons.phone_missed_rounded;
    case CrmStatus.scheduledVisit:
      return Icons.calendar_month_rounded;
    case CrmStatus.notInterested:
      return Icons.cancel_outlined;
    case CrmStatus.siteVisitDone:
      return Icons.where_to_vote_rounded;
    case CrmStatus.followUp:
      return Icons.schedule_rounded;
    case CrmStatus.interested:
      return Icons.thumb_up_alt_rounded;
    case CrmStatus.proposalSent:
      return Icons.description_rounded;
    case CrmStatus.bookingConfirmed:
      return Icons.verified_rounded;
    case CrmStatus.rejected:
      return Icons.block_rounded;
  }
}

class CrmLeadMineScreen extends StatefulWidget {
  const CrmLeadMineScreen({super.key});

  @override
  State<CrmLeadMineScreen> createState() => _CrmLeadMineScreenState();
}

class _CrmLeadMineScreenState extends State<CrmLeadMineScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  // Filter state
  String _searchQuery = '';
  String _binFilter = 'ALL'; // 'ALL', 'ACTIVE', 'BIN'
  String _selectedCampaignId = 'ALL';
  String _selectedStatus = 'ALL';
  String _selectedSource = 'ALL';
  int _currentPage = 1;
  int _pageSize = 50;

  // Data
  Map<String, dynamic> _summary = {};
  List<CrmLead> _leads = [];
  int _totalCount = 0;
  List<CrmCampaign> _campaigns = [];

  bool _showCharts = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCampaigns();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCampaigns() async {
    try {
      final repo = context.read<CrmRepository>();
      final camps = await repo.getCampaigns();
      if (mounted) {
        setState(() => _campaigns = camps);
      }
    } catch (_) {}
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<CrmRepository>();
      final res = await repo.getLeadMineData(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        status: _selectedStatus == 'ALL' ? null : _selectedStatus,
        binStatus: _binFilter,
        campaignId: _selectedCampaignId == 'ALL' ? null : _selectedCampaignId,
        leadSource: _selectedSource == 'ALL' ? null : _selectedSource,
        page: _currentPage,
        limit: _pageSize,
      );

      if (mounted) {
        setState(() {
          _summary = res.summary;
          _leads = res.items;
          _totalCount = res.total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String val) {
    _searchQuery = val.trim();
    _currentPage = 1;
    _fetchData();
  }

  void _onBinFilterChanged(String filter) {
    if (_binFilter == filter) return;
    setState(() {
      _binFilter = filter;
      _currentPage = 1;
    });
    _fetchData();
  }

  Future<void> _handleRestoreLead(CrmLead lead) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Lead'),
        content: Text('Are you sure you want to restore "${lead.name.isNotEmpty ? lead.name : lead.phone}" back to active leads?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final repo = context.read<CrmRepository>();
        await repo.restoreFromBin(lead.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lead restored successfully.'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
          _fetchData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to restore: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _exportCsv() {
    if (_leads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No leads to export.')),
      );
      return;
    }

    final headers = ['ID', 'Name', 'Phone', 'Campaign', 'Status', 'In Bin', 'Telecaller', 'Source', 'Date Added'];
    final rows = _leads.map((l) => [
      l.id,
      '"${l.name.replaceAll('"', '""')}"',
      '"${l.phone}"',
      '"${(l.campaignName ?? '').replaceAll('"', '""')}"',
      l.status.displayName,
      l.isDeleted ? 'YES' : 'NO',
      '"${(l.telecallerName ?? 'Unassigned').replaceAll('"', '""')}"',
      l.leadSource ?? '',
      DateFormat('yyyy-MM-dd HH:mm').format(l.createdAt.toLocal()),
    ].join(',')).toList();

    final csvContent = [headers.join(','), ...rows].join('\n');
    Clipboard.setData(ClipboardData(text: csvContent));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${_leads.length} leads to CSV (Copied to Clipboard)!'),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header Top Bar
            _buildTopBar(isDark, cardBg, borderColor, textMuted),

            // Content Area
            Expanded(
              child: _isLoading && _leads.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null && _leads.isEmpty
                      ? _buildErrorView()
                      : RefreshIndicator(
                          onRefresh: _fetchData,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Quick KPI Cards
                                _buildKpiGrid(isDark, cardBg, borderColor, textMuted),
                                const SizedBox(height: 16),

                                // Visual Charts (Collapsible)
                                if (_showCharts) ...[
                                  _buildChartsSection(isDark, cardBg, borderColor, textMuted),
                                  const SizedBox(height: 20),
                                ],

                                // Filter Controls Bar
                                _buildFilterBar(isDark, cardBg, borderColor, textMuted),
                                const SizedBox(height: 14),

                                // Tabular / List Data Section
                                _buildDataTableCard(isDark, cardBg, borderColor, textMuted),
                                const SizedBox(height: 16),

                                // Pagination Footer
                                _buildPaginationFooter(isDark, cardBg, borderColor, textMuted),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          const AppBackButton(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.diamond_rounded, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Lead Mine',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_rounded, size: 12, color: Color(0xFFF59E0B)),
                          SizedBox(width: 4),
                          Text(
                            'Admin Vault',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  'All-time repository of every lead in CRM including pipeline and bin archives',
                  style: TextStyle(fontSize: 11.5, color: textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CrmScopeSelectorWidget(isSidebar: false),
          const SizedBox(width: 8),
          Tooltip(
            message: _showCharts ? 'Hide Visual Analytics' : 'Show Visual Analytics',
            child: IconButton(
              onPressed: () => setState(() => _showCharts = !_showCharts),
              icon: Icon(
                _showCharts ? Icons.insights_rounded : Icons.bar_chart_rounded,
                color: _showCharts ? const Color(0xFF8B5CF6) : textMuted,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
          Tooltip(
            message: 'Export Filtered Leads to CSV',
            child: OutlinedButton.icon(
              onPressed: _exportCsv,
              icon: const Icon(Icons.download_rounded, size: 15),
              label: const Text('Export CSV', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Refresh Mine',
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    final total = (_summary['totalLeads'] as num?)?.toInt() ?? _totalCount;
    final active = (_summary['activeLeads'] as num?)?.toInt() ?? 0;
    final inBin = (_summary['binLeads'] as num?)?.toInt() ?? 0;
    final booked = (_summary['bookedLeads'] as num?)?.toInt() ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final isMedium = constraints.maxWidth >= 600 && constraints.maxWidth < 900;

        final items = [
          _buildKpiCard(
            title: 'Total Leads In Mine',
            value: total.toString(),
            subtitle: '100% of all CRM records',
            icon: Icons.diamond_rounded,
            gradient: const [Color(0xFF8B5CF6), Color(0xFF6366F1)],
            cardBg: cardBg,
            borderColor: borderColor,
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Active Pipeline',
            value: active.toString(),
            subtitle: total > 0 ? '${((active / total) * 100).toStringAsFixed(1)}% active' : '0%',
            icon: Icons.check_circle_outline_rounded,
            gradient: const [Color(0xFF10B981), Color(0xFF059669)],
            cardBg: cardBg,
            borderColor: borderColor,
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'In Bin / Deleted',
            value: inBin.toString(),
            subtitle: total > 0 ? '${((inBin / total) * 100).toStringAsFixed(1)}% archived' : '0%',
            icon: Icons.delete_outline_rounded,
            gradient: const [Color(0xFFEF4444), Color(0xFFDC2626)],
            cardBg: cardBg,
            borderColor: borderColor,
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Converted / Booked',
            value: booked.toString(),
            subtitle: total > 0 ? '${((booked / total) * 100).toStringAsFixed(1)}% conversion' : '0%',
            icon: Icons.stars_rounded,
            gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
            cardBg: cardBg,
            borderColor: borderColor,
            isDark: isDark,
          ),
        ];

        if (isWide) {
          return Row(
            children: items.map((w) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: w))).toList(),
          );
        } else if (isMedium) {
          return Column(
            children: [
              Row(children: [Expanded(child: items[0]), const SizedBox(width: 10), Expanded(child: items[1])]),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: items[2]), const SizedBox(width: 10), Expanded(child: items[3])]),
            ],
          );
        } else {
          return Column(
            children: items.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w)).toList(),
          );
        }
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required Color cardBg,
    required Color borderColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    // Process Status data
    final byStatus = (_summary['byStatus'] as Map<String, dynamic>?) ?? {};
    final statusData = byStatus.entries.map((e) {
      final label = CrmStatus.fromString(e.key).displayName;
      return _ChartData(label, e.value as num);
    }).toList();

    // Process Source data
    final bySource = (_summary['bySource'] as Map<String, dynamic>?) ?? {};
    final sourceData = bySource.entries.map((e) {
      return _ChartData(e.key, e.value as num);
    }).toList();

    // Process Top Campaigns
    final byCampaign = (_summary['byCampaign'] as List<dynamic>?) ?? [];
    final campData = byCampaign.take(5).map((e) {
      final name = e['name']?.toString() ?? 'Campaign';
      final count = (e['count'] as num?) ?? 0;
      return _ChartData(name.length > 14 ? '${name.substring(0, 12)}…' : name, count);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 960;

        final chart1 = _buildChartContainer(
          title: 'Status & Pipeline Distribution',
          icon: Icons.pie_chart_outline_rounded,
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
          child: statusData.isEmpty
              ? _buildEmptyChartPlaceholder('No status data available')
              : SfCircularChart(
                  legend: Legend(
                    isVisible: true,
                    position: LegendPosition.bottom,
                    textStyle: TextStyle(fontSize: 10, color: textMuted),
                    overflowMode: LegendItemOverflowMode.wrap,
                  ),
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: <DoughnutSeries<_ChartData, String>>[
                    DoughnutSeries<_ChartData, String>(
                      dataSource: statusData,
                      xValueMapper: (_ChartData d, _) => d.x,
                      yValueMapper: (_ChartData d, _) => d.y,
                      innerRadius: '58%',
                      explode: true,
                      explodeIndex: 0,
                      dataLabelSettings: const DataLabelSettings(
                        isVisible: true,
                        labelPosition: ChartDataLabelPosition.outside,
                        textStyle: TextStyle(fontSize: 9.5),
                      ),
                    ),
                  ],
                ),
        );

        final chart2 = _buildChartContainer(
          title: 'Acquisition Channels / Sources',
          icon: Icons.bubble_chart_outlined,
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
          child: sourceData.isEmpty
              ? _buildEmptyChartPlaceholder('No source data available')
              : SfCircularChart(
                  legend: Legend(
                    isVisible: true,
                    position: LegendPosition.bottom,
                    textStyle: TextStyle(fontSize: 10, color: textMuted),
                    overflowMode: LegendItemOverflowMode.wrap,
                  ),
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: <PieSeries<_ChartData, String>>[
                    PieSeries<_ChartData, String>(
                      dataSource: sourceData,
                      xValueMapper: (_ChartData d, _) => d.x,
                      yValueMapper: (_ChartData d, _) => d.y,
                      dataLabelSettings: const DataLabelSettings(
                        isVisible: true,
                        labelPosition: ChartDataLabelPosition.inside,
                        textStyle: TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
        );

        final chart3 = _buildChartContainer(
          title: 'Top Campaigns Volume',
          icon: Icons.bar_chart_rounded,
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
          child: campData.isEmpty
              ? _buildEmptyChartPlaceholder('No campaign data available')
              : SfCartesianChart(
                  primaryXAxis: const CategoryAxis(
                    labelStyle: TextStyle(fontSize: 9.5),
                    majorGridLines: MajorGridLines(width: 0),
                  ),
                  primaryYAxis: const NumericAxis(
                    majorGridLines: MajorGridLines(dashArray: [4, 4]),
                    labelStyle: TextStyle(fontSize: 9),
                  ),
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: <CartesianSeries<_ChartData, String>>[
                    ColumnSeries<_ChartData, String>(
                      dataSource: campData,
                      xValueMapper: (_ChartData d, _) => d.x,
                      yValueMapper: (_ChartData d, _) => d.y,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ],
                ),
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: chart1),
              const SizedBox(width: 12),
              Expanded(child: chart2),
              const SizedBox(width: 12),
              Expanded(child: chart3),
            ],
          );
        } else {
          return Column(
            children: [
              chart1,
              const SizedBox(height: 12),
              chart2,
              const SizedBox(height: 12),
              chart3,
            ],
          );
        }
      },
    );
  }

  Widget _buildChartContainer({
    required String title,
    required IconData icon,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Widget child,
  }) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: const Color(0xFF8B5CF6)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildEmptyChartPlaceholder(String message) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
      ),
    );
  }

  Widget _buildFilterBar(bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Search & Bin Filter Pills
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Search field
              SizedBox(
                width: 280,
                height: 38,
                child: TextField(
                  controller: _searchController,
                  onSubmitted: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by client name, phone...',
                    hintStyle: TextStyle(fontSize: 12, color: textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),

              // Bin Filter Toggle
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBinFilterBtn('ALL', 'All Leads', Icons.all_inbox_rounded, isDark),
                    _buildBinFilterBtn('ACTIVE', 'Active Pipeline', Icons.check_circle_outline_rounded, isDark),
                    _buildBinFilterBtn('BIN', 'In Bin / Deleted', Icons.delete_outline_rounded, isDark),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Dropdowns (Campaign, Status, Source)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Campaign Filter
              _buildDropdownFilter(
                label: 'Campaign',
                value: _selectedCampaignId,
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('All Campaigns', style: TextStyle(fontSize: 11.5))),
                  ..._campaigns.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, style: const TextStyle(fontSize: 11.5)),
                      )),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedCampaignId = val ?? 'ALL';
                    _currentPage = 1;
                  });
                  _fetchData();
                },
                isDark: isDark,
              ),

              // Status Filter
              _buildDropdownFilter(
                label: 'Status',
                value: _selectedStatus,
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('All Statuses', style: TextStyle(fontSize: 11.5))),
                  ...CrmStatus.values.map((s) => DropdownMenuItem(
                        value: s.backendValue,
                        child: Text(s.displayName, style: const TextStyle(fontSize: 11.5)),
                      )),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedStatus = val ?? 'ALL';
                    _currentPage = 1;
                  });
                  _fetchData();
                },
                isDark: isDark,
              ),

              // Source Filter
              _buildDropdownFilter(
                label: 'Source',
                value: _selectedSource,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Sources', style: TextStyle(fontSize: 11.5))),
                  DropdownMenuItem(value: 'META', child: Text('⚡ Meta Ads', style: TextStyle(fontSize: 11.5))),
                  DropdownMenuItem(value: 'GOOGLE', child: Text('🔍 Google Ads', style: TextStyle(fontSize: 11.5))),
                  DropdownMenuItem(value: 'EXCEL', child: Text('📊 Excel Upload', style: TextStyle(fontSize: 11.5))),
                  DropdownMenuItem(value: 'MANUAL', child: Text('✏️ Manual Entry', style: TextStyle(fontSize: 11.5))),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedSource = val ?? 'ALL';
                    _currentPage = 1;
                  });
                  _fetchData();
                },
                isDark: isDark,
              ),

              // Reset filters button
              if (_searchQuery.isNotEmpty || _selectedCampaignId != 'ALL' || _selectedStatus != 'ALL' || _selectedSource != 'ALL' || _binFilter != 'ALL')
                TextButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _binFilter = 'ALL';
                      _selectedCampaignId = 'ALL';
                      _selectedStatus = 'ALL';
                      _selectedSource = 'ALL';
                      _currentPage = 1;
                    });
                    _fetchData();
                  },
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 14),
                  label: const Text('Reset Filters', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBinFilterBtn(String key, String label, IconData icon, bool isDark) {
    final isSelected = _binFilter == key;
    Color activeBg = const Color(0xFF6366F1);
    if (key == 'ACTIVE') activeBg = const Color(0xFF10B981);
    if (key == 'BIN') activeBg = const Color(0xFFEF4444);

    return InkWell(
      onTap: () => _onBinFilterChanged(key),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          isDense: true,
          style: TextStyle(
            fontSize: 11.5,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
        ),
      ),
    );
  }

  Widget _buildDataTableCard(bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.list_alt_rounded, size: 16, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 6),
                Text(
                  'Lead Records in Mine',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_totalCount found',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                  ),
                ),
                const Spacer(),
                Text(
                  'Click row to view full lead details',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: textMuted),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Table Content
          if (_leads.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.folder_open_rounded, size: 40, color: textMuted),
                    const SizedBox(height: 8),
                    Text('No leads match the current filter criteria.', style: TextStyle(color: textMuted, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 800) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF8FAFC),
                        ),
                        dataRowMinHeight: 48,
                        dataRowMaxHeight: 56,
                        horizontalMargin: 16,
                        columnSpacing: 18,
                        columns: const [
                          DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                          DataColumn(label: Text('Client Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                          DataColumn(label: Text('Phone / WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                          DataColumn(label: Text('Campaign', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                          DataColumn(label: Text('Allocated Telecaller', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                          DataColumn(label: Text('Pipeline Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                          DataColumn(label: Text('Archival / Bin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                          DataColumn(label: Text('Source', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                          DataColumn(label: Text('Date Added', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                        ],
                        rows: _leads.asMap().entries.map((entry) {
                          final idx = (_currentPage - 1) * _pageSize + entry.key + 1;
                          final lead = entry.value;
                          return _buildDataRow(idx, lead, isDark, textMuted);
                        }).toList(),
                      ),
                    ),
                  );
                } else {
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _leads.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final lead = _leads[index];
                      return _buildMobileLeadItem(lead, isDark, textMuted);
                    },
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(int idx, CrmLead lead, bool isDark, Color textMuted) {
    return DataRow(
      onSelectChanged: (_) => _openLeadDetail(lead),
      cells: [
        DataCell(Text('#$idx', style: TextStyle(fontSize: 11, color: textMuted))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.25 : 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4), width: 0.8),
                ),
                child: const Icon(Icons.info_outline_rounded, size: 12.5, color: Color(0xFF6366F1)),
              ),
              Text(
                lead.name.trim().isNotEmpty ? lead.name : 'Unknown Client',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                lead.phone.isNotEmpty ? lead.phone : 'No Phone',
                style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Send WhatsApp',
                icon: const Icon(Icons.chat_bubble_rounded, size: 15, color: Color(0xFF22C55E)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: () => showSendWhatsappDialog(context, lead: lead),
              ),
            ],
          ),
        ),
        DataCell(
          Text(
            lead.campaignName ?? 'Unassigned',
            style: const TextStyle(fontSize: 11),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                lead.telecallerName != null && lead.telecallerName!.isNotEmpty
                    ? Icons.headset_mic_rounded
                    : Icons.hourglass_top_rounded,
                size: 13,
                color: lead.telecallerName != null && lead.telecallerName!.isNotEmpty
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFD97706),
              ),
              const SizedBox(width: 4),
              Text(
                lead.telecallerName ?? 'Waiting List (WL)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: lead.telecallerName != null && lead.telecallerName!.isNotEmpty
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFD97706),
                ),
              ),
            ],
          ),
        ),
        DataCell(_buildStatusBadge(lead.status)),
        DataCell(_buildBinStatusBadge(lead)),
        DataCell(_buildSourceBadge(lead)),
        DataCell(
          Text(
            DateFormat('dd MMM yyyy, hh:mm a').format(lead.createdAt.toLocal()),
            style: TextStyle(fontSize: 10.5, color: textMuted),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'View Full Lead Details',
                icon: const Icon(Icons.visibility_rounded, size: 17, color: Color(0xFF6366F1)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => _openLeadDetail(lead),
              ),
              if (lead.isDeleted)
                IconButton(
                  tooltip: 'Restore from Bin',
                  icon: const Icon(Icons.restore_from_trash_rounded, size: 17, color: Color(0xFF16A34A)),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => _handleRestoreLead(lead),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLeadItem(CrmLead lead, bool isDark, Color textMuted) {
    return InkWell(
      onTap: () => _openLeadDetail(lead),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    lead.name.trim().isNotEmpty ? lead.name : 'Unknown Client',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
                _buildBinStatusBadge(lead),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.phone_rounded, size: 12, color: textMuted),
                const SizedBox(width: 4),
                Text(lead.phone, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                _buildStatusBadge(lead.status),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (lead.campaignName != null)
                  _buildTagPill(lead.campaignName!, const Color(0xFF8B5CF6)),
                _buildSourceBadge(lead),
                if (lead.telecallerName != null)
                  _buildTagPill(lead.telecallerName!, const Color(0xFF16A34A)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(CrmStatus status) {
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildBinStatusBadge(CrmLead lead) {
    if (lead.isDeleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_rounded, size: 11, color: Color(0xFFEF4444)),
            SizedBox(width: 3),
            Text(
              'IN BIN',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFEF4444)),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF10B981)),
          SizedBox(width: 3),
          Text(
            'ACTIVE',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBadge(CrmLead lead) {
    if (!lead.isManual && lead.leadSource == 'META') {
      return _buildTagPill('⚡ Meta', const Color(0xFF2563EB));
    } else if (!lead.isManual && lead.leadSource == 'GOOGLE') {
      return _buildTagPill('🔍 Google', const Color(0xFFEA4335));
    } else if (lead.isManual) {
      return _buildTagPill('✏️ Manual', const Color(0xFF8B5CF6));
    } else {
      return _buildTagPill('📊 Excel', const Color(0xFF16A34A));
    }
  }

  Widget _buildTagPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildPaginationFooter(bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    final totalPages = (_totalCount / _pageSize).ceil().clamp(1, 9999);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Text(
            'Showing ${(_currentPage - 1) * _pageSize + 1} - ${((_currentPage) * _pageSize).clamp(0, _totalCount)} of $_totalCount leads',
            style: TextStyle(fontSize: 11.5, color: textMuted),
          ),
          const Spacer(),
          // Page size dropdown
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Rows: ', style: TextStyle(fontSize: 11, color: textMuted)),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _pageSize,
                  items: const [
                    DropdownMenuItem(value: 25, child: Text('25', style: TextStyle(fontSize: 11))),
                    DropdownMenuItem(value: 50, child: Text('50', style: TextStyle(fontSize: 11))),
                    DropdownMenuItem(value: 100, child: Text('100', style: TextStyle(fontSize: 11))),
                    DropdownMenuItem(value: 200, child: Text('200', style: TextStyle(fontSize: 11))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pageSize = val;
                        _currentPage = 1;
                      });
                      _fetchData();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            onPressed: _currentPage > 1
                ? () {
                    setState(() => _currentPage--);
                    _fetchData();
                  }
                : null,
            visualDensity: VisualDensity.compact,
          ),
          Text('Page $_currentPage of $totalPages', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            onPressed: _currentPage < totalPages
                ? () {
                    setState(() => _currentPage++);
                    _fetchData();
                  }
                : null,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              'Failed to load Lead Mine records',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'An unexpected error occurred.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  void _openLeadDetail(CrmLead lead) {
    context.go('/crm/lead-mine/${lead.id}', extra: lead);
  }
}
