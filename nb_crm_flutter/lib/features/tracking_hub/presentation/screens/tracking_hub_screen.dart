import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers.dart';

class TrackingHubScreen extends ConsumerStatefulWidget {
  const TrackingHubScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TrackingHubScreen> createState() => _TrackingHubScreenState();
}

class _TrackingHubScreenState extends ConsumerState<TrackingHubScreen> {
  String? _selectedEmployeeId;
  String _statusFilter = 'All'; // All, Active, Completed, Anomalous

  @override
  Widget build(BuildContext context) {
    // Watch providers
    final kpisAsync = ref.watch(hubKpisProvider(_selectedEmployeeId));
    final tripsAsync = ref.watch(hubTripsProvider(_selectedEmployeeId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Intelligence (Tracking Hub)'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildFilterBar(theme),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: kpisAsync.when(
                data: (kpis) => _buildKpiDashboard(kpis, theme),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Text('Error loading KPIs: $e', style: TextStyle(color: theme.colorScheme.error)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Trip History',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          tripsAsync.when(
            data: (trips) {
              final filteredTrips = _filterTrips(trips);
              if (filteredTrips.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: Text('No trips found for these filters.')),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 130,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _buildTripCard(context, filteredTrips[index], theme);
                    },
                    childCount: filteredTrips.length,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
            error: (e, st) => SliverToBoxAdapter(child: Text('Error loading trips: $e')),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 200,
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Employee ID',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (val) {
                  setState(() {
                    _selectedEmployeeId = val.trim().isEmpty ? null : val.trim();
                  });
                },
              ),
            ),
            DropdownButton<String>(
              value: _statusFilter,
              items: ['All', 'Active', 'Completed', 'Anomalous']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _statusFilter = val);
              },
            ),
            if (_selectedEmployeeId != null || _statusFilter != 'All')
              TextButton.icon(
                icon: const Icon(Icons.clear),
                label: const Text('Clear Filters'),
                onPressed: () {
                  setState(() {
                    _selectedEmployeeId = null;
                    _statusFilter = 'All';
                  });
                },
              )
          ],
        ),
      ),
    );
  }

  List<dynamic> _filterTrips(List<dynamic> trips) {
    if (_statusFilter == 'All') return trips;
    return trips.where((t) {
      final isCompleted = t['endTime'] != null;
      final gapCount = t['gapCount'] as int? ?? 0;
      if (_statusFilter == 'Active') return !isCompleted;
      if (_statusFilter == 'Completed') return isCompleted;
      if (_statusFilter == 'Anomalous') return gapCount > 0;
      return true;
    }).toList();
  }

  Widget _buildKpiDashboard(Map<String, dynamic> kpis, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Overall Performance', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 600) {
              return Row(
                children: [
                  Expanded(child: _kpiCard('Distance', '${kpis['totalDistanceKm'].toStringAsFixed(2)} km', Icons.directions_car, theme.colorScheme.primary, theme)),
                  const SizedBox(width: 8),
                  Expanded(child: _kpiCard('Uptime', '${kpis['averageUptimePercent'].toStringAsFixed(1)}%', Icons.timer, theme.colorScheme.secondary, theme)),
                  const SizedBox(width: 8),
                  Expanded(child: _kpiCard('Active Time', _formatSeconds(kpis['totalActiveTime']), Icons.run_circle, theme.colorScheme.tertiary, theme)),
                  const SizedBox(width: 8),
                  Expanded(child: _kpiCard('Gaps Detected', '${kpis['totalGaps']}', Icons.warning_amber, theme.colorScheme.error, theme)),
                ],
              );
            }
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _kpiCard('Distance', '${kpis['totalDistanceKm'].toStringAsFixed(2)} km', Icons.directions_car, theme.colorScheme.primary, theme)),
                    const SizedBox(width: 8),
                    Expanded(child: _kpiCard('Uptime', '${kpis['averageUptimePercent'].toStringAsFixed(1)}%', Icons.timer, theme.colorScheme.secondary, theme)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _kpiCard('Active Time', _formatSeconds(kpis['totalActiveTime']), Icons.run_circle, theme.colorScheme.tertiary, theme)),
                    const SizedBox(width: 8),
                    Expanded(child: _kpiCard('Gaps Detected', '${kpis['totalGaps']}', Icons.warning_amber, theme.colorScheme.error, theme)),
                  ],
                ),
              ],
            );
          }
        )
      ],
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color, ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(title, style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.7))),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  String _formatSeconds(int seconds) {
    if (seconds == 0) return '0h 0m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }

  Widget _buildTripCard(BuildContext context, dynamic trip, ThemeData theme) {
    final empName = trip['employee']?['generalInfo']?['fullName'] ?? 'Unknown Employee';
    final startTime = DateTime.parse(trip['startTime']).toLocal().toString().split('.')[0];
    final distance = ((trip['distanceKm'] as num?) ?? 0).toStringAsFixed(2);
    final uptime = ((trip['trackingUptimePercent'] as num?) ?? 100).toStringAsFixed(1);
    final gaps = (trip['gapCount'] as int?) ?? 0;
    final isCompleted = trip['endTime'] != null;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          context.push('/admin/tracking-hub/trip/${trip['id']}');
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(empName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isCompleted ? 'Completed' : 'Active',
                      style: TextStyle(fontSize: 10, color: isCompleted ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onPrimaryContainer),
                    ),
                  )
                ],
              ),
              const Spacer(),
              Text('Start: $startTime', style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Dist: $distance km', style: theme.textTheme.bodySmall),
                  Text('Uptime: $uptime%', style: theme.textTheme.bodySmall?.copyWith(
                    color: uptime == '100.0' ? theme.colorScheme.primary : theme.colorScheme.error,
                  )),
                ],
              ),
              const SizedBox(height: 4),
              Text('Gaps: $gaps', style: theme.textTheme.bodySmall?.copyWith(
                color: gaps == 0 ? theme.colorScheme.primary : theme.colorScheme.error,
              )),
            ],
          ),
        ),
      ),
    );
  }
}
