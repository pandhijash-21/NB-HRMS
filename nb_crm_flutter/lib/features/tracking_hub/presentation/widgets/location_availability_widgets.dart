import 'package:flutter/material.dart';

String formatAvailabilityDuration(int seconds) {
  if (seconds <= 0) return '0m';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  if (m > 0) return s > 0 ? '${m}m ${s}s' : '${m}m';
  return '${s}s';
}

String formatAvailabilityClock(String? iso, {bool withDate = false}) {
  if (iso == null || iso.isEmpty) return '—';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return iso;
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  final ss = dt.second.toString().padLeft(2, '0');
  if (!withDate) return '$hh:$mm:$ss';
  final d = dt.day.toString().padLeft(2, '0');
  final mo = dt.month.toString().padLeft(2, '0');
  return '$d/$mo $hh:$mm:$ss';
}

String reasonLabel(String? reason) {
  if (reason == null || reason.isEmpty) return 'Unknown';
  switch (reason) {
    case 'NO_LOCATION_PING':
      return 'No GPS ping';
    case 'WAITING_FOR_GPS':
      return 'Waiting for first GPS fix';
    case 'LOCATION_PERMISSION_REVOKED':
      return 'Location permission off';
    case 'LOCATION_SERVICE_DISABLED':
      return 'Device location off';
    case 'BACKGROUND_SERVICE_KILLED':
      return 'Background tracking stopped';
    case 'GPS_SIGNAL_LOST':
      return 'GPS signal lost';
    case 'NETWORK_UNAVAILABLE':
      return 'No network';
    default:
      return reason.replaceAll('_', ' ');
  }
}

bool isLocationCurrentlyOn(Map<String, dynamic> row) {
  return row['currentlyAvailable'] == true || row['isLive'] == true;
}

bool isLocationAlertActive(Map<String, dynamic> row) {
  if (isLocationCurrentlyOn(row)) return false;
  return row['alertActive'] == true;
}

List<Map<String, dynamic>> activeLocationAlerts(List<dynamic> alerts) {
  final out = <Map<String, dynamic>>[];
  for (final raw in alerts) {
    if (raw is! Map) continue;
    if (raw['active'] == false) continue;
    out.add(Map<String, dynamic>.from(raw));
  }
  return out;
}

class AvailabilitySlotBar extends StatelessWidget {
  const AvailabilitySlotBar({
    super.key,
    required this.segments,
    this.height = 14,
  });

