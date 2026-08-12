import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../providers.dart';

class TrackingHubEmployeeDetailScreen extends ConsumerWidget {
  const TrackingHubEmployeeDetailScreen({
    super.key,
    required this.employeeId,
    this.date,
  });

  final int employeeId;
  final String? date;

  String get _date {
    if (date != null && date!.isNotEmpty) return date!;
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _formatSeconds(int seconds) {
    if (seconds <= 0) return '0m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String _formatLocal(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    return dt.toString().split('.').first;
  }

  String _reasonLabel(String? reason) {
    if (reason == null || reason.isEmpty) return 'Unknown';
    return reason.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(
      employeeAvailabilityProvider((employeeId: employeeId, date: _date)),
    );

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/admin/tracking-hub'),
        title: const Text('Location availability'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(
                employeeAvailabilityProvider((
                  employeeId: employeeId,
                  date: _date,
                )),
              );
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (row) {
          final available = (row['availableSeconds'] as num?)?.toInt() ?? 0;
          final unavailable =
              (row['unavailableSeconds'] as num?)?.toInt() ?? 0;
          final percent = (row['availablePercent'] as num?)?.toDouble() ?? 0;
          final segments = (row['segments'] as List<dynamic>? ?? const []);
          final name = row['fullName']?.toString() ?? 'Employee #$employeeId';
          final code = row['employeeCode']?.toString();
          final stillOnDuty = row['stillOnDuty'] == true;
          final total = available + unavailable;
          final availRatio = total > 0 ? available / total : 0.0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (code != null && code.isNotEmpty)
                Text(code, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                'Date $_date · ${stillOnDuty ? 'Still on duty' : 'Shift closed'}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Duty window',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Punch in:  ${_formatLocal(row['punchIn']?.toString())}'),
                      Text('Punch out: ${_formatLocal(row['punchOut']?.toString())}'),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 16,
                          child: Row(
                            children: [
                              if (availRatio > 0)
                                Expanded(
                                  flex: (availRatio * 1000).round().clamp(
                                    1,
                                    1000,
                                  ),
                                  child: Container(
                                    color: const Color(0xFF2E7D32),
                                  ),
                                ),
                              if (1 - availRatio > 0)
                                Expanded(
                                  flex: ((1 - availRatio) * 1000)
                                      .round()
                                      .clamp(1, 1000),
                                  child: Container(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _chip(
                            theme,
                            'Available ${_formatSeconds(available)}',
                            const Color(0xFF2E7D32),
                          ),
                          _chip(
                            theme,
                            'Not available ${_formatSeconds(unavailable)}',
                            theme.colorScheme.error,
                          ),
                          _chip(
                            theme,
                            '${percent.toStringAsFixed(1)}%',
                            percent >= 90
                                ? theme.colorScheme.primary
                                : theme.colorScheme.error,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Timeline between punch-in and punch-out',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (segments.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('No punch window / no segments for this day.'),
                    ),
                  ),
                )
              else
                ...segments.map((raw) {
                  final seg = Map<String, dynamic>.from(raw as Map);
                  final availableSeg = seg['status'] == 'AVAILABLE';
                  final color = availableSeg
                      ? const Color(0xFF2E7D32)
                      : theme.colorScheme.error;
                  final duration =
                      (seg['durationSeconds'] as num?)?.toInt() ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        availableSeg ? Icons.gps_fixed : Icons.gps_off,
                        color: color,
                      ),
                      title: Text(
                        availableSeg ? 'Location available' : 'Location not available',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      subtitle: Text(
                        '${_formatLocal(seg['start']?.toString())} → ${_formatLocal(seg['end']?.toString())}\n'
                        'Duration: ${_formatSeconds(duration)}'
                        '${availableSeg ? '' : '\nReason: ${_reasonLabel(seg['reason']?.toString())}'
                            '${seg['confidence'] != null ? ' (${seg['confidence']})' : ''}'}',
                      ),
                      isThreeLine: true,
                    ),
                  );
                }),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  context.go(
                    '/admin/tracking-hub?date=$_date&employeeId=$employeeId',
                  );
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Tracking Hub'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(ThemeData theme, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
