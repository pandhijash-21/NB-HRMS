import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/tour/models/tour_models.dart';
import '../../../../core/tour/widgets/tour_target.dart';
import '../../../../core/widgets/header_action_button.dart';
import '../../data/earth_repository.dart';
import '../../domain/earth_kinds.dart';
import '../../domain/earth_models.dart';
import '../widgets/earth_format.dart';
import '../widgets/earth_pin.dart';

class EarthDashboardScreen extends StatefulWidget {
  const EarthDashboardScreen({super.key, required this.repository});

  final EarthRepository repository;

  @override
  State<EarthDashboardScreen> createState() => _EarthDashboardScreenState();
}

class _EarthDashboardScreenState extends State<EarthDashboardScreen> {
  EarthDashboard? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.repository.dashboard();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/admin/earth'),
        title: const Text('Earth dashboard'),
        actions: [
          HeaderActionButton(
            tooltip: 'Refresh',
            label: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, size: 18),
            onPressed: _load,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _body(_data!),
    );
  }

  Widget _body(EarthDashboard d) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        TourTarget(
          id: TourIds.step('hrms.earth_dashboard', 2),
          child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpi('Inventory', '${d.properties}', Icons.public, AppColors.primaryBlue),
            _kpi('Portfolio value', earthMoney(d.totalValue, compact: true), Icons.account_balance_wallet_outlined, AppColors.bronze),
            _kpi('Average price', earthMoney(d.avgPrice, compact: true), Icons.payments_outlined, const Color(0xFF0EA5E9)),
            _kpi('Avg appreciation', earthPct(d.avgAppreciationPct), Icons.trending_up, AppColors.success),
            _kpi('MoM', earthPct(d.momChangePct), Icons.calendar_view_month, const Color(0xFF7C3AED)),
            _kpi('YoY', earthPct(d.yoyChangePct), Icons.timeline, const Color(0xFFDB2777)),
            _kpi('Available', '${d.available}', Icons.check_circle_outline, AppColors.success),
            _kpi(
              'Price / area',
              d.avgPricePerArea == null ? '—' : earthMoney(d.avgPricePerArea, compact: true),
              Icons.square_foot,
              const Color(0xFFCA8A04),
            ),
          ],
        ),
        ),
        const SizedBox(height: 16),
        _split(_trendCard(d), _kindCard(d), leftFlex: 3, rightFlex: 2),
        const SizedBox(height: 12),
        _split(_cityCard(d), _appreciationCard(d)),
        const SizedBox(height: 12),
        _split(_changesCard(d), _staleCard(d)),
      ],
    );
  }

  Widget _split(Widget left, Widget right, {int leftFlex = 1, int rightFlex = 1}) {
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: 12), right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: leftFlex, child: left),
        const SizedBox(width: 12),
        Expanded(flex: rightFlex, child: right),
      ],
    );
  }

  Widget _kpi(String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: 210,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color, size: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelSmall),
                    Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(String title, Widget child, {double height = 320}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            SizedBox(height: height, child: child),
          ],
        ),
      ),
    );
  }

  Widget _trendCard(EarthDashboard d) {
    return _card(
      'Average price trend',
      d.monthlyTrend.isEmpty
          ? const Center(child: Text('Add priced properties to see trends.'))
          : SfCartesianChart(
              tooltipBehavior: TooltipBehavior(enable: true),
              primaryXAxis: const CategoryAxis(),
              series: <CartesianSeries<EarthMonthPoint, String>>[
                SplineAreaSeries<EarthMonthPoint, String>(
                  dataSource: d.monthlyTrend,
                  xValueMapper: (e, _) => e.month.substring(5),
                  yValueMapper: (e, _) => e.avgPrice,
                  color: AppColors.primaryBlue.withValues(alpha: 0.18),
                  borderColor: AppColors.primaryBlue,
                  name: 'Avg price',
                ),
                LineSeries<EarthMonthPoint, String>(
                  dataSource: d.monthlyTrend,
                  xValueMapper: (e, _) => e.month.substring(5),
                  yValueMapper: (e, _) => e.avgPricePerArea ?? 0,
                  color: AppColors.bronze,
                  name: 'Per area',
                  dashArray: const [6, 4],
                ),
              ],
            ),
    );
  }

  Widget _kindCard(EarthDashboard d) {
    return _card(
      'Mix by type',
      d.byKind.isEmpty
          ? const Center(child: Text('No inventory yet.'))
          : SfCircularChart(
              legend: const Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
              series: <CircularSeries<EarthKindStat, String>>[
                DoughnutSeries<EarthKindStat, String>(
                  dataSource: d.byKind,
                  xValueMapper: (e, _) => earthKindLabel(e.kind),
                  yValueMapper: (e, _) => e.count,
                  dataLabelSettings: const DataLabelSettings(isVisible: true),
                  innerRadius: '58%',
                ),
              ],
            ),
    );
  }

  Widget _cityCard(EarthDashboard d) {
    return _card(
      'Cities & micro-markets',
      d.byCity.isEmpty
          ? const Center(child: Text('No city data yet.'))
          : ListView.separated(
              itemCount: d.byCity.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final c = d.byCity[i];
                return ListTile(
                  dense: true,
                  title: Text(c.city, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${c.count} properties · avg ${earthMoney(c.avgPrice, compact: true)}'),
                  trailing: Text(
                    earthPct(c.avgAppreciationPct),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: (c.avgAppreciationPct ?? 0) >= 0 ? AppColors.success : AppColors.error,
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _appreciationCard(EarthDashboard d) {
    return _card(
      'Fastest appreciating pins',
      d.topAppreciation.isEmpty
          ? const Center(child: Text('Need at least two prices on a property.'))
          : ListView.separated(
              itemCount: d.topAppreciation.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = d.topAppreciation[i];
                return ListTile(
                  dense: true,
                  leading: EarthPropertyPin(kind: r.kind, imageUrl: r.imageUrl, size: 32),
                  title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${earthKindLabel(r.kind)} · ${r.city ?? '—'}'),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(earthPct(r.appreciationPct), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success)),
                      Text('${earthMoney(r.firstPrice, compact: true)} → ${earthMoney(r.latestPrice, compact: true)}', style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _changesCard(EarthDashboard d) {
    return _card(
      'Recent price changes',
      d.recentPriceChanges.isEmpty
          ? const Center(child: Text('No price history yet.'))
          : ListView.separated(
              itemCount: d.recentPriceChanges.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = d.recentPriceChanges[i];
                final up = (r.changePct ?? 0) >= 0;
                return ListTile(
                  dense: true,
                  leading: EarthPropertyPin(kind: r.kind, imageUrl: r.imageUrl, size: 32),
                  title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(earthMoney(r.amount)),
                  trailing: Text(
                    r.changePct == null ? 'first' : earthPct(r.changePct),
                    style: TextStyle(fontWeight: FontWeight.w700, color: up ? AppColors.success : AppColors.error),
                  ),
                );
              },
            ),
    );
  }

  Widget _staleCard(EarthDashboard d) {
    return _card(
      'Stale pricing (180+ days)',
      d.stalePricing.isEmpty
          ? const Center(child: Text('All listed prices are fresh.'))
          : ListView.separated(
              itemCount: d.stalePricing.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = d.stalePricing[i];
                return ListTile(
                  dense: true,
                  leading: EarthPropertyPin(kind: r.kind, size: 32),
                  title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(earthMoney(r.currentPrice)),
                  trailing: Text('${r.daysSinceUpdate}d', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning)),
                );
              },
            ),
    );
  }
}
