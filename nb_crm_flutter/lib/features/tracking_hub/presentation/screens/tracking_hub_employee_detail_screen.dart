import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../providers.dart';
import '../widgets/location_availability_widgets.dart';

class TrackingHubEmployeeDetailScreen extends ConsumerStatefulWidget {
  const TrackingHubEmployeeDetailScreen({
    super.key,
    required this.employeeId,
    this.date,
  });

  final int employeeId;
  final String? date;

  @override
  ConsumerState<TrackingHubEmployeeDetailScreen> createState() =>
      _TrackingHubEmployeeDetailScreenState();
}

class _TrackingHubEmployeeDetailScreenState
    extends ConsumerState<TrackingHubEmployeeDetailScreen> {
  Timer? _refreshTimer;

  String get _date {
    if (widget.date != null && widget.date!.isNotEmpty) return widget.date!;
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  ({int employeeId, String date}) get _args =>
      (employeeId: widget.employeeId, date: _date);

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      ref.invalidate(employeeAvailabilityProvider(_args));
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(employeeAvailabilityProvider(_args));

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/admin/tracking-hub'),
        title: const Text('Location availability'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(employeeAvailabilityProvider(_args));
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (row) {
          final name =
              row['fullName']?.toString() ?? 'Employee #${widget.employeeId}';
          final code = row['employeeCode']?.toString();
          final designation = row['designation']?.toString();
          final department = row['department']?.toString();
          final on = isLocationCurrentlyOn(row);
          final alert = isLocationAlertActive(row);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(employeeAvailabilityProvider(_args));
              await ref.read(employeeAvailabilityProvider(_args).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (on)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Location is available. The unavailable alert is cleared.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else if (alert)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB71C1C),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Location is unavailable. This alert disappears automatically when GPS returns.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF6C00),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'GPS is quiet. Waiting to confirm before raising an alert.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Text(
                  name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (code != null && code.isNotEmpty)
                  Text(code, style: theme.textTheme.titleSmall),
                if (designation != null || department != null)
                  Text(
                    [designation, department]
                        .where((e) => e != null && e.isNotEmpty)
                        .join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: 4),
                Text('Date $_date', style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
                AvailabilityDetailsView(row: row),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    context.go(
                      '/admin/tracking-hub?date=$_date&employeeId=${widget.employeeId}',
                    );
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Tracking Hub'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
