import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/widgets/header_action_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/leave_models.dart';
import '../leave_providers.dart';
import '../widgets/leave_shared_widgets.dart';

class LeaveHubScreen extends ConsumerWidget {
  const LeaveHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(leaveYearFilterProvider);
    final balances = ref.watch(leaveBalancesProvider);
    final recentApps = ref.watch(myApplicationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = ref.watch(authNotifierProvider);
    final canApprove = Permissions.canApproveLeave(auth.permissions) ||
        Permissions.canReadLeave(auth.permissions);
    final canAdmin = Permissions.canAdminLeave(
      auth.permissions,
      auth.user?.role ?? '',
      auth.user?.employeeViewScope,
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Leave Management',
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
          onPressed: () => context.go('/home'),
        ),
        actions: [
          HeaderActionButton(
            tooltip: 'Refresh',
            label: 'Refresh',
            icon: Icon(
              Icons.refresh_rounded,
              size: 18,
              color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF212F3D),
            ),
            onPressed: () {
              ref.invalidate(leaveBalancesProvider);
              ref.invalidate(myApplicationsProvider);
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
      body: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0.0, 35.0 * (1.0 - value)),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          children: [
            Row(
              children: [
                Text(
                  'Year Filter',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white60 : const Color(0xFF607D8B),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFFC5A059)),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: year,
                        dropdownColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFFC5A059)),
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF212F3D),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        items: List.generate(5, (i) {
                          final y = DateTime.now().year - 2 + i;
                          return DropdownMenuItem(value: y, child: Text('$y'));
                        }),
                        onChanged: (v) {
                          if (v != null) ref.read(leaveYearFilterProvider.notifier).set(v);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () => context.go('/leave/apply'),
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                        foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                      label: const Text('Apply Leave'),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/leave/history'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                        side: BorderSide(
                          color: isDark ? const Color(0xFFC5A059).withOpacity(0.4) : const Color(0xFF263238).withOpacity(0.5),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      icon: const Icon(Icons.history_rounded, size: 18),
                      label: const Text('History'),
                    ),
                  ),
                ),
              ],
            ),
            if (canApprove || canAdmin) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC5A059),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Leave Workspace',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (canApprove)
                _LeaveWorkspaceTile(
                  icon: Icons.rule_rounded,
                  title: 'Leave Approvals',
                  subtitle: 'Review pending leave requests',
                  color: const Color(0xFF2563eb),
                  onTap: () => context.go('/approvals'),
                ),
              if (canApprove && canAdmin) const SizedBox(height: 10),
              if (canAdmin)
                _LeaveWorkspaceTile(
                  icon: Icons.calendar_month_rounded,
                  title: 'Leave Admin',
                  subtitle: 'Policies, holidays, settings & apply on behalf',
                  color: const Color(0xFF0891b2),
                  onTap: () => context.go('/admin/leaves'),
                ),
            ],
            const SizedBox(height: 36),
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC5A059),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Leave Balances Overview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LeaveAsyncBody<List<LeaveBalance>>(
              value: balances,
              emptyMessage: 'No leave balances for $year.',
              onRetry: () => ref.invalidate(leaveBalancesProvider),
              builder: (items) {
                // Map to chart items
                final chartItems = items.map((b) {
                  final name = b.leaveType?.name ?? b.leaveTypeId;
                  final adminOnly = !(b.leaveType?.employeeCanApply ?? true);
                  final avail = b.displayAvailable;
                  final total = b.totalCredited + b.carryForward;
                  return LeaveChartData(
                    label: adminOnly ? '$name (Admin)' : name,
                    actualAvailable: avail,
                    chartValue: avail <= 0 ? 0.8 : avail,
                    totalAllocated: total,
                    isZero: avail <= 0,
                  );
                }).toList();

                // Sort: zero balances first (bottom of chart)
                chartItems.sort((a, b) {
                  if (a.isZero && !b.isZero) return -1;
                  if (!a.isZero && b.isZero) return 1;
                  return a.actualAvailable.compareTo(b.actualAvailable);
                });

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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: SizedBox(
                      height: chartItems.length * 56.0 + 60.0, // Dynamic height based on data points
                      child: SfCartesianChart(
                        plotAreaBorderWidth: 0,
                        margin: const EdgeInsets.all(0),
                        primaryXAxis: CategoryAxis(
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF263238),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                          majorGridLines: const MajorGridLines(width: 0),
                          axisLine: const AxisLine(width: 0),
                          majorTickLines: const MajorTickLines(width: 0),
                        ),
                        primaryYAxis: NumericAxis(
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                          majorGridLines: MajorGridLines(
                            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                            width: 1,
                          ),
                          axisLine: const AxisLine(width: 0),
                          majorTickLines: const MajorTickLines(width: 0),
                        ),
                        series: <CartesianSeries<LeaveChartData, String>>[
                          BarSeries<LeaveChartData, String>(
                            dataSource: chartItems,
                            xValueMapper: (LeaveChartData data, _) => data.label,
                            yValueMapper: (LeaveChartData data, _) => data.chartValue,
                            // Map colors based on zero status
                            pointColorMapper: (LeaveChartData data, _) {
                              if (data.isZero) {
                                return Colors.red.withOpacity(0.15);
                              }
                              return isDark ? const Color(0xFFC5A059).withOpacity(0.85) : const Color(0xFF263238).withOpacity(0.85);
                            },
                            borderColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                            borderWidth: 1.5,
                            borderRadius: const BorderRadius.all(Radius.circular(8)),
                            dataLabelSettings: DataLabelSettings(
                              isVisible: true,
                              labelAlignment: ChartDataLabelAlignment.outer,
                              textStyle: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF212F3D),
                              ),
                              builder: (dynamic data, dynamic point, dynamic series, int index, int seriesIndex) {
                                final LeaveChartData item = data as LeaveChartData;
                                final valStr = item.actualAvailable.toStringAsFixed(item.actualAvailable % 1 == 0 ? 0 : 1);
                                if (item.isZero) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.12),
                                      border: Border.all(color: Colors.red, width: 1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      '0 Days',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  );
                                }
                                return Text(
                                  '$valStr Days',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 36),
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC5A059),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Recent Applications',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LeaveAsyncBody<LeaveApplicationsPage>(
              value: recentApps,
              emptyMessage: 'No recent applications.',
              onRetry: () => ref.invalidate(myApplicationsProvider),
              builder: (page) {
                final items = page.items.take(5).toList();
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'No recent applications.',
                        style: TextStyle(
                          color: isDark ? Colors.white30 : const Color(0xFF607D8B).withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: items
                      .map((a) => LeaveApplicationCard(application: a))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class LeaveChartData {
  LeaveChartData({
    required this.label,
    required this.actualAvailable,
    required this.chartValue,
    required this.totalAllocated,
    required this.isZero,
  });

  final String label;
  final double actualAvailable;
  final double chartValue;
  final double totalAllocated;
  final bool isZero;
}

class _LeaveWorkspaceTile extends StatelessWidget {
  const _LeaveWorkspaceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1B18) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : const Color(0xFF607D8B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
