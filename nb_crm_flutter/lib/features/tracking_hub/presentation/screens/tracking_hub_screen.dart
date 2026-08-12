import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../providers.dart';
import '../trip_recording_download.dart';

class TrackingHubScreen extends ConsumerStatefulWidget {
  const TrackingHubScreen({
    super.key,
    this.initialDate,
    this.initialEmployeeId,
  });

  final String? initialDate;
  final String? initialEmployeeId;

  @override
  ConsumerState<TrackingHubScreen> createState() => _TrackingHubScreenState();
}

class _TrackingHubScreenState extends ConsumerState<TrackingHubScreen> {
  late DateTime _selectedDate;
  String? _selectedEmployeeId;
  String _statusFilter = 'All';
  final _employeeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDate = _parseDate(widget.initialDate) ?? DateTime.now();
    _selectedEmployeeId = widget.initialEmployeeId?.trim().isEmpty == true
        ? null
        : widget.initialEmployeeId?.trim();
    if (_selectedEmployeeId != null) {
      _employeeController.text = _selectedEmployeeId!;
    }
  }

  @override
  void dispose() {
    _employeeController.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatSeconds(int seconds) {
    if (seconds <= 0) return '0h 0m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  String _formatLocal(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayKey = hubDayKey(
      date: _selectedDate,
      employeeId: _selectedEmployeeId,
    );
    final kpisAsync = ref.watch(hubKpisProvider(_selectedEmployeeId));
    final dayAsync = ref.watch(hubDayAvailabilityProvider(dayKey));
    final tripsAsync = ref.watch(hubTripsProvider(_selectedEmployeeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Intelligence (Tracking Hub)'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(hubDayAvailabilityProvider(dayKey));
              ref.invalidate(hubKpisProvider(_selectedEmployeeId));
              ref.invalidate(hubTripsProvider(_selectedEmployeeId));
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildFilterBar(theme)),
          SliverToBoxAdapter(child: _buildAlertsBanner(theme)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: kpisAsync.when(
                data: (kpis) => _buildKpiDashboard(kpis, theme),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(
                  'Error loading KPIs: $e',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Location availability (punch-in → punch-out)',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Shows how long each employee\'s GPS was reporting vs silent for ${_ymd(_selectedDate)}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.65),
                ),
              ),
            ),
          ),
          dayAsync.when(
            data: (payload) {
              final employees =
                  (payload['employees'] as List<dynamic>? ?? const []);
              if (employees.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No punched-in employees for this date.',
                      ),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.separated(
                  itemCount: employees.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final row = Map<String, dynamic>.from(
                      employees[index] as Map,
                    );
                    return _buildEmployeeAvailabilityCard(row, theme);
                  },
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Error loading availability: $e',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Trip History',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          tripsAsync.when(
            data: (trips) {
              final filteredTrips = _filterTrips(trips);
              if (filteredTrips.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('No trips found for these filters.'),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 148,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return _buildTripCard(
                      context,
                      filteredTrips[index],
                      theme,
                    );
                  }, childCount: filteredTrips.length),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) =>
                SliverToBoxAdapter(child: Text('Error loading trips: $e')),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildAlertsBanner(ThemeData theme) {
    final alertsAsync = ref.watch(trackingAlertsProvider);
    return alertsAsync.maybeWhen(
      data: (alerts) {
        if (alerts.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location unavailable alerts',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...alerts.take(5).map((raw) {
                    final a = Map<String, dynamic>.from(raw as Map);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${a['fullName'] ?? 'Employee'} — off since ${_formatLocal(a['unavailableSince']?.toString())}'
                        ' (${(a['reason']?.toString() ?? 'NO_LOCATION_PING').replaceAll('_', ' ')})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(_ymd(_selectedDate)),
            ),
            SizedBox(
              width: 200,
              child: TextField(
                controller: _employeeController,
                decoration: const InputDecoration(
                  labelText: 'Employee ID',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (val) {
                  setState(() {
                    _selectedEmployeeId =
                        val.trim().isEmpty ? null : val.trim();
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
                  _employeeController.clear();
                  setState(() {
                    _selectedEmployeeId = null;
                    _statusFilter = 'All';
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeAvailabilityCard(
    Map<String, dynamic> row,
    ThemeData theme,
  ) {
    final name = row['fullName']?.toString() ?? 'Employee';
    final code = row['employeeCode']?.toString();
    final available = (row['availableSeconds'] as num?)?.toInt() ?? 0;
    final unavailable = (row['unavailableSeconds'] as num?)?.toInt() ?? 0;
    final percent = (row['availablePercent'] as num?)?.toDouble() ?? 0;
    final gaps = (row['gapCount'] as num?)?.toInt() ?? 0;
    final stillOnDuty = row['stillOnDuty'] == true;
    final employeeId = (row['employeeId'] as num?)?.toInt() ?? 0;
    final total = available + unavailable;
    final availRatio = total > 0 ? available / total : 0.0;

    return Card(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: employeeId == 0
            ? null
            : () {
                context.push(
                  '/admin/tracking-hub/employee/$employeeId?date=${_ymd(_selectedDate)}',
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (code != null && code.isNotEmpty)
                          Text(
                            code,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: stillOnDuty
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      stillOnDuty ? 'On duty' : 'Punched out',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'In ${_formatLocal(row['punchIn']?.toString())}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Out ${_formatLocal(row['punchOut']?.toString())}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    '${percent.toStringAsFixed(1)}% available',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: percent >= 90
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      if (availRatio > 0)
                        Expanded(
                          flex: (availRatio * 1000).round().clamp(1, 1000),
                          child: Container(color: const Color(0xFF2E7D32)),
                        ),
                      if (1 - availRatio > 0)
                        Expanded(
                          flex: ((1 - availRatio) * 1000).round().clamp(1, 1000),
                          child: Container(color: theme.colorScheme.error),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _miniStat(
                    theme,
                    Icons.gps_fixed,
                    'Available',
                    _formatSeconds(available),
                    const Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 16),
                  _miniStat(
                    theme,
                    Icons.gps_off,
                    'Not available',
                    _formatSeconds(unavailable),
                    theme.colorScheme.error,
                  ),
                  const SizedBox(width: 16),
                  _miniStat(
                    theme,
                    Icons.warning_amber,
                    'Gaps',
                    '$gaps',
                    gaps == 0
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.55),
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
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
        Text(
          'Overall Performance',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _kpiCard(
                'Distance',
                '${(kpis['totalDistanceKm'] as num? ?? 0).toStringAsFixed(2)} km',
                Icons.directions_car,
                theme.colorScheme.primary,
                theme,
              ),
              _kpiCard(
                'Uptime',
                '${(kpis['averageUptimePercent'] as num? ?? 0).toStringAsFixed(1)}%',
                Icons.timer,
                theme.colorScheme.secondary,
                theme,
              ),
              _kpiCard(
                'Active Time',
                _formatSeconds((kpis['totalActiveTime'] as num?)?.toInt() ?? 0),
                Icons.run_circle,
                theme.colorScheme.tertiary,
                theme,
              ),
              _kpiCard(
                'Gaps Detected',
                '${kpis['totalGaps'] ?? 0}',
                Icons.warning_amber,
                theme.colorScheme.error,
                theme,
              ),
            ];
            if (constraints.maxWidth > 600) {
              return Row(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: cards[i]),
                  ],
                ],
              );
            }
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 8),
                    Expanded(child: cards[1]),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: cards[2]),
                    const SizedBox(width: 8),
                    Expanded(child: cards[3]),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _kpiCard(
    String title,
    String value,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, dynamic trip, ThemeData theme) {
    final empName =
        trip['employee']?['generalInfo']?['fullName'] ?? 'Unknown Employee';
    final startTime = DateTime.parse(
      trip['startTime'],
    ).toLocal().toString().split('.')[0];
    final distance = ((trip['distanceKm'] as num?) ?? 0).toStringAsFixed(2);
    final uptime = ((trip['trackingUptimePercent'] as num?) ?? 100)
        .toStringAsFixed(1);
    final gaps = (trip['gapCount'] as int?) ?? 0;
    final isCompleted = trip['endTime'] != null;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          context.push('/admin/tracking-hub/trip/${trip['id']}');
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      empName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Download recording',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.download_rounded, size: 20),
                    onPressed: () {
                      final id = trip['id']?.toString();
                      if (id == null || id.isEmpty) return;
                      showTripDownloadMenu(
                        context: context,
                        dioClient: ref.read(dioClientProvider),
                        tripId: id,
                      );
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? theme.colorScheme.surfaceContainerHighest
                          : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isCompleted ? 'Completed' : 'Active',
                      style: TextStyle(
                        fontSize: 10,
                        color: isCompleted
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text('Start: $startTime', style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Dist: $distance km', style: theme.textTheme.bodySmall),
                  Text(
                    'Uptime: $uptime%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: uptime == '100.0'
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Gaps: $gaps',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: gaps == 0
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