  final List<dynamic> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (final raw in segments)
              Builder(
                builder: (_) {
                  final seg = Map<String, dynamic>.from(raw as Map);
                  final on = seg['status'] == 'AVAILABLE';
                  final dur = (seg['durationSeconds'] as num?)?.toInt() ?? 1;
                  return Expanded(
                    flex: dur.clamp(1, 86400),
                    child: Tooltip(
                      message:
                          '${on ? 'Available' : 'Off'} ${formatAvailabilityClock(seg['start']?.toString())}–${formatAvailabilityClock(seg['end']?.toString())} (${formatAvailabilityDuration(dur)})',
                      child: Container(
                        color: on ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class AvailabilitySlotLegend extends StatelessWidget {
  const AvailabilitySlotLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text('Available', style: style),
        const SizedBox(width: 14),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFFC62828),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text('Off', style: style),
      ],
    );
  }
}

class ActiveLocationAlertsBanner extends StatelessWidget {
  const ActiveLocationAlertsBanner({
    super.key,
    required this.alerts,
    this.onTapEmployee,
    this.dense = false,
  });

  final List<dynamic> alerts;
  final void Function(int employeeId)? onTapEmployee;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final active = activeLocationAlerts(alerts);
    if (active.isEmpty) return const SizedBox.shrink();
    return Material(
      color: const Color(0xFFB71C1C),
      elevation: dense ? 8 : 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, dense ? 10 : 14, 14, dense ? 10 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'GPS currently unavailable',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'This alert disappears automatically when location is available again.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...active.take(6).map((a) {
              final id = (a['employeeId'] as num?)?.toInt();
              final child = Text(
                '${a['fullName'] ?? 'Employee'}  ·  off since ${formatAvailabilityClock(a['unavailableSince']?.toString())}'
                '  ·  ${reasonLabel(a['reason']?.toString())}'
                '${a['lastKnownLatitude'] != null ? '  ·  ${a['lastKnownLatitude']}, ${a['lastKnownLongitude']}' : ''}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              );
              if (id == null || onTapEmployee == null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: child,
                );
              }
              return InkWell(
                onTap: () => onTapEmployee!(id),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: child,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class AvailabilityStatusPill extends StatelessWidget {
  const AvailabilityStatusPill({
    super.key,
    required this.available,
    this.live = false,
  });

  final bool available;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final on = available || live;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: on ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(on ? Icons.gps_fixed : Icons.gps_off, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            live ? 'LIVE' : on ? 'GPS ON' : 'GPS OFF',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class AvailabilitySegmentCard extends StatelessWidget {
  const AvailabilitySegmentCard({super.key, required this.segment});

  final Map<String, dynamic> segment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = segment['status'] == 'AVAILABLE';
    final color = on ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final duration = (segment['durationSeconds'] as num?)?.toInt() ?? 0;
    final lat = (segment['lastKnownLatitude'] as num?)?.toDouble();
    final lng = (segment['lastKnownLongitude'] as num?)?.toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        on ? 'Location available' : 'Location not available',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: color,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${formatAvailabilityClock(segment['start']?.toString(), withDate: true)}  →  ${formatAvailabilityClock(segment['end']?.toString(), withDate: true)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  formatAvailabilityDuration(duration),
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            if (!on) ...[
              const SizedBox(height: 8),
              Text(
                'Reason: ${reasonLabel(segment['reason']?.toString())}'
                '${segment['confidence'] != null ? '  ·  ${segment['confidence']}' : ''}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (lat != null && lng != null) ...[
              const SizedBox(height: 6),
              Text(
                'Last known: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFC5A059),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AvailabilityDetailsView extends StatelessWidget {
  const AvailabilityDetailsView({
    super.key,
    required this.row,
    this.compact = false,
  });

  final Map<String, dynamic> row;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = (row['availableSeconds'] as num?)?.toInt() ?? 0;
    final unavailable = (row['unavailableSeconds'] as num?)?.toInt() ?? 0;
    final percent = (row['availablePercent'] as num?)?.toDouble() ?? 0;
    final segments = (row['segments'] as List?) ?? const [];
    final stillOnDuty = row['stillOnDuty'] == true;
    final live = row['isLive'] == true;
    final on = isLocationCurrentlyOn(row);
    final alert = isLocationAlertActive(row);
    final pings = (row['pingCount'] as num?)?.toInt() ?? 0;
    final lat = (row['lastKnownLatitude'] as num?)?.toDouble();
    final lng = (row['lastKnownLongitude'] as num?)?.toDouble();
    final age = (row['lastPingAgeSeconds'] as num?)?.toInt();
    final lastSeg = segments.isNotEmpty
        ? Map<String, dynamic>.from(segments.last as Map)
        : null;

    final statusText = on
        ? 'Location available${age != null ? '  ·  last ping ${formatAvailabilityDuration(age)} ago' : ''}'
        : alert
            ? 'Location unavailable  ·  ${reasonLabel(lastSeg?['reason']?.toString())}'
            : 'Checking GPS… not an alert yet${age != null ? '  ·  silent ${formatAvailabilityDuration(age)}' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AvailabilityStatusPill(available: on, live: live),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: stillOnDuty
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                stillOnDuty ? 'On duty' : 'Punched out',
                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Spacer(),
            Text(
              '${percent.toStringAsFixed(1)}%',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: percent >= 90 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          statusText,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: on
                ? const Color(0xFF2E7D32)
                : alert
                    ? const Color(0xFFC62828)
                    : const Color(0xFFEF6C00),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Punch in ${formatAvailabilityClock(row['punchIn']?.toString(), withDate: true)}'
          '   ·   Punch out ${formatAvailabilityClock(row['punchOut']?.toString(), withDate: true)}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        AvailabilitySlotBar(segments: segments, height: compact ? 12 : 16),
        const SizedBox(height: 6),
        const AvailabilitySlotLegend(),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _statChip(theme, Icons.gps_fixed, 'Available', formatAvailabilityDuration(available), const Color(0xFF2E7D32)),
            _statChip(theme, Icons.gps_off, 'Off', formatAvailabilityDuration(unavailable), const Color(0xFFC62828)),
            _statChip(theme, Icons.cell_tower, 'Pings', '$pings', const Color(0xFFC5A059)),
            _statChip(theme, Icons.warning_amber, 'Gaps', '${row['gapCount'] ?? 0}', theme.colorScheme.tertiary),
            _statChip(
              theme,
              Icons.view_timeline_outlined,
              'Slots',
              '${segments.length}',
              theme.colorScheme.primary,
            ),
          ],
        ),
        if (lat != null && lng != null) ...[
          const SizedBox(height: 10),
          Text(
            'Last known ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
            '  ·  ${formatAvailabilityClock(row['lastKnownAt']?.toString(), withDate: true)}'
            '${age != null ? '  ·  ${formatAvailabilityDuration(age)} ago' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFFC5A059),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (compact && lastSeg != null) ...[
          const SizedBox(height: 10),
          Text(
            'Latest slot: ${lastSeg['status'] == 'AVAILABLE' ? 'Available' : 'Off'} '
            '${formatAvailabilityClock(lastSeg['start']?.toString())} → ${formatAvailabilityClock(lastSeg['end']?.toString())}'
            ' (${formatAvailabilityDuration((lastSeg['durationSeconds'] as num?)?.toInt() ?? 0)})'
            '${segments.length > 1 ? '  ·  ${segments.length} slots' : ''}',
            style: theme.textTheme.labelMedium,
          ),
        ],
        if (!compact) ...[
          const SizedBox(height: 18),
          Text(
            'All slots between punch-in and punch-out',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (segments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No availability slots for this day.')),
            )
          else
            ...segments.map(
              (raw) => AvailabilitySegmentCard(
                segment: Map<String, dynamic>.from(raw as Map),
              ),
            ),
        ],
      ],
    );
  }

  Widget _statChip(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              Text(
                value,
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
