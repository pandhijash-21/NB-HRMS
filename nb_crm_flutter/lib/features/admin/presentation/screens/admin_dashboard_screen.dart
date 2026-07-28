import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/widgets/header_action_button.dart';
import '../../../admin/presentation/admin_notifier.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../leave/presentation/leave_providers.dart';
import '../../../profile/domain/profile_models.dart';

final _dashboardEmployeesProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.read(adminRepositoryProvider).listEmployees(limit: 1000, offset: 0);
});

final _recentEmployeesProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.read(adminRepositoryProvider).listEmployees(limit: 5, offset: 0);
});

final _pendingApprovalsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final list = await ref.read(adminRepositoryProvider).listApprovals(status: 'PENDING');
  return list.length;
});

final _pendingLeaveCountProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final page = await ref.read(leaveRepositoryProvider).getAdminApplications(
          status: 'PENDING',
          limit: 1,
          page: 0,
        );
    return page.total;
  } catch (_) {
    return 0;
  }
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final hasAccess = Permissions.canAccessAdminPortal(
      auth.permissions,
      auth.user?.employeeViewScope,
    );

    if (!hasAccess) {
      return const Scaffold(
        body: Center(child: Text('Access Denied')),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final employeesAsync = ref.watch(_dashboardEmployeesProvider);
    final recentAsync = ref.watch(_recentEmployeesProvider);
    final pendingAsync = ref.watch(_pendingApprovalsCountProvider);
    final leavePendingAsync = ref.watch(_pendingLeaveCountProvider);

    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final medium = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF212F3D),
          ),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        actions: [
          HeaderActionButton(
            tooltip: 'Refresh Dashboard',
            label: 'Refresh',
            icon: Icon(
              Icons.refresh_rounded,
              size: 18,
              color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
            ),
            onPressed: () {
              ref.invalidate(_dashboardEmployeesProvider);
              ref.invalidate(_recentEmployeesProvider);
              ref.invalidate(_pendingApprovalsCountProvider);
              ref.invalidate(_pendingLeaveCountProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
            height: 1.5,
          ),
        ),
      ),
      body: employeesAsync.when(
        data: (data) {
          final items = data['items'] as List<EmployeeProfile>;
          final total = data['total'] as int;
          final activeCount = items.where((e) => e.status.toUpperCase() == 'ACTIVE').length;
          
          final deptDistribution = _getDeptDistribution(items);
          final catDistribution = _getCategoryDistribution(items);
          final timelineData = _getHiringTimeline(items);

          final deptChartData = deptDistribution.entries
              .map((e) => _ChartData(e.key, e.value.toDouble()))
              .toList();

          final catChartData = catDistribution.entries
              .map((e) => _ChartData(e.key, e.value.toDouble()))
              .toList();

          final pendingCount = pendingAsync.value ?? 0;
          final pendingLeave = leavePendingAsync.value ?? 0;
          final totalPending = pendingCount + pendingLeave;

          final kpis = [
            _KpiItem(
              label: 'Total Employees',
              value: '$total',
              icon: Icons.people_alt_rounded,
              color: const Color(0xFF0284c7),
              onTap: () => context.push('/admin/employees'),
            ),
            _KpiItem(
              label: 'Active Staff',
              value: '$activeCount',
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF16a34a),
            ),
            _KpiItem(
              label: 'Departments',
              value: '${deptDistribution.length}',
              icon: Icons.business_center_rounded,
              color: const Color(0xFF9333ea),
            ),
            _KpiItem(
              label: 'Pending Tasks',
              value: '$totalPending',
              icon: Icons.pending_actions_rounded,
              color: const Color(0xFFea580c),
              onTap: () => context.push('/admin/approvals'),
            ),
          ];

          return ListView(
            padding: EdgeInsets.symmetric(
              horizontal: medium ? 24 : 16,
              vertical: 24,
            ),
            children: [
              // KPI Row
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: kpis.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: wide ? 4 : (medium ? 2 : 1),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: wide ? 1.6 : (medium ? 2.2 : 2.8),
                ),
                itemBuilder: (context, index) {
                  final kpi = kpis[index];
                  return _KpiCard(kpi: kpi, isDark: isDark);
                },
              ),
              const SizedBox(height: 24),
              
              // Charts Double Grid (Row 1)
              GridView.count(
                crossAxisCount: wide ? 2 : 1,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: wide ? 1.4 : 1.2,
                children: [
                  _buildChartCard(
                    title: 'Department Allocation',
                    isDark: isDark,
                    child: SfCircularChart(
                      palette: const [
                        Color(0xFF0284c7),
                        Color(0xFF16a34a),
                        Color(0xFF9333ea),
                        Color(0xFFea580c),
                        Color(0xFFdb2777),
                        Color(0xFF0d9488),
                      ],
                      legend: Legend(
                        isVisible: true,
                        position: LegendPosition.bottom,
                        textStyle: TextStyle(
                          color: isDark ? Colors.white70 : const Color(0xFF263238),
                          fontSize: 11,
                        ),
                      ),
                      tooltipBehavior: TooltipBehavior(enable: true),
                      series: <DoughnutSeries<_ChartData, String>>[
                        DoughnutSeries<_ChartData, String>(
                          dataSource: deptChartData,
                          xValueMapper: (_ChartData data, _) => data.x,
                          yValueMapper: (_ChartData data, _) => data.y,
                          dataLabelSettings: const DataLabelSettings(
                            isVisible: true,
                            labelPosition: ChartDataLabelPosition.outside,
                          ),
                          innerRadius: '60%',
                          explode: true,
                          explodeIndex: 0,
                        ),
                      ],
                    ),
                  ),
                  _buildChartCard(
                    title: 'Workforce Growth Trend',
                    isDark: isDark,
                    child: SfCartesianChart(
                      primaryXAxis: CategoryAxis(
                        labelStyle: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF607D8B)),
                        majorGridLines: const MajorGridLines(width: 0),
                      ),
                      primaryYAxis: NumericAxis(
                        labelStyle: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF607D8B)),
                        majorGridLines: MajorGridLines(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      tooltipBehavior: TooltipBehavior(enable: true),
                      series: <CartesianSeries<_ChartData, String>>[
                        SplineAreaSeries<_ChartData, String>(
                          dataSource: timelineData,
                          xValueMapper: (_ChartData data, _) => data.x,
                          yValueMapper: (_ChartData data, _) => data.y,
                          name: 'Employees',
                          color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFF0284c7).withOpacity(0.15),
                          borderColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF0284c7),
                          borderWidth: 2.5,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Charts Double Grid (Row 2)
              GridView.count(
                crossAxisCount: wide ? 2 : 1,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: wide ? 1.4 : 1.2,
                children: [
                  _buildChartCard(
                    title: 'Category Split',
                    isDark: isDark,
                    child: SfCartesianChart(
                      primaryXAxis: CategoryAxis(
                        labelStyle: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF607D8B)),
                        majorGridLines: const MajorGridLines(width: 0),
                      ),
                      primaryYAxis: NumericAxis(
                        labelStyle: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF607D8B)),
                        majorGridLines: MajorGridLines(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      tooltipBehavior: TooltipBehavior(enable: true),
                      series: <CartesianSeries<_ChartData, String>>[
                        ColumnSeries<_ChartData, String>(
                          dataSource: catChartData,
                          xValueMapper: (_ChartData data, _) => data.x,
                          yValueMapper: (_ChartData data, _) => data.y,
                          name: 'Headcount',
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          color: isDark ? const Color(0xFFC5A059) : const Color(0xFF9333ea),
                          dataLabelSettings: const DataLabelSettings(isVisible: true),
                        ),
                      ],
                    ),
                  ),
                  // Recent Employees Card with unified styling
                  Card(
                    elevation: 0,
                    color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recent Joiners',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.push('/admin/employees'),
                                style: TextButton.styleFrom(
                                  foregroundColor: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF212F3D),
                                ),
                                child: const Row(
                                  children: [
                                    Text('View Directory', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_rounded, size: 14),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: recentAsync.when(
                              data: (data) {
                                final list = data['items'] as List<EmployeeProfile>;
                                if (list.isEmpty) {
                                  return const Center(
                                    child: Text(
                                      'No employees registered yet.',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  );
                                }
                                return ListView.separated(
                                  itemCount: list.length,
                                  separatorBuilder: (context, _) => Divider(
                                    height: 12,
                                    color: isDark ? const Color(0xFFC5A059).withOpacity(0.1) : Colors.black.withOpacity(0.04),
                                  ),
                                  itemBuilder: (context, index) {
                                    final emp = list[index];
                                    return _recentRow(context, emp, isDark);
                                  },
                                );
                              },
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (err, _) => Center(child: Text('Error: $err')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(64),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (err, _) => _ErrorPanel(
          message: 'Failed to load dashboard data',
          detail: '$err',
          onRetry: () => ref.invalidate(_dashboardEmployeesProvider),
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required bool isDark,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF212F3D),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _recentRow(BuildContext context, EmployeeProfile emp, bool isDark) {
    final initials = emp.generalInfo?.fullName.split(' ').map((e) => e[0]).take(2).join('').toUpperCase() ?? '#';
    return InkWell(
      onTap: () => context.push('/admin/employees/${emp.id}'),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFE5ECF0),
              child: Text(
                initials,
                style: TextStyle(
                  color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emp.generalInfo?.fullName ?? 'Employee #${emp.id}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${emp.generalInfo?.employeeCode ?? '—'} · ${emp.generalInfo?.designation ?? '—'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF607D8B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white.withOpacity(0.3) : const Color(0xFF607D8B),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, int> _getDeptDistribution(List<EmployeeProfile> employees) {
    final Map<String, int> distribution = {};
    for (var emp in employees) {
      final dept = emp.generalInfo?.department ?? 'Unassigned';
      final cleanDept = dept.trim().isEmpty ? 'Unassigned' : dept.trim();
      distribution[cleanDept] = (distribution[cleanDept] ?? 0) + 1;
    }
    return distribution;
  }

  Map<String, int> _getCategoryDistribution(List<EmployeeProfile> employees) {
    final Map<String, int> distribution = {};
    for (var emp in employees) {
      final cat = emp.generalInfo?.employeeCategory ?? 'OTHER';
      final cleanCat = cat.replaceAll('_', ' ').toUpperCase();
      distribution[cleanCat] = (distribution[cleanCat] ?? 0) + 1;
    }
    return distribution;
  }

  List<_ChartData> _getHiringTimeline(List<EmployeeProfile> employees) {
    final Map<int, int> yearCounts = {};
    for (var emp in employees) {
      final year = emp.generalInfo?.joiningDate.year ?? DateTime.now().year;
      yearCounts[year] = (yearCounts[year] ?? 0) + 1;
    }
    final sortedYears = yearCounts.keys.toList()..sort();
    List<_ChartData> timeline = [];
    int cumulative = 0;
    for (var year in sortedYears) {
      cumulative += yearCounts[year]!;
      timeline.add(_ChartData(year.toString(), cumulative.toDouble()));
    }
    // Handle empty data
    if (timeline.isEmpty) {
      timeline.add(_ChartData(DateTime.now().year.toString(), 0));
    }
    return timeline;
  }
}

class _KpiItem {
  const _KpiItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.kpi,
    required this.isDark,
  });

  final _KpiItem kpi;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    kpi.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : const Color(0xFF607D8B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    kpi.value,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: kpi.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                kpi.icon,
                color: kpi.color,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );

    if (kpi.onTap == null) return card;
    return InkWell(
      onTap: kpi.onTap,
      borderRadius: BorderRadius.circular(16),
      child: card,
    );
  }
}

class _ChartData {
  _ChartData(this.x, this.y);
  final String x;
  final double y;
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
